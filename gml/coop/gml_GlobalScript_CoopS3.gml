// ===== Frickbear's Coop 0.6.3 (tester session 2 fixes) =====
// Fredbear (route 4) host-authoritative microgames + shared lives, Happiest Day (route 2) shared level / win,
// maze: separate spawn, shared dialogs, look-at-partner bot, team "Time Lasted", real-input Salvage bot,
// jump flags for every ending and for a boss win.

global.CoopS3 = {
    parsed: false,
    // fredbear
    fbGo: undefined, fbGoAt: 0, fbGoneN: -1, fbHoldN: -1, fbHoldAt: 0, fbFailN: -1, fbLogAt: 0, fbWaitN: -1, fbWaitAt: 0,
    // happiest day
    hdLv: -1, hdSendAt: 0, pHdLv: 0, pHdAt: 0, hdWon: false, hdFred: false,
    // maze
    spawnDone: false, spawnRoom: -1, mzIn: 0, lookT: -1, lookDone: false, lookUntil: 0, lookShot: false,
    // time lasted
    hostTod: -1, hostTodAt: 0, todSendAt: 0, todLogged: false, todShown: -1,
    // bots
    bossReal: -1, brPhase: 0, brAt: 0, brStart: 0, brKeys: [], brLogAt: 0, brHp0: -1, brDone: false, brFallback: "",
    ending: "", endingDone: false, bossWin: -1, bossWinDone: false
};

function coop_s3_parse_args()
{
    var _S = global.CoopS3, _n = parameter_count();
    _S.parsed = true;
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i), _v = (i + 1 < _n) ? parameter_string(i + 1) : "";
        if (_p == "-coop-botmazelook") { i++; _S.lookT = real(_v); }
        else if (_p == "-coop-botbossreal") { i++; _S.bossReal = real(_v); }
        else if (_p == "-coop-botending") { i++; _S.ending = string_lower(_v); }
        else if (_p == "-coop-botbosswin") { i++; _S.bossWin = real(_v); }
    }
}

// ---------------- packets ----------------
function coop_s3_packet(_t, _m)
{
    var _S = global.CoopS3;
    switch (_t)
    {
        case "fbgo": // client: host launches microgame n
            _S.fbGo = _m; _S.fbGoAt = current_time;
            coop_log("FREDBEAR: host launches #" + string(_m.n) + " '" + string(_m.cmd) + "' lives " + string(_m.lf));
            return true;
        case "fbfail": // host: partner failed microgame n -> the team loses ONE life for it
            if (coop_is_host() && instance_exists(oFredbearManager))
            {
                with (oFredbearManager)
                {
                    if (_S.fbFailN == _m.n) { coop_log("FREDBEAR: partner failed #" + string(_m.n) + " too (life already taken)"); break; }
                    _S.fbFailN = _m.n; FailMode = true;
                    Lives = max(0, Lives - 1);
                    coop_log("FREDBEAR: partner failed #" + string(_m.n) + " -> shared lives " + string(Lives));
                    // already back in FredbearHome with the next game chosen: re-choose (game over) like the original end-of-game code
                    if (Lives == 0 && room == FredbearHome && MicrogameNumber > _m.n) { SpecialFlag = 0; choose_microgame(); coop_log("FREDBEAR: no lives left -> GAME OVER for both"); }
                }
            }
            return true;
        case "hdlv":
            _S.pHdLv = _m.lv; _S.pHdAt = current_time;
            return true;
        case "hdwin":
            coop_log("HD: partner reached the kid on level 5 -> boss beaten here too");
            coop_hd_win_apply();
            return true;
        case "mztb":
            coop_maze_tb_in(_m);
            return true;
        case "tod":
            _S.hostTod = _m.v; _S.hostTodAt = current_time;
            return true;
        case "s3end":
            coop_log("bot: host jumps to ending '" + string(_m.k) + "' -> same here");
            coop_s3_ending_go(_m.k, false);
            return true;
    }
    return false;
}

// ================= Fredbear (route 4 / Fredbear minigames) =================
function coop_fb_on() { var _c = global.Coop; return coop_active() && _c.connected && current_time - _c.partnerSnapAt < 3000; }

