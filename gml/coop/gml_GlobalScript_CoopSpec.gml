// ===== Frickbear's Coop, stage 4: SPECTATOR + HELP =====
// Spectator: dying while the partner is still alive in the office does NOT count a death (no Deaths++/save,
// no Endless life lost) and does not show the death screen: the GameOver room becomes a spectator view that
// shows a downscaled live frame of the partner, streamed over the SAME TCP socket (binary packets, zlib),
// with adaptive size/rate driven by acks (works through a Porthole relay: slower acks -> smaller/rarer frames).
// Partner reaches 6 AM -> win_night() here too (normal progress on the host). Partner dies too -> the
// skipped death is counted now and the real GameOver screen appears for both.
// Help: G = give 10% power, H = warn partner (flash where their threat is; free, cd 20 s),
// L = remote audio lure in partner's office. Small native buttons under the mini-window do the same.

global.CoopS = {
    spec: false, armed: false, skipped: false, killer: -1, specSince: 0, partnerDeadSince: -1,
    // receiver
    frameSurf: -1, fw: 0, fh: 0, framesIn: 0, lastFrameAt: 0, fpsT: 0, fpsN: 0, rfps: 0, inLevel: -1, ackQ: [], botLag: 0,
    // sender
    capSurf: -1, seq: 0, ackSeq: 0, sentAt: array_create(64, 0), level: 2, lastSend: -100000, lastAdapt: 0,
    lat: -1, bytesWin: 0, kbps: 0, framesOut: 0, lastSize: 0, budget: 4096, sending: false,
    rxBytesWin: 0, rxKbps: 0, rxRateAt: 0, lastFrameSize: 0,
    // help
    cdGive: -100000, cdWarn: -100000, warnUntil: 0, warnWhere: "", warnName: "", cdLure: -100000, hintUntil: 0,
    botHelp: -1, botHelpStep: 0, botHelpAt: 0, botDie: -1, botDieDone: false, shotPend: "", shotAt: 0, specShot: false, btnShot: false,
    st: { specIn: 0, specWin: 0, specLose: 0, skipped: 0, counted: 0, framesOut: 0, framesIn: 0, levelUp: 0, levelDown: 0, give: 0, warn: 0, lure: 0, giveIn: 0, warnIn: 0, lureIn: 0, refunds: 0 }
};
// [w, h, interval ms]
#macro COOP_LV [[960, 540, 16], [640, 360, 16], [480, 270, 16], [320, 180, 16], [256, 144, 16]]

function coop_spec_parse_args()
{
    var _s = global.CoopS, _n = parameter_count();
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i);
        if (_p == "-coop-botlag" && i + 1 < _n) { i++; _s.botLag = real(parameter_string(i)); }
        else if (_p == "-coop-bothelp" && i + 1 < _n) { i++; _s.botHelp = real(parameter_string(i)); }
        else if (_p == "-coop-botdie" && i + 1 < _n) { i++; _s.botDie = real(parameter_string(i)); }
        else if (_p == "-coop-budget" && i + 1 < _n) { i++; _s.budget = real(parameter_string(i)); }
    }
}

function coop_partner_alive_in_office()
{
    var _c = global.Coop;
    return _c.connected && current_time - _c.partnerSnapAt < 3000 && coop_partner_get("rm", "") == "Office"
        && coop_partner_get("alive", false) && !coop_partner_get("sp", 0) && !_c.partnerWon;
}

// count_jumpscare() hook: true = do not count this death (partner still alive -> I become a spectator)
function coop_spec_skip_count(_id)
{
    if (!coop_active() || room != Office || !coop_partner_alive_in_office()) { return false; }
    var _s = global.CoopS;
    _s.armed = true; _s.skipped = true; _s.killer = _id; _s.st.skipped++;
    coop_log("SPECTATOR: death by " + coop_anim_name(_id) + " NOT counted (partner alive) - no Deaths++, no save; Deaths=" + json_stringify(global.Deaths));
    return true;
}

