// ===== Frickbear's Coop 0.5.0: co-op saves, warn icons, camera marks, revive, "both hold the door", night score =====
// Nothing here costs power.

global.CoopSaveTag = "";
global.CoopF = {
    saveTagArg: "",
    // marks
    marks: [], markCd: 0, botMark: -1, botMarkDone: false, markShotAt: 0,
    // revive
    revLeft: 1, revHold: 0, revPend: undefined, revivedEnter: false, invulUntil: 0, botRevive: -1, revShotAt: 0, revHoldShot: false,
    // joint door event
    jd: { state: "idle", side: 0, t0: 0, t1: 0, okMe: -1, okP: -1, resAt: 0, done: false, sent: false, outAt: 0, outOk: -1 },
    botJd: -1, botJdClose: 1, jdShotWarn: false, jdShotWin: false,
    forceJs: false,
    // night score
    sc: { rep: 0, warn: 0, rev: 0, give: 0, jd: 0, mark: 0 }, scFinal: undefined, scShotAt: 0, scShown: false,
    // warn self-test
    botWarnSelf: -1, warnSelfStep: 0, warnSelfAt: 0,
    // remote lure proof
    botRlure: -1, rlureNext: 0, rlureN: 0, rlureHit: false, botSpecMark: -1, botSpecMarkDone: false
};

function coop_feat_parse_args()
{
    var _f = global.CoopF, _n = parameter_count();
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i);
        if (_p == "-coop-savetag" && i + 1 < _n) { i++; _f.saveTagArg = "_" + string_lettersdigits(parameter_string(i)); }
        else if (_p == "-coop-unlockall") { _f.unlockAll = true; if (_f.saveTagArg == "") { _f.saveTagArg = "_unlockall"; } } // 0.6.2 tester flag: Extras / Custom Night / bosses unlocked in the CO-OP save only
        else if (_p == "-coop-botmark" && i + 1 < _n) { i++; _f.botMark = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botrevive" && i + 1 < _n) { i++; _f.botRevive = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botjd" && i + 1 < _n) { i++; _f.botJd = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botjdclose" && i + 1 < _n) { i++; _f.botJdClose = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botwarnself" && i + 1 < _n) { i++; _f.botWarnSelf = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botrlure" && i + 1 < _n) { i++; _f.botRlure = coop_arg_num(parameter_string(i), 0); }
        else if (_p == "-coop-botspecmark" && i + 1 < _n) { i++; _f.botSpecMark = coop_arg_num(parameter_string(i), 0); }
    }
}

function coop_admin_save_active()
{
    return variable_global_exists("CoopAdmin") && variable_struct_exists(global.CoopAdmin, "enabled")
        && global.CoopAdmin.enabled && global.CoopAdmin.saveReady && global.CoopSaveTag == "_coop_admin";
}

// ---------------- co-op saves ----------------
// SaveData file names get global.CoopSaveTag appended (apply.csx). In co-op it is "_coop": the original
// savedata/records/endlessdata are never read or written again till co-op ends at the title screen.
function coop_save_copy(_from, _to)
{
    var _b = buffer_load(_from);
    if (_b < 0) { return false; }
    buffer_save(_b, _to);
    buffer_delete(_b);
    return true;
}

function coop_save_enter()
{
    if (global.CoopSaveTag != "") { return; }
    var _tag = "_coop" + global.CoopF.saveTagArg;
    var _f = [["savedata", ".wario"], ["records", ".wario"], ["endlessdata", ".txt"]];
    for (var i = 0; i < 3; i++)
    {
        var _o = _f[i][0] + global.CurrentVersion + _f[i][1];
        var _n = _f[i][0] + global.CurrentVersion + _tag + _f[i][1];
        if (file_exists(_n)) { coop_log("save: co-op file exists, keeping it: " + _n); }
        else if (file_exists(_o)) { coop_log("save: copy " + _o + " -> " + _n + (coop_save_copy(_o, _n) ? " ok" : " FAILED")); }
        else { coop_log("save: no " + _o + ", co-op file will be created fresh: " + _n); }
    }
    global.CoopSaveTag = _tag;
    try { load_permanent_data(); } catch (_e) { coop_log("save: load_permanent_data error " + string(_e)); }
    try { load_save(); } catch (_e2) { coop_log("save: load_save error " + string(_e2)); }
    coop_log("save: CO-OP SAVES ACTIVE (tag " + _tag + "), originals are not touched; night=" + string(global.Night));
}

function coop_save_leave()
{
    if (global.CoopSaveTag == "") { return; }
    global.CoopSaveTag = "";
    try { load_permanent_data(); } catch (_e) { }
    try { load_save(); } catch (_e2) { }
    coop_log("save: co-op over -> back to the normal save (reloaded)");
}

// ---------------- pixel icons ----------------
function coop_icon_col(_ch)
{
    switch (_ch)
    {
        case "K": return make_color_rgb(16, 12, 16);
        case "W": return make_color_rgb(244, 240, 232);
        case "R": return make_color_rgb(214, 40, 40);
        case "G": return make_color_rgb(88, 200, 72);
        case "O": return make_color_rgb(240, 152, 64);
        case "B": return make_color_rgb(96, 152, 232);
        case "H": return make_color_rgb(255, 236, 200);
    }
    return -1;
}