// patched into oFredbearManager Draw_73: "Frame += coop_fb_frame_step(WaitTime);" (manager scope)
// The launch (Frame >= WaitTime) waits until both are on FredbearHome; the host decides which microgame and the lives.
function coop_fb_frame_step(_wt)
{
    var _sp = global.MicrogameSpeed, _S = global.CoopS3;
    if (!coop_fb_on() || room != FredbearHome) { return _sp; }
    if (Frame + _sp < _wt - 1) { return _sp; }
    if (_S.fbGoneN == MicrogameNumber) { return _sp; }
    if (coop_is_host())
    {
        if (_S.fbHoldN != MicrogameNumber) { _S.fbHoldN = MicrogameNumber; _S.fbHoldAt = current_time; }
        var _lim = (MicrogameNumber == 0) ? 12000 : 5000;
        var _pIn = coop_partner_get("rm", "") == "FredbearHome";
        if (!_pIn && current_time - _S.fbHoldAt < _lim) { return 0; }
        _S.fbGoneN = MicrogameNumber;
        coop_send({ t: "fbgo", n: MicrogameNumber, cmd: ChosenCommand, rm: room_get_name(ChosenRoom), lf: Lives, lvl: global.MicrogameLevel, spd: global.MicrogameSpeed, sf: SpecialFlag });
        coop_log("FREDBEAR: launch #" + string(MicrogameNumber) + " '" + ChosenCommand + "' lives " + string(Lives) + (_pIn ? " (partner ready, waited " + string(current_time - _S.fbHoldAt) + " ms)" : " (partner not on FredbearHome after " + string(_lim) + " ms -> alone)"));
        return _sp;
    }
    // client: wait for the host's launch of this number
    if (_S.fbWaitN != MicrogameNumber) { _S.fbWaitN = MicrogameNumber; _S.fbWaitAt = current_time; }
    var _g = _S.fbGo;
    if (is_struct(_g) && _g.n >= MicrogameNumber)
    {
        coop_fb_apply(_g);
        _S.fbGoneN = MicrogameNumber;
        return _sp;
    }
    if (current_time - _S.fbWaitAt > 8000) { _S.fbGoneN = MicrogameNumber; coop_log("FREDBEAR: no launch from the host for #" + string(MicrogameNumber) + " in 8 s -> local microgame"); return _sp; }
    return 0;
}

function coop_fb_apply(_g)
{
    var _was = ChosenCommand;
    MicrogameNumber = _g.n; Lives = _g.lf; global.MicrogameLevel = _g.lvl; global.MicrogameSpeed = _g.spd;
    if (Lives <= 0) { Lives = 0; SpecialFlag = 0; choose_microgame(); }
    else if (_g.cmd == "SURVIVE!") { SpecialFlag = 3; choose_microgame(); }
    else if (ChosenCommand != _g.cmd || room_get_name(ChosenRoom) != _g.rm)
    {
        var _pick = -1;
        for (var i = 0; i < array_length(MicrogameList); i++) { if (MicrogameList[i].Command == _g.cmd && room_get_name(MicrogameList[i].Room) == _g.rm) { _pick = i; break; } }
        if (_pick < 0) { for (var i = 0; i < array_length(MicrogameList); i++) { if (MicrogameList[i].Command == _g.cmd) { _pick = i; break; } } }
        if (_pick >= 0) { ChosenMicrogame = MicrogameList[_pick]; ChosenCommand = ChosenMicrogame.Command; ChosenRoom = ChosenMicrogame.Room; ChosenObject = ChosenMicrogame.Object; }
    }
    coop_log("FREDBEAR: launch #" + string(MicrogameNumber) + " from host '" + ChosenCommand + "'" + (_was != ChosenCommand ? " (mine was '" + _was + "')" : "") + " lives " + string(Lives));
}

// patched over "Lives--; FailMode = true;" at the end of a lost microgame (manager scope)
function coop_fb_fail()
{
    var _S = global.CoopS3;
    if (!coop_fb_on()) { Lives--; FailMode = true; return; }
    FailMode = true;
    if (coop_is_client())
    {
        Lives--;
        coop_send({ t: "fbfail", n: MicrogameNumber });
        coop_log("FREDBEAR: I failed #" + string(MicrogameNumber) + " -> lives " + string(Lives) + " (host keeps the shared count)");
    }
    else if (_S.fbFailN != MicrogameNumber) { _S.fbFailN = MicrogameNumber; Lives--; coop_log("FREDBEAR: I failed #" + string(MicrogameNumber) + " -> shared lives " + string(Lives)); }
    else { coop_log("FREDBEAR: I failed #" + string(MicrogameNumber) + " (partner already lost the life for it)"); }
}