// oGameOver Create hook (instance scope): true = spectator mode, the death screen stays inactive
function coop_spec_gameover_create()
{
    var _s = global.CoopS;
    if (!_s.armed) { return false; }
    _s.armed = false;
    if (coop_partner_alive_in_office())
    {
        _s.spec = true; _s.specSince = current_time; _s.partnerDeadSince = -1; _s.st.specIn++;
        _s.framesIn = 0; _s.inLevel = -1; _s.ackQ = [];
        _s.fpsN = 0; _s.rfps = 0; _s.fpsT = current_time;
        _s.rxBytesWin = 0; _s.rxKbps = 0; _s.rxRateAt = current_time; _s.lastFrameSize = 0;
        application_surface_draw_enable(true);
        coop_log("SPECTATOR: watching partner (GameOver screen suppressed)");
        return true;
    }
    coop_log("SPECTATOR: partner no longer alive at GameOver -> normal death");
    coop_spec_count_now();
    return false;
}

function coop_spec_count_now()
{
    var _s = global.CoopS;
    if (!_s.skipped) { return; }
    _s.skipped = false; _s.st.counted++;
    coop_prepare_night();
    try { count_jumpscare(_s.killer); coop_log("SPECTATOR: skipped death counted now (" + coop_anim_name(_s.killer) + ")"); }
    catch (_e) { coop_log("SPECTATOR: count_jumpscare failed: " + string(_e)); }
}

function coop_spec_win()
{
    var _s = global.CoopS;
    _s.spec = false; _s.skipped = false; _s.st.specWin++;
    coop_log("SPECTATOR: partner survived to 6 AM -> NightClear here too (night " + string(global.Night) + ", host=" + string(coop_is_host()) + ")");
    // NightClear draws global.Freezeframe: use the last streamed frame
    var _w = display_get_gui_width(), _h = display_get_gui_height();
    var _t = surface_create(_w, _h);
    surface_set_target(_t); draw_clear(c_black);
    if (surface_exists(_s.frameSurf)) { gpu_set_blendenable(false); draw_surface_stretched(_s.frameSurf, 0, 0, _w, _h); gpu_set_blendenable(true); }
    surface_reset_target();
    global.Freezeframe = sprite_create_from_surface(_t, 0, 0, _w, _h, false, false, 0, 0);
    surface_free(_t);
    coop_prepare_night();
    var _coopBefore = variable_global_exists("RunEarnings") ? global.RunEarnings : 0;
    win_night();
    if (is_numeric(global.Night)) { coop_spec_reward(_coopBefore); }
    coop_log("SPECTATOR: after win_night Deaths=" + json_stringify(global.Deaths) + " StartRoom=" + string(global.StartRoom));
}

function coop_spec_lose(_why)
{
    var _s = global.CoopS;
    _s.spec = false; _s.st.specLose++;
    coop_log("SPECTATOR: " + _why + " -> both dead, GameOver for real");
    coop_spec_count_now();
    room_restart();
}

// oCoopNet Step
function coop_spec_step()
{
    var _s = global.CoopS, _c = global.Coop;
    // bot: die on purpose at a given timer (picks an active animatronic as the killer)
    if (_s.botDie >= 0 && !_s.botDieDone && room == Office && variable_global_exists("Timer") && global.Timer >= _s.botDie && coop_alive())
    {
        var _k = -1; for (var n = 0; n < array_length(global.CoopA.ids); n++) { var _q = global.CoopA.ids[n]; if (coop_anim_inst(_q) != noone && !coop_partner_holds(_q)) { _k = _q; break; } }
        if (_k >= 0)
        {
            _s.botDieDone = true;
            coop_log("bot: dying on purpose at timer " + string(global.Timer) + " killer " + coop_anim_name(_k));
            jumpscare(_k);
        }
    }
    // deliver delayed acks (bot: simulated slow relay)
    while (array_length(_s.ackQ) > 0 && current_time >= _s.ackQ[0][0]) { coop_send({ t: "fack", s: _s.ackQ[0][1] }); array_delete(_s.ackQ, 0, 1); }
    if (_s.shotPend != "" && current_time >= _s.shotAt) { coop_log("SHOT " + _s.shotPend); _s.shotPend = ""; }
    if (!_s.spec) { return; }
    if (room != GameOver) { _s.spec = false; coop_log("SPECTATOR: left GameOver room -> spectator off"); return; }
    if (!_c.connected) { coop_spec_lose("partner disconnected"); return; }
    if (_c.partnerWon || coop_partner_get("rm", "") == "NightClear") { coop_spec_win(); return; }
    var _pdead = current_time - _c.partnerSnapAt < 3000 && (!coop_partner_get("alive", true) || coop_partner_get("sp", 0) || coop_partner_get("rm", "Office") == "GameOver");
    if (_pdead) { if (_s.partnerDeadSince < 0) { _s.partnerDeadSince = current_time; } else if (current_time - _s.partnerDeadSince > 500) { coop_spec_lose("partner died too"); return; } }
    else { _s.partnerDeadSince = -1; }
    if (keyboard_check_pressed(ord("P"))) { coop_send_ping(); }
    if (_c.bot && !_s.specShot && _s.framesIn > 3 && current_time - _s.specSince > 6000) { _s.specShot = true; coop_send_ping(); coop_log("SHOT spectator"); }
    if (current_time - _s.fpsT >= 2000) { _s.rfps = _s.fpsN * 1000 / max(1, current_time - _s.fpsT); _s.fpsN = 0; _s.fpsT = current_time; }
}

