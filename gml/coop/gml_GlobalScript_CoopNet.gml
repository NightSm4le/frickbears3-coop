// ===== Frickbear's Coop: network core (2 players, ONE TCP port, host-authoritative clock) =====
// Protocol: GameMaker framed TCP packets, each = one JSON string { t: <type>, ... }.
// Works through Porthole / any single-port TCP tunnel: client connects to 127.0.0.1:<port>.

global.Coop = {
    proto: 7,
    modver: "0.7.9",
    rjLeft: 0,           // 0.6.2: auto-reconnect attempts left (client)
    rjAt: 0,
    rjN: 0,
    rjWhy: "",
    menuMiss: false,
    mode: "off",          // off | host | client
    server: -1,
    sock: -1,             // client: own socket, host: partner socket
    connected: false,     // handshake complete
    ip: "127.0.0.1",
    port: 7777,
    lastRecv: 0,
    lastPing: 0,
    rtt: -1,
    status: "offline",
    bot: false,
    botImplied: "",       // 0.7.9 (S11-1): the -coop-bot* / -coop-autonight flag that switched bot mode on by itself
    autoNight: -1,
    logFile: "coop.log",
    lastClockSend: 0,
    lastClientClockReset: -100000,
    hostTimer: -1,
    hostNight: undefined,
    partnerWon: false,
    partnerWonNight: undefined,
    menuOpen: false,
    focus: 0,             // 0 none, 1 ip, 2 port
    prevRoom: -1,
    bytesOut: 0,
    bytesIn: 0,
    // stage 2: partner snapshot / HUD / ping
    lastSnapSend: 0,
    partner: undefined,   // last "snap" struct from the partner
    partnerSnapAt: 0,
    snapsIn: 0,
    clockDiff: undefined, // my Timer - partner Timer (seconds), from the last snap
    pingFlash: -100000,   // current_time of the last received ping
    lastPingSent: -100000,
    pingsIn: 0,
    botPing: false,
    botWin: -1,
    botEndless: false,
    botEndlessRound: 1,
    botCustom: -1,
    botPhony: false,
    botDoors: -1,
    botAI: [],            // [[id, level], ...]
    botCam: false,
    botKick: -1,
    botLure: -1,
    botLureNext: 0,
    botShots: [],
    botShot: "",
    botShotIdx: -1,
    botShotAt: 0,
    botDie: -1
};

global.CoopPause = { remotePending: false, remoteOpening: false, remotePaused: false, remoteResume: false, localPaused: false, opening: false };

// synced from the 0.6.6@2.1.5 user build (988a): pause open/resume race fix
function coop_pause_requested(arg0)
{
    var _p = global.CoopPause;
    if (_p.opening || instance_exists(oTransitionMinigame))
    {
        return false;
    }
    if (_p.remotePending)
    {
        _p.remotePending = false;
        _p.remoteOpening = true;
        _p.opening = true;
        return true;
    }
    if (arg0)
    {
        _p.opening = true;
        return true;
    }
    return false;
}

// synced from the 0.6.6@2.1.5 user build (988a): pause open/resume race fix
function coop_pause_on_open()
{
    var _p = global.CoopPause;
    var _c = global.Coop;
    _p.opening = true;
    if (_p.remoteOpening)
    {
        _p.remoteOpening = false;
        _p.remotePaused = true;
        coop_log("PAUSE: partner paused both games");
        exit;
    }
    if (_c.connected)
    {
        _p.localPaused = true;
        coop_send(
        {
            t: "pause",
            paused: 1
        });
        coop_log("PAUSE: requested for both games");
    }
}

// synced from the 0.6.6@2.1.5 user build (988a): pause open/resume race fix
function coop_pause_on_close()
{
    var _p = global.CoopPause;
    var _c = global.Coop;
    _p.opening = false;
    if (_p.remoteResume)
    {
        _p.remoteResume = false;
        _p.remotePaused = false;
        _p.localPaused = false;
        exit;
    }
    if (_c.connected && (_p.localPaused || _p.remotePaused))
    {
        _p.localPaused = false;
        _p.remotePaused = false;
        coop_send(
        {
            t: "pause",
            paused: 0
        });
        coop_log("PAUSE: resume sent to partner");
    }
}