// ================= Happiest Day (route 2) =================
function coop_hd_step()
{
    var _S = global.CoopS3, _c = global.Coop;
    if (!instance_exists(oHappiestDayDrawer) || room != Office) { _S.hdLv = -1; _S.hdWon = false; _S.hdFred = false; return; }
    var _d = instance_find(oHappiestDayDrawer, 0);
    if (instance_exists(oNightmareFreddy)) { _S.hdFred = true; }
    if (_c.connected && (_d.Level != _S.hdLv || current_time - _S.hdSendAt > 2000))
    {
        if (_d.Level != _S.hdLv) { coop_log("HD: my level " + string(_d.Level) + " (" + _d.Screen + ")"); }
        _S.hdLv = _d.Level; _S.hdSendAt = current_time;
        coop_send({ t: "hdlv", lv: _d.Level });
    }
    // I won on level 5 (the original destroyed the nightmares) -> partner wins too
    if (_c.connected && !_S.hdWon && _S.hdFred && _d.Level == 5 && !instance_exists(oNightmareFreddy) && coop_alive())
    {
        _S.hdWon = true; coop_send({ t: "hdwin" }); coop_log("HD: I reached the kid on level 5 -> partner wins too");
    }
    // partner is on a later level: I go there too (same code the game runs after the kid talk)
    if (_c.connected && current_time - _S.pHdAt < 5000 && _S.pHdLv > _d.Level && coop_alive())
    {
        with (_d)
        {
            if (Screen == "Level" || Screen == "KidTalk")
            {
                coop_log("HD: partner is on level " + string(global.CoopS3.pHdLv) + ", I was on " + string(Level) + " -> advancing");
                Timer = 0; Level = global.CoopS3.pHdLv; Screen = "LevelOpen";
                instance_destroy(oHappiestDayObject, false);
            }
        }
    }
}

// the same block oHD_Guard runs when the kid is reached on level 5
function coop_hd_win_apply()
{
    var _S = global.CoopS3;
    _S.hdWon = true;
    if (!instance_exists(oNightmareFreddy)) { return; }
    with (oNightmare) { global.Temperature = 0; Timer = 10; audio_stop_all(); }
    instance_destroy(oNightmareFreddy); instance_destroy(oNightmareBonnie); instance_destroy(oNightmareChica); instance_destroy(oNightmareFoxy);
    update_boss_scores();
    if (global.Night == "Custom") { win_night(); }
}

function coop_hd_draw()
{
    var _S = global.CoopS3;
    if (!instance_exists(oHappiestDayDrawer) || room != Office || !global.Coop.connected) { return; }
    var _lv = oHappiestDayDrawer.Level;
    var _t = "SHARED: LEVEL " + string(_lv) + "/5" + ((current_time - _S.pHdAt < 5000) ? "  (P" + string(coop_partner_slot()) + " LEVEL " + string(_S.pHdLv) + ")" : "");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    var _w = string_width(_t) + 8;
    draw_set_alpha(0.65); draw_set_color(c_black); draw_rectangle(4, 48, 4 + _w, 62, false); draw_set_alpha(1);
    draw_set_color(make_color_rgb(244, 240, 232)); draw_text(8, 49, _t); draw_set_color(c_white);
}

// ================= maze =================
// client: start a little away from the host (same spawn point in the room)
function coop_maze_spawn_step()
{
    var _S = global.CoopS3, _c = global.Coop;
    if (!coop_is_maze_room(room) || !instance_exists(oCamera3DMaze)) { _S.spawnRoom = -1; _S.spawnDone = false; _S.lookDone = false; _S.lookShot = false; return; }
    if (_S.spawnRoom != room) { _S.spawnRoom = room; _S.mzIn = current_time; _S.spawnDone = false; _S.lookDone = false; _S.lookShot = false; }
    if (_S.spawnDone || !coop_is_client() || !_c.connected || !global.CoopCfg.maze) { return; }
    _S.spawnDone = true;
    var _best = undefined;
    with (oCamera3DMaze)
    {
        var _ds = [96, 80, 112, 64, 128];
        for (var k = 0; k < array_length(_ds) && is_undefined(_best); k++)
        {
            for (var a = 0; a < 360 && is_undefined(_best); a += 45)
            {
                var _nx = x + lengthdir_x(_ds[k], a), _ny = y + lengthdir_y(_ds[k], a);
                if (!place_meeting(_nx, _ny, oMazeWallParent) && collision_line(x, y, _nx, _ny, oMazeWallParent, false, true) == noone) { _best = [_nx, _ny, _ds[k], a]; }
            }
        }
        if (!is_undefined(_best)) { coop_log("MAZE: client spawn moved " + string(_best[2]) + " px (dir " + string(_best[3]) + ") from the shared spawn " + string(round(x)) + "," + string(round(y)) + " -> " + string(round(_best[0])) + "," + string(round(_best[1]))); x = _best[0]; y = _best[1]; xprevious = x; yprevious = y; }
        else { coop_log("MAZE: no free spot 64-128 px around the spawn -> same spawn"); }
    }
}