// ---------- stream: sender (alive player, called from Draw GUI End) ----------
function coop_stream_tick()
{
    var _s = global.CoopS, _c = global.Coop;
    var _want = room == Office && _c.connected && current_time - _c.partnerSnapAt < 3000 && coop_partner_get("sp", 0);
    if (!_want) { if (_s.sending) { _s.sending = false; coop_log("stream: stop (frames " + string(_s.framesOut) + ")"); } return; }
    if (!_s.sending) { _s.sending = true; _s.ackSeq = _s.seq; _s.lastAdapt = current_time; _s.bytesWin = 0; coop_log("stream: start, level " + string(_s.level)); }
    var _lv = COOP_LV;
    var _inflight = _s.seq - _s.ackSeq;
    // adapt every 3 s: latency of acks (includes relay RTT) and bandwidth budget
    if (current_time - _s.lastAdapt >= 3000)
    {
        _s.kbps = _s.bytesWin / 1024 / ((current_time - _s.lastAdapt) / 1000);
        _s.bytesWin = 0; _s.lastAdapt = current_time;
        var _old = _s.level;
        if ((_s.lat > 400 || _s.kbps > _s.budget || _inflight >= 24) && _s.level < 4) { _s.level++; _s.st.levelDown++; }
        else if (_s.lat >= 0 && _s.lat < 150 && _inflight < 16 && _s.kbps < _s.budget * 0.5 && _s.level > 0) { _s.level--; _s.st.levelUp++; }
        if (_old != _s.level) { coop_log("stream: level " + string(_old) + " -> " + string(_s.level) + " (" + string(_lv[_s.level][0]) + "x" + string(_lv[_s.level][1]) + " every " + string(_lv[_s.level][2]) + "ms; ack lat " + string(round(_s.lat)) + "ms, " + string_format(_s.kbps, 1, 1) + " KB/s, inflight " + string(_inflight) + ")"); }
    }
    if (_inflight >= 32) { if (current_time - _s.lastSend > 4000) { _s.ackSeq = _s.seq; coop_log("stream: acks stalled 4s, resync"); } return; }
    if (current_time - _s.lastSend < _lv[_s.level][2]) { return; }
    var _w = _lv[_s.level][0], _h = _lv[_s.level][1];
    var _src = surface_exists(global.UISurface) ? global.UISurface : application_surface;
    if (!surface_exists(_src)) { return; }
    if (!surface_exists(_s.capSurf) || surface_get_width(_s.capSurf) != _w) { if (surface_exists(_s.capSurf)) { surface_free(_s.capSurf); } _s.capSurf = surface_create(_w, _h); }
    surface_set_target(_s.capSurf);
    draw_clear(c_black);
    gpu_set_blendenable(false);
    draw_surface_stretched(_src, 0, 0, _w, _h);
    gpu_set_blendenable(true);
    surface_reset_target();
    var _raw = buffer_create(_w * _h * 4, buffer_fixed, 1);
    buffer_get_surface(_raw, _s.capSurf, 0);
    var _cmp = buffer_compress(_raw, 0, _w * _h * 4);
    buffer_delete(_raw);
    var _csz = buffer_get_size(_cmp);
    var _pk = buffer_create(10 + _csz, buffer_fixed, 1);
    _s.seq++;
    buffer_write(_pk, buffer_u8, 1); buffer_write(_pk, buffer_u32, _s.seq); buffer_write(_pk, buffer_u16, _w); buffer_write(_pk, buffer_u16, _h); buffer_write(_pk, buffer_u8, _s.level);
    buffer_copy(_cmp, 0, _csz, _pk, 10);
    buffer_delete(_cmp);
    network_send_packet(_c.sock, _pk, 10 + _csz);
    buffer_delete(_pk);
    _c.bytesOut += 10 + _csz; _s.bytesWin += 10 + _csz; _s.lastSize = 10 + _csz;
    _s.sentAt[_s.seq mod 64] = current_time; _s.lastSend = current_time; _s.framesOut++; _s.st.framesOut++;
    if (_s.framesOut == 1 || _s.framesOut mod 40 == 0) { coop_log("stream: frame #" + string(_s.seq) + " " + string(_w) + "x" + string(_h) + " " + string(10 + _csz) + " bytes (raw " + string(_w * _h * 4) + "), lat " + string(round(_s.lat)) + "ms"); }
}

