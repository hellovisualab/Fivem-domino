-- Lógica pura del dominó (sin natives de FiveM) para poder probarla fuera del juego.
-- Una ficha es { a, b } con a <= b. Las sillas van de 1 a 4 en contra de las manecillas
-- del reloj (se juega "a la derecha"); la pareja 1 es sillas 1 y 3, la pareja 2 sillas 2 y 4.

Domino = {}

function Domino.NewSet()
    local set = {}
    for a = 0, 6 do
        for b = a, 6 do
            set[#set + 1] = { a, b }
        end
    end
    return set
end

function Domino.Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function Domino.SortHand(hand)
    table.sort(hand, function(x, y)
        if x[1] ~= y[1] then return x[1] < y[1] end
        return x[2] < y[2]
    end)
    return hand
end

-- Reparte las 28 fichas: 7 por jugador, no queda pozo.
function Domino.Deal()
    local set = Domino.Shuffle(Domino.NewSet())
    local hands = { {}, {}, {}, {} }
    for i, tile in ipairs(set) do
        local seat = ((i - 1) % 4) + 1
        hands[seat][#hands[seat] + 1] = tile
    end
    for seat = 1, 4 do
        Domino.SortHand(hands[seat])
    end
    return hands
end

function Domino.IsDouble(t) return t[1] == t[2] end

function Domino.Has(t, n) return t[1] == n or t[2] == n end

function Domino.Same(t, a, b)
    return (t[1] == a and t[2] == b) or (t[1] == b and t[2] == a)
end

function Domino.HandPips(hand)
    local total = 0
    for _, t in ipairs(hand) do
        total = total + t[1] + t[2]
    end
    return total
end

function Domino.FindTile(hand, a, b)
    for i, t in ipairs(hand) do
        if Domino.Same(t, a, b) then return i end
    end
    return nil
end

function Domino.TeamOf(seat) return (seat % 2 == 1) and 1 or 2 end

function Domino.NextSeat(seat) return seat % 4 + 1 end

function Domino.Partner(seat) return (seat + 1) % 4 + 1 end

-- Quién tiene el doble seis (la "cochina")
function Domino.FindStarter(hands)
    for seat = 1, 4 do
        if Domino.FindTile(hands[seat], 6, 6) then return seat end
    end
    return 1
end

-- ------------------------------------------------------------
-- Tablero: la salida queda en el centro y crecen dos brazos.
-- Cada ficha de un brazo se guarda como { interior, exterior }.
-- ------------------------------------------------------------

function Domino.NewBoard()
    return { center = nil, leftArm = {}, rightArm = {}, leftEnd = -1, rightEnd = -1, count = 0 }
end

function Domino.PlayableSides(board, t)
    if not board.center then return { 'center' } end
    local sides = {}
    if Domino.Has(t, board.leftEnd) then sides[#sides + 1] = 'left' end
    if Domino.Has(t, board.rightEnd) then sides[#sides + 1] = 'right' end
    return sides
end

-- mustPlay: ficha obligada (el doble seis en la primera mano)
function Domino.ValidMoves(board, hand, mustPlay)
    local moves = {}
    for _, t in ipairs(hand) do
        if not mustPlay or Domino.Same(t, mustPlay[1], mustPlay[2]) then
            for _, side in ipairs(Domino.PlayableSides(board, t)) do
                moves[#moves + 1] = { tile = t, side = side }
            end
        end
    end
    return moves
end

function Domino.Place(board, t, side)
    if not board.center then
        board.center = { t[1], t[2] }
        board.leftEnd, board.rightEnd = t[1], t[2]
        board.count = 1
        return true
    end
    local endValue
    if side == 'left' then
        endValue = board.leftEnd
    elseif side == 'right' then
        endValue = board.rightEnd
    else
        return false
    end
    if not Domino.Has(t, endValue) then return false end
    local outer = (t[1] == endValue) and t[2] or t[1]
    if side == 'left' then
        board.leftArm[#board.leftArm + 1] = { endValue, outer }
        board.leftEnd = outer
    else
        board.rightArm[#board.rightArm + 1] = { endValue, outer }
        board.rightEnd = outer
    end
    board.count = board.count + 1
    return true
end

-- Capicú: la última ficha sirve en las dos puntas. Nunca aplica con un doble.
function Domino.IsCapicu(board, t, requireDifferentEnds)
    if not board.center or Domino.IsDouble(t) then return false end
    local l, r = board.leftEnd, board.rightEnd
    if requireDifferentEnds then
        return l ~= r and Domino.Same(t, l, r)
    end
    return Domino.Has(t, l) and Domino.Has(t, r)
end

-- Tranque: ningún jugador lleva para ninguna de las dos puntas.
function Domino.IsBlocked(board, hands)
    if not board.center then return false end
    for seat = 1, 4 do
        for _, t in ipairs(hands[seat]) do
            if Domino.Has(t, board.leftEnd) or Domino.Has(t, board.rightEnd) then
                return false
            end
        end
    end
    return true
end

-- Decide quién gana un tranque. Devuelve la pareja ganadora o nil si se anula.
-- pips: puntos que le quedan a cada silla.
function Domino.ResolveTranque(pips, mode, tieRule, starterSeat)
    local winner
    if mode == 'player' then
        local min, teams = math.huge, {}
        for seat = 1, 4 do
            if pips[seat] < min then
                min, teams = pips[seat], { [Domino.TeamOf(seat)] = true }
            elseif pips[seat] == min then
                teams[Domino.TeamOf(seat)] = true
            end
        end
        if not (teams[1] and teams[2]) then
            winner = teams[1] and 1 or 2
        end
    else
        local team1, team2 = pips[1] + pips[3], pips[2] + pips[4]
        if team1 < team2 then
            winner = 1
        elseif team2 < team1 then
            winner = 2
        end
    end
    if not winner and tieRule == 'starter' and starterSeat then
        winner = Domino.TeamOf(starterSeat)
    end
    return winner
end