// FLAGGED bot -coop-botmazelook T: both turn to face the partner (no teleport), SHOT maze_partner3d
function coop_maze_look_step()
{
    var _S = global.CoopS3, _M = global.CoopM;
    if (_S.lookT < 0 || !_M.sync || !instance_exists(oCamera3DMaze) || instance_exists(oTextBox)) { return; }
    var _sec = (current_time - _S.mzIn) / 1000;
    if (!_S.lookDone && _sec >= _S.lookT)
    {
        _S.lookDone = true; _S.lookUntil = current_time + 5000;
        coop_log("bot: FORCED look at the partner (" + string(round(point_distance(oCamera3DMaze.x, oCamera3DMaze.y, _M.px, _M.py))) + " px away), no teleport");
    }
    if (_S.lookDone && current_time < _S.lookUntil)
    {
        with (oCamera3DMaze)
        {
            var _r = point_direction(x, y, _M.px, _M.py) - 180;
            CameraRotationHTarget = _r; CameraRotationVTarget = 0;
        }
        if (!_S.lookShot && current_time > _S.lookUntil - 2500) { _S.lookShot = true; global.CoopMore.shotReq = "maze_partner3d"; global.CoopMore.shotAt = current_time; }
    }
}

// patched into oCamera3DMaze_Cursor Draw after the dialog is opened: open it for the partner too
function coop_maze_tb_open(_key, _px, _py)
{
    var _c = global.Coop;
    if (!_c.connected || !global.CoopCfg.maze || !coop_is_maze_room(room)) { return; }
    coop_send({ t: "mztb", k: _key, rm: room_get_name(room), qx: _px, qy: _py });
    coop_log("MAZE: I opened dialog '" + string(_key) + "' -> partner sees it too");
}

function coop_maze_tb_in(_m)
{
    if (!coop_is_maze_room(room) || room_get_name(room) != _m.rm || !instance_exists(oCamera3DMaze)) { coop_log("MAZE: partner dialog '" + string(_m.k) + "' ignored (not in " + string(_m.rm) + ")"); return; }
    if (instance_exists(oTextBox)) { coop_log("MAZE: partner dialog '" + string(_m.k) + "' ignored (a dialog is already open here)"); return; }
    with (instance_create_depth(0, 0, 0, oTextBox)) { game_text(_m.k); }
    // look at the same point if it exists here (NPCs are randomized per player, see README)
    var _pt = noone;
    with (oInteractionPoint) { if (Text == _m.k) { if (_pt == noone || point_distance(x, y, _m.qx, _m.qy) < point_distance(_pt.x, _pt.y, _m.qx, _m.qy)) { _pt = id; } } }
    if (_pt != noone) { with (oCamera3DMaze) { LockOnTarget = _pt; LockX = _pt.x; LockY = _pt.y; LockZ = _pt.Height; } }
    coop_log("MAZE: partner opened dialog '" + string(_m.k) + "' -> opened here" + (_pt != noone ? " (same point)" : " (point not in my maze, text only)"));
}

// ================= "Time Lasted" (host decides: the team lasted until the last player died) =================
function coop_tod()
{
    var _S = global.CoopS3, _c = global.Coop;
    var _own = variable_global_exists("TimeOfDeath") ? global.TimeOfDeath : 0;
    if (!coop_active() || !_c.connected) { return _own; }
    if (coop_is_host())
    {
        var _p = coop_partner_get("tod", -1);
        return (is_real(_p) && (coop_partner_get("rm", "") == "GameOver" || coop_partner_get("alive", 1) == 0)) ? max(_own, _p) : _own;
    }
    return (current_time - _S.hostTodAt < 3000 && _S.hostTod >= 0) ? max(_own, _S.hostTod) : _own;
}