function coop_stream_on_ack(_seq)
{
    var _s = global.CoopS;
    var _l = current_time - _s.sentAt[_seq mod 64];
    _s.lat = (_s.lat < 0) ? _l : _s.lat * 0.7 + _l * 0.3;
    _s.ackSeq = max(_s.ackSeq, _seq);
}

// ---------- stream: receiver (async networking, binary packet) ----------
function coop_stream_on_frame(_b, _size)
{
    var _s = global.CoopS;
    buffer_seek(_b, buffer_seek_start, 1);
    var _seq = buffer_read(_b, buffer_u32), _w = buffer_read(_b, buffer_u16), _h = buffer_read(_b, buffer_u16), _lvl = buffer_read(_b, buffer_u8);
    if (_s.botLag > 0) { array_push(_s.ackQ, [current_time + _s.botLag, _seq]); } else { coop_send({ t: "fack", s: _seq }); }
    if (!_s.spec) { return; }
    var _cb = buffer_create(_size - 10, buffer_fixed, 1);
    buffer_copy(_b, 10, _size - 10, _cb, 0);
    var _d = buffer_decompress(_cb);
    buffer_delete(_cb);
    if (_d < 0) { coop_log("stream: bad frame " + string(_seq)); return; }
    if (buffer_get_size(_d) == _w * _h * 4)
    {
        if (!surface_exists(_s.frameSurf) || surface_get_width(_s.frameSurf) != _w) { if (surface_exists(_s.frameSurf)) { surface_free(_s.frameSurf); } _s.frameSurf = surface_create(_w, _h); }
        buffer_set_surface(_d, _s.frameSurf, 0);
        _s.fw = _w; _s.fh = _h; _s.framesIn++; _s.st.framesIn++; _s.fpsN++; _s.lastFrameAt = current_time;
        _s.rxBytesWin += _size; _s.lastFrameSize = _size;
        var _rateElapsed = current_time - _s.rxRateAt;
        if (_rateElapsed >= 1000) { _s.rxKbps = _s.rxBytesWin / 1024 / (_rateElapsed / 1000); _s.rxBytesWin = 0; _s.rxRateAt = current_time; }
        if (_s.inLevel != _lvl) { coop_log("stream: receiving level " + string(_lvl) + " " + string(_w) + "x" + string(_h) + " (" + string(_size) + " bytes/frame)"); _s.inLevel = _lvl; }
    }
    buffer_delete(_d);
}