// draws the icon with its top-left at (_x,_y), _sc GUI px per pixel, mirrored if _flip; returns [w, h]
function coop_icon_draw(_n, _x, _y, _sc, _alpha, _flip, _recol)
{
    var _r = coop_icon_rows(_n);
    var _h = array_length(_r);
    if (_h == 0) { return [0, 0]; }
    var _w = string_length(_r[0]);
    draw_set_alpha(_alpha);
    for (var j = 0; j < _h; j++)
    {
        var _row = _r[j];
        for (var i = 0; i < _w; i++)
        {
            var _ch = string_char_at(_row, i + 1);
            if (_ch == ".") { continue; }
            if (_recol != undefined && _ch == "O") { draw_set_color(_recol); } else { draw_set_color(coop_icon_col(_ch)); }
            var _xx = _flip ? (_x + (_w - 1 - i) * _sc) : (_x + i * _sc);
            draw_rectangle(_xx, _y + j * _sc, _xx + _sc - 1, _y + j * _sc + _sc - 1, false);
        }
    }
    draw_set_alpha(1);
    return [_w * _sc, _h * _sc];
}

// outlined variant for warn labels (readable on light camera map and dark office)
function coop_warn_text(_x, _y, _txt, _col, _alpha, _ha)
{
    draw_set_halign(_ha); draw_set_valign(fa_top);
    draw_set_alpha(_alpha); draw_set_color(make_color_rgb(16, 12, 16));
    draw_text(_x - 1, _y, _txt); draw_text(_x + 1, _y, _txt); draw_text(_x, _y - 1, _txt); draw_text(_x, _y + 1, _txt);
    draw_set_color(_col); draw_text(_x, _y, _txt);
    draw_set_alpha(1); draw_set_halign(fa_left);
}

function coop_small_text(_x, _y, _txt, _col, _alpha, _ha)
{
    draw_set_halign(_ha); draw_set_valign(fa_top);
    draw_set_alpha(_alpha * 0.8); draw_set_color(c_black);
    draw_text(_x + 1, _y + 1, _txt);
    draw_set_alpha(_alpha); draw_set_color(_col);
    draw_text(_x, _y, _txt);
    draw_set_alpha(1); draw_set_halign(fa_left);
}

// ---------------- H warn: where is the threat in MY office ----------------
// returns [where, name, how]: where = "L" | "R" | "V" (vent) | "M" (music box) | "!" (in office / no side) | "CLEAR"
function coop_threat_of(_id)
{
    var _i = coop_anim_inst(_id);
    if (_i == noone) { return ["", "", ""]; }
    var _nm = coop_anim_name(_id);
    for (var s = 0; s < 2; s++) { if (global.DoorOccupant[s] == _id) { return [s ? "R" : "L", _nm, "DoorOccupant[" + string(s) + "]"]; } }
    var _k = coop_anim_kind(_i);
    var _sd = variable_instance_exists(_i, "Side") && is_numeric(_i.Side) && _i.Side != 0;
    var _side = (_sd && _i.Side > 0) ? "R" : "L";
    if (_k == "vent")
    {
        if (_i.Mode != "Vents" || _i.VentY >= 1) { return ["V", _nm, "oVentParent Mode=" + string(_i.Mode) + " VentY=" + string(_i.VentY)]; }
        return ["", "", ""];
    }
    if (_k == "stage")
    {
        var _st = _i.Stage;
        if (_st == "Hallway" || _st == "TransitionC" || _st == "Doorway" || _st == "Kill" || _st == "Blocked") { return [_side, _nm, "Stage=" + _st + " Side=" + (_sd ? string(_i.Side) : "?")]; }
        return ["", "", ""];
    }
    if (_k == "foxy")
    {
        if (_i.Mode == "Run" || _i.Phase > _i.WaitTime * 0.6) { return [_sd ? _side : "L", _nm, "Mode=" + string(_i.Mode) + " (left hall)"]; }
        return ["", "", ""];
    }
    var _o = _i.object_index;
    if (_o == oMarionette)
    {
        if (_i.MusicTimer <= 20) { return ["M", _nm, "MusicTimer=" + string(floor(_i.MusicTimer))]; }
        return ["", "", ""];
    }
    if (variable_instance_exists(_i, "Mode") && is_string(_i.Mode))
    {
        var _m = _i.Mode;
        if (_o == oPlushtrap && (_m == "Door" || _m == "KILL")) { return [_side, _nm, "Mode=" + _m + " Side"]; }
        if (_o == oDreadbear && (_m == "Rise" || _m == "Clench" || _m == "Hoist" || _m == "Slam")) { return [_side, _nm, "Mode=" + _m + " Side"]; }
        if (_o == oFuntimeFreddy && (_m == "Hallway" || _m == "Attacking")) { return [_side, _nm, "Mode=" + _m + " Side"]; }
        if (_o == oNightmarionne && _m == "Descend") { return [_side, _nm, "Mode=" + _m + " Side"]; }
        if ((_o == oWitheredBonnie && (_m == "Attack" || _m == "Kill")) || (_o == oEndoskeleton && (_m == "Active" || _m == "Kill")) || (_o == oGoldenFreddy && _m == "Active") || (_o == oShadowFreddy && _m == "PowerOut") || (_o == oWitheredFoxy && (_m == "Rise" || _m == "Clench")))
        {
            return ["!", _nm, "Mode=" + _m + " (no door side)"];
        }
    }
    return ["", "", ""];
}