function coop_tod_step()
{
    var _S = global.CoopS3, _c = global.Coop;
    if (room != GameOver || !_c.connected) { _S.todLogged = false; _S.todShown = -1; return; }
    if (coop_is_host() && current_time - _S.todSendAt > 500) { _S.todSendAt = current_time; coop_send({ t: "tod", v: coop_tod() }); }
    var _v = coop_tod();
    if (_S.todLogged && _v != _S.todShown) { _S.todLogged = false; } // 0.6.3: re-log when the team value changes (partner died later)
    if (!_S.todLogged && (coop_is_host() || current_time - _S.hostTodAt < 3000)) { _S.todLogged = true; _S.todShown = _v; coop_log("TIME LASTED: own " + string_format(variable_global_exists("TimeOfDeath") ? global.TimeOfDeath : 0, 1, 2) + " -> shown " + string_format(coop_tod(), 1, 2) + (coop_is_host() ? " (host: max of both)" : " (from host)")); }
}

// ================= FLAGGED bot: Salvage damage with real key presses =================
// -coop-botbossreal T: from T s in the Office, open the cameras with the camera key, switch to Salvage's cam with its
// cam key and HOLD the flashlight key (keyboard_key_press = a key press as GameMaker sees it). Damage then comes from
// the ORIGINAL oSalvage code (flashlight on its cam), and goes to the host through the normal co-op path.
function coop_s3_key(_idx) { var _k = global.Settings[0][_idx]; return is_mouse_input(_k) ? -1 : _k; }
function coop_s3_press(_k) { if (_k >= 0) { keyboard_key_press(_k); array_push(global.CoopS3.brKeys, _k); } }
function coop_s3_release_all() { var _S = global.CoopS3; for (var i = 0; i < array_length(_S.brKeys); i++) { keyboard_key_release(_S.brKeys[i]); } _S.brKeys = []; }

function coop_boss_real_step()
{
    var _S = global.CoopS3, _X = global.CoopMore;
    if (_S.bossReal < 0 || _S.brDone) { return; }
    if (room != Office || !instance_exists(oSalvage) || !coop_alive()) { if (array_length(_S.brKeys) > 0) { coop_s3_release_all(); } return; }
    if (current_time - _X.officeAt < _S.bossReal * 1000) { return; }
    coop_s3_release_all(); // keys are pressed again below each step while needed
    if (_S.brStart == 0) { _S.brStart = current_time; _S.brHp0 = oSalvage.HP; coop_log("bot: REAL input boss damage starts, Salvage HP " + string_format(oSalvage.HP, 1, 2) + " on cam " + string(oSalvage.CurrentCam)); }
    var _cam = oSalvage.CurrentCam;
    if (!global.CamUp)
    {
        if (_S.brPhase != 1) { _S.brPhase = 1; _S.brAt = current_time; }
        var _k = coop_s3_key(6);
        if (_k >= 0 && current_time - _S.brAt < 1500) { if ((current_time div 100) mod 3 == 0) { coop_s3_press(_k); } }
        else if (current_time - _S.brAt >= 1500) { global.CamUp = true; _S.brFallback += "camup "; coop_log("bot: camera key did not open the cams -> FALLBACK global.CamUp"); }
        return;
    }
    if (global.Cam != _cam)
    {
        if (_S.brPhase != 2) { _S.brPhase = 2; _S.brAt = current_time; }
        var _kc = (12 + _cam < array_length(global.Settings[0])) ? coop_s3_key(12 + _cam) : -1;
        if (_kc >= 0 && current_time - _S.brAt < 1500) { if ((current_time div 100) mod 3 == 0) { coop_s3_press(_kc); } }
        else if (current_time - _S.brAt >= 1500) { global.Cam = _cam; _S.brFallback += "cam "; coop_log("bot: cam key did not switch to cam " + string(_cam) + " -> FALLBACK global.Cam"); }
        return;
    }
    _S.brPhase = 3;
    var _kf = coop_s3_key(10);
    if (_kf >= 0) { coop_s3_press(_kf); } else if (!global.Flashlight) { global.Flashlight = true; if (string_pos("flash", _S.brFallback) == 0) { _S.brFallback += "flash "; coop_log("bot: flashlight is on a mouse button -> FALLBACK global.Flashlight"); } }
    if (current_time - _S.brLogAt > 2000)
    {
        _S.brLogAt = current_time;
        coop_log("bot: REAL input: cams " + string(global.CamUp) + " cam " + string(global.Cam) + "=Salvage cam " + string(_cam) + " flashlight " + string(global.Flashlight) + " -> Salvage HP " + string_format(oSalvage.HP, 1, 2) + " (start " + string_format(_S.brHp0, 1, 2) + ")" + (_S.brFallback != "" ? " fallbacks: " + _S.brFallback : " no fallbacks"));
    }
    if (current_time - _S.brStart > 25000) { _S.brDone = true; coop_s3_release_all(); coop_log("bot: REAL input boss damage done after 25 s, Salvage HP " + string_format(oSalvage.HP, 1, 2) + " (start " + string_format(_S.brHp0, 1, 2) + ")"); }
}