// ---------- spectator view (Draw GUI End) ----------
function coop_spec_draw()
{
    var _s = global.CoopS, _c = global.Coop;
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    draw_set_alpha(1); draw_set_color(c_black); draw_rectangle(0, 0, _gw, _gh, false);
    if (surface_exists(_s.frameSurf) && _s.framesIn > 0)
    {
        gpu_set_blendenable(false);
        draw_surface_stretched(_s.frameSurf, 0, 0, _gw, _gh);
        gpu_set_blendenable(true);
    }
    else { draw_set_color(c_gray); draw_set_halign(fa_center); draw_text(_gw / 2, _gh / 2, "waiting for partner's camera..."); draw_set_halign(fa_left); }
    // partner HUD on top (from the state snapshot)
    var _tm = coop_partner_get("tm", 0), _hr = floor(_tm / 60 + 12) mod 12; if (_hr == 0) { _hr = 12; }
    var _pw = coop_partner_get("pw", 0);
    var _view = coop_partner_get("cu", 0) ? ((coop_partner_get("ms", "Cameras") == "Shop") ? "SHOP" : "CAM " + string(coop_partner_get("cam", "?"))) : "OFFICE";
    if (coop_partner_get("mk", 0)) { _view = "MASK"; } if (coop_partner_get("pu", 0)) { _view = "PANEL"; }
    draw_set_alpha(0.55); draw_set_color(c_black); draw_rectangle(0, 0, _gw, 14, false); draw_set_alpha(1);
    draw_set_color(((current_time div 600) mod 2) ? c_red : c_white); draw_text(4, 1, "SPECTATING PARTNER");
    draw_set_alpha(0.55); draw_set_color(c_black); draw_rectangle(2, 16, 54, 74, false); draw_set_alpha(1);
    coop_art_partner_portrait(4, 18, 48, 1);
    draw_set_color(c_white); draw_text(6, 62, "P" + string(coop_partner_slot()));
    draw_set_color(c_white);
    draw_text(140, 1, string(_hr) + " AM   power " + string(floor(max(_pw, 0))) + "%   doors " + (coop_partner_get("d0", 0) ? "L" : "-") + (coop_partner_get("d1", 0) ? "R" : "-") + "   " + _view);
    draw_set_color(c_ltgray);
    var _age = current_time - _s.lastFrameAt;
    draw_set_alpha(0.72); draw_set_color(c_black); draw_rectangle(0, _gh - 32, _gw, _gh, false); draw_set_alpha(1);
    draw_set_color(c_ltgray);
    draw_text(4, _gh - 29, "P: ping    M: mark partner's camera");
    draw_set_halign(fa_right);
    draw_text(_gw - 4, _gh - 13, string(_s.fw) + "x" + string(_s.fh) + " " + string_format(_s.rfps, 1, 1) + "fps" + ((_c.rtt >= 0) ? " " + string(_c.rtt) + "ms" : "") + ((_age > 2000 && _s.framesIn > 0) ? " (stalled)" : ""));
    draw_set_halign(fa_left);
    draw_text(4, _gh - 15, "Both players must die for Game Over | 6 AM wins");
    if (global.CoopCfg.devMode)
    {
        var _dx = max(4, _gw - 274), _dy = 18, _rtt = (_c.rtt >= 0) ? string(_c.rtt) : "--";
        draw_set_alpha(0.82); draw_set_color(c_black); draw_rectangle(_dx, _dy, _gw - 4, _dy + 76, false); draw_set_alpha(1);
        draw_set_color(c_yellow); draw_text(_dx + 6, _dy + 3, "DEV STREAM  level " + string(max(_s.inLevel, 0)));
        draw_set_color(c_white);
        draw_text(_dx + 6, _dy + 17, "Frame: " + string(_s.fw) + "x" + string(_s.fh) + "  " + string_format(_s.rfps, 1, 1) + " FPS");
        draw_text(_dx + 6, _dy + 31, "RTT: " + _rtt + " ms  rate: " + string_format(_s.rxKbps, 1, 1) + " KB/s");
        draw_text(_dx + 6, _dy + 45, "Packet: " + string(_s.lastFrameSize) + " B  age: " + string(_age) + " ms");
        draw_text(_dx + 6, _dy + 59, "Frames received: " + string(_s.framesIn));
    }
    if (current_time - _c.lastPingSent < 1500) { draw_set_color(c_yellow); draw_text(4, 16, "ping sent!"); }
    coop_draw_alerts();
}

// ---------- help ----------
function coop_help_key_free(_k)
{
    if (!variable_global_exists("ControlsOptions")) { return true; }
    return !array_contains(global.ControlsOptions, _k);
}

// 0.6.3: how much power the partner can still take; -1 = no fresh data (snapshot older than 1.5 s)
function coop_give_room()
{
    var _c = global.Coop;
    if (current_time - _c.partnerSnapAt > 1500) { return -1; }
    var _ppw = coop_partner_get("pw", -1), _pmax = coop_partner_get("pmax", 100);
    if (!is_real(_ppw) || _ppw < 0 || !is_real(_pmax)) { return -1; }
    return _pmax - _ppw;
}

function coop_help_power_max() { return (instance_exists(oCamera) && variable_instance_exists(oCamera, "MaxPower")) ? oCamera.MaxPower : 100; }

