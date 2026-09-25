'use strict';

(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'domino-boricua';
    const DESIGN_W = 1600;
    const DESIGN_H = 900;

    const $ = (sel, el = document) => el.querySelector(sel);
    // Lua manda las tablas vacías como {} y no como []
    const arr = (x) => (Array.isArray(x) ? x : x && typeof x === 'object' ? Object.values(x) : []);
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => '$' + Math.abs(Number(n) || 0).toLocaleString('en-US');
    const post = (name, data = {}) =>
        fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => {});

    // ------------------------------------------------------------
    // Íconos
    // ------------------------------------------------------------

    function starPoints(cx, cy, R, r) {
        const pts = [];
        for (let i = 0; i < 10; i++) {
            const a = -Math.PI / 2 + (i * Math.PI) / 5;
            const rad = i % 2 ? r : R;
            pts.push(`${(cx + rad * Math.cos(a)).toFixed(2)},${(cy + rad * Math.sin(a)).toFixed(2)}`);
        }
        return pts.join(' ');
    }

    const ICON = {
        flag: `<svg viewBox="0 0 150 100"><rect width="150" height="100" fill="#e0262d"/><rect y="20" width="150" height="20" fill="#fff"/><rect y="60" width="150" height="20" fill="#fff"/><path d="M0 0L86.6 50L0 100Z" fill="#2f73e0"/><polygon fill="#fff" points="${starPoints(28.9, 50, 14, 5.6)}"/></svg>`,
        star: `<svg viewBox="0 0 100 100"><polygon fill="#fff" points="${starPoints(50, 53, 48, 19)}"/></svg>`,
        coqui: `<svg viewBox="0 0 64 64"><g stroke="#4a2e0e" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"><path d="M18 45C7 44 5 55 13 57L23 55" fill="#b8792f"/><path d="M46 45C57 44 59 55 51 57L41 55" fill="#b8792f"/><ellipse cx="32" cy="42" rx="15" ry="12" fill="#d39545"/><path d="M21 45L14 52M43 45L50 52" fill="none"/><ellipse cx="32" cy="27" rx="14" ry="11" fill="#d39545"/><circle cx="23" cy="19" r="7" fill="#d39545"/><circle cx="41" cy="19" r="7" fill="#d39545"/></g><ellipse cx="32" cy="45" rx="8" ry="6" fill="#ecc07a"/><circle cx="23" cy="19" r="4.2" fill="#1b1b24"/><circle cx="41" cy="19" r="4.2" fill="#1b1b24"/><circle cx="24.6" cy="17.4" r="1.5" fill="#fff"/><circle cx="42.6" cy="17.4" r="1.5" fill="#fff"/><path d="M25 31Q32 35 39 31" fill="none" stroke="#4a2e0e" stroke-width="2" stroke-linecap="round"/><g fill="#f5d08f"><circle cx="12" cy="53" r="2.3"/><circle cx="15.5" cy="55" r="2"/><circle cx="52" cy="53" r="2.3"/><circle cx="48.5" cy="55" r="2"/><circle cx="11" cy="57" r="2"/><circle cx="53" cy="57" r="2"/></g></svg>`,
        pava: `<svg viewBox="0 0 64 40"><ellipse cx="32" cy="29" rx="30" ry="8" fill="#ecca7f" stroke="#8a6424" stroke-width="2"/><path d="M19 28Q18 9 32 7Q46 9 45 28Z" fill="#f3d993" stroke="#8a6424" stroke-width="2"/><path d="M19.2 22Q32 25 44.8 22L45 27Q32 30 19 27Z" fill="#e0262d"/><path d="M24 14H40M23 18H41" stroke="#c9a456" stroke-width="1.2"/></svg>`,
        garita: `<svg viewBox="0 0 80 120"><defs><linearGradient id="gGarita" x1="0" x2="1"><stop offset="0" stop-color="#f6e7c2"/><stop offset=".6" stop-color="#e2c68d"/><stop offset="1" stop-color="#b08b52"/></linearGradient></defs><circle cx="40" cy="9" r="4.5" fill="url(#gGarita)"/><rect x="38.5" y="12" width="3" height="5" fill="#b08b52"/><path d="M15 44Q15 16 40 16Q65 16 65 44Z" fill="url(#gGarita)"/><rect x="10" y="43" width="60" height="7" rx="2" fill="#f7ead0"/><rect x="16" y="50" width="48" height="42" fill="url(#gGarita)"/><rect x="35.5" y="58" width="9" height="24" rx="4.5" fill="#2b1c10"/><rect x="12" y="91" width="56" height="5" rx="2" fill="#f7ead0"/><path d="M16 96H64L50 116H30Z" fill="url(#gGarita)"/></svg>`,
        chair: `<svg viewBox="0 0 40 40" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4V22H28"/><path d="M12 22V36M28 22V36M12 13H24"/></svg>`,
        soundOn: `<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9h4l5-4v14l-5-4H4z" fill="#fff"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/></svg>`,
        soundOff: `<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9h4l5-4v14l-5-4H4z" fill="#fff"/><path d="M16.5 9.5l5 5M21.5 9.5l-5 5"/></svg>`,
    };

    // ------------------------------------------------------------
    // Sonidos sintetizados (no hacen falta archivos)
    // ------------------------------------------------------------

    const Sound = (() => {
        let ctx = null;
        let muted = false;
        try { muted = localStorage.getItem('dominoBoricuaMuted') === '1'; } catch { /* sin storage */ }

        function ac() {
            if (muted) return null;
            if (!ctx) {
                const C = window.AudioContext || window.webkitAudioContext;
                if (!C) return null;
                ctx = new C();
            }
            if (ctx.state === 'suspended') ctx.resume();
            return ctx;
        }

        function tone(c, f1, f2, start, dur, vol, type = 'sine') {
            const o = c.createOscillator();
            const g = c.createGain();
            o.type = type;
            o.frequency.setValueAtTime(f1, start);
            o.frequency.exponentialRampToValueAtTime(f2, start + dur);
            g.gain.setValueAtTime(0.0001, start);
            g.gain.exponentialRampToValueAtTime(vol, start + 0.012);
            g.gain.exponentialRampToValueAtTime(0.0001, start + dur);
            o.connect(g).connect(c.destination);
            o.start(start);
            o.stop(start + dur + 0.03);
        }

        function noise(c, start, dur, freq, vol, mod = 0) {
            const len = Math.floor(c.sampleRate * dur);
            const buf = c.createBuffer(1, len, c.sampleRate);
            const d = buf.getChannelData(0);
            for (let i = 0; i < len; i++) {
                const env = Math.pow(1 - i / len, mod ? 1 : 4);
                const gate = mod ? (Math.floor((i / c.sampleRate) * mod) % 2 ? 1 : 0.15) : 1;
                d[i] = (Math.random() * 2 - 1) * env * gate;
            }
            const src = c.createBufferSource();
            const bp = c.createBiquadFilter();
            const g = c.createGain();
            src.buffer = buf;
            bp.type = 'bandpass';
            bp.frequency.value = freq;
            bp.Q.value = 1.1;
            g.gain.value = vol;
            src.connect(bp).connect(g).connect(c.destination);
            src.start(start);
        }

        return {
            get muted() { return muted; },
            toggle() {
                muted = !muted;
                try { localStorage.setItem('dominoBoricuaMuted', muted ? '1' : '0'); } catch { /* sin storage */ }
                return muted;
            },
            // ficha contra la mesa
            clack() {
                const c = ac(); if (!c) return;
                const t = c.currentTime;
                noise(c, t, 0.06, 2600, 0.9);
                tone(c, 190, 70, t, 0.1, 0.35);
            },
            // ¡co-quí! cuando te toca
            coqui() {
                const c = ac(); if (!c) return;
                const t = c.currentTime;
                tone(c, 1150, 1080, t, 0.09, 0.22);
                tone(c, 1850, 2550, t + 0.14, 0.17, 0.2);
            },
            pass() {
                const c = ac(); if (!c) return;
                const t = c.currentTime;
                noise(c, t, 0.05, 900, 0.6);
                noise(c, t + 0.12, 0.05, 900, 0.6);
            },
            // güiro + cuatro pa' celebrar
            win() {
                const c = ac(); if (!c) return;
                const t = c.currentTime;
                noise(c, t, 0.32, 3200, 0.5, 38);
                [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => tone(c, f, f * 1.001, t + 0.3 + i * 0.09, 0.35, 0.16, 'triangle'));
            },
            lose() {
                const c = ac(); if (!c) return;
                const t = c.currentTime;
                tone(c, 392, 380, t, 0.25, 0.14, 'triangle');
                tone(c, 311, 290, t + 0.22, 0.4, 0.14, 'triangle');
            },
        };
    })();

    // ------------------------------------------------------------
    // Estado
    // ------------------------------------------------------------

    const App = {
        S: null,
        phrases: [],
        visible: false,
        lastActionId: null,
        lastResultId: null,
        lastTurnId: null,
        lastHandNo: null,
        selected: null,
        pending: false,
        resultDelayUntil: 0,
        overlayKey: '',
        rulesOpen: false,
        phrasesOpen: false,
        log: [],
    };

    const POS = ['bottom', 'right', 'top', 'left'];
    const teamOf = (seat) => (seat % 2 === 1 ? 1 : 2);
    const viewSeat = () => (App.S && App.S.mySeat) || 1;
    const posOf = (seat) => POS[(seat - viewSeat() + 4) % 4];
    const myTeam = () => (App.S && App.S.mySeat ? teamOf(App.S.mySeat) : 1);
    const seatInfo = (seat) => arr(App.S.seats)[seat - 1] || { empty: true };
    const same = (t, a, b) => (t[0] === a && t[1] === b) || (t[0] === b && t[1] === a);

    function teamName(team) {
        if (App.S && App.S.mySeat) return team === myTeam() ? 'Nosotros' : 'Ellos';
        return team === 1 ? 'Pareja Roja' : 'Pareja Azul';
    }

    function initials(name) {
        const parts = String(name || '?').trim().split(/\s+/);
        return esc(((parts[0] || '?')[0] + (parts[1] ? parts[1][0] : '')).toUpperCase());
    }

    // ------------------------------------------------------------
    // Fichas
    // ------------------------------------------------------------

    const PIPS = {
        0: [],
        1: [[1, 1]],
        2: [[0, 2], [2, 0]],
        3: [[0, 2], [1, 1], [2, 0]],
        4: [[0, 0], [0, 2], [2, 0], [2, 2]],
        5: [[0, 0], [0, 2], [1, 1], [2, 0], [2, 2]],
        6: [[0, 0], [1, 0], [2, 0], [0, 2], [1, 2], [2, 2]],
    };

    function pipsHTML(n, orient) {
        return (PIPS[n] || [])
            .map(([r, c]) => {
                const [row, col] = orient === 'h' ? [c, 2 - r] : [r, c];
                return `<i style="grid-area:${row + 1}/${col + 1}"></i>`;
            })
            .join('');
    }

    function tileHTML(a, b, orient = 'v', cls = '', style = '', attrs = '') {
        return `<div class="tile ${orient} ${cls}" style="${style}" ${attrs}><div class="half">${pipsHTML(a, orient)}</div><div class="bar"><span></span></div><div class="half">${pipsHTML(b, orient)}</div></div>`;
    }

    const backHTML = (orient) => `<span class="back ${orient}">${ICON.star}</span>`;

    // ------------------------------------------------------------
    // Tablero en forma de culebra: la salida al centro, el brazo
    // derecho dobla hacia abajo y el izquierdo hacia arriba.
    // ------------------------------------------------------------

    function placeArm(arm, startX, startY, dir, vdir, u, bounds, items, armName) {
        const L = u * 2;
        let x = startX;
        let y = startY;
        let d = dir;
        let afterCorner = false;

        arm.forEach((t, idx) => {
            const inner = t[0];
            const outer = t[1];
            const dbl = inner === outer;
            // un doble justo después de una esquina va acostado para no montarse
            const cross = dbl && !afterCorner;
            const w = cross ? u : L;
            const h = cross ? L : u;
            const fits = d > 0 ? x + w + u <= bounds.right : x - w - u >= bounds.left;

            if (fits) {
                const left = d > 0 ? x : x - w;
                if (cross) {
                    items.push({ a: inner, b: outer, orient: 'v', x: left, y: y - h / 2, w, h, arm: armName, idx });
                } else {
                    items.push({
                        a: d > 0 ? inner : outer,
                        b: d > 0 ? outer : inner,
                        orient: 'h', x: left, y: y - h / 2, w, h, arm: armName, idx,
                    });
                }
                x = d > 0 ? x + w : x - w;
                afterCorner = false;
            } else {
                // esquina: ficha parada que baja (o sube) a la siguiente fila
                const left = d > 0 ? x : x - u;
                const top = vdir > 0 ? y - u / 2 : y + u / 2 - L;
                items.push({
                    a: vdir > 0 ? inner : outer,
                    b: vdir > 0 ? outer : inner,
                    orient: 'v', x: left, y: top, w: u, h: L, arm: armName, idx,
                });
                x = d > 0 ? x + u : x - u;
                y += vdir * 2 * u;
                d = -d;
                afterCorner = true;
            }
        });

        // dónde caería la próxima ficha (para escoger la punta)
        const fits = d > 0 ? x + L + u <= bounds.right : x - L - u >= bounds.left;
        if (fits) return { x: d > 0 ? x : x - L, y: y - u / 2, w: L, h: u };
        return { x: d > 0 ? x : x - u, y: vdir > 0 ? y - u / 2 : y + u / 2 - L, w: u, h: L };
    }

    function tryLayout(board, W, H, u) {
        const items = [];
        const c = board.center;
        if (!c) return { u, items, ends: null, fits: true };
        const margin = u * 0.4;
        const bounds = { left: margin, right: W - margin, top: margin, bottom: H - margin };
        const cx = W / 2;
        const cy = H / 2;
        const dbl = c[0] === c[1];
        const cw = dbl ? u : u * 2;
        const ch = dbl ? u * 2 : u;
        items.push({ a: c[0], b: c[1], orient: dbl ? 'v' : 'h', x: cx - cw / 2, y: cy - ch / 2, w: cw, h: ch, arm: 'center', idx: 0 });
        const right = placeArm(arr(board.rightArm), cx + cw / 2, cy, 1, 1, u, bounds, items, 'right');
        const left = placeArm(arr(board.leftArm), cx - cw / 2, cy, -1, -1, u, bounds, items, 'left');
        const all = items.concat([right, left]);
        const fits = all.every((it) => it.y >= bounds.top && it.y + it.h <= bounds.bottom);
        return { u, items, ends: { left, right }, fits };
    }

    function layoutBoard(board, W, H) {
        let lay = null;
        for (let u = 36; u >= 12; u--) {
            lay = tryLayout(board, W, H, u);
            if (lay.fits) return lay;
        }
        return lay;
    }

    // ------------------------------------------------------------
    // Mensajes desde Lua
    // ------------------------------------------------------------

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.action) return;
        switch (data.action) {
            case 'init':
                App.phrases = arr(data.phrases);
                break;
            case 'open':
                show();
                break;
            case 'close':
                hide();
                break;
            case 'state':
                setState(data.state);
                break;
            case 'phrase':
                if (App.S) bubble(data.seat, App.phrases[data.index - 1] || '¡Wepa!');
                break;
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || !App.visible) return;
        if (App.rulesOpen) return toggleRules(false);
        if (App.phrasesOpen) {
            App.phrasesOpen = false;
            return render();
        }
        if (App.selected) {
            App.selected = null;
            return render();
        }
        closeUI();
    });

    function fit() {
        const s = Math.min(window.innerWidth / DESIGN_W, window.innerHeight / DESIGN_H);
        $('#stage').style.transform = `scale(${s})`;
    }
    window.addEventListener('resize', fit);

    function show() {
        App.visible = true;
        $('#app').classList.add('visible');
        fit();
        render();
    }

    function hide() {
        App.visible = false;
        App.selected = null;
        toggleRules(false);
        $('#app').classList.remove('visible');
    }

    function closeUI() {
        hide();
        post('close');
    }

    function setState(next) {
        const prev = App.S;
        if (prev && prev.id !== next.id) {
            App.lastActionId = null;
            App.lastResultId = null;
            App.overlayKey = '';
        }
        App.S = next;
        App.pending = false;
        const g = next.game;
        if (!g || next.phase !== 'playing' || g.turn !== next.mySeat) App.selected = null;
        react(prev, next);
        render();
    }

    // Sonidos, gritos y burbujas según lo que pasó
    function react(prev, S) {
        const g = S.game;
        if (!g) {
            App.lastActionId = null;
            return;
        }
        const firstSight = App.lastActionId === null;
        const changed = g.actionId !== App.lastActionId;
        App.lastActionId = g.actionId;

        if (firstSight) {
            if (g.result) App.lastResultId = g.result.actionId;
            App.lastTurnId = g.actionId;
            App.lastHandNo = g.handNo;
            return;
        }
        if (!changed) return;

        const la = g.lastAction;
        if (S.phase === 'playing' && g.handNo !== App.lastHandNo) App.log = [];
        if (la) {
            App.log.unshift(la.kind === 'play' ? { seat: la.seat, tile: arr(la.tile), side: la.side, auto: la.auto } : { seat: la.seat, pass: true });
            App.log.length = Math.min(App.log.length, 12);
        }
        if (la && la.kind === 'play') {
            Sound.clack();
            if (la.auto && la.seat === S.mySeat) shout('Se te fue el tiempo…', 'small');
        } else if (la && la.kind === 'pass') {
            Sound.pass();
            bubble(la.seat, '¡Paso!', 'pass');
        }

        if (g.result && g.result.actionId !== App.lastResultId && (S.phase === 'handover' || S.phase === 'gameover')) {
            App.lastResultId = g.result.actionId;
            celebrate(g.result, S);
        }

        if (S.phase === 'playing' && g.handNo !== App.lastHandNo) {
            App.lastHandNo = g.handNo;
            App.dealAnim = true;
            if (g.turn !== S.mySeat) shout(`Mano ${g.handNo}`, 'small');
        }

        if (S.phase === 'playing' && S.mySeat && g.turn === S.mySeat && App.lastTurnId !== g.actionId) {
            App.lastTurnId = g.actionId;
            if (arr(g.moves).length) {
                Sound.coqui();
                shout('¡Te toca, dale!', 'turn');
            }
        }
    }

    function celebrate(r, S) {
        const mine = !S.mySeat || r.winnerTeam === myTeam();
        let text = '¡Dominó!';
        if (r.annulled) text = '¡Se trancó!';
        else if (r.chuchazo) text = '¡Chuchazo!';
        else if (r.capicu) text = '¡Capicú!';
        else if (r.reason === 'tranque') text = '¡Se trancó!';
        shout(text, 'big');
        if (r.annulled) Sound.pass();
        else if (mine) Sound.win();
        else Sound.lose();
        App.resultDelayUntil = Date.now() + 1500;
        setTimeout(render, 1550);
    }

    // ------------------------------------------------------------
    // Render
    // ------------------------------------------------------------

    function render() {
        const S = App.S;
        if (!S || !App.visible) return;
        $('#tableLabel').textContent = S.label || 'La mesa del barrio';
        $('#btnSound').innerHTML = Sound.muted ? ICON.soundOff : ICON.soundOn;
        renderPhaseChip();
        const inGame = S.phase !== 'lobby' && S.game;
        $('#lobby').classList.toggle('active', !inGame);
        $('#game').classList.toggle('active', !!inGame);
        if (inGame) {
            renderBoard();
            renderPlates();
            renderHand();
            renderLibreta();
            renderGameSide();
        } else {
            renderLobby();
            $('#libreta').innerHTML = '';
            renderLobbySide();
        }
        renderOverlay();
        if (App.rulesOpen) $('#rules').innerHTML = rulesHTML();
    }

    function renderPhaseChip() {
        const S = App.S;
        const g = S.game;
        let text = '';
        if (S.phase === 'lobby') text = 'Buscando jugadores';
        else if (S.phase === 'playing') text = `<span class="dot"></span>Mano ${g.handNo} · a ${g.target}`;
        else if (S.phase === 'handover') text = 'Contando las fichas';
        else if (S.phase === 'gameover') text = 'Se acabó la partida';
        $('#phaseChip').innerHTML = text;
    }

    function renderBoard() {
        const S = App.S;
        const g = S.game;
        const el = $('#board');
        const board = g.board || {};
        const W = el.clientWidth;
        const H = el.clientHeight;

        if (!board.center) {
            let msg = 'Esperando la salida…';
            let sub = '';
            const starter = g.starter ? seatInfo(g.starter) : null;
            if (g.mustPlay) sub = 'La primera mano sale con el doble seis, la cochina';
            if (starter && !starter.empty) msg = S.mySeat === g.starter ? '¡Te toca salir!' : `Sale ${esc(starter.name)}`;
            el.innerHTML = `<div class="board-empty"><div>${msg}<small>${sub}</small></div></div>`;
            return;
        }

        const lay = layoutBoard(board, W, H);
        el.style.setProperty('--u', `${lay.u}px`);
        const la = g.lastAction;
        const fresh = App.freshAction !== g.actionId && la && la.kind === 'play';
        const leftLen = arr(board.leftArm).length;
        const rightLen = arr(board.rightArm).length;

        let html = '';
        lay.items.forEach((it) => {
            let isFresh = false;
            if (fresh) {
                if (la.side === 'center' && it.arm === 'center') isFresh = true;
                if (la.side === 'left' && it.arm === 'left' && it.idx === leftLen - 1) isFresh = true;
                if (la.side === 'right' && it.arm === 'right' && it.idx === rightLen - 1) isFresh = true;
            }
            html += tileHTML(it.a, it.b, it.orient, isFresh ? 'fresh' : '', `--u:${lay.u}px;left:${it.x}px;top:${it.y}px`);
        });
        App.freshAction = g.actionId;

        if (App.selected && lay.ends) {
            App.selected.sides.forEach((side) => {
                const e = lay.ends[side];
                if (!e) return;
                html += `<div class="drop ${e.h > e.w ? 'tall' : ''}" data-side="${side}" style="left:${e.x - 3}px;top:${e.y - 3}px;width:${e.w + 6}px;height:${e.h + 6}px">Aquí</div>`;
            });
        }
        el.innerHTML = html;
    }

    function plateHTML(seat) {
        const S = App.S;
        const g = S.game;
        const s = seatInfo(seat);
        if (s.empty) return '';
        const pos = posOf(seat);
        const team = teamOf(seat);
        const count = arr(g.counts)[seat - 1] || 0;
        const active = S.phase === 'playing' && g.turn === seat;
        const starter = g.starter === seat && S.phase !== 'gameover';

        let backs = '';
        if (pos !== 'bottom') {
            const orient = pos === 'top' ? 'v' : 'h';
            for (let i = 0; i < count; i++) backs += backHTML(orient);
        }

        let timer = '';
        if (active) {
            const total = g.turnTotal || 30000;
            const left = g.turnRemaining || 0;
            timer = left > 0
                ? `<div class="timer"><span class="run" style="animation-duration:${left}ms;--from:${Math.min(1, left / total).toFixed(3)}"></span></div>`
                : '<div class="timer"><span class="think"></span></div>';
        }

        const tags = [];
        if (s.me) tags.push('<b class="tag tu">TÚ</b>');
        if (s.kind === 'bot') tags.push('<b class="tag">BOT</b>');
        if (starter) tags.push('<b class="tag salida">SALIDA</b>');
        const sub = `${tags.join(' ')} ${teamName(team)}`;

        return `<div class="plate pos-${pos} team-${team} ${active ? 'active' : ''}" data-seat="${seat}">
            <div class="avatar">${initials(s.name)}${s.host ? `<span class="pava">${ICON.pava}</span>` : ''}</div>
            <div class="info"><div class="name">${esc(s.name)}</div><div class="sub">${sub}</div>
            ${pos !== 'bottom' ? `<div class="backs">${backs || '<span class="count-pill">¡Se pegó!</span>'}</div>` : ''}</div>
            ${timer}
        </div>`;
    }

    function renderPlates() {
        $('#plates').innerHTML = [1, 2, 3, 4].map(plateHTML).join('');
    }

    function renderHand() {
        const S = App.S;
        const g = S.game;
        const el = $('#hand');
        if (!S.mySeat) {
            el.innerHTML = '<div class="watching">Estás mirando la partida desde afuera</div>';
            return;
        }
        const myTurn = S.phase === 'playing' && g.turn === S.mySeat;
        const moves = arr(g.moves);
        const deal = App.dealAnim;
        App.dealAnim = false;

        el.innerHTML = arr(g.hand)
            .map((t, i) => {
                t = arr(t);
                const playable = myTurn && !App.pending && moves.some((m) => same(arr(m.tile), t[0], t[1]));
                const selected = App.selected && same([App.selected.a, App.selected.b], t[0], t[1]);
                const cls = [playable ? 'playable' : '', myTurn && !playable ? 'dim' : '', selected ? 'selected' : '', deal ? 'deal' : ''].join(' ');
                const style = deal ? `animation-delay:${i * 70}ms` : '';
                return tileHTML(t[0], t[1], 'v', cls, style, `data-a="${t[0]}" data-b="${t[1]}"`);
            })
            .join('');
    }

    function renderLibreta() {
        const S = App.S;
        const g = S.game;
        const t1 = myTeam();
        const t2 = 3 - t1;
        const history = arr(g.history).slice(-8);
        const mark = (h) => `${h.capicu ? '<sup>C</sup>' : ''}${h.chuchazo ? '<sup>CH</sup>' : ''}${h.reason === 'tranque' ? '<sup>T</sup>' : ''}`;

        let rows = '';
        history.forEach((h) => {
            if (!h.team) {
                rows += '<div class="c nulo">nula</div><div class="c nulo">nula</div>';
                return;
            }
            rows += `<div class="c">${h.team === t1 ? h.points + mark(h) : ''}</div><div class="c">${h.team === t2 ? h.points + mark(h) : ''}</div>`;
        });
        if (!history.length) rows = '<div class="c"></div><div class="c"></div>';

        const scores = arr(g.scores);
        $('#libreta').innerHTML = `
            <div class="lib-head"><span class="lib-title">La Libreta</span><span class="lib-meta">a ${g.target}</span></div>
            <div class="lib-cols">
                <div class="h t${t1}">${teamName(t1)}</div><div class="h t${t2}">${teamName(t2)}</div>
                ${rows}
                <div class="tot">${scores[t1 - 1] || 0}</div><div class="tot">${scores[t2 - 1] || 0}</div>
            </div>
            <div class="lib-foot"><span>Mano ${g.handNo}</span>${g.bet > 0 ? `<span>Bote: <b>${money(g.pot)}</b></span>` : '<span>De gratis</span>'}</div>`;
    }

    function statusHTML() {
        const S = App.S;
        const g = S.game;
        let title = '';
        let sub = '';
        let mine = false;
        if (S.phase === 'playing') {
            const who = seatInfo(g.turn);
            if (S.mySeat && g.turn === S.mySeat) {
                mine = true;
                if (arr(g.moves).length) {
                    title = '¡Te toca, dale!';
                    sub = g.mustPlay ? 'Sal con el doble seis (la cochina)' : App.selected ? 'Escoge en qué punta la pones' : 'Escoge una ficha que pegue';
                } else {
                    title = 'No llevas… ¡paso!';
                    sub = 'Toca esperar la próxima vuelta';
                }
            } else {
                title = `Juega ${esc(who.name || '…')}`;
                sub = who.kind === 'bot' ? 'El bot está pensando…' : teamName(teamOf(g.turn));
            }
        } else if (S.phase === 'handover') {
            title = 'Contando las fichas';
            sub = 'La próxima mano empieza ahorita';
        } else if (S.phase === 'gameover') {
            title = 'Se acabó la partida';
            sub = S.isHost ? 'Dale a "Otra partida" pa\' seguir' : 'Esperando al anfitrión';
        }
        if (!S.mySeat) sub = 'Estás mirando la partida';
        return `<div class="status ${mine ? 'mine' : ''}"><div class="coqui">${ICON.coqui}</div><div><div class="status-title">${title}</div><div class="status-sub">${sub}</div></div></div>`;
    }

    const SIDE_NAME = { left: 'a la izquierda', right: 'a la derecha', center: 'de salida' };

    function logHTML() {
        const S = App.S;
        const g = S.game;
        const b = g.board || {};
        const ends = b.center
            ? `<div class="log-ends"><span>Puntas</span><b>${b.leftEnd}</b><i>·</i><b>${b.rightEnd}</b></div>`
            : '<div class="log-ends"><span>Puntas</span><em>sin salida</em></div>';
        const items = App.log
            .map((e) => {
                const s = seatInfo(e.seat);
                const who = `<span class="dot-team t${teamOf(e.seat)}"></span><b>${esc(s.name)}</b>`;
                if (e.pass) return `<li>${who}<span class="pasó">pasó</span></li>`;
                return `<li>${who}${tileHTML(e.tile[0], e.tile[1], 'h')}<span>${SIDE_NAME[e.side] || ''}${e.auto ? ' (auto)' : ''}</span></li>`;
            })
            .join('');
        return `<div class="card log">${ends}<ul>${items || '<li class="empty">Todavía no se ha jugado nada</li>'}</ul></div>`;
    }

    function phrasesHTML() {
        const S = App.S;
        if (!S.mySeat || !App.phrases.length || !App.phrasesOpen) return '';
        return `<div class="frases-pop"><div class="side-title">Frases de la mesa</div><div class="frases">${App.phrases
            .map((p, i) => `<button data-phrase="${i + 1}" ${App.phraseLock > Date.now() ? 'disabled' : ''}>${esc(p)}</button>`)
            .join('')}</div></div>`;
    }

    function sideActionsHTML(rulesLabel) {
        const S = App.S;
        const canTalk = S.mySeat && App.phrases.length;
        return `<div class="side-actions">
            ${canTalk ? `<button class="btn ${App.phrasesOpen ? 'on' : ''}" data-act="phrases">Frases</button>` : ''}
            <button class="btn" data-act="rules">${rulesLabel}</button>
            ${S.mySeat ? '<button class="btn red" data-act="stand">Levantarme</button>' : '<button class="btn" data-act="close">Cerrar</button>'}
        </div>`;
    }

    function renderGameSide() {
        $('#sidePanel').innerHTML = `${statusHTML()}${logHTML()}${phrasesHTML()}${sideActionsHTML('Reglas')}`;
    }

    // ------------------------------------------------------------
    // Lobby
    // ------------------------------------------------------------

    function renderLobby() {
        const S = App.S;
        const seats = [1, 2, 3, 4]
            .map((seat) => {
                const s = seatInfo(seat);
                const pos = posOf(seat);
                const team = teamOf(seat);
                let body;
                let action = '';
                if (s.empty) {
                    body = `<span class="chair">${ICON.chair}</span><span class="free">Silla libre</span>`;
                    if (S.phase === 'lobby') {
                        action = `<button class="btn ${team === 1 ? 'red' : 'blue'}" data-sit="${seat}">${S.mySeat ? 'Cambiarme aquí' : 'Sentarme aquí'}</button>`;
                    }
                } else {
                    body = `<div class="avatar" style="--tc:var(--team${team})">${initials(s.name)}${s.host ? `<span class="pava">${ICON.pava}</span>` : ''}</div>
                        <div><div class="name">${esc(s.name)}</div><div class="sub">${s.me ? '<b class="tag tu">TÚ</b> ' : ''}${s.host ? 'Anfitrión' : s.kind === 'bot' ? 'Bot' : 'Listo pa\' jugar'}</div></div>`;
                }
                return `<div class="lseat pos-${pos} team-${team} ${s.me ? 'me' : ''}">
                    <div class="lseat-head"><span>Silla ${seat}</span><span class="team">${team === 1 ? 'Pareja Roja' : 'Pareja Azul'}</span></div>
                    <div class="lseat-body">${body}</div>${action}
                </div>`;
            })
            .join('');

        $('#lobby').innerHTML = `
            <div class="lobby-center">
                <div class="garita">${ICON.garita}</div>
                <h2>Dominó<em>Boricua</em></h2>
                <p>En parejas · Doble seis · A la derecha</p>
                <div class="vs"><span class="dot-team t1"></span>Sillas 1 y 3 &nbsp;vs&nbsp; Sillas 2 y 4<span class="dot-team t2"></span></div>
            </div>
            ${seats}`;
    }

    function renderLobbySide() {
        const S = App.S;
        const st = S.settings || {};
        const lim = S.limits || {};
        const r = S.rules || {};
        const host = S.isHost;
        const seats = arr(S.seats);
        const humans = seats.filter((s) => !s.empty && s.kind === 'player').length;
        const hostSeat = seats.find((s) => s.host);
        const canStart = host && (humans === 4 || (st.bots && lim.botsAllowed));
        const dis = host ? '' : 'disabled';

        const targets = arr(lim.targets)
            .map((t) => `<button class="${t === st.target ? 'on' : ''}" data-target="${t}" ${dis}>${t}</button>`)
            .join('');

        const bet = st.bet || 0;
        const step = lim.step || 100;
        const betField = lim.betting
            ? `<div class="field"><span class="field-label">Apuesta por jugador</span>
                <div class="stepper">
                    <button data-bet="${bet - step}" ${!host || bet <= (lim.minBet || 0) ? 'disabled' : ''}>−</button>
                    <div class="amount">${bet > 0 ? money(bet) : 'De gratis'}</div>
                    <button data-bet="${bet + step}" ${!host || bet >= (lim.maxBet || 0) ? 'disabled' : ''}>+</button>
                </div>
                <small>Entre ${money(lim.minBet || 0)} y ${money(lim.maxBet)} · Con bots se juega de gratis${r.pollonaDouble ? ' · La pollona paga doble' : ''}</small>
            </div>`
            : '';

        const botsField = lim.botsAllowed
            ? `<div class="field"><div class="toggle ${st.bots ? 'on' : ''} ${host ? '' : 'off'}" data-bots="${st.bots ? 0 : 1}">
                <span class="sw"></span><span>Llenar sillas vacías con bots</span></div></div>`
            : '';

        let hint = '';
        if (!S.mySeat) hint = 'Siéntate en una silla pa\' jugar';
        else if (!host) hint = `Esperando a que ${esc(hostSeat ? hostSeat.name : 'el anfitrión')} arranque`;
        else if (!canStart) hint = `Faltan ${4 - humans} jugadores (o activa los bots)`;
        else if (humans < 4) hint = `Se juega con ${4 - humans} bot${4 - humans > 1 ? 's' : ''}`;

        $('#sidePanel').innerHTML = `
            <div class="card">
                <h3>La mesa</h3>
                <div class="field"><span class="field-label">Partida a</span><div class="seg">${targets}</div></div>
                ${betField}
                ${botsField}
                ${host ? `<button class="btn red big" data-act="start" ${canStart ? '' : 'disabled'}>¡A jugar!</button>` : ''}
                ${hint ? `<div class="hint">${hint}</div>` : ''}
            </div>
            <div class="card">
                <h3>Reglas de la casa</h3>
                <div class="chips">
                    <span class="chip">Capicú <b>+${r.capicu}</b></span>
                    <span class="chip">Chuchazo <b>+${r.chuchazo}</b></span>
                    <span class="chip">${r.countAll ? 'Se cuentan las 4 manos' : 'Se cuentan las fichas de ellos'}</span>
                    <span class="chip">Tranque: ${r.tranqueMode === 'player' ? 'gana el de menos' : 'gana la pareja de menos'}</span>
                    <span class="chip">${r.nextStarter === 'rotate' ? 'La salida rota' : 'Sale el que ganó'}</span>
                    <span class="chip">${r.turnSeconds}s por jugada</span>
                </div>
            </div>
            ${phrasesHTML()}
            ${sideActionsHTML('Reglas')}`;
    }

    // ------------------------------------------------------------
    // Resultado de la mano y fin de partida
    // ------------------------------------------------------------

    function playersHTML(r) {
        const order = [0, 1, 2, 3].map((i) => ((viewSeat() - 1 + i) % 4) + 1);
        const hands = arr(r.hands);
        const pips = arr(r.pips);
        return order
            .map((seat) => {
                const s = seatInfo(seat);
                const team = teamOf(seat);
                const tiles = arr(hands[seat - 1]).map((t) => tileHTML(arr(t)[0], arr(t)[1], 'h')).join('');
                return `<div class="prow ${r.winnerTeam === team ? 'win' : ''}">
                    <span class="dot-team t${team}"></span>
                    <div class="pname">${esc(s.name || '—')}<small>${teamName(team)}</small></div>
                    <div class="minis">${tiles || '<span class="none">¡Se pegó!</span>'}</div>
                    <div class="pips">${pips[seat - 1] || 0}</div>
                </div>`;
            })
            .join('');
    }

    function resultHTML() {
        const S = App.S;
        const g = S.game;
        const r = g.result;
        const who = seatInfo(r.seat).name || '';
        const tile = arr(r.tile);
        let stamp = '¡Dominó!';
        let cls = '';
        if (r.annulled) { stamp = 'Tranque empatado'; cls = 'gold'; }
        else if (r.chuchazo) stamp = '¡Chuchazo!';
        else if (r.capicu) stamp = '¡Capicú!';
        else if (r.reason === 'tranque') { stamp = '¡Se trancó!'; cls = 'blue'; }

        let sub;
        if (r.reason === 'domino') sub = `${esc(who)} se pegó con el ${tile[0]}|${tile[1]}${r.capicu ? ', que servía en las dos puntas' : ''}${r.chuchazo ? ', la chucha' : ''}.`;
        else if (r.annulled) sub = 'Nadie lleva y las parejas empataron en puntos. La mano se anula.';
        else sub = `Nadie lleva: ${esc(who)} trancó el juego y se cuentan las fichas.`;

        const tp = arr(r.teamPips);
        let gain;
        if (r.annulled) {
            gain = `<div class="gain">Mano nula<small>${teamName(1)} ${tp[0]} · ${teamName(2)} ${tp[1]}</small></div>`;
        } else {
            const bonus = r.bonus > 0 ? ` + ${r.bonus} de ${r.capicu ? 'capicú' : 'chuchazo'}` : '';
            const tranque = r.reason === 'tranque' ? ` (${teamName(1)} ${tp[0]} · ${teamName(2)} ${tp[1]})` : '';
            gain = `<div class="gain">+${r.points + r.bonus} pa' ${teamName(r.winnerTeam)}<small>${r.points} en fichas${bonus}${tranque}</small></div>`;
        }
        const sc = arr(r.scores);
        const t1 = myTeam();
        const t2 = 3 - t1;

        let next = '';
        if (S.phase === 'handover') {
            const total = g.nextHandTotal || 9000;
            const left = g.nextHandIn || 0;
            next = `<div class="next">Próxima mano en un chin…<div class="bar"><span style="animation-duration:${left}ms;--from:${Math.min(1, left / total).toFixed(3)}"></span></div></div>`;
        }

        return `<div class="result">
            <div class="stamp ${cls}">${stamp}</div>
            <div class="sub">${sub}</div>
            <div class="players">${playersHTML(r)}</div>
            <div class="summary">${gain}<div class="score">${teamName(t1)} <b>${sc[t1 - 1]}</b> · ${teamName(t2)} <b>${sc[t2 - 1]}</b><br>a ${g.target}</div></div>
            ${next}
        </div>`;
    }

    function gameOverHTML() {
        const S = App.S;
        const g = S.game;
        const f = g.final;
        const win = f.winnerTeam;
        let title;
        let cls = '';
        if (S.mySeat) {
            if (teamOf(S.mySeat) === win) title = '¡Ganamos, wepa!';
            else { title = 'Perdimos, mano'; cls = 'blue'; }
        } else {
            title = `¡Ganó la ${teamName(win)}!`;
        }
        const t1 = myTeam();
        const t2 = 3 - t1;
        const sc = arr(g.scores);

        const pays = arr(f.payouts);
        let payouts = '';
        if (g.bet > 0) {
            payouts = '<div class="payouts">' + [1, 2, 3, 4]
                .filter((seat) => pays[seat - 1])
                .map((seat) => {
                    const v = pays[seat - 1];
                    return `<div class="payout"><span>${esc(seatInfo(seat).name)}</span><span class="${v > 0 ? 'plus' : 'minus'}">${v > 0 ? '+' : '−'}${money(v)}</span></div>`;
                })
                .join('') + '</div>';
        }

        return `<div class="result">
            <div class="stamp ${cls}">${title}</div>
            ${f.pollona ? '<div class="stamp pollona">¡POLLONA!</div>' : ''}
            <div class="sub">${f.pollona ? 'La otra pareja no se anotó ni un punto. ¡Tremenda pela!' : `Partida a ${g.target} en ${g.handNo} manos.`}</div>
            <div class="final-score">
                <div class="team t${t1} ${win === t1 ? 'win' : ''}"><span>${teamName(t1)}</span><b>${sc[t1 - 1]}</b></div>
                <div class="dash">—</div>
                <div class="team t${t2} ${win === t2 ? 'win' : ''}"><span>${teamName(t2)}</span><b>${sc[t2 - 1]}</b></div>
            </div>
            ${payouts}
            <div class="actions">
                ${S.isHost ? '<button class="btn red" data-act="rematch">Otra partida</button>' : ''}
                ${S.mySeat ? '<button class="btn ghost" data-act="stand">Levantarme</button>' : ''}
                <button class="btn ghost" data-act="close">Cerrar</button>
            </div>
        </div>`;
    }

    function confettiHTML() {
        const colors = ['#e0262d', '#ffffff', '#2f73e0', '#f5c542'];
        let html = '<div class="confetti">';
        for (let i = 0; i < 70; i++) {
            const left = Math.random() * 100;
            const delay = Math.random() * 1.2;
            const dur = 2.4 + Math.random() * 1.8;
            const c = colors[i % colors.length];
            html += `<i style="left:${left}%;background:${c};animation-duration:${dur}s;animation-delay:${delay}s"></i>`;
        }
        return html + '</div>';
    }

    function renderOverlay() {
        const S = App.S;
        const g = S.game;
        const el = $('#overlay');
        const showIt = g && g.result && (S.phase === 'handover' || S.phase === 'gameover') && Date.now() >= App.resultDelayUntil;
        if (!showIt) {
            el.classList.remove('show');
            el.innerHTML = '';
            App.overlayKey = '';
            return;
        }
        const key = `${S.phase}:${g.result.actionId}:${S.isHost}:${S.mySeat}`;
        if (key === App.overlayKey) return;
        App.overlayKey = key;
        let html = S.phase === 'gameover' ? gameOverHTML() : resultHTML();
        if (S.phase === 'gameover' && (!S.mySeat || g.final.winnerTeam === myTeam())) html = confettiHTML() + html;
        el.innerHTML = html;
        el.classList.add('show');
    }

    // ------------------------------------------------------------
    // Reglas
    // ------------------------------------------------------------

    function rulesHTML() {
        const r = (App.S && App.S.rules) || {};
        const targets = arr(App.S && App.S.limits && App.S.limits.targets).join(', ') || '500';
        return `<div class="modal-card">
            <button class="x" data-act="rules-close">×</button>
            <h2>Cómo se juega el <em>dominó boricua</em></h2>
            <ol>
                <li><b>En parejas.</b> Cuatro jugadores y el compañero se sienta al frente: Pareja Roja (sillas 1 y 3) contra Pareja Azul (sillas 2 y 4).</li>
                <li><b>Doble seis.</b> Son 28 fichas, 7 pa' cada uno. No hay pozo: se reparten todas.</li>
                <li><b>La salida.</b> ${r.firstDoubleSix ? 'La primera mano la sale quien tenga el doble seis (la cochina).' : 'La primera salida se sortea.'} ${r.nextStarter === 'rotate' ? 'Después la salida rota a la derecha.' : 'Después sale el que ganó la mano anterior.'}</li>
                <li><b>A la derecha.</b> Se juega en contra de las manecillas del reloj. Si llevas, tienes que jugar; si no llevas, pasas.</li>
                <li><b>Dominó.</b> El que se pega (se queda sin fichas) gana la mano y su pareja se anota ${r.countAll ? 'los puntos de todas las fichas que quedan en la mesa, las de las cuatro manos' : 'los puntos que le quedan a la pareja contraria'}.</li>
                <li><b>Capicú (+${r.capicu}).</b> Pegarse con una ficha que sirve en las dos puntas${r.capicuDifferent ? ' (las puntas tienen que ser distintas)' : ''}. Con un doble no hay capicú.</li>
                <li><b>Chuchazo (+${r.chuchazo}).</b> Pegarse con la chucha: el doble blanco.</li>
                <li><b>Tranque.</b> Si nadie puede jugar, se cuentan las fichas: gana ${r.tranqueMode === 'player' ? 'el jugador con menos puntos (y su pareja)' : 'la pareja con menos puntos'} y se anota todo. ${r.tranqueTie === 'starter' ? 'Si empatan, gana la pareja que salió.' : 'Si empatan, la mano se anula.'}</li>
                <li><b>La partida.</b> Gana la primera pareja que llegue a la meta (${targets}; la tradicional es a 500).</li>
                <li><b>Pollona.</b> Ganar la partida sin que la otra pareja se anote ni un punto.${r.pollonaDouble ? ' Si hay apuesta, la pollona se paga doble.' : ''}</li>
                <li><b>El reloj.</b> Tienes ${r.turnSeconds || 30} segundos pa' jugar. Si se acaba, la ficha se juega sola.</li>
            </ol>
            <p class="glosario"><b>Glosario:</b> <i>la cochina</i> = doble seis · <i>la chucha</i> = doble blanco · <i>pegarse</i> = quedarse sin fichas · <i>ahorcá</i> = un doble que ya no puede salir · <i>la libreta</i> = donde se anotan los tantos · <i>Nosotros / Ellos</i> = las columnas de la libreta</p>
        </div>`;
    }

    function toggleRules(open) {
        App.rulesOpen = open;
        const el = $('#rules');
        el.innerHTML = open ? rulesHTML() : '';
        el.classList.toggle('show', open);
    }

    // ------------------------------------------------------------
    // Burbujas y gritos
    // ------------------------------------------------------------

    function bubble(seat, text, kind = '') {
        const el = document.createElement('div');
        el.className = `bubble pos-${posOf(seat)} ${kind}`;
        el.textContent = text;
        $('#bubbles').appendChild(el);
        setTimeout(() => el.remove(), 3300);
    }

    function shout(text, kind = 'big') {
        const el = $('#shout');
        el.innerHTML = `<span class="${kind}">${esc(text)}</span>`;
        el.classList.remove('go');
        void el.offsetWidth;
        el.classList.add('go');
    }

    // ------------------------------------------------------------
    // Clicks
    // ------------------------------------------------------------

    function play(a, b, side) {
        App.selected = null;
        App.pending = true;
        post('play', { a, b, side });
        render();
    }

    function onHandTile(el) {
        const S = App.S;
        const g = S.game;
        const a = Number(el.dataset.a);
        const b = Number(el.dataset.b);
        const move = arr(g.moves).find((m) => same(arr(m.tile), a, b));
        if (S.phase !== 'playing' || g.turn !== S.mySeat || !move || App.pending) {
            el.classList.remove('shake');
            void el.offsetWidth;
            el.classList.add('shake');
            return;
        }
        const sides = arr(move.sides);
        if (App.selected && same([App.selected.a, App.selected.b], a, b)) {
            App.selected = null;
            return render();
        }
        if (sides.length === 1) return play(a, b, sides[0]);
        // si las dos puntas son iguales da lo mismo: al brazo más corto
        const board = g.board || {};
        if (board.leftEnd === board.rightEnd) {
            return play(a, b, arr(board.leftArm).length <= arr(board.rightArm).length ? 'left' : 'right');
        }
        App.selected = { a, b, sides };
        render();
    }

    document.addEventListener('click', (e) => {
        const t = e.target;
        const tile = t.closest('#hand .tile');
        if (tile) return onHandTile(tile);

        const drop = t.closest('.drop');
        if (drop && App.selected) return play(App.selected.a, App.selected.b, drop.dataset.side);

        const sit = t.closest('[data-sit]');
        if (sit) return post('sit', { seat: Number(sit.dataset.sit) });

        const target = t.closest('[data-target]');
        if (target && !target.disabled) return post('settings', { target: Number(target.dataset.target) });

        const bet = t.closest('[data-bet]');
        if (bet && !bet.disabled) return post('settings', { bet: Number(bet.dataset.bet) });

        const bots = t.closest('[data-bots]');
        if (bots && App.S && App.S.isHost) return post('settings', { bots: bots.dataset.bots === '1' });

        const phrase = t.closest('[data-phrase]');
        if (phrase && !phrase.disabled) {
            App.phrasesOpen = false;
            App.phraseLock = Date.now() + 3000;
            post('phrase', { index: Number(phrase.dataset.phrase) });
            return render();
        }

        const act = t.closest('[data-act]');
        if (!act) return;
        switch (act.dataset.act) {
            case 'start': return post('start');
            case 'stand': return post('stand');
            case 'rematch': return post('rematch');
            case 'close': return closeUI();
            case 'rules': return toggleRules(true);
            case 'phrases':
                App.phrasesOpen = !App.phrasesOpen;
                return render();
            case 'rules-close': return toggleRules(false);
        }
    });

    $('#btnClose').addEventListener('click', closeUI);
    $('#btnRules').addEventListener('click', () => toggleRules(!App.rulesOpen));
    $('#btnSound').addEventListener('click', () => {
        Sound.toggle();
        $('#btnSound').innerHTML = Sound.muted ? ICON.soundOff : ICON.soundOn;
    });
    $('#rules').addEventListener('click', (e) => {
        if (e.target.id === 'rules') toggleRules(false);
    });

    document.querySelectorAll('[data-icon]').forEach((el) => {
        el.innerHTML = ICON[el.dataset.icon] || '';
    });
    $('#btnSound').innerHTML = Sound.muted ? ICON.soundOff : ICON.soundOn;
    fit();
})();
