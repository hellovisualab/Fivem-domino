-- Panel de admin: lista de mesas y modo colocar con una mesa fantasma.

local placing = nil

local function setAdmin(open)
    DominoCL.adminOpen = open
    DominoCL.refreshFocus()
    SendNUIMessage({ action = open and 'adminOpen' or 'adminClose' })
end

local function presetFor(model)
    for _, preset in ipairs(Config.Props.tableModels) do
        if preset.model == model then return preset end
    end
    return nil
end

RegisterNetEvent('domino_boricua:client:admin', function(data)
    DominoCL.initNui()
    -- solo los modelos que existen en este build del juego
    local models = {}
    for _, preset in ipairs(data.models or {}) do
        if IsModelInCdimage(GetHashKey(preset.model)) then models[#models + 1] = preset end
    end
    data.models = models
    SendNUIMessage({ action = 'admin', data = data })
    if data.open and not placing then setAdmin(true) end
end)

-- ------------------------------------------------------------
-- Modo colocar
-- ------------------------------------------------------------

local function raycast(distance)
    local camPos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dx = -math.sin(rz) * math.abs(math.cos(rx))
    local dy = math.cos(rz) * math.abs(math.cos(rx))
    local dz = math.sin(rx)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z,
        camPos.x + dx * distance, camPos.y + dy * distance, camPos.z + dz * distance, 1, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(handle)
    return hit == 1 or hit == true, coords
end

local function ghost(hash)
    local obj = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(obj, 170, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    return obj
end

local function stopPlacement()
    if not placing then return end
    for _, obj in ipairs(placing.objects) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    placing = nil
    SendNUIMessage({ action = 'placement', show = false })
end

local CONTROLS = { 14, 15, 16, 17, 24, 25, 37, 38, 44, 45, 140, 141, 142, 177, 199, 200, 257, 263 }

local function startPlacement(model)
    local preset = presetFor(model) or Config.Props.tableModels[1]
    local tableHash = DominoCL.loadModel(preset.model) or DominoCL.loadModel(Config.Props.table)
    if not tableHash then return setAdmin(true) end
    local chairHash = DominoCL.loadModel(DominoCL.chairFor(preset.model, preset.chair))

    local mesa = { center = vector3(0.0, 0.0, 0.0), heading = GetEntityHeading(PlayerPedId()), groundZ = 0.0 }
    DominoCL.measure(mesa, tableHash)

    local objects = { ghost(tableHash) }
    if chairHash then
        for _ = 1, 4 do objects[#objects + 1] = ghost(chairHash) end
    end

    placing = { model = preset.model, mesa = mesa, objects = objects, valid = false }
    SendNUIMessage({ action = 'placement', show = true, heading = mesa.heading, valid = false, label = preset.label })

    CreateThread(function()
        local lastSent = -1
        while placing do
            for _, control in ipairs(CONTROLS) do DisableControlAction(0, control, true) end

            -- girar: rueda del mouse (Shift = fino) o Q / E sostenido
            local step = IsControlPressed(0, 21) and 1.0 or 7.5
            if IsDisabledControlJustPressed(0, 14) then mesa.heading = mesa.heading - step end
            if IsDisabledControlJustPressed(0, 15) then mesa.heading = mesa.heading + step end
            if IsDisabledControlPressed(0, 44) then mesa.heading = mesa.heading + 1.5 end
            if IsDisabledControlPressed(0, 38) then mesa.heading = mesa.heading - 1.5 end
            mesa.heading = mesa.heading % 360.0

            local hit, coords = raycast(15.0)
            local ped = PlayerPedId()
            placing.valid = hit and #(GetEntityCoords(ped) - coords) < 12.0
            if hit then
                mesa.center = coords
                mesa.groundZ = coords.z
                SetEntityCoords(objects[1], coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityHeading(objects[1], mesa.heading)
                for seat = 1, 4 do
                    local chair = objects[seat + 1]
                    if chair then
                        local pos, heading = DominoCL.seatPosition(mesa, seat)
                        SetEntityCoords(chair, pos.x, pos.y, pos.z, false, false, false, false)
                        SetEntityHeading(chair, heading + Config.Props.chairHeadingOffset)
                    end
                end
                local alpha = placing.valid and 190 or 90
                for _, obj in ipairs(objects) do SetEntityAlpha(obj, alpha, false) end
            end

            local rounded = math.floor(mesa.heading + 0.5)
            local key = rounded + (placing.valid and 1000 or 0)
            if key ~= lastSent then
                lastSent = key
                SendNUIMessage({ action = 'placement', show = true, heading = rounded, valid = placing.valid })
            end

            if placing.valid and (IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 191)) then
                local result = {
                    x = mesa.center.x, y = mesa.center.y, z = mesa.groundZ, w = mesa.heading,
                }
                local chosen = placing.model
                stopPlacement()
                SendNUIMessage({ action = 'adminForm', coords = result, model = chosen })
                setAdmin(true)
                break
            elseif IsDisabledControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 177)
                or IsDisabledControlJustPressed(0, 200) then
                stopPlacement()
                setAdmin(true)
                break
            end
            Wait(0)
        end
    end)
end

-- ------------------------------------------------------------
-- Callbacks de la NUI
-- ------------------------------------------------------------

RegisterNUICallback('adminClose', function(_, cb)
    setAdmin(false)
    cb('ok')
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    TriggerServerEvent('domino_boricua:admin:refresh')
    cb('ok')
end)

RegisterNUICallback('adminPlace', function(data, cb)
    setAdmin(false)
    CreateThread(function() startPlacement(data.model) end)
    cb('ok')
end)

RegisterNUICallback('adminCreate', function(data, cb)
    if type(data) == 'table' and type(data.coords) == 'table' then
        TriggerServerEvent('domino_boricua:admin:create', {
            coords = data.coords,
            label = data.label,
            minBet = tonumber(data.minBet),
            maxBet = tonumber(data.maxBet),
            model = data.model,
            blip = data.blip ~= false,
        })
    end
    cb('ok')
end)

RegisterNUICallback('adminDelete', function(data, cb)
    TriggerServerEvent('domino_boricua:admin:delete', data.id)
    cb('ok')
end)

RegisterNUICallback('adminReset', function(data, cb)
    TriggerServerEvent('domino_boricua:admin:reset', data.id)
    cb('ok')
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    setAdmin(false)
    TriggerServerEvent('domino_boricua:admin:teleport', data.id)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopPlacement()
end)
