-- Puente de frameworks (servidor): QBCore, Qbox, ESX o standalone.

Bridge = {}

local QBCore, ESX

local function isRunning(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function detectFramework()
    local forced = Config.Framework
    if forced and forced ~= 'auto' then return forced end
    -- Qbox primero: qbx_core también responde como qb-core
    if isRunning('qbx_core') then return 'qbox' end
    if isRunning('qb-core') then return 'qbcore' end
    if isRunning('es_extended') then return 'esx' end
    return 'standalone'
end

-- Se detecta la primera vez que se usa, así no importa el orden de arranque de los recursos.
local framework
function Bridge.GetFramework()
    if not framework or framework == 'standalone' then
        framework = detectFramework()
    end
    return framework
end

local function core()
    if Bridge.GetFramework() == 'qbcore' and not QBCore then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif Bridge.GetFramework() == 'esx' and not ESX then
        ESX = exports['es_extended']:getSharedObject()
    end
end

local function account()
    local acc = Config.Betting.account or 'cash'
    if Bridge.GetFramework() == 'esx' and acc == 'cash' then return 'money' end
    return acc
end

local function getPlayer(src)
    core()
    local fw = Bridge.GetFramework()
    if fw == 'qbcore' then
        return QBCore.Functions.GetPlayer(src)
    elseif fw == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    elseif fw == 'esx' then
        return ESX.GetPlayerFromId(src)
    end
    return nil
end

function Bridge.CanBet()
    return Config.Betting.enabled and Bridge.GetFramework() ~= 'standalone'
end

function Bridge.GetName(src)
    local fw = Bridge.GetFramework()
    local ok, name = pcall(function()
        local player = getPlayer(src)
        if not player then return nil end
        if fw == 'qbcore' or fw == 'qbox' then
            local info = player.PlayerData and player.PlayerData.charinfo
            if info then return ('%s %s'):format(info.firstname, info.lastname) end
        elseif fw == 'esx' then
            return player.getName()
        end
    end)
    if ok and name and name ~= '' then return name end
    return GetPlayerName(src) or ('Jugador ' .. tostring(src))
end

function Bridge.GetMoney(src)
    local fw = Bridge.GetFramework()
    local ok, amount = pcall(function()
        local player = getPlayer(src)
        if not player then return 0 end
        if fw == 'qbcore' or fw == 'qbox' then
            return player.PlayerData.money[account()] or 0
        elseif fw == 'esx' then
            local acc = player.getAccount(account())
            return acc and acc.money or 0
        end
        return 0
    end)
    return ok and tonumber(amount) or 0
end

function Bridge.RemoveMoney(src, amount, reason)
    if amount <= 0 then return true end
    if Bridge.GetMoney(src) < amount then return false end
    local fw = Bridge.GetFramework()
    local ok, result = pcall(function()
        if fw == 'qbox' then
            return exports.qbx_core:RemoveMoney(src, account(), amount, reason)
        end
        local player = getPlayer(src)
        if not player then return false end
        if fw == 'qbcore' then
            return player.Functions.RemoveMoney(account(), amount, reason)
        elseif fw == 'esx' then
            player.removeAccountMoney(account(), amount, reason)
            return true
        end
        return false
    end)
    return ok and result ~= false
end

function Bridge.AddMoney(src, amount, reason)
    if amount <= 0 then return true end
    local fw = Bridge.GetFramework()
    local ok, result = pcall(function()
        if fw == 'qbox' then
            return exports.qbx_core:AddMoney(src, account(), amount, reason)
        end
        local player = getPlayer(src)
        if not player then return false end
        if fw == 'qbcore' then
            return player.Functions.AddMoney(account(), amount, reason)
        elseif fw == 'esx' then
            player.addAccountMoney(account(), amount, reason)
            return true
        end
        return false
    end)
    return ok and result ~= false
end

-- Admin: permisos ACE (command.dominoadmin / dominoboricua.admin) o grupos del framework
function Bridge.IsAdmin(src)
    if src == 0 then return true end
    for _, ace in ipairs(Config.Admin.aces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    local fw = Bridge.GetFramework()
    local ok, result = pcall(function()
        core()
        if fw == 'qbcore' then
            for _, group in ipairs(Config.Admin.groups) do
                if QBCore.Functions.HasPermission(src, group) then return true end
            end
        elseif fw == 'esx' then
            local player = ESX.GetPlayerFromId(src)
            local group = player and player.getGroup()
            for _, allowed in ipairs(Config.Admin.groups) do
                if group == allowed then return true end
            end
        end
        return false
    end)
    return ok and result == true
end

-- kind: 'success' | 'error' | 'info'
function Bridge.Notify(src, msg, kind)
    TriggerClientEvent('domino_boricua:client:notify', src, msg, kind or 'info')
end