function coop_warn_threat()
{
    var _a = global.CoopA;
    // 1) doorway occupants first (occupy_doorway users: Foxy, Molten Freddy, Big Top, Glamrock Freddy, ...)
    for (var s = 0; s < 2; s++) { if (global.DoorOccupant[s] >= 0) { var _t = coop_threat_of(global.DoorOccupant[s]); if (_t[0] != "") { return _t; } return [s ? "R" : "L", coop_anim_name(global.DoorOccupant[s]), "DoorOccupant"]; } }
    // 2) everyone else by own state; doors before vents before the rest
    var _best = ["CLEAR", "", ""], _rank = 99;
    for (var n = 0; n < array_length(_a.ids); n++)
    {
        var _t = coop_threat_of(_a.ids[n]);
        if (_t[0] == "") { continue; }
        var _r = (_t[0] == "L" || _t[0] == "R") ? 0 : ((_t[0] == "V") ? 1 : 2);
        if (_r < _rank) { _rank = _r; _best = _t; }
    }
    return _best;
}

// compact native icon at the door / vent; soft pulse, nothing covered
function coop_warn_draw()
{
    var _s = global.CoopS;
    if (room != Office || current_time > _s.warnUntil) { return; }
    var _w = display_get_gui_width(), _h = display_get_gui_height();
    var _left = _s.warnUntil - current_time;
    var _a = 0.7 + 0.3 * (0.5 + 0.5 * sin(current_time / 140));
    if (_left < 600) { _a *= _left / 600; }
    var _oldFont = draw_get_font();
    draw_set_font(-1);
    switch (_s.warnWhere)
    {
        case "CLEAR":
            coop_icon_draw("check", _w / 2 - 11, 26, 2, _a, false, undefined);
            break;
        case "L":
            var _d = coop_icon_draw("warn", 22, _h / 2 - 34, 1, _a, false, undefined);
            coop_icon_draw("chevL", 12, _h / 2 - 32, 1, _a, false, undefined);
            coop_warn_text(13, _h / 2 - 20, string_upper(_s.warnName), make_color_rgb(244, 240, 232), _a * 0.9, fa_left);
            break;
        case "R":
            coop_icon_draw("warn", _w - 37, _h / 2 - 34, 1, _a, false, undefined);
            coop_icon_draw("chevL", _w - 17, _h / 2 - 32, 1, _a, true, undefined);
            coop_warn_text(_w - 13, _h / 2 - 20, string_upper(_s.warnName), make_color_rgb(244, 240, 232), _a * 0.9, fa_right);
            break;
        case "V":
            coop_icon_draw("vent", _w / 2 - 7, 24, 1, _a, false, undefined);
            coop_warn_text(_w / 2, 37, string_upper(_s.warnName), make_color_rgb(244, 240, 232), _a * 0.9, fa_center);
            break;
        case "M":
            coop_icon_draw("note", _w / 2 - 6, coop_hint_base(), 1, _a, false, undefined);
            coop_warn_text(_w / 2, coop_hint_base() + 12, string_upper(_s.warnName), make_color_rgb(244, 240, 232), _a * 0.9, fa_center);
            break;
        default:
            coop_icon_draw("warn", _w / 2 - 7, 24, 1, _a, false, undefined);
            coop_warn_text(_w / 2, 37, string_upper(_s.warnName), make_color_rgb(244, 240, 232), _a * 0.9, fa_center);
            break;
    }
    draw_set_color(c_white); draw_set_font(_oldFont);
}

