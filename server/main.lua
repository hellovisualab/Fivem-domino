-- Dominó Boricua: el servidor manda. Toda jugada se valida aquí.

local R = Config.Rules
local T = Config.Timing

local STATE_PREFIX = 'domino_boricua:'
local SAVE_FILE = 'data/tables.json'

local Tables = {}   -- [id] = estado de la mesa
local Order = {}    -- ids en orden de creación
local Seated = {}   -- [src] = id de la mesa donde está sentado
local Watching = {} -- [src] = id de la mesa que está mirando (sin sentarse)
local LastPhrase = {}

math.randomseed(os.time())

local function now() return GetGameTimer() end

local function notify(src, kind, key, ...)
    Bridge.Notify(src, L(key, ...), kind)
end

-- ------------------------------------------------------------
-- Utilidades de mesa
-- ------------------------------------------------------------

local function seatOf(tbl, src)
    for i = 1, 4 do
        local s = tbl.seats[i]
        if s and s.kind == 'player' and s.src == src then return i end
    end
    return nil
end

local function humans(tbl)
    local list = {}
    for i = 1, 4 do
        local s = tbl.seats[i]
        if s and s.kind == 'player' then list[#list + 1] = i end
    end
    return list
end

local function firstHuman(tbl)
    local list = humans(tbl)
    return list[1] and tbl.seats[list[1]].src or nil
end

local function forEachRecipient(tbl, fn)
    local sent = {}
    for i = 1, 4 do
        local s = tbl.seats[i]
        if s and s.kind == 'player' and not sent[s.src] then
            sent[s.src] = true
            fn(s.src)
        end
    end
    for src in pairs(tbl.viewers) do
        if not sent[src] then
            sent[src] = true
            fn(src)
        end
    end
end

local function notifyTable(tbl, kind, key, ...)
    local msg = L(key, ...)
    forEachRecipient(tbl, function(src) Bridge.Notify(src, msg, kind) end)
end

local function isNear(src, tbl)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end -- sin OneSync no se puede validar
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 then return true end
    local t = tbl.cfg.coords
    local dx, dy, dz = c.x - t.x, c.y - t.y, c.z - t.z
    return math.sqrt(dx * dx + dy * dy + dz * dz) <= Config.MaxServerDistance
end

local function pickBotName(tbl)
    local used = {}
    for i = 1, 4 do
        local s = tbl.seats[i]
        if s then used[s.name] = true end
    end
    local pool = {}
    for _, name in ipairs(Config.Bots.names) do
        if not used[name] then pool[#pool + 1] = name end
    end
    if #pool == 0 then return 'Bot' end
    return pool[math.random(#pool)]
end

local function copyTile(t) return { t[1], t[2] } end

local function copyHands(hands)
    local out = {}
    for seat = 1, 4 do
        out[seat] = {}
        for i, t in ipairs(hands[seat]) do out[seat][i] = copyTile(t) end
    end
    return out
end

-- ------------------------------------------------------------
-- Estado que se manda a cada cliente
-- ------------------------------------------------------------

local function movesForClient(moves)
    local list, index = {}, {}
    for _, m in ipairs(moves or {}) do
        local key = m.tile[1] .. '-' .. m.tile[2]
        if not index[key] then
            list[#list + 1] = { tile = copyTile(m.tile), sides = {} }
            index[key] = list[#list]
        end
        local sides = index[key].sides
        sides[#sides + 1] = m.side
    end
    return list
end

local function buildState(tbl, src)
    local mySeat = seatOf(tbl, src)
    local seats = {}
    for i = 1, 4 do
        local s = tbl.seats[i]
        if s then
            seats[i] = {
                name = s.name,
                kind = s.kind,
                host = s.kind == 'player' and s.src == tbl.host,
                me = s.kind == 'player' and s.src == src,
            }
        else
            seats[i] = { empty = true }
        end
    end

    local cfg = tbl.cfg
    local state = {
        id = tbl.id,
        label = cfg.label,
        phase = tbl.phase,
        mySeat = mySeat or 0,
        isHost = src == tbl.host,
        seats = seats,
        settings = {
            target = tbl.settings.target,
            bet = tbl.settings.bet,
            bots = tbl.settings.bots,
        },
        limits = {
            targets = R.targetOptions,
            minBet = cfg.minBet or 0,
            maxBet = cfg.maxBet or 0,
            step = Config.Betting.step or 100,
            betting = Bridge.CanBet() and (cfg.maxBet or 0) > 0,
            botsAllowed = Config.Bots.enabled,
        },
        rules = {
            capicu = R.capicuBonus,
            chuchazo = R.chuchazoBonus,
            capicuDifferent = R.capicuRequireDifferentEnds,
            tranqueMode = R.tranqueMode,
            tranqueTie = R.tranqueTie,
            nextStarter = R.nextStarter,
            countAll = R.countAllHands,
            firstDoubleSix = R.firstHandDoubleSix,
            pollonaDouble = Config.Betting.pollonaPaysDouble,
            turnSeconds = T.turnSeconds,
        },
    }

    local g = tbl.game
    if g then
        local counts = {}
        for i = 1, 4 do counts[i] = g.hands and #g.hands[i] or 0 end
        state.game = {
            handNo = g.handNo,
            scores = { g.scores[1], g.scores[2] },
            target = g.target,
            bet = g.bet,
            pot = g.pot,
            turn = tbl.phase == 'playing' and g.turn or 0,
            starter = g.starter or 0,
            board = g.board,
            counts = counts,
            actionId = tbl.actionId,
            lastAction = g.lastAction,
            turnRemaining = g.turnDeadline and math.max(0, g.turnDeadline - now()) or 0,
            turnTotal = T.turnSeconds * 1000,
            nextHandIn = g.nextHandAt and math.max(0, g.nextHandAt - now()) or 0,
            nextHandTotal = T.betweenHands,
            mustPlay = g.mustPlay,
            history = g.history,
            result = g.result,
            final = g.final,
        }
        if mySeat and g.hands then
            state.game.hand = g.hands[mySeat]
            if tbl.phase == 'playing' and g.turn == mySeat then
                state.game.moves = movesForClient(g.turnMoves)
            end
        end
    end
    return state
end

-- Estado público (sin manos) que ven todos los clientes para dibujar la mesa 3D,
-- sentar a los bots y marcar el turno.
local function publish(tbl)
    local seats = {}
    for i = 1, 4 do
        local s = tbl.seats[i]
        seats[i] = s and { k = s.kind == 'player' and 'p' or 'b', n = s.name } or { k = '' }
    end
    local pub = { phase = tbl.phase, seats = seats, turn = 0 }
    local g = tbl.game
    if g and g.board then
        pub.board = { c = g.board.center, l = g.board.leftArm, r = g.board.rightArm }
        local counts = {}
        for i = 1, 4 do counts[i] = g.hands and #g.hands[i] or 0 end
        pub.counts = counts
        pub.turn = tbl.phase == 'playing' and g.turn or 0
    end
    GlobalState[STATE_PREFIX .. tbl.id] = pub
end

local function sync(tbl)
    forEachRecipient(tbl, function(src)
        TriggerClientEvent('domino_boricua:client:state', src, buildState(tbl, src))
    end)
    publish(tbl)
end

-- ------------------------------------------------------------
-- Flujo del juego
-- ------------------------------------------------------------

local startHand, scheduleTurn, doPlay, doPass, endHand, gameOver, resetTable

resetTable = function(tbl)
    tbl.token = tbl.token + 1
    tbl.phase = 'lobby'
    tbl.game = nil
    for i = 1, 4 do
        local s = tbl.seats[i]
        if s and s.kind ~= 'player' then tbl.seats[i] = false end
        if s and s.kind == 'player' then s.paid = 0 end
    end
    tbl.host = firstHuman(tbl)
end

startHand = function(tbl)
    local g = tbl.game
    g.handNo = g.handNo + 1
    g.hands = Domino.Deal()
    g.board = Domino.NewBoard()
    g.passed = { {}, {}, {}, {} }
    g.result = nil
    g.lastAction = nil
    g.nextHandAt = nil
    g.mustPlay = nil

    if g.handNo == 1 or not g.nextStarter then
        if R.firstHandDoubleSix then
            g.starter = Domino.FindStarter(g.hands)
            g.mustPlay = { 6, 6 }
        else
            g.starter = math.random(4)
        end
    else
        g.starter = g.nextStarter
    end

    g.turn = g.starter
    tbl.phase = 'playing'
    tbl.actionId = tbl.actionId + 1
    scheduleTurn(tbl)
end

scheduleTurn = function(tbl)
    local g = tbl.game
    tbl.token = tbl.token + 1
    local token = tbl.token
    local seat = g.turn
    local occupant = tbl.seats[seat]
    local moves = Domino.ValidMoves(g.board, g.hands[seat], g.mustPlay)
    g.turnMoves = moves
    g.turnDeadline = nil

    if #moves == 0 then
        -- Si no llevas, pasas.
        sync(tbl)
        SetTimeout(T.autoPassDelay, function()
            if tbl.token ~= token then return end
            doPass(tbl, seat)
        end)
        return
    end

    if not occupant or occupant.kind == 'bot' then
        sync(tbl)
        SetTimeout(math.random(T.botMinDelay, T.botMaxDelay), function()
            if tbl.token ~= token then return end
            local move = Bot.ChooseMove(g, seat, moves)
            doPlay(tbl, seat, move.tile, move.side, false)
        end)
        return
    end

    g.turnDeadline = now() + T.turnSeconds * 1000
    sync(tbl)
    SetTimeout(T.turnSeconds * 1000, function()
        if tbl.token ~= token then return end
        local move = Bot.ChooseMove(g, seat, moves)
        doPlay(tbl, seat, move.tile, move.side, true)
    end)
end

doPass = function(tbl, seat)
    local g = tbl.game
    local known = g.passed[seat]
    known[g.board.leftEnd] = true
    known[g.board.rightEnd] = true
    tbl.actionId = tbl.actionId + 1
    g.lastAction = { kind = 'pass', seat = seat }
    g.turn = Domino.NextSeat(seat)
    scheduleTurn(tbl)
end

doPlay = function(tbl, seat, tile, side, auto)
    local g = tbl.game
    local hand = g.hands[seat]
    local idx = Domino.FindTile(hand, tile[1], tile[2])
    if not idx then return false end
    local t = hand[idx]
    local lastTile = #hand == 1
    local capicu = lastTile and Domino.IsCapicu(g.board, t, R.capicuRequireDifferentEnds)
    if not Domino.Place(g.board, t, side) then return false end
    table.remove(hand, idx)

    g.mustPlay = nil
    tbl.actionId = tbl.actionId + 1
    g.lastAction = { kind = 'play', seat = seat, tile = copyTile(t), side = side, auto = auto == true }

    if #hand == 0 then
        endHand(tbl, {
            reason = 'domino',
            seat = seat,
            tile = t,
            capicu = capicu,
            chuchazo = t[1] == 0 and t[2] == 0,
        })
        return true
    end

    if Domino.IsBlocked(g.board, g.hands) then
        endHand(tbl, { reason = 'tranque', seat = seat, tile = t })
        return true
    end

    g.turn = Domino.NextSeat(seat)
    scheduleTurn(tbl)
    return true
end

endHand = function(tbl, info)
    local g = tbl.game
    tbl.token = tbl.token + 1
    g.turnDeadline = nil
    g.turnMoves = nil

    local pips, total = {}, 0
    for seat = 1, 4 do
        pips[seat] = Domino.HandPips(g.hands[seat])
        total = total + pips[seat]
    end
    local teamPips = { pips[1] + pips[3], pips[2] + pips[4] }

    local result = {
        handNo = g.handNo,
        reason = info.reason,
        seat = info.seat,
        tile = copyTile(info.tile),
        pips = pips,
        teamPips = teamPips,
        hands = copyHands(g.hands),
        winnerTeam = 0,
        points = 0,
        bonus = 0,
        capicu = false,
        chuchazo = false,
        annulled = false,
    }

    local nextStarter
    if info.reason == 'domino' then
        local team = Domino.TeamOf(info.seat)
        result.winnerTeam = team
        result.points = R.countAllHands and total or teamPips[3 - team]
        if info.chuchazo and R.chuchazoBonus > 0 then
            result.chuchazo, result.bonus = true, R.chuchazoBonus
        elseif info.capicu and R.capicuBonus > 0 then
            result.capicu, result.bonus = true, R.capicuBonus
        end
        nextStarter = info.seat
    else
        local team = Domino.ResolveTranque(pips, R.tranqueMode, R.tranqueTie, g.starter)
        if team then
            result.winnerTeam = team
            result.points = R.countAllHands and total or teamPips[3 - team]
            -- sale el de la pareja ganadora con menos puntos
            local a, b = team == 1 and 1 or 2, team == 1 and 3 or 4
            nextStarter = pips[a] <= pips[b] and a or b
        else
            result.annulled = true
        end
    end

    if R.nextStarter == 'rotate' or not nextStarter then
        nextStarter = Domino.NextSeat(g.starter)
    end
    g.nextStarter = nextStarter

    if result.winnerTeam > 0 then
        g.scores[result.winnerTeam] = g.scores[result.winnerTeam] + result.points + result.bonus
    end
    result.scores = { g.scores[1], g.scores[2] }

    g.history[#g.history + 1] = {
        hand = g.handNo,
        team = result.winnerTeam,
        points = result.points + result.bonus,
        reason = result.reason,
        capicu = result.capicu,
        chuchazo = result.chuchazo,
    }
    g.result = result
    tbl.actionId = tbl.actionId + 1
    result.actionId = tbl.actionId

    local winner
    if g.scores[1] >= g.target then
        winner = 1
    elseif g.scores[2] >= g.target then
        winner = 2
    end
    if winner then return gameOver(tbl, winner) end

    tbl.phase = 'handover'
    g.nextHandAt = now() + T.betweenHands
    local token = tbl.token
    SetTimeout(T.betweenHands, function()
        if tbl.token ~= token or tbl.phase ~= 'handover' then return end
        startHand(tbl)
    end)
    sync(tbl)
end

gameOver = function(tbl, winner)
    local g = tbl.game
    local loser = 3 - winner
    tbl.phase = 'gameover'
    g.turn = 0

    local pollona = g.scores[loser] == 0
    local payouts = { 0, 0, 0, 0 }
    local pot = g.pot

    if g.bet > 0 then
        -- La pollona se paga doble
        if pollona and Config.Betting.pollonaPaysDouble then
            for seat = 1, 4 do
                local s = tbl.seats[seat]
                if s and s.kind == 'player' and (s.paid or 0) > 0 and Domino.TeamOf(seat) == loser then
                    if Bridge.RemoveMoney(s.src, g.bet, 'domino-pollona') then
                        pot = pot + g.bet
                        payouts[seat] = -g.bet
                        notify(s.src, 'error', 'pollona_charge', g.bet)
                    end
                end
            end
        end

        local winners = {}
        for seat = 1, 4 do
            local s = tbl.seats[seat]
            if s and s.kind == 'player' and Domino.TeamOf(seat) == winner then
                winners[#winners + 1] = seat
            end
        end
        if #winners > 0 then
            local cut = math.floor(pot * (Config.Betting.houseCut or 0))
            local share = math.floor((pot - cut) / #winners)
            for _, seat in ipairs(winners) do
                local s = tbl.seats[seat]
                if Bridge.AddMoney(s.src, share, 'domino-premio') then
                    payouts[seat] = share
                    notify(s.src, 'success', 'payout', share)
                end
            end
        end
    end

    for seat = 1, 4 do
        local s = tbl.seats[seat]
        if s and s.kind == 'player' then s.paid = 0 end
    end

    g.final = { winnerTeam = winner, pollona = pollona, payouts = payouts, pot = pot }
    local token = tbl.token
    SetTimeout(T.gameOverReset, function()
        if tbl.token ~= token or tbl.phase ~= 'gameover' then return end
        resetTable(tbl)
        sync(tbl)
    end)
    sync(tbl)
end

-- ------------------------------------------------------------
-- Entrar y salir de la mesa
-- ------------------------------------------------------------

local function stopWatching(src)
    local id = Watching[src]
    if id and Tables[id] then Tables[id].viewers[src] = nil end
    Watching[src] = nil
end

local function leaveSeat(src, reason)
    local id = Seated[src]
    if not id then return end
    local tbl = Tables[id]
    Seated[src] = nil
    if not tbl then return end
    local seat = seatOf(tbl, src)

    if seat then
        local occupant = tbl.seats[seat]
        if tbl.phase == 'playing' or tbl.phase == 'handover' then
            -- Se pierde la apuesta y un bot termina la partida en su silla
            tbl.seats[seat] = { kind = 'bot', name = pickBotName(tbl), replaced = true }
            notifyTable(tbl, 'info', 'player_left_bot', occupant.name)
        else
            tbl.seats[seat] = false
        end
    end

    if tbl.host == src then tbl.host = firstHuman(tbl) end

    if reason ~= 'drop' then
        TriggerClientEvent('domino_boricua:client:stand', src)
        tbl.viewers[src] = true
        Watching[src] = id
    end

    if #humans(tbl) == 0 and tbl.phase ~= 'lobby' then
        resetTable(tbl)
    elseif tbl.phase == 'playing' and seat and tbl.game.turn == seat then
        scheduleTurn(tbl) -- que el bot juegue ya
        return
    end
    sync(tbl)
end

RegisterNetEvent('domino_boricua:server:open', function(tableId)
    local src = source
    local tbl = Tables[Seated[src] or tableId]
    if not tbl then return end
    if not Seated[src] then
        if not isNear(src, tbl) then return notify(src, 'error', 'too_far') end
        if Watching[src] ~= tbl.id then stopWatching(src) end
        tbl.viewers[src] = true
        Watching[src] = tbl.id
    end
    local state = buildState(tbl, src)
    state.open = true
    TriggerClientEvent('domino_boricua:client:state', src, state)
end)

RegisterNetEvent('domino_boricua:server:close', function()
    stopWatching(source)
end)

RegisterNetEvent('domino_boricua:server:sit', function(tableId, seat)
    local src = source
    seat = tonumber(seat)
    local tbl = Tables[tableId]
    if not tbl or not seat or seat < 1 or seat > 4 or seat % 1 ~= 0 then return end
    if Seated[src] and Seated[src] ~= tableId then return notify(src, 'error', 'already_seated') end
    if tbl.phase ~= 'lobby' then return notify(src, 'error', 'game_running') end
    if tbl.seats[seat] then return notify(src, 'error', 'seat_taken') end
    if not isNear(src, tbl) then return notify(src, 'error', 'too_far') end

    local current = seatOf(tbl, src)
    if current then tbl.seats[current] = false end
    tbl.seats[seat] = { kind = 'player', src = src, name = Bridge.GetName(src), paid = 0 }
    Seated[src] = tbl.id
    stopWatching(src)
    if not tbl.host then tbl.host = src end

    TriggerClientEvent('domino_boricua:client:sit', src, tbl.id, seat)
    sync(tbl)
end)

RegisterNetEvent('domino_boricua:server:stand', function()
    leaveSeat(source, 'stand')
end)

RegisterNetEvent('domino_boricua:server:settings', function(data)
    local src = source
    local tbl = Tables[Seated[src] or '']
    if not tbl or tbl.phase ~= 'lobby' or type(data) ~= 'table' then return end
    if tbl.host ~= src then return notify(src, 'error', 'not_host') end

    local target = tonumber(data.target)
    if target then
        for _, option in ipairs(R.targetOptions) do
            if option == target then tbl.settings.target = target end
        end
    end

    local bet = tonumber(data.bet)
    if bet then
        local minBet, maxBet = tbl.cfg.minBet or 0, tbl.cfg.maxBet or 0
        bet = math.floor(math.max(minBet, math.min(maxBet, bet)))
        if not Bridge.CanBet() then bet = 0 end
        tbl.settings.bet = bet
    end

    if type(data.bots) == 'boolean' then
        tbl.settings.bots = data.bots and Config.Bots.enabled
    end
    sync(tbl)
end)

RegisterNetEvent('domino_boricua:server:start', function()
    local src = source
    local tbl = Tables[Seated[src] or '']
    if not tbl or tbl.phase ~= 'lobby' then return end
    if tbl.host ~= src then return notify(src, 'error', 'not_host') end

    local seatedHumans = humans(tbl)
    local empty = 4 - #seatedHumans
    if empty > 0 and not (tbl.settings.bots and Config.Bots.enabled) then
        return notify(src, 'error', 'need_players')
    end

    local bet = Bridge.CanBet() and tbl.settings.bet or 0
    if empty > 0 and bet > 0 then
        bet = 0
        notifyTable(tbl, 'info', 'bots_no_bet')
    end

    -- Cobrar la apuesta a todos o a nadie
    local paid = {}
    if bet > 0 then
        for _, seat in ipairs(seatedHumans) do
            local s = tbl.seats[seat]
            if Bridge.GetMoney(s.src) < bet then
                return notifyTable(tbl, 'error', 'no_money', s.name, bet)
            end
        end
        for _, seat in ipairs(seatedHumans) do
            local s = tbl.seats[seat]
            if not Bridge.RemoveMoney(s.src, bet, 'domino-apuesta') then
                for _, p in ipairs(paid) do
                    Bridge.AddMoney(p.src, bet, 'domino-reembolso')
                    p.paid = 0
                end
                return notifyTable(tbl, 'error', 'no_money', s.name, bet)
            end
            s.paid = bet
            paid[#paid + 1] = s
        end
        for _, s in ipairs(paid) do notify(s.src, 'info', 'bet_charged', bet) end
    end

    for seat = 1, 4 do
        if not tbl.seats[seat] then
            tbl.seats[seat] = { kind = 'bot', name = pickBotName(tbl) }
        end
    end

    tbl.game = {
        scores = { 0, 0 },
        handNo = 0,
        target = tbl.settings.target,
        bet = bet,
        pot = bet * #paid,
        history = {},
    }
    startHand(tbl)
end)

RegisterNetEvent('domino_boricua:server:play', function(data)
    local src = source
    local tbl = Tables[Seated[src] or '']
    if not tbl or tbl.phase ~= 'playing' or type(data) ~= 'table' then return end
    local g = tbl.game
    local seat = seatOf(tbl, src)
    if not seat or g.turn ~= seat or not g.turnMoves then return end

    local a, b, side = tonumber(data.a), tonumber(data.b), data.side
    for _, move in ipairs(g.turnMoves) do
        if Domino.Same(move.tile, a, b) and move.side == side then
            doPlay(tbl, seat, move.tile, move.side, false)
            return
        end
    end
end)

RegisterNetEvent('domino_boricua:server:phrase', function(index)
    local src = source
    index = tonumber(index)
    local tbl = Tables[Seated[src] or '']
    if not tbl or not index or not Config.Phrases[index] then return end
    local seat = seatOf(tbl, src)
    if not seat then return end
    local t = now()
    if LastPhrase[src] and t - LastPhrase[src] < Config.PhraseCooldown then return end
    LastPhrase[src] = t
    forEachRecipient(tbl, function(target)
        TriggerClientEvent('domino_boricua:client:phrase', target, seat, index)
    end)
end)

RegisterNetEvent('domino_boricua:server:rematch', function()
    local src = source
    local tbl = Tables[Seated[src] or '']
    if not tbl or tbl.phase ~= 'gameover' then return end
    if tbl.host ~= src then return notify(src, 'error', 'not_host') end
    resetTable(tbl)
    sync(tbl)
end)

local function forget(src)
    leaveSeat(src, 'drop')
    stopWatching(src)
    LastPhrase[src] = nil
end

AddEventHandler('playerDropped', function()
    forget(source)
end)

-- Cambio de personaje sin desconectarse (QBCore/Qbox y ESX)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    forget(tonumber(src) or source)
end)
AddEventHandler('esx:playerLogout', function(src)
    forget(tonumber(src) or source)
end)

local function refundTable(tbl)
    if not tbl.game or tbl.game.bet <= 0 or (tbl.phase ~= 'playing' and tbl.phase ~= 'handover') then return end
    for seat = 1, 4 do
        local s = tbl.seats[seat]
        if s and s.kind == 'player' and (s.paid or 0) > 0 then
            Bridge.AddMoney(s.src, s.paid, 'domino-reembolso')
            notify(s.src, 'info', 'refund', s.paid)
            s.paid = 0
        end
    end
end

-- Si se apaga el recurso con partidas corriendo, se devuelven las apuestas.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, tbl in pairs(Tables) do refundTable(tbl) end
end)

-- ------------------------------------------------------------
-- Mesas: las de config.lua + las que crean los admins (data/tables.json)
-- ------------------------------------------------------------

local function plainCoords(c)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = (c.w or 0.0) + 0.0 }
end

local function clientTables()
    local list = {}
    for _, id in ipairs(Order) do
        local cfg = Tables[id].cfg
        list[#list + 1] = {
            id = cfg.id,
            label = cfg.label,
            coords = cfg.coords,
            spawnProps = cfg.spawnProps ~= false,
            blip = cfg.blip ~= false,
            tableModel = cfg.tableModel,
            chairModel = cfg.chairModel,
            dynamic = cfg.dynamic == true,
        }
    end
    return list
end

local function broadcastTables(target)
    TriggerClientEvent('domino_boricua:client:tables', target or -1, clientTables())
end

local function saveTables()
    local list = {}
    for _, id in ipairs(Order) do
        local cfg = Tables[id].cfg
        if cfg.dynamic then
            list[#list + 1] = {
                id = cfg.id,
                label = cfg.label,
                coords = cfg.coords,
                blip = cfg.blip ~= false,
                minBet = cfg.minBet,
                maxBet = cfg.maxBet,
                tableModel = cfg.tableModel,
                chairModel = cfg.chairModel,
                createdBy = cfg.createdBy,
                createdAt = cfg.createdAt,
            }
        end
    end
    SaveResourceFile(GetCurrentResourceName(), SAVE_FILE, json.encode(list), -1)
end

local function addTable(cfg)
    cfg.coords = plainCoords(cfg.coords)
    Tables[cfg.id] = {
        id = cfg.id,
        cfg = cfg,
        phase = 'lobby',
        seats = { false, false, false, false },
        host = nil,
        settings = {
            target = R.defaultTarget,
            bet = cfg.minBet or 0,
            bots = Config.Bots.enabled,
        },
        viewers = {},
        token = 0,
        actionId = 0,
        game = nil,
    }
    Order[#Order + 1] = cfg.id
    publish(Tables[cfg.id])
    return Tables[cfg.id]
end

local function removeTable(id)
    local tbl = Tables[id]
    if not tbl then return false end
    refundTable(tbl)
    tbl.token = tbl.token + 1
    for seat = 1, 4 do
        local s = tbl.seats[seat]
        if s and s.kind == 'player' then
            Seated[s.src] = nil
            TriggerClientEvent('domino_boricua:client:stand', s.src)
            TriggerClientEvent('domino_boricua:client:closed', s.src, id)
        end
    end
    for src in pairs(tbl.viewers) do
        Watching[src] = nil
        TriggerClientEvent('domino_boricua:client:closed', src, id)
    end
    Tables[id] = nil
    for i, other in ipairs(Order) do
        if other == id then
            table.remove(Order, i)
            break
        end
    end
    GlobalState[STATE_PREFIX .. id] = nil
    return true
end

RegisterNetEvent('domino_boricua:server:tables', function()
    broadcastTables(source)
end)

-- API interna para server/admin.lua
DominoTables = {
    all = function()
        local list = {}
        for _, id in ipairs(Order) do list[#list + 1] = Tables[id] end
        return list
    end,
    get = function(id) return Tables[id] end,
    humans = humans,
    add = function(cfg)
        local tbl = addTable(cfg)
        saveTables()
        broadcastTables()
        return tbl
    end,
    remove = function(id)
        if not removeTable(id) then return false end
        saveTables()
        broadcastTables()
        return true
    end,
    reset = function(id)
        local tbl = Tables[id]
        if not tbl then return false end
        refundTable(tbl)
        resetTable(tbl)
        sync(tbl)
        return true
    end,
}

-- /dominoreset [id]: reinicia una mesa (o todas) y devuelve las apuestas.
RegisterCommand('dominoreset', function(_, args)
    for _, id in ipairs(Order) do
        if not args[1] or args[1] == id then
            DominoTables.reset(id)
            print(('[domino-boricua] mesa %s reiniciada'):format(id))
        end
    end
end, true)

-- ------------------------------------------------------------
-- Arranque
-- ------------------------------------------------------------

for _, cfg in ipairs(Config.Tables) do
    local copy = {}
    for k, v in pairs(cfg) do copy[k] = v end
    addTable(copy)
end

do
    local raw = LoadResourceFile(GetCurrentResourceName(), SAVE_FILE)
    local ok, saved = pcall(json.decode, raw or '[]')
    if ok and type(saved) == 'table' then
        for _, cfg in ipairs(saved) do
            if type(cfg) == 'table' and cfg.id and cfg.coords and not Tables[cfg.id] then
                cfg.dynamic = true
                cfg.spawnProps = true
                addTable(cfg)
            end
        end
    end
end

broadcastTables()
