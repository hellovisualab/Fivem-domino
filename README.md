# 🇵🇷 Dominó Boricua — FiveM

Dominó en parejas **estilo Puerto Rico** para FiveM, compatible con **QBCore**, **Qbox** y **ESX** (también corre standalone, sin apuestas).
Mesas físicas en el mapa, sillas con animación de sentarse, bots para llenar sillas, apuestas con dinero del framework y una interfaz con sabor boricua: bandera, coquí, pava, garita del Morro y la libreta de anotar "Nosotros / Ellos".

![Partida](docs/partida.jpg)

| Lobby de la mesa | ¡Capicú! |
| --- | --- |
| ![Lobby](docs/lobby.jpg) | ![Capicú](docs/capicu.jpg) |

---

## Reglas del dominó boricua (lo que implementa el script)

| Regla | Cómo funciona |
| --- | --- |
| **Parejas** | 4 jugadores. El compañero se sienta al frente: Pareja Roja (sillas 1 y 3) contra Pareja Azul (sillas 2 y 4). |
| **Fichas** | Doble seis: 28 fichas, 7 por jugador. No hay pozo. |
| **La salida** | La primera mano de cada partida sale obligada con el **doble seis** ("la cochina"). Después **sale el que ganó la mano** (configurable para que la salida rote). |
| **Dirección** | Se juega **a la derecha** (en contra de las manecillas del reloj). |
| **Obligación** | Si llevas, tienes que jugar. Si no llevas, pasas (el pase es automático). |
| **Dominó** | El que se pega (se queda sin fichas) gana la mano y su pareja se anota **los puntos de todas las fichas que quedan en las 4 manos** (configurable: solo las de la pareja contraria). |
| **Capicú** | Pegarse con una ficha que sirve en las dos puntas: **+100**. No aplica con dobles. Por defecto las puntas deben ser distintas. |
| **Chuchazo** | Pegarse con la chucha (doble blanco): **+100**. |
| **Tranque** | Si nadie puede jugar, se cuentan las fichas: gana **la pareja con menos puntos** y se anota todo. Si empatan, **la mano se anula** (ambas cosas configurables). |
| **Partida** | A **500** puntos (el anfitrión puede escoger 100, 200 o 500). |
| **Pollona** | Ganar la partida sin que la otra pareja se anote ni un punto. Si hay apuesta, **la pollona se paga doble**. |
| **Reloj** | 30 segundos por jugada; si se acaba, la ficha se juega sola. |

Glosario que usa la interfaz: *la cochina* (doble seis), *la chucha* (doble blanco), *pegarse* (quedarse sin fichas), *ahorcá* (un doble que ya no puede salir), *la libreta* (donde se anotan los tantos).

---

## Características

- **Servidor autoritativo**: el reparto, las jugadas, los pases, el tranque y el conteo se validan en el servidor. Nadie ve las fichas de los demás hasta el conteo.
- **Multi-framework** con detección automática: `qbx_core`, `qb-core`, `es_extended` o standalone.
- **ox_target / qb-target** automáticos; si no hay target, texto 3D y tecla **E**.
- **Mesas y sillas** que se crean solas (props locales) y animación de sentarse en la silla que te toca.
- **Bots** con IA (sueltan fichas pesadas, cuidan los dobles, tranquean al contrario cuando saben que no lleva y no ahogan al compañero). Si alguien se va a mitad de partida, un bot coge su silla.
- **Apuestas**: se cobra a todos o a nadie al empezar, el bote se reparte a la pareja ganadora, comisión opcional de la casa, reembolso si se apaga el recurso. Con bots en la mesa se juega de gratis.
- **Interfaz boricua**: tablero en forma de culebra con esquinas, libreta de "Nosotros / Ellos", registro de jugadas, puntas, frases rápidas ("¡Wepa!", "¡Ay bendito!", "¡Esa ficha estaba ahorcá!"…), gritos de ¡Capicú!, ¡Chuchazo!, ¡Se trancó! y ¡Pollona!, confeti en los colores de la bandera.
- **Sonidos sintetizados** (sin archivos): golpe de ficha, un *¡co-quí!* cuando te toca y un güiro cuando ganas.
- Las fuentes vienen incluidas, así que la interfaz funciona sin conexión.

---

## Instalación

1. Descarga el repositorio y pon la carpeta en `resources` con el nombre **`domino-boricua`**.
2. En `server.cfg`, después de tu framework y tu target:

   ```cfg
   ensure qb-core        # o qbx_core / es_extended
   ensure ox_target      # opcional (o qb-target)
   ensure domino-boricua
   ```

3. Ajusta las mesas en `config.lua` (ver abajo) y reinicia.