// bot self-test of every warn variant on REAL instances (state set, threat computed, state restored)
function coop_warn_selftest()
{
    var _f = global.CoopF, _s = global.CoopS;
    if (_f.botWarnSelf < 0 || room != Office || !coop_alive() || global.Timer < _f.botWarnSelf || current_time < _f.warnSelfAt || _f.warnSelfStep >= 6) { return; }
    _f.warnSelfAt = current_time + 6000;
    var _cases = ["bonnie", "chica", "wchica", "marionette", "foxy", "clear"];
    var _case = _cases[_f.warnSelfStep];
    _f.warnSelfStep++;
    var _id = -1, _i = noone, _save = undefined;
    var _oc = [global.DoorOccupant[0], global.DoorOccupant[1]];
    global.DoorOccupant[0] = -1; global.DoorOccupant[1] = -1;
    switch (_case)
    {
        case "bonnie": _id = 1; _i = coop_anim_inst(1); if (_i != noone) { _save = _i.Stage; _i.Stage = "Hallway"; } break;
        case "chica": _id = 2; _i = coop_anim_inst(2); if (_i != noone) { _save = _i.Stage; _i.Stage = "Doorway"; } break;
        case "wchica": _id = 12; _i = coop_anim_inst(12); if (_i != noone) { _save = [_i.Mode, _i.VentY]; _i.VentY = 1; } break;
        case "marionette": _id = 16; _i = coop_anim_inst(16); if (_i != noone) { _save = _i.MusicTimer; _i.MusicTimer = 12; } break;
        case "foxy": _id = 3; _i = coop_anim_inst(3); if (_i != noone) { _save = _i.Mode; _i.Mode = "Run"; } break;
    }
    var _t = coop_warn_threat();
    switch (_case)
    {
        case "bonnie": case "chica": if (_i != noone) { _i.Stage = _save; } break;
        case "wchica": if (_i != noone) { _i.Mode = _save[0]; _i.VentY = _save[1]; } break;
        case "marionette": if (_i != noone) { _i.MusicTimer = _save; } break;
        case "foxy": if (_i != noone) { _i.Mode = _save; } break;
    }
    global.DoorOccupant[0] = _oc[0]; global.DoorOccupant[1] = _oc[1];
    _s.warnWhere = _t[0]; _s.warnName = _t[1]; _s.warnUntil = current_time + 5000;
    coop_log("WARNTEST " + _case + " -> " + _t[0] + " " + _t[1] + " [" + _t[2] + "]");
    coop_log("SHOT warn_" + _case);
}

// ---------------- 1) camera marks ----------------
function coop_mark_send(_cam, _src)
{
    var _f = global.CoopF;
    if (current_time < _f.markCd || !global.Coop.connected) { return false; }
    _f.markCd = current_time + 1000; _f.sc.mark++;
    coop_send({ t: "mark", cam: _cam });
    coop_alert("Mark on CAM " + string(_cam) + " sent to partner (8s)", c_lime, undefined);
    coop_log("mark: CAM " + string(_cam) + " sent (" + _src + ")");
    return true;
}

function coop_mark_active(_cam)
{
    var _f = global.CoopF;
    for (var i = 0; i < array_length(_f.marks); i++) { if (string(_f.marks[i].cam) == string(_cam) && current_time < _f.marks[i].till) { return _f.marks[i]; } }
    return undefined;
}

function coop_marks_draw()
{
    var _f = global.CoopF;
    var _keep = [];
    for (var i = 0; i < array_length(_f.marks); i++) { if (current_time < _f.marks[i].till) { array_push(_keep, _f.marks[i]); } }
    _f.marks = _keep;
    if (array_length(_keep) == 0 || room != Office || !coop_alive()) { return; }
    var _w = display_get_gui_width(), _h = display_get_gui_height();
    var _pc = coop_is_host() ? make_color_rgb(240, 152, 64) : make_color_rgb(96, 152, 232); // partner's colour (P2 orange / P1 blue)
    var _a = 0.6 + 0.4 * (0.5 + 0.5 * sin(current_time / 120));
    var _on = (variable_global_exists("CamUp") && global.CamUp && variable_global_exists("Cam")) ? coop_mark_active(global.Cam) : undefined;
    if (_on != undefined)
    {
        coop_icon_draw("pin", _w / 2 - 9, 40, 2, _a, false, _pc);
        coop_small_text(_w / 2, 60, "PARTNER MARK " + string(ceil((_on.till - current_time) / 1000)) + "s", make_color_rgb(244, 240, 232), _a, fa_center);
    }
    // list of live marks (small, under the clock)
    var _y = 70;
    for (var i = 0; i < array_length(_keep); i++)
    {
        coop_icon_draw("pin", 6, _y, 1, 0.9, false, _pc);
        coop_small_text(18, _y, "CAM " + string(_keep[i].cam), make_color_rgb(244, 240, 232), 0.9, fa_left);
        _y += 12;
    }
}

// ---------------- 2) revive ----------------
function coop_revive_step()
{
    var _f = global.CoopF, _c = global.Coop;
    if (room != Office || !coop_alive() || !_c.connected || _f.revLeft <= 0 || !coop_partner_get("sp", 0) || current_time - _c.partnerSnapAt > 3000)
    {
        _f.revHold = 0; return;
    }
    var _hold = keyboard_check(ord("V")) && coop_help_key_free(ord("V"));
    // 0.8.1 (S13-2): boss nights keep global.Timer at 0 (it is the boss phase clock), so the bot uses coop_bot_clock();
    // the DEAD side's -coop-botrevive also works: its snapshot asks (brq=1) and a bot survivor starts holding V
    var _botWhy = "";
    if (_f.botRevive >= 0 && _c.bot && coop_bot_clock() >= _f.botRevive) { _hold = true; _botWhy = "-coop-botrevive " + string(_f.botRevive); }
    else if (_c.bot && coop_partner_get("brq", 0) == 1) { _hold = true; _botWhy = "partner asked (its -coop-botrevive)"; }
    if (_botWhy != "" && _f.revHold <= 0) { coop_log("bot: revive hold starts (" + _botWhy + ", clock " + string_format(coop_bot_clock(), 1, 1) + ")"); }
    if (!_hold) { _f.revHold = 0; return; }
    _f.revHold += delta_time / 1000;
    // the reviver's office is vulnerable while holding: doors forced open, no cams/mask
    global.Doors[0] = 0; global.Doors[1] = 0;
    if (variable_global_exists("CamUp")) { global.CamUp = 0; }
    if (variable_global_exists("MaskDown")) { global.MaskDown = 0; }
    if (_f.revHold > 1500 && !_f.revHoldShot) { _f.revHoldShot = true; coop_log("SHOT revive_hold"); }
    if (_f.revHold >= 3000)
    {
        _f.revHold = 0; _f.revLeft--; _f.sc.rev++;
        coop_send({ t: "revive", pw: 35, inv: 6000 });
        coop_alert("Partner revived! (once per night)", c_lime, sfxBitCollect);
        coop_log("revive: sent (hold 3 s done), revives left " + string(_f.revLeft));
    }
}