// _what: "give" | "warn" | "lure"; returns true if sent
function coop_help_do(_what, _src)
{
    var _s = global.CoopS;
    if (room != Office || !coop_alive()) { return false; }
    if (!coop_partner_alive_in_office()) { coop_alert("Help: partner is not in the office", c_gray, undefined); return false; }
    var _now = current_time;
    switch (_what)
    {
        case "give":
            if (_now < _s.cdGive) { coop_alert("Give power: cooldown " + string(ceil((_s.cdGive - _now) / 1000)) + "s", c_gray, undefined); return false; }
            if (global.Power < 15) { coop_alert("Give power: need 15%+", c_gray, undefined); return false; }
            // 0.6.3: ONE check for every path (G key, F8 button, bot): fresh partner power, give only what fits (max 10%)
            var _room = coop_give_room();
            if (_room < 0) { coop_alert("Give power: partner's power unknown (no fresh data)", c_gray, undefined); coop_log("help: give skipped (" + _src + "), partner power data stale"); return false; }
            if (_room < 2) { coop_alert("Give power: partner's power is full", c_gray, undefined); coop_log("help: give skipped (" + _src + "), partner power " + string(coop_partner_get("pw", -1)) + "/" + string(coop_partner_get("pmax", 100))); return false; }
            var _amt = min(10, floor(_room));
            global.Power -= _amt; _s.cdGive = _now + 20000; _s.st.give++; global.CoopF.sc.give += _amt;
            coop_send({ t: "give", amt: _amt });
            coop_alert("Sent " + string(_amt) + "% power to partner", c_lime, sfxBitCollect);
            break;
        case "warn":
            if (_now < _s.cdWarn) { coop_alert("Warn: cooldown " + string(ceil((_s.cdWarn - _now) / 1000)) + "s", c_gray, undefined); return false; }
            _s.cdWarn = _now + 20000; _s.st.warn++; global.CoopF.sc.warn++;
            coop_send({ t: "warn" });
            coop_alert("Warning sent to partner (they see where the threat is)", c_lime, undefined);
            break;
        case "lure":
            if (_now < _s.cdLure) { coop_alert("Remote lure: cooldown " + string(ceil((_s.cdLure - _now) / 1000)) + "s", c_gray, undefined); return false; }
            _s.cdLure = _now + 15000; _s.st.lure++; // 0.5.0: free (no power cost)
            coop_send({ t: "rlure" });
            coop_alert("Remote lure played in partner's office", c_lime, sfxBitCollect);
            break;
        default: return false;
    }
    coop_log("help: " + _what + " sent (" + _src + "), my power now " + string(global.Power));
    if (_src == "bot") { _s.shotPend = "help_" + _what; _s.shotAt = current_time + 1200; }
    return true;
}

function coop_help_packet(_t, _m)
{
    var _s = global.CoopS;
    switch (_t)
    {
        case "fack": coop_stream_on_ack(_m.s); return true;
        case "give":
            _s.st.giveIn++;
            if (room != Office || !coop_alive()) { coop_send({ t: "helpack", what: "give", ok: 0, amt: _m.amt }); return true; }
            var _old = global.Power;
            global.Power = min(global.Power + _m.amt, max(coop_help_power_max(), global.Power));
            var _got = global.Power - _old;
            if (round(_got) >= 1) { coop_alert("Partner sent you +" + string(round(_got)) + "% power", c_lime, sfxBitCollect); } // 0.6.2: no "+0%" alert
            coop_log("help: got power " + string(_old) + " -> " + string(global.Power));
            if (_got < _m.amt) { coop_send({ t: "helpack", what: "give", ok: 0, amt: _m.amt - _got }); }
            coop_send(coop_snapshot()); global.Coop.lastSnapSend = current_time; // 0.6.3: the giver sees my new power at once
            return true;
        case "warn":
            _s.st.warnIn++;
            if (room != Office || !coop_alive()) { return true; }
            var _w = coop_warn_threat();
            _s.warnWhere = _w[0]; _s.warnName = _w[1]; _s.warnUntil = current_time + 2800;
            audio_play_sound(sfxError, 10, false);
            coop_log("help: partner warned me -> threat " + _w[0] + " (" + _w[1] + ")");
            return true;
        case "rlure":
            _s.st.lureIn++;
            coop_log("help: partner played a remote lure here");
            if (room == Office && coop_alive()) { coop_alert("Partner played a lure on your cameras", c_lime, undefined); }
            var _old = global.CoopA.lureChance; global.CoopA.lureChance = 80;
            coop_anim_packet("lure", _m);
            global.CoopA.lureChance = _old;
            return true;
        case "helpack":
            if (!_m.ok)
            {
                _s.st.refunds++;
                var _ref = (_m.what == "give") ? _m.amt : 0;
                if (room == Office) { global.Power += _ref; } global.CoopF.sc.give = max(0, global.CoopF.sc.give - _ref);
                coop_alert("Help not needed (" + _m.what + "), refunded " + string(round(_ref)) + "%", c_gray, undefined);
                coop_log("help: " + _m.what + " refused by partner, refund " + string(_ref));
            }
            return true;
    }
    return false;
}

