// ===== Frickbear's Coop: partner overlay, mod settings file, title-menu "Co-op" screen =====
// Mod settings live in coop_settings.ini (separate from the game's saves).

global.CoopUI = { show: true, corner: 0, loaded: false, forceMode: -1 };
#macro COOP_INI "coop_settings.ini"

function coop_ui_load()
{
    var _u = global.CoopUI;
    ini_open(COOP_INI);
    _u.show = ini_read_real("overlay", "show", 1) != 0;
    _u.corner = clamp(ini_read_real("overlay", "corner", 0), 0, 3);
    var _ip = ini_read_string("net", "ip", "127.0.0.1");
    var _port = ini_read_real("net", "port", 7777);
    ini_close();
    _u.loaded = true;
    if (global.Coop.mode == "off") { global.Coop.ip = _ip; global.Coop.port = _port; }
    coop_log("settings: overlay show=" + string(_u.show) + " corner=" + string(_u.corner) + " ip=" + _ip + " port=" + string(_port));
}

function coop_ui_save()
{
    var _u = global.CoopUI;
    ini_open(COOP_INI);
    ini_write_real("overlay", "show", _u.show ? 1 : 0);
    ini_write_real("overlay", "corner", _u.corner);
    if (instance_exists(oCoopNet)) { ini_write_string("net", "ip", oCoopNet.IpText); ini_write_real("net", "port", real(oCoopNet.PortText)); }
    ini_close();
    coop_log("settings saved: show=" + string(_u.show) + " corner=" + string(_u.corner));
}

// Tab = hide/show, F9 = next corner (only in the office, never consumes game input)
function coop_ui_keys()
{
    if (room != Office || !global.Coop.connected) { return; }
    if (variable_global_exists("DevMode") && global.DevMode) { return; } // Tab is a dev-mode key in the base game
    var _u = global.CoopUI;
    if (keyboard_check_pressed(vk_tab)) { _u.show = !_u.show; coop_ui_save(); }
    if (keyboard_check_pressed(vk_f9)) { _u.corner = (_u.corner + 1) mod 4; coop_ui_save(); }
}

// 0 = compact panel, 1 = pill, 2 = hidden (alerts still drawn)
function coop_overlay_mode()
{
    var _u = global.CoopUI;
    if (_u.forceMode >= 0) { return _u.forceMode; }
    if (instance_exists(oJumpscareTransition) || !coop_alive()) { return 2; }
    if (!_u.show) { return 2; }
    if (global.CamUp || global.PanelUp) { return 1; }
    return 0;
}

function coop_partner_state_text()
{
    var _c = global.Coop;
    if (_c.partnerWon || coop_partner_get("rm", "") == "NightClear") { return ["SURVIVED 6AM", c_lime]; }
    if (current_time - _c.partnerSnapAt > 1500) { return ["no data", c_gray]; }
    if (!coop_partner_get("alive", true) || coop_partner_get("rm", "") == "GameOver") { return ["DEAD", c_red]; }
    if (coop_partner_get("rm", "") != "Office") { return [string(coop_partner_get("rm", "?")), c_ltgray]; }
    return ["", c_white];
}