// ================= FLAGGED bot: endings / boss win =================
// -coop-botending normal|good|evil|money|ultimate|secret (host; the partner jumps too)
function coop_s3_ending_go(_k, _send)
{
    var _S = global.CoopS3;
    _S.endingDone = true;
    if (_send && global.Coop.connected) { coop_send({ t: "s3end", k: _k }); }
    if (!variable_global_exists("SalvagedMasks") || !is_array(global.SalvagedMasks)) { global.SalvagedMasks = array_create(4, 0); }
    if (!variable_global_exists("SalvagedScraps") || !is_array(global.SalvagedScraps)) { global.SalvagedScraps = array_create(4, 0); }
    for (var i = 0; i < 4; i++) { global.SalvagedMasks[i] = (_k == "good" || _k == "ultimate") ? 1 : 0; global.SalvagedScraps[i] = (_k == "evil" || _k == "ultimate") ? 1 : 0; }
    if (!variable_global_exists("Upgrades") || !is_array(global.Upgrades)) { global.Upgrades = []; }
    if (_k == "money" && !has_upgrade(41)) { array_push(global.Upgrades, 41); }
    global.Night = 5; global.Route = 0;
    if (_k == "secret") { global.Night = 6; global.Route = 4; }
    var _dst = (_k == "secret") ? "CassidyEnding" : "MidnightCutscnes (night 5)";
    coop_log("bot: FORCED ending '" + _k + "' -> " + _dst + " (co-op save tag only)");
    room_goto(MidnightCutscnes);
}

function coop_s3_bot_step()
{
    var _S = global.CoopS3, _c = global.Coop, _X = global.CoopMore;
    if (_S.ending != "" && !_S.endingDone && coop_is_host() && _c.connected && room == TitleScreenMap && oCoopNet.BotTimer > 180) { coop_s3_ending_go(_S.ending, true); }
    // -coop-botbosswin T (host): T s into a boss night, beat the boss the way the game counts it
    if (_S.bossWin >= 0 && !_S.bossWinDone && coop_is_host() && room == Office && coop_alive() && current_time - _X.officeAt >= _S.bossWin * 1000 && boss_fight_night())
    {
        _S.bossWinDone = true;
        if (instance_exists(oSalvage)) { coop_log("bot: FORCED boss win: Salvage HP " + string_format(oSalvage.HP, 1, 2) + " -> 0 via lose_hp"); with (oSalvage) { lose_hp((HP + 1) / max(HPDrainRate, 0.0001), true); } }
        else if (instance_exists(oHappiestDayDrawer)) { coop_log("bot: FORCED boss win: Happiest Day level 5 kid reached"); oHappiestDayDrawer.Level = 5; global.CoopS3.hdFred = true; coop_hd_win_apply(); if (_c.connected) { coop_send({ t: "hdwin" }); } }
        else { coop_log("bot: FORCED boss win: win_night() (route " + string(global.Route) + ")"); win_night(); }
    }
}

// ================= hooks =================
function coop_s3_step()
{
    var _S = global.CoopS3;
    if (!_S.parsed) { coop_s3_parse_args(); }
    if (!coop_active()) { return; }
    coop_maze_spawn_step();
    coop_maze_look_step();
    coop_hd_step();
    coop_tod_step();
    if (global.Coop.bot) { coop_boss_real_step(); coop_s3_bot_step(); }
}

function coop_s3_draw()
{
    if (!coop_active()) { return; }
    coop_hd_draw();
}
