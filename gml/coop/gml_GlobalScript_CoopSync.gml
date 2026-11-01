// ===== Frickbear's Coop 0.6.1: synced start =====
// Whoever starts (host OR client) - New Game / Continue / Custom Night / Extras / Brave Tower / Four Layers Down -
// the partner starts the same thing. Story dialogs advance together (a press on either side advances both),
// the night-opening card waits for both and its skip is shared, quitting to the menu only shows a small notice.
// Host is the authority for the night number (Continue with different saves -> host's night).

global.CoopSync = {
    parsed: false, applying: false, recvAt: -100000, contAt: -100000, followAt: -100000,
    pend: undefined, pendAt: 0, pendStep: 0,
    tbPend: [], tbIn: 0, tbOut: 0, tbApplied: 0,
    note: "", noteAt: -100000, noteMs: 4000,
    prevRoom: -1, gateStart: 0, gating: false, gateLogged: false,
    botMenu: "", botMenuAt: 6000, botMenuDone: false, botMenuSeen: -1,
    botPress: -1, botPressAt: 0, botPressMax: 1000000, botPressN: 0,
    botQuit: -1, botQuitDone: false
};

function coop_sync_parse_args()
{
    var _S = global.CoopSync;
    _S.parsed = true;
    var _n = parameter_count();
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i);
        var _v = (i + 1 < _n) ? parameter_string(i + 1) : "";
        if (_p == "-coop-botmenu") { i++; _S.botMenu = _v; }              // FLAGGED test bot: new[:diff] | cont | custom | extras | endless | 4ld
        else if (_p == "-coop-botmenuat") { i++; _S.botMenuAt = real(_v); } // ms after the main menu appears
        else if (_p == "-coop-botpress") { i++; _S.botPress = real(_v); }   // FLAGGED: "press" the dialog key every N ms (same path as a real key press)
        else if (_p == "-coop-botpressmax") { i++; _S.botPressMax = real(_v); }
        else if (_p == "-coop-botquit") { i++; _S.botQuit = real(_v); }      // FLAGGED: quit to menu after N s in the Office
    }
}

function coop_sync_is_menu(_r)
{
    return _r == TitleScreenMap || _r == TitleScreen4LD || _r == Extras || _r == CustomNightMenu || _r == EndlessSelection || _r == ModSettings || _r == WarningScreen;
}

function coop_sync_note(_txt, _ms)
{
    var _S = global.CoopSync;
    if (room == Office && global.Coop.connected) { coop_alert(_txt, c_yellow, undefined); }
    _S.note = _txt; _S.noteAt = current_time; _S.noteMs = _ms;
    coop_log("SYNC note: " + _txt);
}

function coop_sync_pname() { return coop_is_host() ? "P2" : "P1"; }

function coop_sync_ready() { return coop_active() && global.Coop.connected; }

// called from the patched title menu (oTitleMenu scope): new_game(), "Continue", "Quit to Menu", room transitions
function coop_sync_menu(_kind, _arg)
{
    var _S = global.CoopSync;
    if (!coop_sync_ready() || _S.applying) { return; }
    if (current_time - _S.recvAt < 2500 && _kind != "quit") { return; } // this transition is the partner's, do not echo it back
    switch (_kind)
    {
        case "new":
            var _m = { t: "go", a: "new", d: _arg };
            if (variable_global_exists("Guard")) { _m.g = global.Guard; }
            if (variable_global_exists("ShuffleMode")) { _m.sh = global.ShuffleMode; }
            coop_send(_m);
            coop_log("SYNC: I started New Game (difficulty " + string(_arg) + ", guard " + (variable_global_exists("Guard") ? string(global.Guard) : "-") + ") -> partner");
            coop_sync_note(coop_sync_pname() + " starts with you", 3000);
            break;
        case "cont":
            _S.contAt = current_time;
            if (coop_is_host()) { coop_send({ t: "go", a: "cont", dest: room_get_name(global.StartRoom), n: global.Night }); }
            else { coop_send({ t: "go", a: "cont" }); }
            coop_log("SYNC: I pressed Continue (night " + string(global.Night) + ", " + room_get_name(global.StartRoom) + ") -> partner");
            coop_sync_note(coop_sync_pname() + " continues with you", 3000);
            break;
        case "room":
            if (current_time - _S.contAt < 1500 || !coop_sync_is_menu(room)) { return; }
            var _d = _arg;
            var _ok = _d == CustomNightMenu || _d == Extras || _d == EndlessSelection || _d == TitleScreen4LD || _d == Opening4LD || (_d == TitleScreenMap && room == TitleScreen4LD);
            if (!_ok) { return; }
            coop_send({ t: "go", a: "room", dest: room_get_name(_d) });
            coop_log("SYNC: I opened " + room_get_name(_d) + " -> partner");
            break;
        case "quit":
            if (coop_sync_is_menu(room)) { return; }
            coop_send({ t: "quit", rm: room_get_name(room) });
            coop_log("SYNC: I quit to the menu from " + room_get_name(room) + " -> partner notified (not kicked)");
            break;
    }
}

