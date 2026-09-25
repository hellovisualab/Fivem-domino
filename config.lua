Config = {}

-- ============================================================
--  GENERAL
-- ============================================================

-- 'auto' detecta el framework solo. También puedes forzarlo:
-- 'qbcore' | 'qbox' | 'esx' | 'standalone'
Config.Framework = 'auto'

-- Idioma de las notificaciones (ver shared/locale.lua)
Config.Locale = 'es'

Config.Debug = false

-- ============================================================
--  INTERACCIÓN
-- ============================================================

-- 'auto' | 'ox_target' | 'qb-target' | 'none'
-- Con 'none' (o si no hay target instalado) se usa texto 3D + tecla E.
Config.Target = 'auto'
Config.InteractKey = 38          -- E
Config.StandKey = 73             -- X (levantarse cuando la mesa está cerrada)
Config.InteractDistance = 2.0    -- distancia para abrir la mesa
Config.MaxServerDistance = 8.0   -- tolerancia que valida el servidor (necesita OneSync)

-- /domino abre la mesa más cercana (o la tuya si estás sentado)
Config.OpenCommand = 'domino'
-- Tecla opcional para el comando (ej. 'F7'). Déjalo en '' para no asignar ninguna.
Config.OpenKey = ''
-- Comando de ayuda para sacar coordenadas y crear mesas nuevas
Config.CoordsCommand = 'dominocoords'

-- ============================================================
--  ADMIN
--  /dominoadmin abre el panel pa' crear mesas donde quieras.
--  Tiene permiso quien tenga alguno de estos ACE (los admins con
--  'add_ace group.admin command allow' ya lo tienen) o, en QBCore/ESX,
--  alguno de estos grupos.
-- ============================================================

Config.Admin = {
    command = 'dominoadmin',
    aces = { 'command.dominoadmin', 'dominoboricua.admin' },
    groups = { 'admin', 'god', 'superadmin' },
    maxBet = 1000000,  -- tope de apuesta que se puede poner en una mesa
    minDistance = 3.0, -- distancia mínima entre dos mesas
}

-- ============================================================
--  DINERO / APUESTAS
-- ============================================================

Config.Betting = {
    enabled = true,
    -- QBCore/Qbox: 'cash' o 'bank'. En ESX 'cash' se convierte a 'money'.
    account = 'cash',
    step = 100,              -- saltos del selector de apuesta
    houseCut = 0.0,          -- comisión de la casa (0.05 = 5%)
    pollonaPaysDouble = true -- si hay pollona, la pareja perdedora paga la apuesta doble
}

-- ============================================================
--  REGLAS DEL DOMINÓ BORICUA
-- ============================================================

Config.Rules = {
    targetOptions = { 100, 200, 500 }, -- metas que puede escoger el anfitrión
    defaultTarget = 500,               -- la tradicional: partida a 500

    -- La primera mano de cada partida sale obligatoriamente con el doble seis ("la cochina")
    firstHandDoubleSix = true,

    -- Quién sale en las manos siguientes:
    --  'winner' = sale el que ganó la mano anterior (lo más común en PR)
    --  'rotate' = la salida rota a la derecha
    nextStarter = 'winner',

    -- true  = la pareja que gana se anota los puntos de las fichas de los 4 jugadores (estilo boricua)
    -- false = solo se anota los puntos de la pareja contraria
    countAllHands = true,

    -- Capicú: ganar con una ficha que sirve en las dos puntas
    capicuBonus = 100,
    -- true = las dos puntas deben ser números distintos (ej. puntas 3 y 5, ganas con el 3-5)
    capicuRequireDifferentEnds = true,

    -- Chuchazo: ganar la mano con la chucha (doble blanco)
    chuchazoBonus = 100,

    -- Tranque (nadie puede jugar):
    --  'team'   = gana la pareja con menos puntos en la mano
    --  'player' = gana el jugador con menos puntos (y su pareja)
    tranqueMode = 'team',
    -- Si hay empate en el tranque:
    --  'annul'   = se anula la mano y la salida rota
    --  'starter' = gana la pareja que salió
    tranqueTie = 'annul',
}

-- ============================================================
--  TIEMPOS (milisegundos salvo que diga lo contrario)
-- ============================================================

Config.Timing = {
    turnSeconds = 30,     -- tiempo para jugar; si se acaba, se juega automático
    botMinDelay = 1100,
    botMaxDelay = 2400,
    autoPassDelay = 1300, -- pausa antes de pasar automático cuando no llevas
    betweenHands = 9000,  -- pausa para ver el conteo entre manos
    gameOverReset = 60000 -- si nadie hace nada, la mesa vuelve al lobby
}