// synced from the 0.6.6@2.1.5 user build (988a): pause open/resume race fix
function coop_pause_packet(arg0)
{
    var _p = global.CoopPause;
    if (arg0.paused)
    {
        if (!_p.opening)
        {
            _p.remotePending = true;
        }
        _p.remotePaused = true;
        coop_log("PAUSE: partner paused; opening local pause menu");
    }
    else
    {
        _p.remotePending = false;
        _p.remotePaused = false;
        _p.remoteResume = true;
        var _unpaused = false;
        if (instance_exists(oPauser))
        {
            with (oPauser)
            {
                if (Paused && !Unpause)
                {
                    Unpause = true;
                    _unpaused = true;
                }
            }
        }
        if (!_unpaused && instance_exists(oPersistentPauser))
        {
            with (oPersistentPauser)
            {
                if (Paused && !Unpause)
                {
                    Unpause = true;
                    _unpaused = true;
                }
            }
        }
        // 0.7.3: the local pause menu (oTitleMenu) must close with the remote resume, else it stays on screen while the game runs
        if (_unpaused && room != TitleScreenMap && instance_exists(oTitleMenu)) { with (oTitleMenu) { instance_destroy(); } }
        if (!_unpaused)
        {
            _p.opening = false;
            _p.remoteResume = false;
        }
        coop_log("PAUSE: partner resumed; resuming local game");
    }
}

function coop_log(_msg)
{
    show_debug_message("[coop] " + _msg);
    var _f = file_text_open_append(global.Coop.logFile);
    if (_f >= 0)
    {
        file_text_write_string(_f, string(current_time) + " [" + global.Coop.mode + "] " + _msg);
        file_text_writeln(_f);
        file_text_close(_f);
    }
}