// 0.6.3 (S2-7): the Phone Guy subtitle is drawn bottom-aligned at y 300 and grows UP over y 284 (our hint line).
// While it is on screen, our hints go to the free band under it (y 304..330, above the bottom bars).
function coop_phone_sub_active()
{
    if (!variable_global_exists("Settings")) { return false; }
    var _on = false;
    with (oPhoneGuy) { if (PhoneActive == 2 && Timer > 10 && TonightsCall != undefined && subtitles_enabled()) { _on = true; } }
    return _on;
}
function coop_hint_base() { return coop_phone_sub_active() ? 306 : display_get_gui_height() - 78; }

function coop_revive_draw()
{
    var _f = global.CoopF, _c = global.Coop;
    if (room != Office || !coop_alive() || !_c.connected || !coop_partner_get("sp", 0)) { return; }
    var _w = display_get_gui_width(), _h = display_get_gui_height();
    if (_f.revLeft <= 0) { return; }
    if (_f.revHold <= 0)
    {
        coop_small_text(_w / 2, coop_hint_base() + 2, "PARTNER IS DOWN - HOLD V 3s TO REVIVE (doors open!)", make_color_rgb(244, 240, 232), 0.6 + 0.3 * sin(current_time / 200), fa_center);
        return;
    }
    var _p = clamp(_f.revHold / 3000, 0, 1);
    var _x1 = _w / 2 - 50, _y1 = coop_hint_base();
    draw_set_color(c_black); draw_rectangle(_x1 - 1, _y1 - 1, _x1 + 101, _y1 + 7, false);
    draw_set_color(make_color_rgb(244, 240, 232)); draw_rectangle(_x1 - 1, _y1 - 1, _x1 + 101, _y1 + 7, true);
    draw_set_color(make_color_rgb(88, 200, 72)); draw_rectangle(_x1 + 1, _y1 + 1, _x1 + 1 + 98 * _p, _y1 + 5, false);
    coop_small_text(_w / 2, _y1 + 10, "REVIVING... " + string(floor(_p * 100)) + "%  DOORS OPEN", ((current_time div 250) mod 2) ? make_color_rgb(214, 40, 40) : make_color_rgb(244, 240, 232), 1, fa_center);
}

// spectator side: partner revived me
function coop_revive_in(_m)
{
    var _f = global.CoopF, _s = global.CoopS;
    if (!_s.spec) { coop_log("revive: ignored (not spectating)"); return; }
    _s.spec = false; _s.skipped = false; _s.armed = false;
    _f.revPend = { pw: _m.pw, inv: _m.inv };
    coop_log("revive: REVIVED by partner -> back to the office (death not counted)");
    application_surface_draw_enable(true);
    room_goto(Office);
}

// first step in Office (after oCamera Create reset the night)
function coop_feat_office_enter()
{
    var _f = global.CoopF;
    _f.marks = []; _f.revHold = 0;
    _f.jd.state = "idle";
    if (_f.revPend == undefined) { return; }
    var _p = _f.revPend; _f.revPend = undefined;
    _f.revivedEnter = true; // 0.8.1 (S13-2): coop_more_step keeps the boss state / revive counter for this re-entry
    var _tm = coop_is_host() ? coop_partner_get("tm", -1) : global.Coop.hostTimer;
    if (is_numeric(_tm) && _tm > 0) { global.Timer = _tm; }
    global.Power = min(_p.pw, global.Power);
    _f.invulUntil = current_time + _p.inv;
    coop_alert("REVIVED! " + string(_p.pw) + "% power, safe for " + string(_p.inv div 1000) + "s", c_lime, sfxBitCollect);
    coop_log("revive: back in office, timer " + string(global.Timer) + ", power " + string(global.Power) + ", invulnerable " + string(_p.inv) + "ms");
    _f.revShotAt = current_time + 1500;
}

// ---------------- 3) both hold the door ----------------
function coop_jd_start(_side, _warn, _win)
{
    var _j = global.CoopF.jd;
    _j.state = "warn"; _j.side = _side; _j.t0 = current_time + _warn; _j.t1 = _j.t0 + _win; _j.okMe = -1; _j.okP = -1; _j.done = true; _j.sent = false; _j.outOk = -1;
    coop_log("JD: event - close the " + (_side ? "RIGHT" : "LEFT") + " door together, window in " + string(_warn) + "ms for " + string(_win) + "ms");
    audio_play_sound(sfxError, 10, false);
}