function coop_sync_packet(_t, _m)
{
    var _S = global.CoopSync;
    switch (_t)
    {
        case "go":
            _S.recvAt = current_time;
            if (!coop_sync_is_menu(room))
            {
                // host answering its own Continue request echo while already transitioning is fine; anything else: busy
                if (_m.a == "cont" && coop_is_client() && variable_struct_exists(_m, "dest") && current_time - _S.contAt < 8000) { _S.pend = _m; _S.pendAt = current_time; _S.pendStep = 0; return true; }
                coop_sync_note(coop_sync_pname() + " started " + coop_sync_what(_m) + " - finish here, then join from the menu", 6000);
                return true;
            }
            _S.pend = _m; _S.pendAt = current_time; _S.pendStep = 0;
            coop_log("SYNC: partner started " + coop_sync_what(_m) + " -> following");
            return true;
        case "nreq": // host: the client started a Custom / boss / Endless night from its menu
            if (!coop_is_host()) { return true; }
            _S.recvAt = current_time;
            if (!coop_sync_is_menu(room) || room == WarningScreen)
            {
                coop_sync_note("P2 started " + coop_sync_night_name(_m.night) + " - finish here first", 6000);
                return true;
            }
            coop_apply_night(_m);
            coop_log("SYNC: client started night " + string(_m.night) + " -> host follows");
            coop_sync_note("P2 started " + coop_sync_night_name(_m.night), 3000);
            if (instance_exists(oTitleMenu)) { with (oTitleMenu) { Transitioning = false; TransitionFrame = 0; } }
            if (_m.night == "Endless") { room_goto(Office); } else { room_goto(NightOpening); }
            return true;
        case "tb":
            _S.tbIn++;
            _m.at = current_time;
            array_push(_S.tbPend, _m);
            return true;
        case "tbreq":
            coop_tb_request(_m);
            return true;
        case "nskip":
            if (room == NightOpening && instance_exists(oNightOpening)) { with (oNightOpening) { Frame = max(Frame, 301); } coop_log("SYNC: partner skipped the night card -> skip"); }
            return true;
        case "quit":
            coop_log("SYNC: partner quit to the menu from " + string(_m.rm));
            coop_sync_note(coop_sync_pname() + " returned to the menu (you keep playing)", 6000);
            return true;
    }
    return false;
}

function coop_sync_night_name(_n)
{
    if (_n == "Custom") { return "a Custom Night / boss"; }
    if (_n == "Endless") { return "Brave Tower"; }
    return "Night " + string(_n);
}

function coop_sync_what(_m)
{
    if (_m.a == "new") { return "New Game"; }
    if (_m.a == "cont") { return "Continue"; }
    if (_m.a == "room") { return string(_m.dest); }
    return string(_m.a);
}

