-- IA sencilla para los bots (y para jugar automático cuando a alguien se le acaba el tiempo).
-- Solo usa información pública: el tablero, su mano y los números por los que otros pasaron.

Bot = {}

local function endsAfter(board, move)
    local t = move.tile
    if move.side == 'center' then return t[1], t[2] end
    if move.side == 'left' then
        local outer = (t[1] == board.leftEnd) and t[2] or t[1]
        return outer, board.rightEnd
    end
    local outer = (t[1] == board.rightEnd) and t[2] or t[1]
    return board.leftEnd, outer
end

local function lacks(passed, seat, left, right)
    local known = passed and passed[seat]
    if not known then return 0 end
    local n = 0
    if known[left] then n = n + 1 end
    if known[right] and right ~= left then n = n + 1 end
    return n
end

-- game: { board, hands, passed }, seat: silla del bot, moves: jugadas válidas
function Bot.ChooseMove(game, seat, moves)
    if #moves <= 1 then return moves[1] end

    local hand = game.hands[seat]
    local board = game.board
    local partner = Domino.Partner(seat)
    local nextOpp = Domino.NextSeat(seat)

    local best, bestScore
    for _, move in ipairs(moves) do
        local t = move.tile
        local score = (t[1] + t[2]) * 1.2 -- soltar las fichas pesadas
        if Domino.IsDouble(t) then score = score + 6 end -- los dobles se ahorcan fácil

        local left, right = endsAfter(board, move)

        -- quedarse con fichas que sirvan para las puntas nuevas
        local playableAfter, controlled = 0, 0
        for _, other in ipairs(hand) do
            if other ~= t then
                if Domino.Has(other, left) or Domino.Has(other, right) then
                    playableAfter = playableAfter + 1
                end
                if Domino.Has(other, left) and Domino.Has(other, right) then
                    controlled = controlled + 1
                end
            end
        end
        score = score + playableAfter * 3 + controlled

        -- tranquear al contrario que juega después y no ahogar al compañero
        local oppLacks = lacks(game.passed, nextOpp, left, right)
        if oppLacks > 0 and (left == right or oppLacks == 2) then
            score = score + 9
        elseif oppLacks > 0 then
            score = score + 3
        end
        local partnerLacks = lacks(game.passed, partner, left, right)
        if partnerLacks > 0 and (left == right or partnerLacks == 2) then
            score = score - 5
        end

        -- si las dos puntas son iguales, da lo mismo el lado: preferir el brazo más corto
        if board.center and board.leftEnd == board.rightEnd then
            local arm = move.side == 'left' and board.leftArm or board.rightArm
            score = score - #arm * 0.01
        end

        score = score + math.random() * 0.5
        if not bestScore or score > bestScore then
            best, bestScore = move, score
        end
    end
    return best
end
