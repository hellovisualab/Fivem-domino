Locales = Locales or {}

Locales['es'] = {
    target_label      = 'Jugar Dominó Boricua',
    press_to_open     = '[E] Jugar Dominó Boricua',
    seated_help       = '~INPUT_CONTEXT~ Ver la mesa   ~INPUT_VEH_DUCK~ Levantarte',
    no_table_near     = 'No hay ninguna mesa de dominó cerca.',
    too_far           = 'Estás muy lejos de la mesa.',
    seat_taken        = 'Esa silla ya está ocupada, mano.',
    already_seated    = 'Ya estás sentado en otra mesa.',
    game_running      = 'La partida ya empezó. Puedes mirar desde afuera.',
    not_host          = 'Solo el anfitrión de la mesa puede hacer eso.',
    need_players      = 'Faltan jugadores. Activa los bots o espera a que lleguen más.',
    no_money          = '%s no tiene chavos suficientes para la apuesta ($%d).',
    bots_no_bet       = 'Con bots en la mesa no hay apuestas. Se juega de gratis.',
    bet_charged       = 'Se te cobró $%d de apuesta. ¡Suerte!',
    payout            = '¡Wepa! Ganaste $%d en el dominó.',
    pollona_charge    = '¡Pollona! Se te cobraron $%d extra.',
    player_left_bot   = '%s se fue de la mesa. Un bot cogió su silla.',
    your_turn         = '¡Te toca jugar en el dominó!',
    refund            = 'Se canceló la partida. Te devolvimos $%d.',
    coords_copied     = 'Coordenadas en la consola (F8): %s',
}

function L(key, ...)
    local lang = Locales[Config.Locale] or Locales['es']
    local str = lang[key] or Locales['es'][key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end