// apply a pending partner start; retried every frame (the title menu may not exist yet) for up to 10 s
function coop_sync_pend_step()
{
    var _S = global.CoopSync, _m = _S.pend;
    if (_m == undefined) { return; }
    if (current_time - _S.pendAt > 10000) { coop_log("SYNC: gave up following " + coop_sync_what(_m) + " (room " + room_get_name(room) + ")"); _S.pend = undefined; return; }
    _S.recvAt = current_time;
    switch (_m.a)
    {
        case "new":
            if (room != TitleScreenMap) { if (_S.pendStep == 0) { _S.pendStep = 1; room_goto(TitleScreenMap); } return; }
            if (!coop_sync_menu_up()) { return; }
            if (oTitleMenu.Lock || oTitleMenu.Transitioning || (instance_exists(oCameraTitleScreen) && oCameraTitleScreen.TransitionToCutscene)) { _S.pend = undefined; coop_log("SYNC: already starting here"); return; }
            if (variable_struct_exists(_m, "g")) { global.Guard = _m.g; }
            if (variable_struct_exists(_m, "sh")) { global.ShuffleMode = _m.sh; }
            _S.applying = true;
            var _d = _m.d;
            with (oTitleMenu) { new_game(_d); }
            _S.applying = false;
            coop_log("SYNC: New Game started here too (difficulty " + string(_d) + ", guard " + string(global.Guard) + ")");
            coop_sync_note(coop_sync_pname() + " started New Game", 3000);
            _S.pend = undefined;
            break;
        case "cont":
            if (coop_is_host())
            {
                // client pressed Continue: the HOST's save decides the night, then tell the client where to go
                _S.applying = true;
                if (room == TitleScreenMap && !coop_sync_menu_up()) { _S.applying = false; return; }
                load_save();
                if (instance_exists(oTitleMenu) && !oTitleMenu.Transitioning) { with (oTitleMenu) { Transitioning = true; RoomDestination = global.StartRoom; } }
                else if (!instance_exists(oTitleMenu)) { room_goto(global.StartRoom); }
                _S.applying = false;
                coop_send({ t: "go", a: "cont", dest: room_get_name(global.StartRoom), n: global.Night });
                coop_log("SYNC: client pressed Continue -> host continues night " + string(global.Night) + " (" + room_get_name(global.StartRoom) + "), host's night wins");
                coop_sync_note("P2 pressed Continue", 3000);
                _S.pend = undefined;
            }
            else
            {
                var _dest = asset_get_index(_m.dest);
                if (_dest < 0) { _S.pend = undefined; return; }
                if (room == TitleScreenMap && !coop_sync_menu_up() && current_time - _S.contAt > 8000) { return; }
                if (current_time - _S.contAt > 8000) { load_save(); }
                if (variable_global_exists("Night") && global.Night != _m.n) { coop_log("SYNC: my save is at night " + string(global.Night) + ", host's at " + string(_m.n) + " -> host's night"); }
                global.Night = _m.n; global.StartRoom = _dest;
                if (instance_exists(oTitleMenu) && room != Office) { with (oTitleMenu) { Transitioning = true; RoomDestination = _dest; } }
                else if (room != _dest) { room_goto(_dest); }
                coop_log("SYNC: continue -> night " + string(_m.n) + " in " + _m.dest + " (host's save)");
                if (current_time - _S.contAt > 8000) { coop_sync_note("P1 pressed Continue", 3000); }
                _S.pend = undefined;
            }
            break;
        case "room":
            var _dest = asset_get_index(_m.dest);
            if (_dest < 0 || room == _dest) { _S.pend = undefined; return; }
            if (room == TitleScreenMap && !coop_sync_menu_up()) { return; }
            if (instance_exists(oTitleMenu) && oTitleMenu.Transitioning) { _S.pend = undefined; return; }
            if (_dest == EndlessSelection) { load_endless_data(); global.CheckForEndlessSave = true; }
            if (instance_exists(oTitleMenu)) { with (oTitleMenu) { Transitioning = true; RoomDestination = _dest; } }
            else { room_goto(_dest); }
            coop_log("SYNC: followed partner to " + _m.dest);
            coop_sync_note(coop_sync_pname() + " opened " + coop_sync_room_title(_dest), 3000);
            _S.pend = undefined;
            break;
        default:
            _S.pend = undefined;
    }
}

function coop_sync_room_title(_r)
{
    if (_r == CustomNightMenu) { return "Custom Night"; }
    if (_r == Extras) { return "Extras"; }
    if (_r == EndlessSelection) { return "Brave Tower"; }
    if (_r == TitleScreen4LD || _r == Opening4LD) { return "Four Layers Down"; }
    if (_r == TitleScreenMap) { return "Frickbear's 3"; }
    return room_get_name(_r);
}

// title screen: the menu appears only after "Press space" - press it for the follower
function coop_sync_menu_up()
{
    if (instance_exists(oTitleMenu) && variable_instance_exists(oTitleMenu, "new_game")) { return true; }
    if (instance_exists(oCameraTitleScreen))
    {
        with (oCameraTitleScreen)
        {
            if (Frame < 151) { Frame = 151; }
            if (!SpacePressed) { TitleBrightness = 1; SpacePressed = true; TitleFlySpeed = 11; }
        }
    }
    if (!instance_exists(oTitleMenu) && room == TitleScreenMap) { instance_create_depth(0, 0, 0, oTitleMenu); }
    return false;
}

