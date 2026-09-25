-- La mesa en 3D: fichas sobre la mesa física, fichas paradas frente a cada
-- jugador, flecha del turno y bots sentados como NPCs. Usa el estado público
-- que el servidor publica en GlobalState (sin las manos de nadie).

local W = Config.World
local PREFIX = 'domino_boricua:'

local Public = {}  -- [id] = estado público
local Layouts = {} -- [id] = { board, items, u }
local Peds = {}    -- [id] = { [seat] = { ped, name } }

AddStateBagChangeHandler(nil, 'global', function(_, key, value)
    if type(key) ~= 'string' or key:sub(1, #PREFIX) ~= PREFIX then return end
    Public[key:sub(#PREFIX + 1)] = value or false
end)

local function publicOf(id)
    local pub = Public[id]
    if pub == nil then
        pub = GlobalState[PREFIX .. id] or false
        Public[id] = pub
    end
    return pub or nil
end

-- ------------------------------------------------------------
-- Tablero en culebra (misma lógica que la NUI, en metros)
-- ------------------------------------------------------------

local function placeArm(arm, startX, startY, dir, vdir, u, bounds, out)
    local L = u * 2
    local x, y, d = startX, startY, dir
    local afterCorner = false
    for _, t in ipairs(arm) do
        local inner, outer = t[1], t[2]
        local cross = inner == outer and not afterCorner
        local w, h = u, L
        if not cross then w, h = L, u end
        local fits
        if d > 0 then fits = x + w + u <= bounds.right else fits = x - w - u >= bounds.left end

        if fits then
            local left = (d > 0) and x or (x - w)
            local a, b = inner, outer
            if not cross and d < 0 then a, b = outer, inner end
            out[#out + 1] = { a = a, b = b, v = cross, x = left, y = y - h / 2, w = w, h = h }
            if d > 0 then x = x + w else x = x - w end
            afterCorner = false
        else
            local left = (d > 0) and x or (x - u)
            local top = (vdir > 0) and (y - u / 2) or (y + u / 2 - L)
            local a, b = inner, outer
            if vdir < 0 then a, b = outer, inner end
            out[#out + 1] = { a = a, b = b, v = true, x = left, y = top, w = u, h = L }
            if d > 0 then x = x + u else x = x - u end
            y = y + vdir * 2 * u
            d = -d
            afterCorner = true
        end
    end
end

local function layout(board, width, depth)
    local c = board.c
    local items, size
    for u = 0.03, 0.008, -0.001 do
        items, size = {}, u
        local dbl = c[1] == c[2]
        local cw, ch = u * 2, u
        if dbl then cw, ch = u, u * 2 end
        local cx, cy = width / 2, depth / 2
        items[1] = { a = c[1], b = c[2], v = dbl, x = cx - cw / 2, y = cy - ch / 2, w = cw, h = ch }
        local margin = u * 0.4
        local bounds = { left = margin, right = width - margin }
        placeArm(board.r or {}, cx + cw / 2, cy, 1, 1, u, bounds, items)
        placeArm(board.l or {}, cx - cw / 2, cy, -1, -1, u, bounds, items)
        local fits = true
        for _, it in ipairs(items) do
            if it.y < margin or it.y + it.h > depth - margin then
                fits = false
                break
            end
        end
        if fits then break end
    end
    return items, size
end

-- ------------------------------------------------------------
-- Dibujo
-- ------------------------------------------------------------

local function toWorld(m, lx, ly)
    local r = math.rad(m.heading)
    local c, s = math.cos(r), math.sin(r)
    return m.center.x + lx * c - ly * s, m.center.y + lx * s + ly * c
end

-- Rectángulo plano (se dibuja por los dos lados)
local function flat(m, x0, y0, x1, y1, z, r, g, b, a)
    local ax, ay = toWorld(m, x0, y0)
    local bx, by = toWorld(m, x1, y0)
    local cx, cy = toWorld(m, x1, y1)
    local dx, dy = toWorld(m, x0, y1)
    DrawPoly(ax, ay, z, bx, by, z, cx, cy, z, r, g, b, a)
    DrawPoly(ax, ay, z, cx, cy, z, dx, dy, z, r, g, b, a)
    DrawPoly(cx, cy, z, bx, by, z, ax, ay, z, r, g, b, a)
    DrawPoly(dx, dy, z, cx, cy, z, ax, ay, z, r, g, b, a)
end

-- Rectángulo parado (una ficha en la mano)
local function upright(m, x0, y0, x1, y1, z0, z1, r, g, b, a)
    local ax, ay = toWorld(m, x0, y0)
    local bx, by = toWorld(m, x1, y1)
    DrawPoly(ax, ay, z0, bx, by, z0, bx, by, z1, r, g, b, a)
    DrawPoly(ax, ay, z0, bx, by, z1, ax, ay, z1, r, g, b, a)
    DrawPoly(bx, by, z1, bx, by, z0, ax, ay, z0, r, g, b, a)
    DrawPoly(ax, ay, z1, bx, by, z1, ax, ay, z0, r, g, b, a)
end

local PIPS = {
    [0] = {},
    { { 1, 1 } },
    { { 0, 2 }, { 2, 0 } },
    { { 0, 2 }, { 1, 1 }, { 2, 0 } },
    { { 0, 0 }, { 0, 2 }, { 2, 0 }, { 2, 2 } },
    { { 0, 0 }, { 0, 2 }, { 1, 1 }, { 2, 0 }, { 2, 2 } },
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 0, 2 }, { 1, 2 }, { 2, 2 } },
}

-- (hx, hy) esquina de arriba a la izquierda de la mitad en coordenadas de "pantalla".
-- Cada puntito es un cilindro chatito: una sola llamada y se ve redondo.
local function drawPips(m, value, hx, hy, u, vertical, width, depth, z)
    local pad = u * 0.2
    local cell = (u - pad * 2) / 3
    local size = u * 0.17
    for _, p in ipairs(PIPS[value] or {}) do
        local row, col = p[1], p[2]
        if not vertical then row, col = col, 2 - row end
        local wx, wy = toWorld(m, hx + pad + cell * (col + 0.5) - width / 2, depth / 2 - (hy + pad + cell * (row + 0.5)))
        DrawMarker(1, wx, wy, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.0015,
            22, 24, 34, 255, false, false, 2, false, nil, nil, false)
    end
end

local function drawBoard(id, m, pub, dist)
    local width, depth = m.halfW * 2 * 0.86, m.halfD * 2 * 0.86
    local cache = Layouts[id]
    if not cache or cache.board ~= pub.board or cache.width ~= width then
        local items, u = layout(pub.board, width, depth)
        cache = { board = pub.board, items = items, u = u, width = width }
        Layouts[id] = cache
    end

    local z = m.top + 0.004
    local u = cache.u
    local pips = dist <= W.pipsDistance
    for _, it in ipairs(cache.items) do
        -- de "pantalla" (y hacia abajo) a la mesa (y hacia la silla 3)
        local x0 = it.x - width / 2
        local x1 = x0 + it.w
        local y0 = depth / 2 - it.y
        local y1 = y0 - it.h
        flat(m, x0, y0, x1, y1, z + 0.002, 246, 242, 232, 255)
        if it.v then
            local mid = (y0 + y1) / 2
            flat(m, x0 + it.w * 0.15, mid + 0.0008, x1 - it.w * 0.15, mid - 0.0008, z + 0.004, 60, 60, 70, 255)
            if pips then
                drawPips(m, it.a, it.x, it.y, u, true, width, depth, z + 0.004)
                drawPips(m, it.b, it.x, it.y + u, u, true, width, depth, z + 0.004)
            end
        else
            local mid = (x0 + x1) / 2
            flat(m, mid - 0.0008, y0 - it.h * 0.15, mid + 0.0008, y1 + it.h * 0.15, z + 0.004, 60, 60, 70, 255)
            if pips then
                drawPips(m, it.a, it.x, it.y, u, false, width, depth, z + 0.004)
                drawPips(m, it.b, it.x + u, it.y, u, false, width, depth, z + 0.004)
            end
        end
    end
end

-- Fichas paradas frente a cada silla (se ven de espaldas)
local function drawHands(m, pub)
    local counts = pub.counts
    if not counts then return end
    local tw, th, gap = 0.022, 0.044, 0.005
    for seat = 1, 4 do
        local n = counts[seat] or 0
        if n > 0 then
            local half = (seat % 2 == 1) and m.halfD or m.halfW
            local edge = -(half * 0.82)
            local total = n * tw + (n - 1) * gap
            for i = 0, n - 1 do
                local lx0 = -total / 2 + i * (tw + gap)
                local ax, ay = DominoCL.rotate(lx0, edge, (seat - 1) * 90.0)
                local bx, by = DominoCL.rotate(lx0 + tw, edge, (seat - 1) * 90.0)
                upright(m, ax, ay, bx, by, m.top + 0.002, m.top + th, 238, 234, 222, 255)
            end
        end
    end
end

local function drawTurn(m, pub)
    local seat = pub.turn
    if not seat or seat == 0 then return end
    local pos = DominoCL.seatPosition(m, seat)
    DrawMarker(2, pos.x, pos.y, m.groundZ + 1.75, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.16, 0.16, 0.16,
        255, 214, 10, 200, true, true, 2, false, nil, nil, false)
end

CreateThread(function()
    while true do
        local sleep = 500
        if W.enabled then
            local pos = GetEntityCoords(PlayerPedId())
            for id, m in pairs(DominoCL.Mesas) do
                local pub = publicOf(id)
                if pub and pub.phase ~= 'lobby' then
                    local dist = #(pos - m.center)
                    if dist < W.drawDistance then
                        sleep = 0
                        if pub.board and pub.board.c then drawBoard(id, m, pub, dist) end
                        if W.handTiles and pub.phase == 'playing' then drawHands(m, pub) end
                        if W.turnMarker and pub.phase == 'playing' then drawTurn(m, pub) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ------------------------------------------------------------
-- Bots sentados (NPCs locales)
-- ------------------------------------------------------------

local function deletePed(entry)
    if entry and DoesEntityExist(entry.ped) then DeleteEntity(entry.ped) end
end

local function modelFor(name)
    local models = Config.Bots.models
    local sum = 0
    for i = 1, #name do sum = sum + name:byte(i) end
    return models[(sum % #models) + 1]
end

local function spawnBot(m, seat, name)
    local hash = DominoCL.loadModel(modelFor(name))
    if not hash then return nil end
    local pos, heading = DominoCL.seatPosition(m, seat)
    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, heading, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    TaskStartScenarioAtPosition(ped, Config.Props.sitScenario, pos.x, pos.y, pos.z + Config.Props.sitZOffset,
        heading, 0, true, true)
    return ped
end

function DominoCL.clearWorld(id)
    for _, entry in pairs(Peds[id] or {}) do deletePed(entry) end
    Peds[id] = nil
    Layouts[id] = nil
end

CreateThread(function()
    while true do
        if Config.Bots.spawnPeds and #Config.Bots.models > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            for id, m in pairs(DominoCL.Mesas) do
                local pub = publicOf(id)
                local near = #(pos - m.center) < 60.0 and m.propsReady
                local peds = Peds[id] or {}
                Peds[id] = peds
                for seat = 1, 4 do
                    local s = near and pub and pub.seats and pub.seats[seat]
                    local want = s and s.k == 'b' and s.n or nil
                    local cur = peds[seat]
                    if cur and (cur.name ~= want or not DoesEntityExist(cur.ped)) then
                        deletePed(cur)
                        peds[seat] = nil
                        cur = nil
                    end
                    if want and not cur then
                        local ped = spawnBot(m, seat, want)
                        if ped then peds[seat] = { ped = ped, name = want } end
                    end
                end
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(Peds) do DominoCL.clearWorld(id) end
end)
