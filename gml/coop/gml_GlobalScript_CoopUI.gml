// ===== Frickbear's Coop: partner overlay, mod settings file, title-menu "Co-op" screen =====
// Mod settings live in coop_settings.ini (separate from the game's saves).

global.CoopUI = { show: true, corner: 0, loaded: false, forceMode: -1, btns: [] };
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
    // 0.8.3 (UX-S16-O2): every toggle is acknowledged on screen (alerts stay visible even with the HUD hidden)
    if (keyboard_check_pressed(vk_tab))
    {
        _u.show = !_u.show; coop_ui_save();
        coop_alert(_u.show ? "Co-op HUD shown (Tab to hide)" : "Co-op HUD hidden (Tab to show)", c_ltgray, undefined);
        if (_u.show) { global.CoopS.hintUntil = current_time + 4000; }
    }
    if (keyboard_check_pressed(vk_f9))
    {
        _u.corner = (_u.corner + 1) mod 4; coop_ui_save();
        var _cn = ["top-right", "top-left", "bottom-left", "bottom-right"];
        coop_alert("Co-op HUD moved: " + _cn[_u.corner] + " (F9)", c_ltgray, undefined);
    }
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
    if (coop_partner_get("sp", 0)) { return ["SPECTATING", c_orange]; }
    if (!coop_partner_get("alive", true) || coop_partner_get("rm", "") == "GameOver") { return ["DEAD", c_red]; }
    if (coop_partner_get("rm", "") != "Office") { return [string(coop_partner_get("rm", "?")), c_ltgray]; }
    return ["", c_white];
}

// synced from the 0.6.6@2.1.5 user build (988a): bigger PLAYER cards + addon scene art
function coop_draw_scene_participants()
{
    if (!global.Coop.connected || room == Office)
    {
        exit;
    }
    if (!variable_global_exists("CoopSceneArt"))
    {
        global.CoopSceneArt = 
        {
            names: [],
            sprites: []
        };
    }
    if (room == NightOpening)
    {
        coop_draw_night_participants();
        exit;
    }
    var _gw = display_get_gui_width();
    var _me = coop_my_slot();
    var _other = coop_partner_slot();
    var _myName = guard_name(global.Guard);
    var _otherName = string(coop_partner_get("gn", ""));
    var _ownSpr = coop_scene_mod_sprite(_myName);
    var _partnerSpr = coop_scene_mod_sprite(_otherName);
    if (_ownSpr < 0)
    {
        _ownSpr = coop_art_get(_me, global.CoopCfg.mask, "portrait");
    }
    if (_partnerSpr < 0)
    {
        _partnerSpr = coop_art_get(_other, global.CoopCfg.partnerMask, "portrait");
    }
    // 0.7.5: one compact panel bottom-right (was two big boxes in both top corners over native titles / money)
    if (instance_exists(oTitleMenu) || room == TitleScreenMap || room == Extras || room == CustomNightMenu || coop_is_maze_room(room)) { exit; }
    var _gh = display_get_gui_height(), _sz = 24, _x2 = _gw - 4, _x1 = _x2 - 2 * _sz - 10, _y1 = _gh - _sz - 30;
    coop_ui_panel(_x1, _y1, _x2, _y1 + _sz + 14);
    if (_ownSpr >= 0) { draw_sprite_ext(_ownSpr, 0, _x1 + 3, _y1 + 12, _sz / sprite_get_width(_ownSpr), _sz / sprite_get_height(_ownSpr), 0, c_white, 1); }
    if (_partnerSpr >= 0) { draw_sprite_ext(_partnerSpr, 0, _x1 + 7 + _sz, _y1 + 12, _sz / sprite_get_width(_partnerSpr), _sz / sprite_get_height(_partnerSpr), 0, c_white, 1); }
    draw_set_color(make_color_rgb(200, 196, 188)); draw_set_halign(fa_center);
    draw_text(_x1 + 3 + _sz / 2, _y1, "P" + string(_me)); draw_text(_x1 + 7 + _sz * 1.5, _y1, "P" + string(_other));
    draw_set_halign(fa_left);
    draw_set_color(c_white);
}

function coop_scene_mod_sprite(_guardName)
{
    if (!is_string(_guardName) || _guardName == "") { return -1; }
    var _cache = global.CoopSceneArt;
    for (var i = 0; i < array_length(_cache.names); i++)
    {
        if (_cache.names[i] == _guardName) { return _cache.sprites[i]; }
    }

    var _spr = -1;
    if (string_pos("/", _guardName) > 0 || string_pos(chr(92), _guardName) > 0 || string_pos(":", _guardName) > 0 || string_pos("..", _guardName) > 0)
    {
        coop_log("location card: rejected invalid remote mod name");
    }
    else
    {
        var _path = working_directory + "addons/" + _guardName + "/selection.png";
        if (file_exists(_path))
        {
            try { _spr = sprite_add(_path, 2, false, false, 0, 0); }
            catch (_e) { coop_log("location card: failed to load mod sprite " + _path + ": " + string(_e)); }
            if (_spr < 0) { coop_log("location card: failed to load mod sprite " + _path); }
        }
        else { coop_log("location card: no local selection.png for mod guard " + _guardName); }
    }
    array_push(_cache.names, _guardName);
    array_push(_cache.sprites, _spr);
    return _spr;
}

