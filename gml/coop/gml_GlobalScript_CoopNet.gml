// ===== Frickbear's Coop: network core (2 players, ONE TCP port, host-authoritative clock) =====
// Protocol: GameMaker framed TCP packets, each = one JSON string { t: <type>, ... }.
// Works through Porthole / any single-port TCP tunnel: client connects to 127.0.0.1:<port>.

global.Coop = {
    proto: 1,
    modver: "0.2.0",
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
    autoNight: -1,
    logFile: "coop.log",
    lastClockSend: 0,
    hostTimer: -1,
    hostNight: undefined,
    partnerWon: false,
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
    botDoors: -1
};

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
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i);
        if (_p == "-coop-host") { _c.mode = "want_host"; }
        else if (_p == "-coop-join") { _c.mode = "want_join"; if (i + 1 < _n && string_char_at(parameter_string(i + 1), 1) != "-") { i++; _c.ip = parameter_string(i); } }
        else if (_p == "-coop-port" && i + 1 < _n) { i++; _c.port = real(parameter_string(i)); }
        else if (_p == "-coop-bot") { _c.bot = true; }
        else if (_p == "-coop-autonight" && i + 1 < _n) { i++; _c.autoNight = real(parameter_string(i)); }
        else if (_p == "-coop-log" && i + 1 < _n) { i++; _c.logFile = parameter_string(i); }
        else if (_p == "-coop-botping") { _c.botPing = true; }
        else if (_p == "-coop-botdoors" && i + 1 < _n) { i++; _c.botDoors = real(parameter_string(i)); }
        else if (_p == "-coop-botwin" && i + 1 < _n) { i++; _c.botWin = real(parameter_string(i)); }
    }
}

function coop_is_client() { return global.Coop.mode == "client"; }
function coop_is_host() { return global.Coop.mode == "host"; }
// coop session in progress: the other player keeps playing, so losing window focus must not pause
function coop_active() { return variable_global_exists("Coop") && global.Coop.mode != "off"; }

function coop_block_save(_what)
{
    if (coop_is_client())
    {
        coop_log("save blocked on client: " + _what);
        return true;
    }
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
    return true;
}

function coop_disconnect(_why)
{
    var _c = global.Coop;
    if (_c.connected) { coop_send({ t: "bye", why: _why }); }
    if (_c.sock >= 0) { network_destroy(_c.sock); }
    if (_c.server >= 0) { network_destroy(_c.server); }
    if (_c.mode != "off") { coop_log("disconnect: " + _why); }
    _c.sock = -1;
    _c.server = -1;
    _c.connected = false;
    _c.mode = "off";
    _c.rtt = -1;
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
    return _m;
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
            if (room == NightOpening || room == Office) { coop_send(coop_night_payload()); }
            break;
        case "welcome": // client side
            _c.connected = true;
            _c.status = "connected as player 2";
            coop_log("welcome, slot " + string(variable_struct_get(_m, "slot")));
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
        case "night": // client: follow host into the same night
            if (!coop_is_client()) { break; }
            _c.hostNight = variable_struct_get(_m, "night");
            _c.partnerWon = false;
            global.Night = variable_struct_get(_m, "night");
            if (variable_struct_exists(_m, "difficulty")) { global.Difficulty = _m.difficulty; }
            if (variable_struct_exists(_m, "ai")) { global.AILevels = _m.ai; }
            if (variable_struct_exists(_m, "speedup")) { global.NightSpeedup = _m.speedup; }
            if (variable_struct_exists(_m, "shuffle")) { global.ShuffleMode = _m.shuffle; }
            coop_log("host started night " + string(global.Night));
            if (room != NightOpening && room != Office) { room_goto(NightOpening); }
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
        case "snap": // partner office state, ~10 per second
            _c.partner = _m;
            _c.partnerSnapAt = current_time;
            _c.snapsIn++;
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
            coop_log("partner reached 6AM (night " + string(variable_struct_get(_m, "night")) + ")");
            break;
        case "bye":
            coop_log("partner left: " + string(variable_struct_get(_m, "why")));
            if (coop_is_host()) { coop_drop_partner("partner left"); } else { coop_disconnect("host left"); }
            break;
        default:
            coop_log("unknown packet " + string(_t));
    }
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
}

