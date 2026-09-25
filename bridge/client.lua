-- Puente de frameworks (cliente): solo notificaciones y detección de target.

Bridge = {}

local function isRunning(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local framework
function Bridge.GetFramework()
    if not framework or framework == 'standalone' then
        local forced = Config.Framework
        if forced and forced ~= 'auto' then
            framework = forced
        elseif isRunning('qbx_core') then
            framework = 'qbox'
        elseif isRunning('qb-core') then
            framework = 'qbcore'
        elseif isRunning('es_extended') then
            framework = 'esx'
        else
            framework = 'standalone'
        end
    end
    return framework
end

function Bridge.GetTarget()
    local mode = Config.Target
    if mode == 'none' then return nil end
    if mode == 'auto' then
        if isRunning('ox_target') then return 'ox_target' end
        if isRunning('qb-target') then return 'qb-target' end
        return nil
    end
    return isRunning(mode) and mode or nil
end

-- kind: 'success' | 'error' | 'info'
function Bridge.Notify(msg, kind)
    kind = kind or 'info'
    local fw = Bridge.GetFramework()
    if fw == 'qbcore' then
        TriggerEvent('QBCore:Notify', msg, kind == 'info' and 'primary' or kind)
    elseif fw == 'qbox' then
        exports.qbx_core:Notify(msg, kind == 'info' and 'inform' or kind)
    elseif fw == 'esx' then
        TriggerEvent('esx:showNotification', msg, kind)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

RegisterNetEvent('domino_boricua:client:notify', function(msg, kind)
    Bridge.Notify(msg, kind)
end)