**Requisitos**: servidor FiveM reciente con **OneSync** (el servidor valida la distancia a la mesa; sin OneSync esa validación se omite).

---

## Configuración (`config.lua`)

| Opción | Descripción |
| --- | --- |
| `Config.Framework` | `'auto'`, `'qbcore'`, `'qbox'`, `'esx'` o `'standalone'`. |
| `Config.Target` | `'auto'`, `'ox_target'`, `'qb-target'` o `'none'` (tecla E). |
| `Config.Betting` | Cuenta (`'cash'` o `'bank'`; en ESX `'cash'` se convierte a `'money'`), salto del selector, comisión de la casa y si la pollona paga doble. |
| `Config.Rules` | Metas disponibles, salida con doble seis, quién sale después (`'winner'` / `'rotate'`), si se cuentan las 4 manos, bonos de capicú y chuchazo, modo de tranque (`'team'` / `'player'`) y qué pasa si empatan (`'annul'` / `'starter'`). |
| `Config.Timing` | Segundos por jugada, velocidad de los bots, pausa entre manos. |
| `Config.Bots` | Activar bots y sus nombres (Don Cheo, Tití Carmen, Papo, Wiso…). |
| `Config.Phrases` | Frases rápidas de la mesa. |
| `Config.Props` | Modelos de mesa y silla, distancia de las sillas y escenario de sentarse. |
| `Config.Tables` | Las mesas del servidor. |

### Agregar una mesa

Párate donde quieres el **centro** de la mesa y escribe `/dominocoords` (la silla 1 queda a tu espalda). Copia la línea que sale en la consola (F8) a `Config.Tables`:

```lua
{
    id = 'chinchorro_playa',        -- único
    label = 'Chinchorro de la Playa',
    coords = vector4(-1208.50, -1558.50, 4.00, 35.0),
    spawnProps = true,               -- false si ya hay una mesa del mapa en ese sitio
    blip = true,
    minBet = 100,
    maxBet = 10000,                  -- 0 = sin apuestas en esta mesa
},
```

> Las coordenadas que vienen de ejemplo (Legion Square) son un punto de partida: revísalas en tu mapa.

---

## Cómo se juega en el servidor

1. Acércate a la mesa y usa el target (o **E**) → se abre la mesa.
2. Escoge una silla. El primero que se sienta es el **anfitrión** (la pava 👒) y escoge la meta, la apuesta y si se llenan las sillas con bots.
3. **¡A jugar!** Cuando te toca, las fichas que pegan brillan. Si una ficha sirve en las dos puntas, escoges dónde ponerla.
4. **ESC** cierra la ventana pero te quedas sentado: **E** para volver a la mesa, **X** para levantarte.

### Comandos

| Comando | Uso |
| --- | --- |
| `/domino` | Abre la mesa más cercana (o la tuya si estás sentado). Se le puede asignar tecla con `Config.OpenKey`. |
| `/dominocoords` | Imprime la línea `coords = vector4(...)` de tu posición para crear mesas. |
| `/dominoreset [id]` | (Admin) Reinicia una mesa o todas y devuelve las apuestas. Requiere `add_ace group.admin command.dominoreset allow`. |

---

## Estructura

```
domino-boricua/
├── fxmanifest.lua
├── config.lua
├── shared/
│   ├── locale.lua        # textos de las notificaciones
│   └── domino.lua        # lógica pura del juego (sin natives)
├── bridge/
│   ├── server.lua        # QBCore / Qbox / ESX: nombre, dinero, notificaciones
│   └── client.lua        # notificaciones y detección de target
├── server/
│   ├── bot.lua           # IA de los bots
│   └── main.lua          # mesas, turnos, conteo, apuestas
├── client/
│   └── main.lua          # props, sillas, target, NUI
└── html/                 # interfaz (HTML/CSS/JS sin dependencias)
    └── fonts/            # Lilita One, Pacifico, Caveat, Nunito (SIL OFL)
```

### Seguridad

El servidor solo escucha eventos `domino_boricua:server:*` que valida contra el estado de la mesa, así que un cliente no puede jugar fuera de turno, jugar fichas que no tiene ni cambiar la apuesta si no es el anfitrión.

---

## Créditos

- Fuentes: [Lilita One](https://fonts.google.com/specimen/Lilita+One), [Pacifico](https://fonts.google.com/specimen/Pacifico), [Caveat](https://fonts.google.com/specimen/Caveat) y [Nunito](https://fonts.google.com/specimen/Nunito), bajo la SIL Open Font License (licencias en `html/fonts/`).
- Reglas basadas en el dominó de parejas que se juega en Puerto Rico: partida a 500, capicú y chuchazo de 100, tranque por menos puntos y pollona.