// ---------- dialogs ----------
function coop_tb_key(_i)
{
    var _t = "";
    try { _t = string(_i.Text[_i.TextPage]); } catch (_e) { }
    return string(_i.TextPage) + "|" + string_copy(_t, 1, 48);
}

function coop_tb_can(_i)
{
    with (_i) { return TextPage > 0 && !ExternalPause && Delay[TextPage] == 0 && !Lock[TextPage]; }
    return false;
}

// one forward press on ONE textbox (same as oTextBox draw_everything with ForwardKey)
function coop_tb_forward_inst(_i)
{
    with (_i)
    {
        if (TextDrawChar != TextLength[TextPage]) { TextDrawChar = TextLength[TextPage]; return "reveal"; }
        if (TextPage < (TextPageNumber - 1))
        {
            if (TextPage == (TextPageNumber - 2) && TextOptionNumber > 0) { var _dst = TextOptionLink[TextOptionPosition]; audio_play_sound(sfxCamSwitch, 5, false); initialize(); var _boundGameText = method(id, game_text); _boundGameText(_dst); }
            TextPage += 1; TextDrawChar = 0;
            if (is_callable(Function[TextPage])) { Function[TextPage](); }
            if (array_length(CGPFunction) > 0 && TextPage < array_length(CGPFunction))
            {
                var _f = CGPFunction[TextPage];
                if (array_length(_f) == 1) { _f[0](); } else if (array_length(_f) > 1) { _f[0](_f[1]); }
            }
            Frame = 0;
            return "adv";
        }
        instance_destroy();
        return "end";
    }
    return "";
}

function coop_tb_list()
{
    var _l = [];
    with (oTextBox) { array_push(_l, id); }
    if (object_exists(oTextBox_Fredbear)) { with (oTextBox_Fredbear) { if (!array_contains(_l, id)) { array_push(_l, id); } } }
    return _l;
}

// 0.6.3: maze dialogs are shared too (opened for both by coop_maze_tb_open, pages turned by either player)
function coop_tb_sync_room() { return room != Office && (!coop_is_maze_room(room) || (variable_global_exists("CoopCfg") && global.CoopCfg.maze)); }

// a local press on a dialog: tell the partner which page and what it did (reveal / advance)
function coop_tb_send_press(_i)
{
    var _S = global.CoopSync;
    var _act = (_i.TextDrawChar != _i.TextLength[_i.TextPage]) ? "reveal" : "adv";
    var _type = coop_is_client() ? "tbreq" : "tb";
    coop_send({ t: _type, k: coop_tb_key(_i), act: _act, opt: _i.TextOptionPosition, o: object_get_name(_i.object_index) });
    _S.tbOut++;
    coop_log("SYNC tb out: " + _type + " " + _act + " [" + coop_tb_key(_i) + "]");
}

function coop_tb_request(_m)
{
    if (!coop_is_host()) { return; }
    var _l = coop_tb_list(), _key = string(_m.k);
    for (var k = 0; k < array_length(_l); k++)
    {
        var _i = _l[k];
        if (!instance_exists(_i) || coop_tb_key(_i) != _key || !coop_tb_can(_i)) { continue; }
        _i.TextOptionPosition = _m.opt;
        var _act = coop_tb_forward_inst(_i);
        coop_send({ t: "tb", k: _key, act: _act, opt: _m.opt, o: _m.o });
        coop_log("SYNC tb request: client " + string(_m.act) + " -> host " + _act + " [" + _key + "]");
        return;
    }
    coop_log("SYNC tb request: ignored; host is not on [" + _key + "]");
}