function coop_parse_args()
{
    var _c = global.Coop;
    var _n = parameter_count();
    // 0.7.9 (S11-1): every -coop-bot<x> flag and -coop-autonight only run inside bot mode (oCoopNet Step "if (_c.bot)",
    // coop_more_bot, coop_s3_bot_step...), so any of them now implies -coop-bot (which also skips BEAR IN MIND).
    for (var i = 0; i < _n; i++)
    {
        var _q = parameter_string(i);
        if (_q != "-coop-bot" && (string_copy(_q, 1, 9) == "-coop-bot" || _q == "-coop-autonight")) { if (_c.botImplied == "") { _c.botImplied = _q; } }
    }
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i);
        if (_p == "-coop-host") { _c.mode = "want_host"; }
        else if (_p == "-coop-join") { _c.mode = "want_join"; if (i + 1 < _n && string_char_at(parameter_string(i + 1), 1) != "-") { i++; _c.ip = parameter_string(i); } }
        else if (_p == "-coop-port" && i + 1 < _n) { i++; _c.port = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-bot") { _c.bot = true; }
        else if (_p == "-coop-autonight" && i + 1 < _n) { i++; _c.autoNight = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-log" && i + 1 < _n) { i++; _c.logFile = parameter_string(i); }
        else if (_p == "-coop-botping") { _c.botPing = true; }
        else if (_p == "-coop-botdoors" && i + 1 < _n) { i++; _c.botDoors = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botendless") { _c.botEndless = true; }
        else if (_p == "-coop-botendlessround" && i + 1 < _n) { i++; _c.botEndless = true; _c.botEndlessRound = max(1, coop_arg_num(parameter_string(i), 0)); }
        else if (_p == "-coop-botphony") { _c.botPhony = true; }
        else if (_p == "-coop-botcustom" && i + 1 < _n) { i++; _c.botCustom = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botwin" && i + 1 < _n) { i++; _c.botWin = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botai" && i + 1 < _n)
        {
            i++;
            var _parts = string_split(parameter_string(i), ",");
            for (var k = 0; k < array_length(_parts); k++) { var _kv = string_split(_parts[k], "="); if (array_length(_kv) == 2) { array_push(_c.botAI, [real(_kv[0]), real(_kv[1])]); } }
        }
        else if (_p == "-coop-botcam") { _c.botCam = true; }
        else if (_p == "-coop-botdrop" && i + 1 < _n) { i++; _c.botDrop = coop_arg_num(parameter_string(i), 0); } // 0.6.2: client fakes a lost host after N s in the Office
        else if (_p == "-coop-botkick" && i + 1 < _n) { i++; _c.botKick = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botlure" && i + 1 < _n) { i++; _c.botLure = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botrepel" && i + 1 < _n) { i++; global.CoopA.repelChance = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botlurechance" && i + 1 < _n) { i++; global.CoopA.lureChance = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botshots" && i + 1 < _n) { i++; _c.botShots = string_split(parameter_string(i), ","); }
    }
    coop_spec_parse_args();
    coop_feat_parse_args();
    coop_more_parse_args();
    if (_c.botImplied != "")
    {
        if (_c.bot) { _c.botImplied = ""; }
        else { _c.bot = true; coop_log("bot: mode ON (implied by " + _c.botImplied + ", no -coop-bot given)"); }
    }
}

function coop_is_client() { return global.Coop.mode == "client"; }
function coop_is_host() { return global.Coop.mode == "host"; }
// coop session in progress: the other player keeps playing, so losing window focus must not pause
function coop_active() { return variable_global_exists("Coop") && global.Coop.mode != "off"; }

function coop_block_save(_what)
{
    // 0.5.0: both sides write their OWN co-op save file (global.CoopSaveTag), the original is never touched
    if (coop_active()) { coop_log("save -> co-op file (" + global.CoopSaveTag + "): " + _what); }
    return false;
}

function coop_host(_port)
{
    coop_disconnect("rehost");
    var _c = global.Coop;
    _c.port = _port;
    _c.server = network_create_server(network_socket_tcp, _port, 1);
    if (_c.server < 0)
    {
        _c.mode = "off";
        _c.status = "cannot listen on port " + string(_port);
        coop_log(_c.status);
        return false;
    }
    _c.mode = "host";
    _c.status = "hosting on port " + string(_port) + ", waiting";
    coop_log(_c.status);
    coop_save_enter();
    return true;
}

function coop_join(_ip, _port)
{
    coop_disconnect("rejoin");
    var _c = global.Coop;
    _c.ip = _ip;
    _c.port = _port;
    network_set_config(network_config_connect_timeout, 5000);
    network_set_config(network_config_use_non_blocking_socket, 1);
    _c.sock = network_create_socket(network_socket_tcp);
    _c.mode = "client";
    _c.status = "connecting to " + _ip + ":" + string(_port);
    coop_log(_c.status);
    network_connect_async(_c.sock, _ip, _port);
    _c.lastRecv = current_time;
    coop_save_enter();
    return true;
}

function coop_disconnect(_why)
{
    var _c = global.Coop;
    // 0.6.2: a client that lost the host by timeout / dropped socket retries by itself; any other reason stops retrying
    if (_c.mode == "client" && _c.connected && (_why == "timeout" || _why == "socket closed"))
    {
        _c.rjLeft = 20; _c.rjN = 0; _c.rjAt = current_time + 2000; _c.rjWhy = _why;
        coop_log("RECONNECT: armed after " + _why + " (20 tries, every ~3 s)");
    }
    else if (_why != "rejoin" && _why != "connect failed" && _why != "connect timeout" && _why != "timeout" && _why != "socket closed") { if (_c.rjLeft > 0) { coop_log("RECONNECT: cancelled (" + _why + ")"); } _c.rjLeft = 0; }
    if (_c.connected) { coop_send({ t: "bye", why: _why }); }
    if (_c.sock >= 0) { network_destroy(_c.sock); }
    if (_c.server >= 0) { network_destroy(_c.server); }
    if (_c.mode != "off") { coop_log("disconnect: " + _why); }
    _c.sock = -1;
    _c.server = -1;
    _c.connected = false;
    _c.mode = "off";
    _c.rtt = -1;
    global.CoopCfg.hostDiff = -1; // 0.7.7 (S9-2)
    _c.status = "offline (" + _why + ")";
}

function coop_send(_msg)
{
    var _c = global.Coop;
    if (_c.sock < 0) { return; }
    var _s = json_stringify(_msg);
    var _len = string_byte_length(_s) + 1;
    var _b = buffer_create(_len, buffer_fixed, 1);
    buffer_write(_b, buffer_string, _s);
    network_send_packet(_c.sock, _b, _len);
    buffer_delete(_b);
    _c.bytesOut += _len;
}

function coop_night_payload()
{
    var _m = { t: "night", night: global.Night };
    if (variable_global_exists("Difficulty")) { _m.difficulty = global.Difficulty; }
    if (variable_global_exists("AILevels")) { _m.ai = global.AILevels; }
    if (variable_global_exists("NightSpeedup")) { _m.speedup = global.NightSpeedup; }
    if (variable_global_exists("ShuffleMode")) { _m.shuffle = global.ShuffleMode; }
    if (is_numeric(global.Night))
    {
        // 0.6.0: one roster for both offices (shared animatronics need the same AllTimeSalvages/SalvagedScraps on both sides)
        if (variable_global_exists("AllTimeSalvages")) { _m.salv = global.AllTimeSalvages; }
        if (variable_global_exists("SalvagedScraps")) { _m.scraps = global.SalvagedScraps; }
    }
    if (global.Night == "Custom" && variable_global_exists("Cheats")) { _m.cheats = global.Cheats; }
    if (global.Night == "Endless")
    {
        // 0.6.0: Endless goes picker -> Office directly (no NightOpening); client mirrors round/guard/salvages
        if (variable_global_exists("AllTimeSalvages")) { _m.salv = global.AllTimeSalvages; }
        if (variable_global_exists("EndlessRound")) { _m.round = global.EndlessRound; }
        if (variable_global_exists("Guard")) { _m.guard = global.Guard; }
    }
    if (global.Night == 6 || global.Night == "Custom")
    {
        if (variable_global_exists("Route")) { _m.route = global.Route; }
        if (variable_global_exists("AllTimeSalvages")) { _m.salv = global.AllTimeSalvages; }
        if (variable_global_exists("BossPhase")) { _m.bossphase = global.BossPhase; }
    }
    return _m;
}

// 0.6.1: shared by the client ("night" from host) and the host ("nreq": the client started a Custom/boss/Endless night)
function coop_apply_night(_m)
{
    var _c = global.Coop;
    global.Night = variable_struct_get(_m, "night");
    coop_prepare_night();
    if (variable_struct_exists(_m, "difficulty")) { global.Difficulty = _m.difficulty; if (coop_is_client()) { global.CoopCfg.hostDiff = _m.difficulty; } }
    if (variable_struct_exists(_m, "ai")) { global.AILevels = _m.ai; }
    if (variable_struct_exists(_m, "speedup")) { global.NightSpeedup = _m.speedup; }
    if (variable_struct_exists(_m, "shuffle")) { global.ShuffleMode = _m.shuffle; }
    if (variable_struct_exists(_m, "route"))
    {
        global.Route = _m.route; if (variable_struct_exists(_m, "salv")) { global.AllTimeSalvages = _m.salv; } if (variable_struct_exists(_m, "bossphase")) { global.BossPhase = _m.bossphase; }
        if (_m.night == "Custom") { global.Upgrades = []; global.SavedBossTime = 0; global.SummonedAnimatronics = []; global.Challenge = undefined; global.ChallengeTitle = "None"; global.CustomNightMusic = undefined; if (!variable_global_exists("Cheats")) { global.Cheats = array_create(10, false); } }
        coop_log("BOSS: route " + string(_m.route) + " phase " + (variable_global_exists("BossPhase") ? string(global.BossPhase) : "-") + " from host (boss_fight=" + string(boss_fight_night()) + ")");
    }
    if (is_numeric(_m.night))
    {
        if (variable_struct_exists(_m, "salv")) { global.AllTimeSalvages = _m.salv; }
        if (variable_struct_exists(_m, "scraps")) { global.SalvagedScraps = _m.scraps; }
        coop_log("ROSTER: " + string(variable_struct_exists(_m, "salv") ? array_length(_m.salv) : -1) + " salvaged animatronics from host");
    }
    if (variable_struct_exists(_m, "cheats")) { global.Cheats = _m.cheats; }
    if (_m.night == "Endless")
    {
        var _dif = global.Difficulty;
        var _fresh = !variable_global_exists("EndlessInventory") || !variable_global_exists("EndlessRound") || (variable_struct_exists(_m, "round") && _m.round <= 1);
        if (_fresh) { initialize_endless_data(); }
        global.Night = "Endless"; global.Difficulty = _dif;
        if (variable_struct_exists(_m, "salv")) { global.AllTimeSalvages = _m.salv; }
        if (variable_struct_exists(_m, "round")) { global.EndlessRound = _m.round; }
        if (variable_struct_exists(_m, "guard")) { global.Guard = _m.guard; if (_fresh) { global.Lives = array_create(3, global.Guard); } }
        global.AILevels = array_create(201, 0);
        coop_log("ENDLESS: round " + string(global.EndlessRound) + " guard " + string(global.Guard) + " salvages " + string(array_length(global.AllTimeSalvages)) + " from host");
    }
    coop_log("ECON: difficulty " + string(global.Difficulty) + " from host (one difficulty for both)");
    coop_log("host started night " + string(global.Night));
}

// --- incoming ---
function coop_on_packet(_m)
{
    var _c = global.Coop;
    var _t = variable_struct_get(_m, "t");
    _c.lastRecv = current_time;
    switch (_t)
    {
        case "hello": // host side
            if (!coop_is_host()) { break; }
            if (variable_struct_get(_m, "proto") != _c.proto) { coop_send({ t: "reject", why: "protocol " + string(variable_struct_get(_m, "proto")) + " != " + string(_c.proto) }); coop_log("reject proto"); coop_drop_partner("bad proto"); break; }
            if (variable_struct_get(_m, "game") != global.CurrentVersion) { coop_send({ t: "reject", why: "game version " + string(variable_struct_get(_m, "game")) + " != " + global.CurrentVersion }); coop_drop_partner("bad game version"); break; }
            _c.connected = true;
            _c.status = "partner connected";
            coop_send({ t: "welcome", proto: _c.proto, slot: 2, game: global.CurrentVersion });
            coop_log("handshake ok, mod " + string(variable_struct_get(_m, "modver")));
            coop_send(coop_cfg_msg());
            if (room == NightOpening || room == Office) { coop_send(coop_night_payload()); }
            break;
        case "welcome": // client side
            if (_c.rjN > 0) { coop_log("RECONNECT: back online after " + string(_c.rjN) + " tries"); coop_alert("Reconnected to the host", c_lime, undefined); }
            _c.rjLeft = 0; _c.rjN = 0;
            _c.connected = true;
            _c.status = "connected as player 2";
            coop_log("welcome, slot " + string(variable_struct_get(_m, "slot")));
            coop_send(coop_cfg_msg());
            break;
        case "reject":
            coop_log("rejected: " + string(variable_struct_get(_m, "why")));
            coop_disconnect("rejected: " + string(variable_struct_get(_m, "why")));
            break;
        case "ping":
            coop_send({ t: "pong", ts: variable_struct_get(_m, "ts") });
            break;
        case "pong":
            _c.rtt = current_time - variable_struct_get(_m, "ts");
            break;
        case "pause":
            coop_pause_packet(_m);
            break;
        case "night": // client: follow host into the same night (host is the authority for the night number)
            if (!coop_is_client()) { break; }
            _c.hostNight = variable_struct_get(_m, "night");
            _c.partnerWon = false;
            var _oldNight = variable_global_exists("Night") ? global.Night : undefined;
            coop_apply_night(_m);
            coop_s4_host_night(_m);
            global.CoopSync.followAt = current_time;
            if (_m.night == "Endless") { if (room != Office) { room_goto(Office); } }
            else if (room == Office && _oldNight == _m.night) { coop_log("SYNC: rejoined during night " + string(_m.night) + " -> staying in my office, clock follows the host"); }
            else if (room == NightOpening && _oldNight != _m.night) { coop_log("SYNC: my save had night " + string(_oldNight) + ", host has " + string(_m.night) + " -> restart opening"); room_restart(); }
            else if (room != NightOpening && room != Office) { room_goto(NightOpening); }
            break;
        case "clock": // client: host is the clock authority
            _c.hostTimer = variable_struct_get(_m, "timer");
            if (coop_is_client() && room == Office && variable_global_exists("Timer"))
            {
                var _d = _c.hostTimer - global.Timer;
                if (abs(_d) > 2) { global.Timer = _c.hostTimer; }
                else { global.Timer += _d * 0.25; }
            }
            break;
        case "clockrewind": // host: client used its own Ultra Clock; apply the same fixed game effect
            if (coop_is_host() && room == Office && variable_global_exists("NightSpeedup")
                && is_numeric(global.NightSpeedup) && global.NightSpeedup > 0
                && current_time - _c.lastClientClockReset > 1000)
            {
                _c.lastClientClockReset = current_time;
                global.Timer = 360 - (360 / global.NightSpeedup);
                coop_log("CLOCK: client used Ultra Clock; host timer reset to " + string(global.Timer));
            }
            else { coop_log("CLOCK: rejected invalid, out-of-room, or duplicate client rewind"); }
            break;
        case "snap": // partner office state, ~10 per second
            _c.partner = _m;
            _c.partnerSnapAt = current_time;
            _c.snapsIn++;
            if (coop_is_host() && variable_struct_exists(_m, "tk") && is_array(_m.tk))
            {
                var _A = global.CoopA;
                var _in = array_create(201, false);
                for (var k = 0; k < array_length(_m.tk); k++) { var _q = _m.tk[k]; if (_q >= 0 && _q < 201) { _in[_q] = true; if (_A.tok[_q] == 2) { _A.tokAt[_q] = current_time; } } }
                for (var k = 0; k < 201; k++) { if (_A.tok[k] == 2 && !_in[k] && current_time - _A.tokAt[k] > 600) { _A.tok[k] = 0; coop_log("token: client no longer holds " + coop_anim_name(k)); } }
            }
            if (room == Office && variable_global_exists("Timer") && variable_struct_exists(_m, "tm")) { _c.clockDiff = global.Timer - _m.tm; }
            else { _c.clockDiff = undefined; }
            break;
        case "alert": // partner pressed ping
            _c.pingFlash = current_time;
            _c.pingsIn++;
            audio_play_sound(sfxBitCollect, 10, false);
            coop_log("ping from partner");
            break;
        case "win":
            _c.partnerWon = true;
            _c.partnerWonNight = variable_struct_get(_m, "night");
            if (variable_struct_exists(_m, "er")) { global.CoopE.partnerEr = _m.er; coop_log("ECON: partner's night earnings " + string(_m.er)); }
            coop_log("partner reached 6AM (night " + string(variable_struct_get(_m, "night")) + ")");
            if (_c.bot && room == Office && coop_alive()) { global.CoopS.shotPend = "overlay_survived"; global.CoopS.shotAt = current_time + 2500; }
            break;
        case "bye":
            coop_log("partner left: " + string(variable_struct_get(_m, "why")));
            if (coop_is_host()) { coop_drop_partner("partner left"); } else { coop_disconnect("host left"); }
            break;
        default:
            if (!coop_help_packet(_t, _m) && !coop_anim_packet(_t, _m) && !coop_feat_packet(_t, _m) && !coop_more_packet(_t, _m) && !coop_sync_packet(_t, _m) && !coop_s3_packet(_t, _m) && !coop_s4_packet(_t, _m)) { coop_log("unknown packet " + string(_t)); }
    }
}

function coop_clock_rewind()
{
    if (!variable_global_exists("Timer") || !variable_global_exists("NightSpeedup")
        || !is_numeric(global.NightSpeedup) || global.NightSpeedup <= 0)
    {
        coop_log("CLOCK: Ultra Clock could not read a valid night speed");
        return false;
    }

    global.Timer = 360 - (360 / global.NightSpeedup);
    if (coop_active() && global.Coop.connected)
    {
        if (coop_is_client()) { coop_send({ t: "clockrewind" }); }
        coop_log("CLOCK: Ultra Clock used locally; shared timer request sent=" + string(coop_is_client()));
    }
    return true;
}

function coop_drop_partner(_why)
{
    var _c = global.Coop;
    if (_c.sock >= 0) { network_destroy(_c.sock); }
    _c.sock = -1;
    _c.connected = false;
    _c.rtt = -1;
    _c.status = "hosting on port " + string(_c.port) + ", waiting (" + _why + ")";
    coop_log("partner dropped: " + _why);
    if (variable_global_exists("CoopA")) { for (var i = 0; i < array_length(global.CoopA.tok); i++) { if (global.CoopA.tok[i] == 2) { global.CoopA.tok[i] = 0; coop_log("token: partner dropped -> released " + coop_anim_name(i)); } } }
}

function coop_on_win_night()
{
    if (global.Coop.connected) { coop_send({ t: "win", night: global.Night, er: (is_numeric(global.Night) ? coop_win_earnings() : 0) }); }
    coop_log("win_night night=" + string(global.Night));
}

function coop_alive()
{
    if (room == GameOver) { return false; }
    if (instance_exists(oJumpscareTransition)) { return false; }
    return true;
}

function coop_snapshot()
{
    var _s = { t: "snap", rm: room_get_name(room), alive: coop_alive(), sp: global.CoopS.spec ? 1 : 0, sc: coop_score_arr() };
    if (variable_global_exists("Guard") && is_numeric(global.Guard)) { _s.gn = guard_name(global.Guard); }
    if (variable_global_exists("TimeOfDeath") && is_numeric(global.TimeOfDeath)) { _s.tod = global.TimeOfDeath; }
    if (room == Office)
    {
        if (variable_global_exists("Power")) { _s.pw = round(global.Power * 10) / 10; }
        if (room == Office) { _s.pmax = coop_help_power_max(); } // 0.6.2
        if (variable_global_exists("Doors")) { _s.d0 = global.Doors[0] ? 1 : 0; _s.d1 = global.Doors[1] ? 1 : 0; }
        if (variable_global_exists("CamUp")) { _s.cu = global.CamUp ? 1 : 0; }
        if (variable_global_exists("Cam")) { _s.cam = global.Cam; }
        if (variable_global_exists("MaskDown")) { _s.mk = global.MaskDown ? 1 : 0; }
        if (variable_global_exists("Fan")) { _s.fan = global.Fan ? 1 : 0; }
        if (variable_global_exists("Flashlight")) { _s.fl = global.Flashlight ? 1 : 0; }
        if (variable_global_exists("Temperature")) { _s.tp = round(global.Temperature); }
        if (variable_global_exists("Timer")) { _s.tm = round(global.Timer * 100) / 100; }
        _s.tk = coop_anim_held_list();
        _s.dc = floor(global.CoopA.myDc);
        if (variable_global_exists("PanelUp")) { _s.pu = global.PanelUp ? 1 : 0; }
        if (variable_global_exists("MonitorSystem")) { _s.ms = global.MonitorSystem; }
    }
    return _s;
}

function coop_send_ping()
{
    var _c = global.Coop;
    if (!_c.connected || current_time - _c.lastPingSent < 1000) { return false; }
    _c.lastPingSent = current_time;
    coop_send({ t: "alert" });
    coop_log("ping sent");
    return true;
}

function coop_partner_get(_k, _def)
{
    var _p = global.Coop.partner;
    if (!is_struct(_p) || !variable_struct_exists(_p, _k)) { return _def; }
    return variable_struct_get(_p, _k);
}

function coop_bot_line()
{
    var _c = global.Coop;
    var _s = "STATE room=" + room_get_name(room) + " conn=" + string(_c.connected) + " rtt=" + string(_c.rtt);
    if (variable_global_exists("Night")) { _s += " night=" + string(global.Night); }
    if (variable_global_exists("Timer")) { _s += " timer=" + string_format(global.Timer, 1, 2); }
    if (variable_global_exists("Power")) { _s += " power=" + string(global.Power); }
    if (room == Office) { _s += " AI1=" + string(global.AILevels[1]) + " AI2=" + string(global.AILevels[2]) + " AI12=" + string(global.AILevels[12]) + " d=" + string(global.Doors[0]) + string(global.Doors[1]) + " cu=" + string(global.CamUp) + " tk=" + json_stringify(coop_anim_held_list()) + " gen=" + string(global.CoopA.genExtra); }
    _s += " hostTimer=" + string(_c.hostTimer) + " partnerWon=" + string(_c.partnerWon) + " out=" + string(_c.bytesOut) + " in=" + string(_c.bytesIn);
    _s += " | P: rm=" + string(coop_partner_get("rm", "?")) + " alive=" + string(coop_partner_get("alive", "?")) + " pw=" + string(coop_partner_get("pw", "?"))
        + " d=" + string(coop_partner_get("d0", "?")) + string(coop_partner_get("d1", "?")) + " cu=" + string(coop_partner_get("cu", "?")) + " cam=" + string(coop_partner_get("cam", "?"))
        + " snaps=" + string(_c.snapsIn) + " age=" + string(current_time - _c.partnerSnapAt) + " clockDiff=" + (is_undefined(_c.clockDiff) ? "?" : string_format(_c.clockDiff, 1, 2)) + " pingsIn=" + string(_c.pingsIn);
    return _s;
}

// ===== GUI: status line, partner mini-window, F8 menu (called from oCoopNet Draw GUI End) =====
function coop_draw_gui()
{
    var _c = global.Coop;
    if (variable_global_exists("FontW97White")) { draw_set_font(global.FontW97White); }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    // 0.6.2: auto-reconnect banner
    if (_c.rjLeft > 0 || (_c.rjN > 0 && _c.mode == "client" && !_c.connected))
    {
        var _bt = "Connection lost - reconnecting... (try " + string(_c.rjN) + "/20)";
        var _bw = string_width(_bt) + 12, _bx = display_get_gui_width() / 2 - _bw / 2;
        coop_ui_panel(_bx, 46, _bx + _bw, 62);
        draw_set_color(c_yellow); draw_text(_bx + 6, 48, _bt); draw_set_color(c_white);
    }
    // small status line (always, when coop active)
    else if (_c.mode != "off" && !_c.menuOpen && !(room == Office && _c.connected) && !(coop_is_maze_room(room) && _c.connected) && !(instance_exists(oTitleMenu) && oTitleMenu.CurMenu == "Co-op"))
    {
        if (!instance_exists(oTitleMenu))
        {
            var _st = "CO-OP " + string_upper(_c.mode) + (_c.connected ? "  " + ((_c.rtt >= 0) ? string(_c.rtt) + "ms" : "...") : "  " + _c.status);
            var _sy = display_get_gui_height() - 19; // 0.7.4: bottom-left, off the Extras / menu titles
            coop_ui_panel(3, _sy, 3 + string_width(_st) + 8, _sy + 15);
            draw_set_alpha(0.9); draw_set_color(_c.connected ? make_color_rgb(244, 240, 232) : c_yellow); draw_text(7, _sy + 1, _st); draw_set_alpha(1); draw_set_color(c_white);
        }
    }
    // --- stage 4: spectator view replaces the death screen; the alive side streams frames ---
    if (global.CoopS.spec && room == GameOver) { coop_spec_draw(); return; }
    coop_stream_tick();
    coop_warn_draw();
    coop_feat_draw();
    coop_more_draw();
    coop_salv_draw(); coop_boss_roles_draw();
    coop_draw_scene_participants();
    coop_sync_draw();
    coop_s3_draw();
    // --- partner mini-window + alerts (Office, connected): see CoopUI ---
    if (room == Office && _c.connected) { coop_draw_overlay(); }
    if (!_c.menuOpen) { return; }
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _x = _gw / 2 - 150, _y = _gh / 2 - 90;
    coop_ui_panel(_x, _y, _x + 300, _y + 175);
    draw_set_color(c_white); draw_rectangle(_x, _y, _x + 300, _y + 175, true);
    draw_text(_x + 10, _y + 10, "CO-OP (F8)");
    draw_text(_x + 10, _y + 42, "IP:");
    draw_text(_x + 10, _y + 72, "Port:");
    draw_set_color(_c.focus == 1 ? c_yellow : c_gray); draw_rectangle(_x + 70, _y + 40, _x + 290, _y + 60, true);
    draw_set_color(_c.focus == 2 ? c_yellow : c_gray); draw_rectangle(_x + 70, _y + 70, _x + 290, _y + 90, true);
    draw_set_color(c_white);
    draw_text(_x + 74, _y + 42, IpText + (_c.focus == 1 && (current_time div 500) mod 2 ? "_" : ""));
    draw_text(_x + 74, _y + 72, PortText + (_c.focus == 2 && (current_time div 500) mod 2 ? "_" : ""));
    var _labels = ["HOST", "JOIN", "LEAVE"];
    for (var i = 0; i < 3; i++)
    {
        var _bx = _x + 10 + i * 95;
        draw_rectangle(_bx, _y + 110, _bx + 90, _y + 135, true);
        draw_text(_bx + 8, _y + 114, _labels[i]);
    }
    draw_text(_x + 10, _y + 145, _c.status);
}

// Starting a story night straight from the title (coop night start / bot) skips the game's New Game/Continue path;
// at boot initialize_endless_data() leaves global.Deaths = 0 (a number), and count_jumpscare / NightClear then index it.
function coop_prepare_night()
{
    var _guard = variable_global_exists("Guard") && is_numeric(global.Guard) ? clamp(floor(global.Guard), 0, 200) : 5;
    var _need = max(6, _guard + 1);
    var _hasDeaths = variable_global_exists("Deaths");
    if (!_hasDeaths || !is_array(global.Deaths))
    {
        var _carry = (_hasDeaths && is_numeric(global.Deaths)) ? global.Deaths : 0;
        global.Deaths = array_create(_need, 0);
        global.Deaths[_guard] = _carry;
        coop_log("prepare night: initialized global.Deaths for guard " + string(_guard));
    }
    else
    {
        while (array_length(global.Deaths) < _need) { array_push(global.Deaths, 0); }
    }
}


// 0.6.2: -coop-botdrop N counts real seconds since this client reached the Office (frame counts lie at low fps)
function coop_bot_drop_due(_c)
{
    if (!variable_struct_exists(_c, "botDropAt") || _c.botDropAt < 0) { _c.botDropAt = current_time; }
    return current_time - _c.botDropAt >= _c.botDrop * 1000;
}

// 0.7.6 (S7-2): safe numeric parse for -coop-* flags. Missing/empty/non-numeric value -> default, never a Code Error.
function coop_arg_num(_s, _def)
{
    if (!is_string(_s) || _s == "") { return _def; }
    var _r = _def;
    try { _r = real(_s); } catch (_e) { _r = _def; }
    return _r;
}