function coop_jd_step()
{
    var _f = global.CoopF, _j = _f.jd, _c = global.Coop;
    if (room != Office) { return; }
    // host: rare trigger (or bot)
    if (coop_is_host() && _c.connected && _j.state == "idle" && !_j.done && coop_alive() && coop_partner_alive_in_office() && variable_global_exists("Timer"))
    {
        var _go = false;
        if (_f.botJd >= 0) { _go = global.Timer >= _f.botJd; }
        else if (global.Timer > 60 && global.Timer < 300 && irandom(18000) == 0) { _go = true; } // ~once per 5 min, at most once a night
        if (_go)
        {
            var _side = irandom(1);
            coop_send({ t: "jd", side: _side, warn: 5000, win: 3000 });
            coop_jd_start(_side, 5000, 3000);
        }
    }
    if (_j.state == "warn" || _j.state == "window")
    {
        if (_j.state == "warn" && current_time >= _j.t0) { _j.state = "window"; coop_log("JD: window open"); }
        // bot: close the door in the window (or not)
        if (_c.bot && _f.botJdClose > 0 && current_time >= _j.t0 + 600) { global.Doors[_j.side] = 1; }
        if (!_f.jdShotWarn && _j.state == "warn" && current_time > _j.t0 - 3500) { _f.jdShotWarn = true; coop_log("SHOT jd_warn"); }
        if (!_f.jdShotWin && _j.state == "window" && current_time > _j.t0 + 1500) { _f.jdShotWin = true; coop_log("SHOT jd_window"); }
        if (current_time >= _j.t1)
        {
            _j.state = "wait"; _j.resAt = current_time;
            _j.okMe = (coop_alive() && global.Doors[_j.side]) ? 1 : 0;
            coop_log("JD: my door " + (_j.side ? "R" : "L") + " at window end: " + (_j.okMe ? "CLOSED" : "open"));
            if (!coop_is_host()) { coop_send({ t: "jdres", ok: _j.okMe }); }
        }
    }
    if (_j.state == "wait" && coop_is_host() && (_j.okP >= 0 || current_time - _j.resAt > 2000))
    {
        var _ok = (_j.okMe == 1 && _j.okP == 1) ? 1 : 0;
        coop_send({ t: "jdout", ok: _ok, me: _j.okMe, p: _j.okP });
        coop_jd_outcome(_ok);
    }
    if (_j.state == "out" && _j.outOk == 0 && current_time >= _j.outAt) { _j.state = "over"; coop_jd_scare(); }
}

function coop_jd_outcome(_ok)
{
    var _f = global.CoopF, _j = _f.jd;
    _j.state = "out"; _j.outOk = _ok; _j.outAt = current_time + 1200;
    if (_ok)
    {
        _f.sc.jd++;
        coop_alert("TOGETHER! The door held.", c_lime, sfxBitCollect);
        coop_log("JD: SUCCESS - both held the door");
    }
    else
    {
        coop_alert("THE DOOR WAS NOT HELD BY BOTH...", c_red, sfxError);
        coop_log("JD: FAIL -> jumpscare for both");
    }
    coop_log("SHOT jd_result");
}

function coop_jd_scare()
{
    var _f = global.CoopF, _a = global.CoopA;
    if (room != Office || !coop_alive()) { return; }
    var _id = -1;
    for (var n = 0; n < array_length(_a.ids); n++) { if (global.AILevels[_a.ids[n]] > 0) { _id = _a.ids[n]; break; } }
    if (_id < 0 && array_length(_a.ids) > 0) { _id = _a.ids[0]; }
    coop_log("JD: jumpscare by " + coop_anim_name(_id));
    _f.forceJs = true;
    jumpscare(_id, 0);
    _f.forceJs = false;
}

function coop_jd_draw()
{
    var _j = global.CoopF.jd;
    if (room != Office || !(_j.state == "warn" || _j.state == "window")) { return; }
    var _w = display_get_gui_width(), _h = display_get_gui_height();
    var _win = _j.state == "window";
    var _a = _win ? (((current_time div 120) mod 2) ? 1 : 0.5) : (0.6 + 0.4 * sin(current_time / 160));
    var _x = _j.side ? (_w - 52) : 40;
    coop_icon_draw("door", _x, _h / 2 + 4, 2, _a, false, undefined);
    coop_icon_draw("chevL", _j.side ? (_x + 20) : (_x - 8), _h / 2 + 10, 1, _a, _j.side, undefined);
    var _txt = _win ? "NOW! BOTH CLOSE " + (_j.side ? "RIGHT" : "LEFT") : "TOGETHER: " + (_j.side ? "RIGHT" : "LEFT") + " DOOR IN " + string(ceil((_j.t0 - current_time) / 1000));
    coop_small_text(_w / 2, 24, _txt, _win ? make_color_rgb(214, 40, 40) : make_color_rgb(244, 240, 232), 1, fa_center);
}

// ---------------- 4) night score ----------------
function coop_score_arr() { var _s = global.CoopF.sc; return [_s.rep, _s.warn, _s.rev, _s.give, _s.jd, _s.mark]; }