// synced from the 0.6.6@2.1.5 user build (988a): bigger PLAYER cards + addon scene art
function coop_draw_night_participants()
{
    if (!variable_global_exists("CoopSceneArt"))
    {
        global.CoopSceneArt = 
        {
            names: [],
            sprites: []
        };
    }
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    var _mySlot = coop_my_slot();
    var _otherSlot = coop_partner_slot();
    var _myName = guard_name(global.Guard);
    var _otherName = string(coop_partner_get("gn", ""));
    var _mySpr = coop_scene_mod_sprite(_myName);
    var _otherSpr = coop_scene_mod_sprite(_otherName);
    if (_mySpr < 0)
    {
        _mySpr = coop_art_get(_mySlot, global.CoopCfg.mask, "portrait");
    }
    if (_otherSpr < 0)
    {
        _otherSpr = coop_art_get(_otherSlot, global.CoopCfg.partnerMask, "portrait");
    }
    var _baseY = _gh * 0.89;
    var _centers = [(_gw * 0.5) - 64, (_gw * 0.5) + 64];
    var _slots = [_mySlot, _otherSlot];
    var _sprites = [_mySpr, _otherSpr];
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    for (var i = 0; i < 2; i++)
    {
        var _spr = _sprites[i];
        var _cx = _centers[i];
        var _slot = _slots[i];
        var _left = _cx - 52;
        var _top = _baseY - 122;
        var _slotColor = (_slot == 1) ? make_color_rgb(96, 152, 232) : make_color_rgb(240, 152, 64);
        draw_set_alpha(0.82);
        draw_set_color(c_black);
        draw_rectangle(_left, _top, _cx + 52, _baseY + 2, false);
        draw_set_alpha(1);
        draw_set_color(_slotColor);
        draw_rectangle(_left, _top, _cx + 52, _baseY + 2, true);
        draw_set_color(c_white);
        draw_text(_cx, _top + 3, "PLAYER " + string(_slot));
        if (_spr >= 0)
        {
            var _sw = max(1, sprite_get_width(_spr));
            var _sh = max(1, sprite_get_height(_spr));
            var _scale = min(88 / _sw, 92 / _sh);
            draw_sprite_ext(_spr, 0, _cx - (_sw * _scale * 0.5), _baseY - (_sh * _scale) - 8, _scale, _scale, 0, c_white, 1);
        }
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
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
    // 0.6.2: on the camera / vent monitor the full panel (with G/H/L) goes into the empty grey strip above the feed
    // (x 244..548, y 3..28: right of the map title, left of Tokens) instead of the clipped pill under Tokens
    var _strip = _mode == 1 && _u.forceMode < 0 && global.CamUp && !global.PanelUp && variable_global_exists("MonitorSystem") && (global.MonitorSystem == "Cameras" || global.MonitorSystem == "Vents");
    _u.strip = _strip;
    var _hb = (_mode == 0 || _strip) && coop_partner_fresh() && !coop_partner_get("sp", 0) && coop_alive();
    var _w = (_mode == 0) ? 116 : 70, _h = (_mode == 0) ? (_hb ? 48 : 30) : 14;
    var _px, _py;
    if (_strip) { _w = 304; _h = 25; _px = 244; _py = 3; }
    else switch (_u.corner)
    {
        case 0: _px = _gw - _w - 4; _py = 26; break;             // top-right, under Tokens
        case 1: _px = 4; _py = 44; break;                        // top-left, under the clock
        case 2: _px = 4; _py = _gh - _h - 48; break;             // bottom-left, above power
        default: _px = _gw - _w - 4; _py = _gh - _h - 48; break; // bottom-right
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    if (_mode < 2)
    {
        coop_ui_panel(_px, _py, _px + _w, _py + _h);
        draw_set_alpha(_flash ? 0.9 : 0.4);
        draw_set_color(_flash ? (_blink ? c_yellow : c_red) : c_white); draw_rectangle(_px, _py, _px + _w, _py + _h, true);
        draw_set_alpha(0.85);
        var _txt = "P" + string(coop_partner_slot()) + " ";
        var _isz = (_mode == 0) ? 24 : 14;
        if (!_strip) { coop_art_partner_portrait((_px > 40) ? _px - _isz - 2 : _px + _w + 2, _py, _isz, 1); }
        if (_st[0] != "") { draw_set_color(_st[1]); draw_text(_px + 3, _py + 1, _txt + _st[0]); }
        else if (_strip)
        {
            // 0.6.3: all text on row 1 (nothing clipped at the strip's bottom edge), row 2 = doors + power bar only
            var _sv = coop_partner_get("cu", 0) ? ((coop_partner_get("ms", "Cameras") == "Shop") ? "SHOP" : "CAM " + string(coop_partner_get("cam", "?"))) : "SEATED";
            if (coop_partner_get("mk", 0)) { _sv = "MASK"; }
            if (coop_partner_get("pu", 0)) { _sv = "PANEL"; }
            if (coop_partner_get("fan", 0)) { _sv += "+FAN"; }
            draw_set_color(c_white); draw_text(_px + 3, _py + 1, _txt + string(floor(max(_pw, 0))) + "% " + _sv);
            draw_set_color(coop_partner_get("d0", 0) ? make_color_rgb(230, 120, 40) : make_color_rgb(70, 70, 80)); draw_rectangle(_px + 4, _py + 16, _px + 10, _py + 21, false);
            draw_set_color(coop_partner_get("d1", 0) ? make_color_rgb(230, 120, 40) : make_color_rgb(70, 70, 80)); draw_rectangle(_px + 13, _py + 16, _px + 19, _py + 21, false);
            draw_set_color(c_dkgray); draw_rectangle(_px + 24, _py + 17, _px + 110, _py + 20, false);
            draw_set_color(_pw > 25 ? make_color_rgb(120, 200, 90) : make_color_rgb(220, 70, 50)); draw_rectangle(_px + 24, _py + 17, _px + 24 + 86 * clamp(_pw, 0, 100) / 100, _py + 20, false);
            draw_set_color(c_gray); draw_text(_px + 114, _py + 12, (_c.rtt >= 0) ? string(_c.rtt) : "");
        }
        else if (_mode == 1)
        {
            draw_set_color(c_white); draw_text(_px + 3, _py + 1, _txt + string(floor(max(_pw, 0))) + "%");
            draw_set_color(coop_partner_get("d0", 0) ? make_color_rgb(230, 120, 40) : make_color_rgb(70, 70, 80)); draw_rectangle(_px + _w - 18, _py + 4, _px + _w - 12, _py + 10, false);
            draw_set_color(coop_partner_get("d1", 0) ? make_color_rgb(230, 120, 40) : make_color_rgb(70, 70, 80)); draw_rectangle(_px + _w - 9, _py + 4, _px + _w - 3, _py + 10, false);
        }
        else
        {
            draw_set_color(c_white); draw_text(_px + 3, _py + 1, _txt + string(floor(max(_pw, 0))) + "%");
            draw_set_color(c_dkgray); draw_rectangle(_px + 56, _py + 5, _px + _w - 4, _py + 10, false);
            draw_set_color(_pw > 25 ? make_color_rgb(120, 200, 90) : make_color_rgb(220, 70, 50)); draw_rectangle(_px + 56, _py + 5, _px + 56 + (_w - 60) * clamp(_pw, 0, 100) / 100, _py + 10, false);
            draw_set_color(coop_partner_get("d0", 0) ? make_color_rgb(230, 120, 40) : make_color_rgb(70, 70, 80)); draw_rectangle(_px + 4, _py + 18, _px + 11, _py + 25, false);
            draw_set_color(coop_partner_get("d1", 0) ? make_color_rgb(230, 120, 40) : make_color_rgb(70, 70, 80)); draw_rectangle(_px + 14, _py + 18, _px + 21, _py + 25, false);
            var _view = coop_partner_get("cu", 0) ? ((coop_partner_get("ms", "Cameras") == "Shop") ? "SHOP" : "CAM " + string(coop_partner_get("cam", "?"))) : "SEATED";
            if (coop_partner_get("mk", 0)) { _view = "MASK"; }
            if (coop_partner_get("pu", 0)) { _view = "PANEL"; }
            if (coop_partner_get("fan", 0)) { _view += " FAN"; }
            draw_set_color(c_white); draw_text(_px + 26, _py + 15, _view);
            draw_set_color(c_gray); draw_text(_px + _w - 34, _py + 15, (_c.rtt >= 0) ? string(_c.rtt) + "ms" : "");
        }
        draw_set_alpha(1);
    }
    // help buttons (compact panel only): exact rects are click-handled in Begin Step, other clicks reach the game
    _u.btns = [];
    if (_mode < 2 && _hb)
    {
        if (_strip) { _u.btns = coop_help_buttons(_px + 148, _py - 25, 152); } // one row at y _py+6.._py+21, right half of the strip
        else { _u.btns = coop_help_buttons(_px + 2, _py, _w - 4); }
        var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
        for (var i = 0; i < array_length(_u.btns); i++)
        {
            var _b = _u.btns[i], _cd = coop_help_cd_of(_b[4]) - current_time, _hov = point_in_rectangle(_mx, _my, _b[0], _b[1], _b[2], _b[3]);
            draw_set_alpha(_hov ? 0.8 : 0.5); draw_set_color(_cd > 0 ? c_dkgray : (_hov ? c_teal : c_black)); draw_rectangle(_b[0], _b[1], _b[2], _b[3], false);
            draw_set_alpha(0.85); draw_set_color(_cd > 0 ? c_gray : c_white);
            draw_set_halign(fa_center); draw_text((_b[0] + _b[2]) / 2, _b[1] + 1, (_cd > 0) ? string(ceil(_cd / 1000)) + "s" : _b[5]); draw_set_halign(fa_left);
        }
        draw_set_alpha(1);
    }
    // key hint for the first seconds of a night
    // 0.8.3 (UX-S16-O1/B1): shown once per session (6 s) and after Tab/F8, in the bottom band above Power / Mute Call,
    // so it no longer stacks with the boss HP / Scraptrap / role panels in the top third
    if (current_time < global.CoopS.hintUntil && coop_alive() && !(variable_struct_exists(global.CoopUI, "strip") && global.CoopUI.strip)) // 0.6.2: not over the cam map tabs
    {
        var _ht = "CO-OP: P ping G power L lure M mark V revive Tab hide F9 move";
        var _hw = string_width(_ht) + 10;
        var _hy = _gh - 44;
        coop_ui_panel(_gw / 2 - _hw / 2, _hy, _gw / 2 + _hw / 2, _hy + 14);
        draw_set_alpha(0.9); draw_set_color(c_ltgray); draw_set_halign(fa_center); draw_text(_gw / 2, _hy + 1, _ht); draw_set_halign(fa_left); draw_set_alpha(1);
    }
    coop_draw_alerts();
}

function coop_draw_alerts()
{
    var _c = global.Coop, _a = global.CoopA;
    var _gw = display_get_gui_width();
    var _flash = current_time - _c.pingFlash < 2000;
    var _blink = ((current_time div 150) mod 2) == 0;
    // alerts: ALWAYS visible (even hidden / cams / jumpscare), small banner top-centre
    var _atxt = "", _acol = c_yellow;
    if (current_time - _a.alertAt < 4000) { _atxt = _a.alertText; _acol = _a.alertCol; }
    if (_flash) { _atxt = "PING from partner!" + (_atxt != "" ? "  |  " + _atxt : ""); _acol = c_yellow; }
    if (_atxt != "")
    {
        var _tw = string_width(_atxt) + 10;
        var _bx = _gw / 2 - _tw / 2, _by = (variable_struct_exists(global.CoopUI, "strip") && global.CoopUI.strip && room == Office) ? 31 : 26; // 0.6.2: below the cam strip
        coop_ui_panel(_bx, _by, _bx + _tw, _by + 15);
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
        "Settings",
        "Back"
    ];
}

function coop_title_desc()
{
    var _c = global.Coop;
    var _s = "CO-OP  -  " + _c.status;
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
        case 4: _c.focus = 0; goto_menu("Co-op Settings", 0); return;
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

// 0.6.2: Phone Guy subtitle position (oPhoneGuy Draw GUI, patched in apply.csx). With the camera/vent monitor up the
// left 240 px are the cam map ("You" marker etc.), so centre the text on the feed (x 240..640) instead of the screen.
function coop_sub_on_feed()
{
    return variable_global_exists("CamUp") && global.CamUp && !(variable_global_exists("PanelUp") && global.PanelUp) && variable_global_exists("MonitorSystem") && (global.MonitorSystem == "Cameras" || global.MonitorSystem == "Vents");
}
function coop_sub_x() { return coop_sub_on_feed() ? 442 : 320; }
function coop_sub_w() { return coop_sub_on_feed() ? 380 : 400; }

// 0.7.3: shared FNaF-style panel (dark translucent fill + thin light frame), used by every co-op HUD element
function coop_ui_panel(_x1, _y1, _x2, _y2)
{
    draw_set_alpha(0.62); draw_set_color(make_color_rgb(14, 12, 18)); draw_rectangle(_x1, _y1, _x2, _y2, false);
    draw_set_alpha(0.75); draw_set_color(make_color_rgb(200, 196, 188)); draw_rectangle(_x1, _y1, _x2, _y2, true);
    draw_set_alpha(1); draw_set_color(c_white);
}
