-- Dominó Boricua: cliente (props, sillas, interacción y NUI)

local Mesas = {}          -- [id] = { cfg, center, heading, groundZ, objects, zone, useKey }
local uiOpen = false
local viewTable = nil     -- mesa que se está mirando en la NUI
local sitting = nil       -- { tableId, seat }
local lastTurnNotified = -1
local nuiReady = false

-- Sillas en contra de las manecillas del reloj: 1 abajo, 2 derecha, 3 arriba, 4 izquierda
local SEAT_LOCAL = {
    { 0.0, -1.0, 0.0 },
    { 1.0, 0.0, 90.0 },
    { 0.0, 1.0, 180.0 },
    { -1.0, 0.0, 270.0 },
}

local function rotate(x, y, heading)
    local r = math.rad(heading)
    return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end

local function seatPosition(mesa, seat)
    local o = SEAT_LOCAL[seat]
    local d = Config.Props.seatDistance
    local ox, oy = rotate(o[1] * d, o[2] * d, mesa.heading)
    return vector3(mesa.center.x + ox, mesa.center.y + oy, mesa.groundZ), (mesa.heading + o[3]) % 360.0
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

local function spawnObject(hash, pos, heading)
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(obj, heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    return obj
end

local function spawnProps(mesa)
    local tableHash = loadModel(mesa.cfg.tableModel or Config.Props.table)
    if tableHash then
        local obj = spawnObject(tableHash, mesa.center, mesa.heading)
        mesa.groundZ = GetEntityCoords(obj).z
        mesa.objects[#mesa.objects + 1] = obj
        SetModelAsNoLongerNeeded(tableHash)
    end
    local chairHash = loadModel(mesa.cfg.chairModel or Config.Props.chair)
    if chairHash then
        for seat = 1, 4 do
            local pos, heading = seatPosition(mesa, seat)
            local obj = spawnObject(chairHash, pos, heading + Config.Props.chairHeadingOffset)
            mesa.objects[#mesa.objects + 1] = obj
        end
        SetModelAsNoLongerNeeded(chairHash)
    end
end

local function deleteProps(mesa)
    for _, obj in ipairs(mesa.objects) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    mesa.objects = {}
end

-- ------------------------------------------------------------
-- NUI
-- ------------------------------------------------------------

local function setUI(open)
    uiOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = open and 'open' or 'close' })
end

local function openTable(id)
    TriggerServerEvent('domino_boricua:server:open', id)
end

local function nearestTable(maxDist)
    local pos = GetEntityCoords(PlayerPedId())
    local bestId, bestDist
    for id, mesa in pairs(Mesas) do
        local dist = #(pos - mesa.center)
        if dist <= maxDist and (not bestDist or dist < bestDist) then
            bestId, bestDist = id, dist
        end
    end
    return bestId
end

RegisterNetEvent('domino_boricua:client:state', function(state)
    if not nuiReady then
        nuiReady = true
        SendNUIMessage({ action = 'init', phrases = Config.Phrases })
    end
    viewTable = state.id
    SendNUIMessage({ action = 'state', state = state })
    if state.open and not uiOpen then setUI(true) end

    -- Aviso cuando te toca y tienes la mesa cerrada
    local g = state.game
    if sitting and not uiOpen and g and state.phase == 'playing' and g.turn == state.mySeat
        and g.actionId ~= lastTurnNotified then
        lastTurnNotified = g.actionId
        Bridge.Notify(L('your_turn'), 'info')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end)

RegisterNetEvent('domino_boricua:client:phrase', function(seat, index)
    SendNUIMessage({ action = 'phrase', seat = seat, index = index })
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    if not sitting then
        TriggerServerEvent('domino_boricua:server:close')
        viewTable = nil
    end
    cb('ok')
end)

RegisterNUICallback('sit', function(data, cb)
    if viewTable then TriggerServerEvent('domino_boricua:server:sit', viewTable, tonumber(data.seat)) end
    cb('ok')
end)

RegisterNUICallback('stand', function(_, cb)
    TriggerServerEvent('domino_boricua:server:stand')
    cb('ok')
end)

RegisterNUICallback('settings', function(data, cb)
    TriggerServerEvent('domino_boricua:server:settings', data)
    cb('ok')
end)

RegisterNUICallback('start', function(_, cb)
    TriggerServerEvent('domino_boricua:server:start')
    cb('ok')
end)

RegisterNUICallback('play', function(data, cb)
    TriggerServerEvent('domino_boricua:server:play', data)
    cb('ok')
end)

RegisterNUICallback('phrase', function(data, cb)
    TriggerServerEvent('domino_boricua:server:phrase', tonumber(data.index))
    cb('ok')
end)

RegisterNUICallback('rematch', function(_, cb)
    TriggerServerEvent('domino_boricua:server:rematch')
    cb('ok')
end)

-- ------------------------------------------------------------
-- Sentarse / levantarse
-- ------------------------------------------------------------

local function standUp()
    if not sitting then return end
    sitting = nil
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

RegisterNetEvent('domino_boricua:client:sit', function(tableId, seat)
    local mesa = Mesas[tableId]
    if not mesa then return end
    local ped = PlayerPedId()
    local pos, heading = seatPosition(mesa, seat)
    if sitting then ClearPedTasksImmediately(ped) end
    sitting = { tableId = tableId, seat = seat }
    TaskStartScenarioAtPosition(ped, Config.Props.sitScenario, pos.x, pos.y, pos.z + Config.Props.sitZOffset,
        heading, 0, true, true)

    CreateThread(function()
        local since = GetGameTimer()
        while sitting and sitting.tableId == tableId and sitting.seat == seat do
            -- no dejar que se levante caminando por accidente
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 44, true)

            if not uiOpen then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(L('seated_help'))
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustReleased(0, Config.InteractKey) then
                    openTable(tableId)
                elseif IsControlJustReleased(0, Config.StandKey) then
                    TriggerServerEvent('domino_boricua:server:stand')
                end
            end

            local ped = PlayerPedId()
            -- si muere o lo sacan de la silla (tp, admin...), se levanta de la mesa
            local moved = GetGameTimer() - since > 3000 and #(GetEntityCoords(ped) - pos) > 5.0
            if IsEntityDead(ped) or moved then
                TriggerServerEvent('domino_boricua:server:stand')
                break
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('domino_boricua:client:stand', function()
    standUp()
end)

-- ------------------------------------------------------------
-- Mesas: blips, target, props por cercanía
-- ------------------------------------------------------------

local function drawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function setupInteraction(id, mesa)
    local mode = Bridge.GetTarget()
    local coords = vector3(mesa.center.x, mesa.center.y, mesa.center.z + 0.6)
    local zoneName = 'domino_boricua_' .. id

    if mode == 'ox_target' then
        mesa.zone = exports.ox_target:addSphereZone({
            coords = coords,
            radius = 1.6,
            debug = Config.Debug,
            options = {
                {
                    name = zoneName,
                    icon = 'fa-solid fa-table-cells-large',
                    label = L('target_label'),
                    distance = Config.InteractDistance + 0.5,
                    onSelect = function() openTable(id) end,
                },
            },
        })
    elseif mode == 'qb-target' then
        exports['qb-target']:AddCircleZone(zoneName, coords, 1.6, {
            name = zoneName,
            debugPoly = Config.Debug,
            useZ = true,
        }, {
            options = {
                {
                    icon = 'fas fa-table-cells-large',
                    label = L('target_label'),
                    action = function() openTable(id) end,
                },
            },
            distance = Config.InteractDistance + 0.5,
        })
        mesa.zone = zoneName
    else
        mesa.useKey = true
    end
    mesa.targetMode = mode
end

CreateThread(function()
    for _, cfg in ipairs(Config.Tables) do
        local c = cfg.coords
        local mesa = {
            cfg = cfg,
            center = vector3(c.x, c.y, c.z),
            heading = c.w or 0.0,
            groundZ = c.z,
            objects = {},
        }
        Mesas[cfg.id] = mesa

        if Config.Blip.enabled and cfg.blip ~= false then
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(cfg.label or Config.Blip.label)
            EndTextCommandSetBlipName(blip)
            mesa.blip = blip
        end

        setupInteraction(cfg.id, mesa)
    end

    -- Crear/borrar props según la distancia
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, mesa in pairs(Mesas) do
            if Config.Props.spawn and mesa.cfg.spawnProps ~= false then
                local dist = #(pos - mesa.center)
                if dist < Config.Props.spawnDistance and #mesa.objects == 0 then
                    spawnProps(mesa)
                elseif dist > Config.Props.spawnDistance + 15.0 and #mesa.objects > 0 then
                    deleteProps(mesa)
                end
            end
        end
        Wait(1500)
    end
end)

-- Interacción con tecla E cuando no hay target
CreateThread(function()
    while true do
        local sleep = 1000
        if not sitting and not uiOpen then
            local pos = GetEntityCoords(PlayerPedId())
            for id, mesa in pairs(Mesas) do
                if mesa.useKey then
                    local dist = #(pos - mesa.center)
                    if dist < 12.0 then
                        sleep = 0
                        if dist <= Config.InteractDistance then
                            drawText3D(vector3(mesa.center.x, mesa.center.y, mesa.groundZ + 1.1), L('press_to_open'))
                            if IsControlJustReleased(0, Config.InteractKey) then openTable(id) end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ------------------------------------------------------------
-- Comandos
-- ------------------------------------------------------------

RegisterCommand(Config.OpenCommand, function()
    if sitting then return openTable(sitting.tableId) end
    local id = nearestTable(Config.InteractDistance + 1.5)
    if id then
        openTable(id)
    else
        Bridge.Notify(L('no_table_near'), 'error')
    end
end, false)

if Config.OpenKey and Config.OpenKey ~= '' then
    RegisterKeyMapping(Config.OpenCommand, 'Abrir la mesa de dominó', 'keyboard', Config.OpenKey)
end

RegisterCommand(Config.CoordsCommand, function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local line = ('coords = vector4(%.2f, %.2f, %.2f, %.1f),'):format(c.x, c.y, c.z - 1.0, GetEntityHeading(ped))
    print(line)
    Bridge.Notify(L('coords_copied', line), 'info')
end, false)

-- ------------------------------------------------------------
-- Limpieza
-- ------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, mesa in pairs(Mesas) do
        deleteProps(mesa)
        if mesa.blip then RemoveBlip(mesa.blip) end
        if mesa.targetMode == 'ox_target' and mesa.zone then
            exports.ox_target:removeZone(mesa.zone)
        elseif mesa.targetMode == 'qb-target' and mesa.zone then
            exports['qb-target']:RemoveZone(mesa.zone)
        end
    end
    if sitting then standUp() end
    if uiOpen then SetNuiFocus(false, false) end
end)