function coop_score_reset()
{
    var _f = global.CoopF;
    _f.sc = { rep: 0, warn: 0, rev: 0, give: 0, jd: 0, mark: 0 }; _f.scFinal = undefined; _f.scShown = false;
    _f.revLeft = 1; _f.jd.done = false; _f.jd.state = "idle"; _f.jdShotWarn = false; _f.jdShotWin = false; _f.revHoldShot = false;
}

function coop_score_draw()
{
    var _f = global.CoopF, _s = global.CoopS;
    var _end = instance_exists(oNightClear) || (room == GameOver && !_s.spec);
    if (!_end || !coop_active()) { _f.scShown = false; return; }
    if (!_f.scShown) { _f.scShown = true; _f.scShotAt = current_time + 2500; coop_log("SCORE me=" + json_stringify(coop_score_arr()) + " partner=" + json_stringify(coop_partner_get("sc", []))); }
    var _me = coop_score_arr(), _p = coop_partner_get("sc", [0, 0, 0, 0, 0, 0]);
    if (!is_array(_p) || array_length(_p) < 6) { _p = [0, 0, 0, 0, 0, 0]; }
    var _w = display_get_gui_width(), _h = display_get_gui_height();
    var _bw = 290, _bh = 104, _x1 = _w / 2 - _bw / 2, _y1 = _h - _bh - 10;
    var _wh = make_color_rgb(244, 240, 232), _rd = make_color_rgb(214, 40, 40);
    var _c1 = coop_is_host() ? make_color_rgb(96, 152, 232) : make_color_rgb(240, 152, 64);
    var _c2 = coop_is_host() ? make_color_rgb(240, 152, 64) : make_color_rgb(96, 152, 232);
    coop_ui_panel(_x1, _y1, _x1 + _bw, _y1 + _bh);
    draw_set_color(_wh); draw_rectangle(_x1, _y1, _x1 + _bw, _y1 + _bh, true); draw_rectangle(_x1 + 2, _y1 + 2, _x1 + _bw - 2, _y1 + _bh - 2, true);
    // checker strip like the office wall
    for (var i = 0; i < 35; i++) { draw_set_color((i mod 2) ? _rd : _wh); draw_rectangle(_x1 + 4 + i * 8, _y1 + 4, _x1 + 11 + i * 8, _y1 + 7, false); }
    var _oldFont = draw_get_font();
    draw_set_font(-1); draw_set_valign(fa_top);
    coop_small_text(_x1 + 6, _y1 + 9, "CO-OP NIGHT SCORE", _wh, 1, fa_left);
    coop_small_text(_x1 + 200, _y1 + 9, "YOU", _c1, 1, fa_center);
    coop_small_text(_x1 + 252, _y1 + 9, "PARTNER", _c2, 1, fa_center);
    var _rows = [["Attacks repelled", 0], ["Warnings", 1], ["Revives", 2], ["Power given %", 3], ["Doors held together", 4]];
    for (var r = 0; r < 5; r++)
    {
        var _yy = _y1 + 23 + r * 12;
        coop_small_text(_x1 + 6, _yy, _rows[r][0], c_ltgray, 1, fa_left);
        coop_small_text(_x1 + 200, _yy, string(floor(_me[_rows[r][1]])), _wh, 1, fa_center);
        coop_small_text(_x1 + 252, _yy, string(floor(_p[_rows[r][1]])), _wh, 1, fa_center);
    }
    var _tm = _me[0] * 10 + _me[1] * 5 + _me[2] * 25 + _me[3] + _me[4] * 15;
    var _tp = _p[0] * 10 + _p[1] * 5 + _p[2] * 25 + _p[3] + _p[4] * 15;
    _tm = floor(_tm); _tp = floor(_tp);
    coop_small_text(_x1 + 6, _y1 + 87, "TOTAL", _rd, 1, fa_left);
    coop_small_text(_x1 + 200, _y1 + 87, string(_tm), _c1, 1, fa_center);
    coop_small_text(_x1 + 252, _y1 + 87, string(_tp), _c2, 1, fa_center);
    if (_f.scShotAt > 0 && current_time > _f.scShotAt) { _f.scShotAt = 0; coop_log("SHOT score_" + ((room == GameOver) ? "gameover" : "6am") + " total me=" + string(_tm) + " partner=" + string(_tp)); }
    draw_set_font(_oldFont);
}

// ---------------- packets ----------------
function coop_feat_packet(_t, _m)
{
    var _f = global.CoopF;
    switch (_t)
    {
        case "mark":
            array_push(_f.marks, { cam: _m.cam, till: current_time + 8000 });
            coop_log("mark: partner marked CAM " + string(_m.cam));
            if (room == Office && coop_alive()) { coop_alert("Partner marked CAM " + string(_m.cam), c_yellow, undefined); }
            if (global.Coop.bot && room == Office && coop_alive()) { global.CamUp = 1; global.MonitorSystem = "Cameras"; global.Cam = _m.cam; _f.markShotAt = current_time + 1500; }
            return true;
        case "revive": coop_revive_in(_m); return true;
        case "jd": if (room == Office) { coop_jd_start(_m.side, _m.warn, _m.win); } return true;
        case "jdres": _f.jd.okP = _m.ok; coop_log("JD: partner door " + (_m.ok ? "CLOSED" : "open")); return true;
        case "jdout": if (room == Office) { coop_jd_outcome(_m.ok); } return true;
    }
    return false;
}