function coop_tb_step()
{
    var _S = global.CoopSync;
    if (!coop_sync_ready() || !coop_tb_sync_room()) { _S.tbPend = []; return; }
    var _l = coop_tb_list();
    // local key press (the textbox reads the same key in its Draw, after this Step)
    if (array_length(_l) > 0 && input_check_pressed(0))
    {
        for (var k = 0; k < array_length(_l); k++)
        {
            if (coop_tb_can(_l[k]))
            {
                coop_tb_send_press(_l[k]);
                if (coop_is_client()) { input_clear(0); }
                break;
            }
        }
    }
    // FLAGGED bot: "press" the key - send exactly like a real press, then do what the textbox does with it
    if (_S.botPress >= 0 && array_length(_l) > 0 && _S.botPressN < _S.botPressMax && current_time - _S.botPressAt > max(250, _S.botPress))
    {
        for (var k = 0; k < array_length(_l); k++)
        {
            if (coop_tb_can(_l[k])) { _S.botPressAt = current_time; _S.botPressN++; coop_tb_send_press(_l[k]); coop_tb_forward_inst(_l[k]); break; }
        }
    }
    // partner presses: apply to the SAME page only (a double press on both sides is then harmless)
    var _keep = [];
    for (var j = 0; j < array_length(_S.tbPend); j++)
    {
        var _p = _S.tbPend[j], _done = false;
        _l = coop_tb_list();
        for (var k = 0; k < array_length(_l) && !_done; k++)
        {
            var _i = _l[k];
            if (!instance_exists(_i) || coop_tb_key(_i) != _p.k) { continue; }
            if (!coop_tb_can(_i)) { break; }
            _i.TextOptionPosition = _p.opt;
            if (_p.act == "reveal") { if (_i.TextDrawChar != _i.TextLength[_i.TextPage]) { coop_tb_forward_inst(_i); } }
            else
            {
                if (_i.TextDrawChar != _i.TextLength[_i.TextPage]) { _i.TextDrawChar = _i.TextLength[_i.TextPage]; }
                coop_tb_forward_inst(_i);
            }
            _S.tbApplied++;
            coop_log("SYNC tb in: " + _p.act + " [" + _p.k + "] applied");
            _done = true;
        }
        if (!_done)
        {
            if (current_time - _p.at < 4000) { array_push(_keep, _p); }
            else { coop_log("SYNC tb in: [" + _p.k + "] not here (already pressed here?) -> dropped"); }
        }
    }
    _S.tbPend = _keep;
}

// ---------- step (oCoopNet Step) ----------
function coop_sync_step()
{
    var _S = global.CoopSync, _c = global.Coop;
    if (!_S.parsed) { coop_sync_parse_args(); }
    if (!coop_active()) { return; }
    if (room != _S.prevRoom)
    {
        var _prev = _S.prevRoom;
        _S.prevRoom = room;
        _S.gateStart = current_time; _S.gating = false; _S.gateLogged = false;
        // client started a Custom / boss / Endless night itself -> ask the host to start the same one
        if (coop_is_client() && _c.connected && current_time - _S.followAt > 3000 && current_time - _S.recvAt > 3000 && _prev >= 0 && variable_global_exists("Night"))
        {
            var _req = (room == NightOpening && global.Night == "Custom" && (_prev == CustomNightMenu || _prev == Extras)) || (room == Office && global.Night == "Endless" && _prev == EndlessSelection);
            if (_req)
            {
                var _m = coop_night_payload(); _m.t = "nreq";
                coop_send(_m);
                coop_log("SYNC: I started " + coop_sync_night_name(global.Night) + " -> host follows");
                coop_sync_note("P1 joins your night", 3000);
            }
        }
    }
    if (!_c.connected) { _S.pend = undefined; return; }
    coop_sync_pend_step();
    coop_tb_step();
    // night card: wait until both players are on it, and a skip skips it for both
    if (room == NightOpening && instance_exists(oNightOpening))
    {
        var _pr = coop_partner_get("rm", "");
        var _fresh = current_time - _c.partnerSnapAt < 2500;
        // 0.6.3: a partner who is already AHEAD (Fredbear microgames, maze, game over, night clear) is not waited for
        var _ahead = string_pos("Fredbear", _pr) == 1 || _pr == "GameOver" || _pr == "NightClear" || string_pos("MinigameMaze_", _pr) == 1;
        _S.gating = _fresh && !_ahead && _pr != "NightOpening" && _pr != "Office" && current_time - _S.gateStart < 30000;
        if (_S.gating)
        {
            with (oNightOpening) { if (Frame > 230) { Frame = 230; } }
            if (input_check_pressed(0)) { input_clear(0); }
            if (!_S.gateLogged) { _S.gateLogged = true; coop_log("SYNC: night card waits for partner (partner in " + _pr + ")"); }
        }
        else
        {
            if (_S.gateLogged) { _S.gateLogged = false; coop_log("SYNC: partner reached the night card after " + string(current_time - _S.gateStart) + " ms"); }
            if (input_check_pressed(0) && oNightOpening.Frame > 0) { coop_send({ t: "nskip" }); coop_log("SYNC: I skipped the night card -> partner"); }
        }
    }
    else { _S.gating = false; }
    // FLAGGED bot: start something from the main menu, as if chosen there
    if (_S.botMenu != "" && !_S.botMenuDone && room == TitleScreenMap && _S.pend == undefined && current_time - _S.recvAt > 3000) { coop_sync_menu_up(); }
    if (_S.botMenu != "" && !_S.botMenuDone && room == TitleScreenMap && instance_exists(oTitleMenu) && variable_instance_exists(oTitleMenu, "new_game") && !oTitleMenu.Transitioning && !oTitleMenu.Lock)
    {
        if (_S.botMenuSeen < 0) { _S.botMenuSeen = current_time; }
        if (current_time - _S.botMenuSeen > _S.botMenuAt) { _S.botMenuDone = true; coop_sync_bot_menu(_S.botMenu); }
    }
    if (_S.botQuit >= 0 && !_S.botQuitDone && room == Office && variable_global_exists("Timer") && global.Timer >= _S.botQuit)
    {
        _S.botQuitDone = true;
        coop_log("bot: quit to menu");
        coop_sync_menu("quit", 0);
        global.Night = (variable_global_exists("Night") ? global.Night : 1);
        room_goto(title_screen());
    }
}