-- ============================================================
--  BOTS (rellenan sillas vacías; con bots no hay apuestas)
-- ============================================================

Config.Bots = {
    enabled = true,
    names = {
        'Don Cheo', 'Tití Carmen', 'Papo', 'Wiso', 'Doña Fela', 'Guillo',
        'Cuco', 'Tata', 'Junior', 'Nano', 'Toño', 'Millo',
    },
    -- Los bots se sientan en la mesa como NPCs (solo local en cada cliente)
    spawnPeds = true,
    models = {
        'a_m_m_mexlabor_01', 'a_m_o_genstreet_01', 'a_m_m_og_boss_01',
        'a_f_m_downtown_01', 'a_m_m_salton_02', 'a_f_o_genstreet_01',
    },
}

-- Frases rápidas que los jugadores pueden gritar en la mesa
Config.Phrases = {
    '¡Wepa!',
    '¡Ay bendito!',
    "¡Ahí na' má!",
    "¡Dale, que es pa' hoy!",
    '¡Les vamos a dar pela!',
    '¡Esa ficha estaba ahorcá!',
    '¡Juega ya, que se enfría el café!',
    '¡Cógelo suave, mano!',
    '¡Ese capicú es mío!',
    '¡Brutal, compai!',
}
Config.PhraseCooldown = 3000

-- ============================================================
--  PROPS Y SILLAS
-- ============================================================

Config.Props = {
    spawn = true,                    -- crear mesa y sillas (solo local, no en red)
    spawnDistance = 80.0,
    table = 'prop_table_03',         -- mesa por defecto
    chair = 'prop_chair_01a',        -- silla de respaldo si la del modelo no existe
    chairHeadingOffset = 180.0,      -- ajusta si las sillas quedan de espaldas
    chairGap = 0.45,                 -- espacio entre el borde de la mesa y la silla
    seatDistance = 0.95,             -- si no se puede medir la mesa
    sitZOffset = 0.5,
    sitScenario = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER',

    -- Modelos que el admin puede escoger al crear una mesa.
    -- Solo salen en el panel los que existen en tu build del juego.
    tableModels = {
        { model = 'prop_table_03', chair = 'prop_table_03_chr', label = 'Madera clásica' },
        { model = 'prop_table_04', chair = 'prop_table_04_chr', label = 'Cuadrada de patio' },
        { model = 'prop_table_01', chair = 'prop_table_01_chr_a', label = 'Terraza' },
        { model = 'prop_table_02', chair = 'prop_table_02_chr', label = 'Marquesina' },
        { model = 'prop_table_06', chair = 'prop_table_06_chr', label = 'Moderna' },
    },
}

-- ============================================================
--  MESA EN 3D
--  Las fichas se dibujan sobre la mesa física pa' que todo el que
--  pase por el lado vea la partida, y cada jugador tiene sus fichas
--  paradas frente a su silla.
-- ============================================================

Config.World = {
    enabled = true,
    drawDistance = 15.0,     -- distancia pa' ver las fichas en la mesa
    pipsDistance = 4.0,      -- los puntitos solo se dibujan de cerca (rendimiento)
    handTiles = true,        -- fichas paradas frente a cada jugador
    turnMarker = true,       -- flecha encima del que le toca
    tableHeight = 0.78,      -- si no hay prop (mesa del mapa)
    tableSize = 0.9,         -- tamaño de la superficie si no se puede medir
}

Config.Blip = {
    enabled = true,
    sprite = 93,
    color = 1,
    scale = 0.7,
    label = 'Dominó Boricua',
}

-- ============================================================
--  MESAS FIJAS
--  Lo más fácil es crearlas en el juego con /dominoadmin (se guardan en
--  data/tables.json). Estas de aquí son fijas y no se pueden borrar desde
--  el panel.
--  coords = vector4(x, y, z, heading) del centro de la mesa (a nivel del piso)
--  Usa /dominocoords parado donde quieras la mesa para sacar la línea.
-- ============================================================

Config.Tables = {
    {
        id = 'plaza_legion',
        label = 'Mesa de la Plaza',
        coords = vector4(199.2, -937.6, 30.0, 144.5),
        spawnProps = true,
        tableModel = 'prop_table_03',
        chairModel = 'prop_table_03_chr',
        blip = true,
        minBet = 0,
        maxBet = 5000,
    },
    -- {
    --     id = 'chinchorro_playa',
    --     label = 'Chinchorro de la Playa',
    --     coords = vector4(-1208.5, -1558.5, 4.0, 35.0),
    --     spawnProps = true,
    --     blip = true,
    --     minBet = 100,
    --     maxBet = 10000,
    -- },
}