// ---------------- step / draw ----------------
function coop_feat_step()
{
    var _f = global.CoopF, _c = global.Coop, _s = global.CoopS;
    if (global.CoopSaveTag != "" && _c.mode == "off" && _c.rjLeft <= 0 && room == TitleScreenMap && !coop_admin_save_active()) { coop_save_leave(); } // 0.6.2: not while auto-reconnecting
    if (variable_struct_exists(_f, "unlockAll") && _f.unlockAll && global.CoopSaveTag != "") { coop_unlock_all(); }
    if (!_c.connected) { return; }
    // marks: M on cameras (alive) or as spectator (marks what the partner is watching)
    var _mk = keyboard_check_pressed(ord("M")) && coop_help_key_free(ord("M"));
    if (_mk)
    {
        if (room == Office && coop_alive() && variable_global_exists("CamUp") && global.CamUp && variable_global_exists("Cam")) { coop_mark_send(global.Cam, "key M"); }
        else if (_s.spec && coop_partner_get("cu", 0)) { coop_mark_send(coop_partner_get("cam", 0), "key M spectator"); }
    }
    if (_c.bot && _f.botMark >= 0 && !_f.botMarkDone && room == Office && coop_alive() && global.Timer >= _f.botMark && coop_partner_alive_in_office())
    {
        _f.botMarkDone = true;
        global.CamUp = 1; global.MonitorSystem = "Cameras";
        coop_mark_send(global.Cam, "bot");
    }
    if (_c.bot && _f.botSpecMark >= 0 && !_f.botSpecMarkDone && _s.spec && coop_partner_get("cu", 0) && coop_partner_get("tm", 0) >= _f.botSpecMark)
    {
        _f.botSpecMarkDone = true;
        coop_mark_send(coop_partner_get("cam", 0), "bot spectator");
        coop_log("SHOT mark_spec");
    }
    if (_f.markShotAt > 0 && current_time > _f.markShotAt) { _f.markShotAt = 0; coop_log("SHOT mark_seen cam=" + string(global.Cam)); }
    if (_c.bot && array_length(_f.marks) > 0 && room == Office && coop_alive()) { var _mm = _f.marks[array_length(_f.marks) - 1]; if (current_time < _mm.till) { global.CamUp = 1; global.MonitorSystem = "Cameras"; global.Cam = _mm.cam; } }
    coop_revive_step();
    if (_f.revShotAt > 0 && current_time > _f.revShotAt) { _f.revShotAt = 0; coop_log("SHOT revived"); }
    coop_jd_step();
    coop_warn_selftest();
    // bot: remote lure proof - repeat (free, cd 15 s) till it pulls someone from the partner
    if (_c.bot && _f.botRlure >= 0 && room == Office && coop_alive() && global.Timer >= _f.botRlure && current_time >= _f.rlureNext && _f.rlureN < 8 && global.CoopA.st.lureHits == 0 && !_f.rlureHit)
    {
        _f.rlureNext = current_time + 16000; _f.rlureN++;
        global.CoopS.cdLure = 0;
        coop_help_do("lure", "bot");
    }
}

function coop_feat_draw()
{
    coop_marks_draw();
    coop_revive_draw();
    coop_jd_draw();
    coop_score_draw();
}

// 0.6.2 tester flag -coop-unlockall: unlocks Extras (UnlockedAnimatronics[128]), Custom Night (any animatronic), the
// Extras boss menu ([126]) and 4LD Extras (trophy 47) - only while the co-op save copy is active, so the player's own
// savedata/records are never changed. Re-applied after every save reload (cheap check).
function coop_unlock_all()
{
    if (!variable_global_exists("UnlockedAnimatronics") || !is_array(global.UnlockedAnimatronics)) { return; }
    var _ua = global.UnlockedAnimatronics, _need = false;
    for (var i = 0; i < array_length(_ua); i++) { if (!_ua[i]) { _need = true; break; } }
    if (variable_global_exists("UnlockedTrophies") && is_array(global.UnlockedTrophies) && array_length(global.UnlockedTrophies) > 47 && !global.UnlockedTrophies[47]) { _need = true; }
    if (!_need) { return; }
    for (var i = 0; i < array_length(_ua); i++) { _ua[i] = true; }
    if (variable_global_exists("UnlockedTrophies") && is_array(global.UnlockedTrophies) && array_length(global.UnlockedTrophies) > 47) { global.UnlockedTrophies[47] = true; }
    coop_log("UNLOCK: " + ((variable_struct_exists(global.CoopF, "unlockBuild") && global.CoopF.unlockBuild) ? "Unlock All build" : "-coop-unlockall") + " -> all animatronics + trophy 47 unlocked (co-op save " + global.CoopSaveTag + " only)");
    if (instance_exists(oTitleMenu)) { with (oTitleMenu) { if (CurMenu == "Title" && !Transitioning) { goto_menu("Title", 0); } } }
}
