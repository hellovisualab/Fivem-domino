-- Dominó Boricua: cliente (mesas, sillas, interacción y NUI)

DominoCL = {
    Mesas = {},       -- [id] = { cfg, center, heading, groundZ, top, halfW, halfD, objects, ... }
    sitting = nil,    -- { tableId, seat }
    uiOpen = false,   -- ventana de la mesa abierta
    adminOpen = false,
}

local Mesas = DominoCL.Mesas
local viewTable = nil
local lastTurnNotified = -1
local nuiReady = false

-- Sillas en contra de las manecillas del reloj: 1 abajo, 2 derecha, 3 arriba, 4 izquierda
local SEAT_LOCAL = {
    { 0.0, -1.0, 0.0 },
    { 1.0, 0.0, 90.0 },
    { 0.0, 1.0, 180.0 },
    { -1.0, 0.0, 270.0 },
}

function DominoCL.rotate(x, y, heading)
    local r = math.rad(heading)
    return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end

-- Sirve pa' mesas de verdad y pa' la mesa fantasma del modo colocar
function DominoCL.seatPosition(mesa, seat)
    local o = SEAT_LOCAL[seat]
    local d = Config.Props.seatDistance
    if mesa.halfW then
        local half = (seat % 2 == 1) and mesa.halfD or mesa.halfW
        d = half + Config.Props.chairGap
    end
    local ox, oy = DominoCL.rotate(o[1] * d, o[2] * d, mesa.heading)
    return vector3(mesa.center.x + ox, mesa.center.y + oy, mesa.groundZ), (mesa.heading + o[3]) % 360.0
end

function DominoCL.loadModel(model)
    if not model then return nil end
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

-- Mide la superficie de la mesa pa' poner las sillas y las fichas donde van
function DominoCL.measure(target, hash)
    local minDim, maxDim = GetModelDimensions(hash)
    target.halfW = math.max(0.2, (maxDim.x - minDim.x) / 2)
    target.halfD = math.max(0.2, (maxDim.y - minDim.y) / 2)
    return maxDim.z
end