// usage compensation (door help removed in 0.4.1)
function coop_help_usage_comp() { return 0; }

// coop_warn_threat / coop_warn_draw moved to CoopFeat (0.5.0: compact pixel icons)

// oCoopNet Step (Office)
function coop_help_step()
{
    var _s = global.CoopS, _c = global.Coop;
    if (room != Office) { return; }
    if (!_c.connected || !coop_alive()) { return; }
    if (variable_global_exists("DevMode") && global.DevMode) { return; }
    if (keyboard_check_pressed(ord("G")) && coop_help_key_free(ord("G"))) { coop_help_do("give", "key G"); }
    if (keyboard_check_pressed(ord("H")) && coop_help_key_free(ord("H"))) { coop_help_do("warn", "key H"); }
    if (keyboard_check_pressed(ord("L")) && coop_help_key_free(ord("L"))) { coop_help_do("lure", "key L"); }
    // bot: fire each help action in turn
    if (_s.botHelp >= 0 && global.Timer >= _s.botHelp && _s.botHelpStep < 4 && current_time - _s.botHelpAt > 16000 && coop_partner_alive_in_office())
    {
        _s.botHelpAt = current_time;
        if (!_s.btnShot && _s.botHelpStep == 1) { _s.btnShot = true; coop_log("SHOT help_buttons"); return; } // 0.6.2: give first, while the partner still has full power
        var _acts = ["give", "warn", "lure", "warn"];
        coop_log("bot: help " + _acts[_s.botHelpStep]);
        coop_help_do(_acts[_s.botHelpStep], "bot");
        _s.botHelpStep++;
    }
}

// button rects under the mini-window (only in compact mode): [x1, y1, x2, y2, action, label]
function coop_help_buttons(_px, _py, _w)
{
    var _bw = (_w - 2 * 2) / 3, _y1 = _py + 31, _y2 = _py + 46;
    var _r = [];
    var _def = [["give", "G+pw"], ["warn", "H !"], ["lure", "L lure"]];
    for (var i = 0; i < 3; i++) { var _x1 = _px + i * (_bw + 2); array_push(_r, [_x1, _y1, _x1 + _bw, _y2, _def[i][0], _def[i][1]]); }
    return _r;
}

function coop_help_cd_of(_act)
{
    var _s = global.CoopS;
    switch (_act) { case "give": return _s.cdGive; case "lure": return _s.cdLure; default: return _s.cdWarn; }
}

// Begin Step: a click exactly on a help button is used and cleared; every other click goes to the game
function coop_help_click()
{
    var _u = global.CoopUI;
    if (room != Office || !global.Coop.connected || !coop_alive() || !variable_struct_exists(_u, "btns")) { return; }
    // 0.6.2: press + same-frame hit test; a press that missed is retried on release (cursor not updated yet in that frame)
    var _press = mouse_check_button_pressed(mb_left), _rel = mouse_check_button_released(mb_left) && variable_struct_exists(_u, "btnMiss") && _u.btnMiss;
    if (!_press && !_rel) { return; }
    _u.btnMiss = false;
    var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
    for (var i = 0; i < array_length(_u.btns); i++)
    {
        var _b = _u.btns[i];
        if (point_in_rectangle(_mx, _my, _b[0], _b[1], _b[2], _b[3])) { coop_help_do(_b[4], _press ? "button" : "button (release)"); mouse_clear(mb_left); return; }
    }
    if (_press) { _u.btnMiss = true; }
}