function coop_draw_overlay()
{
    var _c = global.Coop, _a = global.CoopA, _u = global.CoopUI;
    var _mode = coop_overlay_mode();
    var _flash = current_time - _c.pingFlash < 2000;
    var _blink = ((current_time div 150) mod 2) == 0;
    var _st = coop_partner_state_text();
    var _pw = coop_partner_get("pw", 0);
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _w = (_mode == 0) ? 116 : 70, _h = (_mode == 0) ? 30 : 14;
    var _px, _py;
    switch (_u.corner)
    {
        case 0: _px = _gw - _w - 4; _py = 22; break;             // top-right, under Tokens
        case 1: _px = 4; _py = 44; break;                        // top-left, under the clock
        case 2: _px = 4; _py = _gh - _h - 48; break;             // bottom-left, above power
        default: _px = _gw - _w - 4; _py = _gh - _h - 48; break; // bottom-right
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    if (_mode < 2)
    {
        draw_set_alpha(0.35); draw_set_color(c_black); draw_rectangle(_px, _py, _px + _w, _py + _h, false);
        draw_set_alpha(_flash ? 0.9 : 0.4);
        draw_set_color(_flash ? (_blink ? c_yellow : c_red) : c_white); draw_rectangle(_px, _py, _px + _w, _py + _h, true);
        draw_set_alpha(0.85);
        var _txt = "P2 ";
        if (_st[0] != "") { draw_set_color(_st[1]); draw_text(_px + 3, _py + 1, _txt + _st[0]); }
        else if (_mode == 1)
        {
            draw_set_color(c_white); draw_text(_px + 3, _py + 1, _txt + string(floor(max(_pw, 0))) + "%");
            draw_set_color(coop_partner_get("d0", 0) ? c_red : c_dkgray); draw_rectangle(_px + _w - 18, _py + 4, _px + _w - 12, _py + 10, false);
            draw_set_color(coop_partner_get("d1", 0) ? c_red : c_dkgray); draw_rectangle(_px + _w - 9, _py + 4, _px + _w - 3, _py + 10, false);
        }
        else
        {
            draw_set_color(c_white); draw_text(_px + 3, _py + 1, _txt + string(floor(max(_pw, 0))) + "%");
            draw_set_color(c_dkgray); draw_rectangle(_px + 56, _py + 5, _px + _w - 4, _py + 10, false);
            draw_set_color(_pw > 25 ? c_lime : c_red); draw_rectangle(_px + 56, _py + 5, _px + 56 + (_w - 60) * clamp(_pw, 0, 100) / 100, _py + 10, false);
            draw_set_color(coop_partner_get("d0", 0) ? c_red : c_dkgray); draw_rectangle(_px + 4, _py + 18, _px + 11, _py + 25, false);
            draw_set_color(coop_partner_get("d1", 0) ? c_red : c_dkgray); draw_rectangle(_px + 14, _py + 18, _px + 21, _py + 25, false);
            var _view = coop_partner_get("cu", 0) ? ((coop_partner_get("ms", "Cameras") == "Shop") ? "SHOP" : "CAM " + string(coop_partner_get("cam", "?"))) : "OFFICE";
            if (coop_partner_get("mk", 0)) { _view = "MASK"; }
            if (coop_partner_get("pu", 0)) { _view = "PANEL"; }
            if (coop_partner_get("fan", 0)) { _view += " FAN"; }
            draw_set_color(c_white); draw_text(_px + 26, _py + 15, _view);
            draw_set_color(c_gray); draw_text(_px + _w - 34, _py + 15, (_c.rtt >= 0) ? string(_c.rtt) + "ms" : "");
        }
        draw_set_alpha(1);
    }
    // alerts: ALWAYS visible (even hidden / cams / jumpscare), small banner top-centre
    var _atxt = "", _acol = c_yellow;
    if (current_time - _a.alertAt < 4000) { _atxt = _a.alertText; _acol = _a.alertCol; }
    if (_flash) { _atxt = "PING from partner!" + (_atxt != "" ? "  |  " + _atxt : ""); _acol = c_yellow; }
    if (_atxt != "")
    {
        var _tw = string_width(_atxt) + 10;
        var _bx = _gw / 2 - _tw / 2, _by = 26;
        draw_set_alpha(0.55); draw_set_color(c_black); draw_rectangle(_bx, _by, _bx + _tw, _by + 15, false);
        draw_set_alpha(_blink || !_flash ? 1 : 0.6); draw_set_color(_acol); draw_text(_bx + 5, _by + 1, _atxt);
        draw_set_alpha(1);
    }
    draw_set_color(c_white);
}

// ---------- title menu "Co-op" screen (runs in oTitleMenu scope) ----------
function coop_title_options()
{
    var _c = global.Coop;
    var _ip = instance_exists(oCoopNet) ? oCoopNet.IpText : _c.ip;
    var _port = instance_exists(oCoopNet) ? oCoopNet.PortText : string(_c.port);
    var _cur = ((current_time div 400) mod 2) ? "_" : " ";
    return [
        (_c.mode == "host") ? "Stop Hosting" : "Host",
        (_c.mode == "client") ? "Disconnect" : "Join",
        "IP " + _ip + ((_c.focus == 11) ? _cur : ""),
        "Port " + _port + ((_c.focus == 12) ? _cur : ""),
        "Back"
    ];
}

function coop_title_desc()
{
    var _c = global.Coop;
    var _s = "Co-op - 2 players, own offices.\nStatus: " + _c.status;
    if (_c.connected) { _s += "\nPartner ping: " + ((_c.rtt >= 0) ? string(_c.rtt) + " ms" : "..."); }
    if (_c.focus == 11 || _c.focus == 12) { _s += "\nType, then Enter."; }
    return _s;
}

function coop_title_select()
{
    var _c = global.Coop;
    var _keep = SelectedOption;
    if (_c.focus == 11 || _c.focus == 12) { _c.focus = 0; coop_ui_save(); goto_menu("Co-op", _keep); return; }
    switch (SelectedOption)
    {
        case 0: if (_c.mode == "host") { coop_disconnect("menu"); } else { coop_host(real(oCoopNet.PortText)); } break;
        case 1: if (_c.mode == "client") { coop_disconnect("menu"); } else { coop_ui_save(); coop_join(oCoopNet.IpText, real(oCoopNet.PortText)); } break;
        case 2: _c.focus = 11; keyboard_string = oCoopNet.IpText; break;
        case 3: _c.focus = 12; keyboard_string = oCoopNet.PortText; break;
        default: _c.focus = 0; goto_menu("Title", coop_title_index()); return;
    }
    goto_menu("Co-op", _keep);
}

function coop_title_back()
{
    var _c = global.Coop;
    if (_c.focus == 11 || _c.focus == 12) { _c.focus = 0; goto_menu("Co-op", SelectedOption); return; }
    goto_menu("Title", coop_title_index());
}

function coop_title_index()
{
    for (var i = 0; i < array_length(CurrentOptions); i++) { if (CurrentOptions[i] == "Co-op") { return i; } }
    goto_menu("Title", 0);
    for (var i = 0; i < array_length(CurrentOptions); i++) { if (CurrentOptions[i] == "Co-op") { return i; } }
    return 0;
}

// oCoopNet Step: live labels + text entry while the Co-op screen is open
function coop_title_step()
{
    var _c = global.Coop;
    if (!instance_exists(oTitleMenu)) { if (_c.focus >= 11) { _c.focus = 0; } return; }
    with (oTitleMenu)
    {
        if (CurMenu != "Co-op") { if (_c.focus >= 11) { _c.focus = 0; } continue; }
        if (_c.focus == 11)
        {
            var _s = string_copy(keyboard_string, 1, 40), _o = "";
            for (var i = 1; i <= string_length(_s); i++) { var _ch = string_char_at(_s, i); if (string_digits(_ch) != "" || _ch == ".") { _o += _ch; } }
            oCoopNet.IpText = _o;
        }
        else if (_c.focus == 12) { oCoopNet.PortText = string_digits(string_copy(keyboard_string, 1, 5)); }
        CurrentOptions = coop_title_options();
        CurrentDesc = coop_title_desc();
    }
}

// oCoopNet End Step: while typing, letters bound to menu up/down must not move the selection
function coop_title_endstep()
{
    var _c = global.Coop;
    if (_c.focus != 11 && _c.focus != 12) { return; }
    with (oTitleMenu) { if (CurMenu == "Co-op") { SelectedOption = (_c.focus == 11) ? 2 : 3; } }
}

// ---------- bot screenshot choreography ----------
function coop_bot_shot_begin(_n)
{
    var _u = global.CoopUI;
    coop_log("bot shot begin: " + _n);
    switch (_n)
    {
        case "title":
            if (instance_exists(oTitleMenu)) { with (oTitleMenu) { goto_menu("Title", coop_title_index()); } }
            break;
        case "coopmenu":
            if (instance_exists(oTitleMenu)) { with (oTitleMenu) { PreviousOptions = CurrentOptions; goto_menu("Co-op", 0); } }
            break;
        case "hidden": _u.show = false; break;
        case "corner1": _u.show = true; _u.corner = 1; break;
        case "corner2": _u.corner = 2; break;
        case "corner3": _u.corner = 3; break;
        case "corner0": _u.corner = 0; break;
        case "survived": _u.show = true; _u.corner = 0; break;
        case "ping": global.Coop.pingFlash = current_time + 2500; break;
        case "alert": coop_alert("BONNIE -> YOU! (repelled by partner)", c_red, undefined); global.CoopA.alertAt = current_time + 3000; break;
    }
}

function coop_bot_shot_hold(_n)
{
    if (room == TitleScreenMap)
    {
        // skip the intro and "Press space!" the same way the game's own handler does
        with (oCameraTitleScreen) { if (!SpacePressed) { Frame = max(Frame, 150); if (TitleAlpha > 0) { TitleBrightness = 1; SpacePressed = true; TitleFlySpeed = -2; } } }
        if (_n == "title" && instance_exists(oTitleMenu)) { with (oTitleMenu) { if (CurMenu == "Title" && CurrentOptions[SelectedOption] != "Co-op") { SelectedOption = coop_title_index(); } } }
        if (_n == "coopmenu" && instance_exists(oTitleMenu)) { with (oTitleMenu) { if (CurMenu != "Co-op") { PreviousOptions = CurrentOptions; goto_menu("Co-op", 0); } } }
        return;
    }
    if (room != Office) { return; }
    global.CamUp = 0; global.MaskDown = 0; global.PanelUp = 0; global.MonitorSystem = "Cameras";
    if (variable_global_exists("TurnedAround")) { global.TurnedAround = 0; }
    switch (_n)
    {
        case "panl": global.MouseX = 0; break;
        case "panr": global.MouseX = 640; break;
        case "cams": global.CamUp = 1; break;
        case "shop": global.CamUp = 1; global.MonitorSystem = "Shop"; break;
        case "mask": global.MaskDown = 1; break;
        case "panel": global.TurnedAround = 1; global.PanelUp = 1; break;
        case "back": global.TurnedAround = 1; break;
        case "jumpscare": global.CoopUI.forceMode = 2; break;
        default: global.MouseX = 320;
    }
}