function DominoCL.chairFor(tableModel, chairModel)
    if chairModel and IsModelInCdimage(GetHashKey(chairModel)) then return chairModel end
    for _, preset in ipairs(Config.Props.tableModels) do
        if preset.model == tableModel and preset.chair and IsModelInCdimage(GetHashKey(preset.chair)) then
            return preset.chair
        end
    end
    return Config.Props.chair
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
    local tableModel = mesa.cfg.tableModel or Config.Props.table
    local tableHash = DominoCL.loadModel(tableModel) or DominoCL.loadModel(Config.Props.table)
    if tableHash then
        local obj = spawnObject(tableHash, mesa.center, mesa.heading)
        local topOffset = DominoCL.measure(mesa, tableHash)
        local z = GetEntityCoords(obj).z
        mesa.groundZ = z
        mesa.top = z + topOffset
        mesa.objects[#mesa.objects + 1] = obj
        SetModelAsNoLongerNeeded(tableHash)
    end
    local chairHash = DominoCL.loadModel(DominoCL.chairFor(tableModel, mesa.cfg.chairModel))
    if chairHash then
        for seat = 1, 4 do
            local pos, heading = DominoCL.seatPosition(mesa, seat)
            mesa.objects[#mesa.objects + 1] = spawnObject(chairHash, pos, heading + Config.Props.chairHeadingOffset)
        end
        SetModelAsNoLongerNeeded(chairHash)
    end
    mesa.propsReady = true
end

local function deleteProps(mesa)
    for _, obj in ipairs(mesa.objects) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    mesa.objects = {}
    mesa.propsReady = false
end

-- ------------------------------------------------------------
-- NUI
-- ------------------------------------------------------------

function DominoCL.refreshFocus()
    local focus = DominoCL.uiOpen or DominoCL.adminOpen
    SetNuiFocus(focus, focus)
end

function DominoCL.initNui()
    if nuiReady then return end
    nuiReady = true
    SendNUIMessage({ action = 'init', phrases = Config.Phrases })
end

local function setUI(open)
    DominoCL.uiOpen = open
    DominoCL.refreshFocus()
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
    DominoCL.initNui()
    viewTable = state.id
    SendNUIMessage({ action = 'state', state = state })
    if state.open and not DominoCL.uiOpen then setUI(true) end

    -- Aviso cuando te toca y tienes la mesa cerrada
    local g = state.game
    if DominoCL.sitting and not DominoCL.uiOpen and g and state.phase == 'playing' and g.turn == state.mySeat
        and g.actionId ~= lastTurnNotified then
        lastTurnNotified = g.actionId
        Bridge.Notify(L('your_turn'), 'info')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end)

RegisterNetEvent('domino_boricua:client:phrase', function(seat, index)
    SendNUIMessage({ action = 'phrase', seat = seat, index = index })
end)

-- La mesa que estabas mirando ya no existe
RegisterNetEvent('domino_boricua:client:closed', function(id)
    if viewTable ~= id then return end
    viewTable = nil
    if DominoCL.uiOpen then setUI(false) end
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    if not DominoCL.sitting then
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
    if not DominoCL.sitting then return end
    DominoCL.sitting = nil
    ClearPedTasks(PlayerPedId())
end

RegisterNetEvent('domino_boricua:client:sit', function(tableId, seat)
    local mesa = Mesas[tableId]
    if not mesa then return end
    local ped = PlayerPedId()
    local pos, heading = DominoCL.seatPosition(mesa, seat)
    if DominoCL.sitting then ClearPedTasksImmediately(ped) end
    local sitting = { tableId = tableId, seat = seat }
    DominoCL.sitting = sitting
    TaskStartScenarioAtPosition(ped, Config.Props.sitScenario, pos.x, pos.y, pos.z + Config.Props.sitZOffset,
        heading, 0, true, true)

    CreateThread(function()
        local since = GetGameTimer()
        while DominoCL.sitting == sitting do
            -- no dejar que se levante caminando por accidente
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 44, true)

            if not DominoCL.uiOpen and not DominoCL.adminOpen then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(L('seated_help'))
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustReleased(0, Config.InteractKey) then
                    openTable(tableId)
                elseif IsControlJustReleased(0, Config.StandKey) then
                    TriggerServerEvent('domino_boricua:server:stand')
                end
            end

            -- si muere o lo sacan de la silla (tp, admin...), se levanta de la mesa
            local p = PlayerPedId()
            local moved = GetGameTimer() - since > 3000 and #(GetEntityCoords(p) - pos) > 5.0
            if IsEntityDead(p) or moved then
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
-- Mesas: blips, target y props por cercanía
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

local function addMesa(cfg)
    local c = cfg.coords
    local mesa = {
        cfg = cfg,
        center = vector3(c.x, c.y, c.z),
        heading = c.w or 0.0,
        groundZ = c.z,
        -- sin prop (mesa del mapa) se usan las medidas de Config.World
        top = c.z + Config.World.tableHeight,
        halfW = Config.World.tableSize / 2,
        halfD = Config.World.tableSize / 2,
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

local function removeMesa(id)
    local mesa = Mesas[id]
    if not mesa then return end
    deleteProps(mesa)
    if mesa.blip then RemoveBlip(mesa.blip) end
    if mesa.targetMode == 'ox_target' and mesa.zone then
        exports.ox_target:removeZone(mesa.zone)
    elseif mesa.targetMode == 'qb-target' and mesa.zone then
        exports['qb-target']:RemoveZone(mesa.zone)
    end
    if DominoCL.clearWorld then DominoCL.clearWorld(id) end
    Mesas[id] = nil
end

local function sameCfg(a, b)
    return a.label == b.label and a.blip == b.blip and a.spawnProps == b.spawnProps
        and a.tableModel == b.tableModel and a.chairModel == b.chairModel
        and a.coords.x == b.coords.x and a.coords.y == b.coords.y
        and a.coords.z == b.coords.z and a.coords.w == b.coords.w
end

-- El servidor manda la lista completa cada vez que un admin crea o borra una mesa
RegisterNetEvent('domino_boricua:client:tables', function(list)
    local seen = {}
    for _, cfg in ipairs(list) do
        seen[cfg.id] = true
        local mesa = Mesas[cfg.id]
        if mesa and not sameCfg(mesa.cfg, cfg) then
            removeMesa(cfg.id)
            mesa = nil
        end
        if not mesa then addMesa(cfg) end
    end
    for id in pairs(Mesas) do
        if not seen[id] then removeMesa(id) end
    end
end)

RegisterNetEvent('domino_boricua:client:teleport', function(coords)
    local ped = PlayerPedId()
    local ox, oy = DominoCL.rotate(0.0, -2.4, coords.w or 0.0)
    SetEntityCoords(ped, coords.x + ox, coords.y + oy, coords.z + 0.5, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
end)

CreateThread(function()
    TriggerServerEvent('domino_boricua:server:tables')

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
        if not DominoCL.sitting and not DominoCL.uiOpen and not DominoCL.adminOpen then
            local pos = GetEntityCoords(PlayerPedId())
            for id, mesa in pairs(Mesas) do
                if mesa.useKey then
                    local dist = #(pos - mesa.center)
                    if dist < 12.0 then
                        sleep = 0
                        if dist <= Config.InteractDistance then
                            drawText3D(vector3(mesa.center.x, mesa.center.y, mesa.top + 0.35), L('press_to_open'))
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
    if DominoCL.sitting then return openTable(DominoCL.sitting.tableId) end
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
    for id in pairs(Mesas) do removeMesa(id) end
    if DominoCL.sitting then standUp() end
    SetNuiFocus(false, false)
end)
