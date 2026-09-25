-- Panel de administración: crear, borrar, reiniciar mesas e ir a ellas.
-- Todo se valida aquí; el cliente solo manda lo que el admin escogió.

local A = Config.Admin

local function notify(src, kind, key, ...)
    Bridge.Notify(src, L(key, ...), kind)
end

local function modelPreset(model)
    for _, preset in ipairs(Config.Props.tableModels) do
        if preset.model == model then return preset end
    end
    return Config.Props.tableModels[1]
end

local function adminList()
    local list = {}
    for _, tbl in ipairs(DominoTables.all()) do
        local cfg = tbl.cfg
        local bots = 0
        for i = 1, 4 do
            if tbl.seats[i] and tbl.seats[i].kind == 'bot' then bots = bots + 1 end
        end
        list[#list + 1] = {
            id = cfg.id,
            label = cfg.label,
            coords = cfg.coords,
            dynamic = cfg.dynamic == true,
            phase = tbl.phase,
            humans = #DominoTables.humans(tbl),
            bots = bots,
            minBet = cfg.minBet or 0,
            maxBet = cfg.maxBet or 0,
            tableModel = cfg.tableModel or Config.Props.table,
            createdBy = cfg.createdBy,
        }
    end
    return list
end

local function sendPanel(src, open)
    TriggerClientEvent('domino_boricua:client:admin', src, {
        open = open == true,
        tables = adminList(),
        models = Config.Props.tableModels,
        maxBet = A.maxBet,
    })
end

local function cleanLabel(label)
    label = tostring(label or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #label == 0 then label = 'Mesa de dominó' end
    local ok, cut = pcall(utf8.offset, label, 33)
    if ok and cut then label = label:sub(1, cut - 1) end
    return label
end

local function number(v, min, max)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.max(min, math.min(max, v))
end

RegisterCommand(A.command, function(src)
    if src == 0 then return print('[domino-boricua] usa este comando dentro del juego') end
    if not Bridge.IsAdmin(src) then return notify(src, 'error', 'no_perms') end
    sendPanel(src, true)
end, false)

RegisterNetEvent('domino_boricua:admin:refresh', function()
    local src = source
    if Bridge.IsAdmin(src) then sendPanel(src, false) end
end)

RegisterNetEvent('domino_boricua:admin:create', function(data)
    local src = source
    if not Bridge.IsAdmin(src) or type(data) ~= 'table' or type(data.coords) ~= 'table' then return end

    local x = number(data.coords.x, -9000, 9000)
    local y = number(data.coords.y, -9000, 9000)
    local z = number(data.coords.z, -200, 2000)
    local w = number(data.coords.w, -36000, 36000)
    if not (x and y and z and w) then return end

    for _, tbl in ipairs(DominoTables.all()) do
        local c = tbl.cfg.coords
        local dx, dy = c.x - x, c.y - y
        if math.sqrt(dx * dx + dy * dy) < A.minDistance and math.abs(c.z - z) < 3.0 then
            return notify(src, 'error', 'too_close')
        end
    end

    local minBet = math.floor(number(data.minBet, 0, A.maxBet) or 0)
    local maxBet = math.floor(number(data.maxBet, 0, A.maxBet) or 0)
    if minBet > maxBet then minBet, maxBet = maxBet, minBet end
    local preset = modelPreset(data.model)

    local id
    repeat
        id = ('mesa_%d_%d'):format(os.time(), math.random(1000, 9999))
    until not DominoTables.get(id)

    DominoTables.add({
        id = id,
        label = cleanLabel(data.label),
        coords = { x = x, y = y, z = z, w = w % 360.0 },
        blip = data.blip ~= false,
        spawnProps = true,
        minBet = minBet,
        maxBet = maxBet,
        tableModel = preset.model,
        chairModel = preset.chair,
        dynamic = true,
        createdBy = Bridge.GetName(src),
        createdAt = os.time(),
    })
    notify(src, 'success', 'table_created', cleanLabel(data.label))
    sendPanel(src, false)
end)

RegisterNetEvent('domino_boricua:admin:delete', function(id)
    local src = source
    if not Bridge.IsAdmin(src) then return end
    local tbl = DominoTables.get(id)
    if not tbl then return end
    if not tbl.cfg.dynamic then return notify(src, 'error', 'config_table') end
    local label = tbl.cfg.label
    DominoTables.remove(id)
    notify(src, 'success', 'table_deleted', label)
    sendPanel(src, false)
end)

RegisterNetEvent('domino_boricua:admin:reset', function(id)
    local src = source
    if not Bridge.IsAdmin(src) then return end
    if DominoTables.reset(id) then
        notify(src, 'success', 'table_reset')
        sendPanel(src, false)
    end
end)

RegisterNetEvent('domino_boricua:admin:teleport', function(id)
    local src = source
    if not Bridge.IsAdmin(src) then return end
    local tbl = DominoTables.get(id)
    if tbl then TriggerClientEvent('domino_boricua:client:teleport', src, tbl.cfg.coords) end
end)