function coop_on_win_night()
{
    if (global.Coop.connected) { coop_send({ t: "win", night: global.Night }); }
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
    var _s = { t: "snap", rm: room_get_name(room), alive: coop_alive() };
    if (room == Office)
    {
        if (variable_global_exists("Power")) { _s.pw = round(global.Power * 10) / 10; }
        if (variable_global_exists("Doors")) { _s.d0 = global.Doors[0] ? 1 : 0; _s.d1 = global.Doors[1] ? 1 : 0; }
        if (variable_global_exists("CamUp")) { _s.cu = global.CamUp ? 1 : 0; }
        if (variable_global_exists("Cam")) { _s.cam = global.Cam; }
        if (variable_global_exists("MaskDown")) { _s.mk = global.MaskDown ? 1 : 0; }
        if (variable_global_exists("Fan")) { _s.fan = global.Fan ? 1 : 0; }
        if (variable_global_exists("Flashlight")) { _s.fl = global.Flashlight ? 1 : 0; }
        if (variable_global_exists("Temperature")) { _s.tp = round(global.Temperature); }
        if (variable_global_exists("Timer")) { _s.tm = round(global.Timer * 100) / 100; }
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
    // small status line (always, when coop active)
    if (_c.mode != "off" && !_c.menuOpen && !(room == Office && _c.connected))
    {
        draw_set_alpha(0.7);
        draw_set_color(c_white);
        draw_text(4, 4, "COOP " + _c.mode + ": " + _c.status + (_c.rtt >= 0 ? "  " + string(_c.rtt) + "ms" : ""));
        draw_set_alpha(1);
    }
    // --- partner mini-window (Office, connected) ---
    if (room == Office && _c.connected)
    {
        var _gw0 = display_get_gui_width();
        var _w = 150, _h = 84;
        var _px = _gw0 - _w - 4, _py = 30;
        var _fresh = current_time - _c.partnerSnapAt < 1000;
        var _alive = coop_partner_get("alive", true);
        var _flash = current_time - _c.pingFlash < 2000;
        draw_set_alpha(0.75); draw_set_color(c_black); draw_rectangle(_px, _py, _px + _w, _py + _h, false); draw_set_alpha(1);
        var _border = _flash ? (((current_time div 150) mod 2) ? c_yellow : c_red) : (_alive ? c_white : c_red);
        draw_set_color(_border); draw_rectangle(_px, _py, _px + _w, _py + _h, true);
        if (_flash) { draw_rectangle(_px + 1, _py + 1, _px + _w - 1, _py + _h - 1, true); }
        draw_set_color(c_white);
        draw_text(_px + 4, _py + 2, "PARTNER" + (_c.rtt >= 0 ? "  " + string(_c.rtt) + "ms" : ""));
        if (!_fresh) { draw_set_color(c_gray); draw_text(_px + 4, _py + 18, "no data..."); }
        else if (!_alive) { draw_set_color(c_red); draw_text(_px + 4, _py + 18, "DEAD - spectating"); }
        else if (coop_partner_get("rm", "") != "Office") { draw_text(_px + 4, _py + 18, "in " + string(coop_partner_get("rm", "?"))); }
        else
        {
            var _pw = coop_partner_get("pw", 0);
            draw_text(_px + 4, _py + 18, "PWR " + string(max(_pw, 0)) + "%");
            // power bar
            draw_set_color(c_dkgray); draw_rectangle(_px + 76, _py + 21, _px + _w - 6, _py + 29, false);
            draw_set_color(_pw > 25 ? c_lime : c_red); draw_rectangle(_px + 76, _py + 21, _px + 76 + (_w - 82) * clamp(_pw, 0, 100) / 100, _py + 29, false);
            // doors
            draw_set_color(c_white);
            draw_text(_px + 4, _py + 34, "L");
            draw_set_color(coop_partner_get("d0", 0) ? c_red : c_dkgray); draw_rectangle(_px + 16, _py + 35, _px + 30, _py + 47, false);
            draw_set_color(c_white);
            draw_text(_px + 36, _py + 34, "R");
            draw_set_color(coop_partner_get("d1", 0) ? c_red : c_dkgray); draw_rectangle(_px + 48, _py + 35, _px + 62, _py + 47, false);
            draw_set_color(c_white);
            var _view = coop_partner_get("cu", 0) ? "CAM " + string(coop_partner_get("cam", "?")) : "OFFICE";
            if (coop_partner_get("mk", 0)) { _view = "MASK"; }
            draw_text(_px + 70, _py + 34, _view);
            var _ex = "";
            if (coop_partner_get("fan", 0)) { _ex += "FAN "; }
            if (coop_partner_get("fl", 0)) { _ex += "LIGHT "; }
            _ex += "T" + string(coop_partner_get("tp", 0));
            draw_text(_px + 4, _py + 50, _ex);
        }
        draw_set_color(_flash ? c_yellow : c_gray);
        draw_text(_px + 4, _py + 66, _flash ? "PING!" : "P = ping");
        draw_set_color(c_white);
    }
    if (!_c.menuOpen) { return; }
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _x = _gw / 2 - 150, _y = _gh / 2 - 90;
    draw_set_alpha(0.85); draw_set_color(c_black); draw_rectangle(_x, _y, _x + 300, _y + 175, false); draw_set_alpha(1);
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