function coop_sync_bot_menu(_spec)
{
    var _parts = string_split(_spec, ":");
    var _a = _parts[0];
    coop_log("bot: menu " + _spec);
    switch (_a)
    {
        case "new":
            var _d = (array_length(_parts) > 1) ? real(_parts[1]) : 1;
            global.Guard = 0;
            with (oTitleMenu) { new_game(_d); } // goes through the patched new_game -> partner
            break;
        case "cont":
            with (oTitleMenu) { Transitioning = true; load_save(); RoomDestination = global.StartRoom; } // same as the "Continue" entry
            coop_sync_menu("cont", 0);
            break;
        case "custom": with (oTitleMenu) { Transitioning = true; RoomDestination = CustomNightMenu; } break; // TransitionFrame hook sends it
        case "extras": with (oTitleMenu) { Transitioning = true; RoomDestination = Extras; } break;
        case "endless": load_endless_data(); global.CheckForEndlessSave = true; with (oTitleMenu) { Transitioning = true; RoomDestination = EndlessSelection; } break;
        case "4ld": with (oTitleMenu) { Transitioning = true; RoomDestination = array_contains(global.UnlockFlags, "4LD_Opening_Seen") ? TitleScreen4LD : Opening4LD; } break;
    }
}

// ---------- small notice (game font, top centre) ----------
function coop_sync_draw()
{
    var _S = global.CoopSync, _c = global.Coop;
    if (!coop_active()) { return; }
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _txt = "";
    if (!(room == Office && _c.connected) && current_time - _S.noteAt < _S.noteMs) { _txt = _S.note; }
    if (_txt != "")
    {
        var _tw = string_width(_txt) + 10, _bx = _gw / 2 - _tw / 2, _by = 26;
        var _a = clamp((_S.noteMs - (current_time - _S.noteAt)) / 400, 0, 1);
        draw_set_alpha(0.55 * _a); draw_set_color(c_black); draw_rectangle(_bx, _by, _bx + _tw, _by + 15, false);
        draw_set_alpha(_a); draw_set_color(c_yellow); draw_text(_bx + 5, _by + 1, _txt);
        draw_set_alpha(1); draw_set_color(c_white);
    }
    if (_S.gating && room == NightOpening)
    {
        var _w = "Waiting for " + coop_sync_pname() + "...";
        var _ww = string_width(_w) + 10;
        draw_set_alpha(0.55); draw_set_color(c_black); draw_rectangle(_gw / 2 - _ww / 2, _gh - 40, _gw / 2 + _ww / 2, _gh - 25, false);
        draw_set_alpha(0.6 + 0.4 * (((current_time div 500) mod 2) == 0)); draw_set_color(c_ltgray); draw_set_halign(fa_center); draw_text(_gw / 2, _gh - 39, _w); draw_set_halign(fa_left);
        draw_set_alpha(1); draw_set_color(c_white);
    }
}
