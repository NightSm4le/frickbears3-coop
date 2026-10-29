var _c = global.Coop;
// 0.6.1: our own freeze (heavy room load, busy PC) must not count as partner silence
if (!variable_struct_exists(_c, "stepAt")) { _c.stepAt = current_time; }
if (current_time - _c.stepAt > 1500) { _c.lastRecv = min(current_time, _c.lastRecv + (current_time - _c.stepAt)); coop_log("NET: this game froze for " + string(current_time - _c.stepAt) + " ms (not counted as partner silence)"); }
_c.stepAt = current_time;
// --- heartbeat / timeout ---
if (_c.connected)
{
    if (current_time - _c.lastPing > 1000) { _c.lastPing = current_time; coop_send({ t: "ping", ts: current_time }); }
    // 0.6.1: the Office load after the night card can take long on a slow PC; 0.6.2: 20 s base (a loaded PC can stall the partner >10 s)
    var _lim = (room == NightOpening || coop_partner_get("rm", "") == "NightOpening") ? 30000 : 20000;
    if (_c.bot && variable_struct_exists(_c, "botDrop") && _c.botDrop > 0 && coop_is_client() && room == Office && coop_bot_drop_due(_c)) { _c.botDrop = -1; coop_log("bot: simulate a lost host (no packets for " + string(_lim) + " ms)"); _c.lastRecv = current_time - _lim - 1; }
    if (current_time - _c.lastRecv > _lim)
    {
        coop_log("timeout (silent " + string(current_time - _c.lastRecv) + " ms, my fps " + string(fps_real) + ")");
        if (coop_is_host()) { coop_drop_partner("timeout"); } else { coop_disconnect("timeout"); }
    }
}
else if (coop_is_client() && current_time - _c.lastRecv > 12000)
{
    coop_disconnect("connect timeout");
}
// 0.6.2: auto-reconnect (client)
if (_c.rjLeft > 0 && _c.mode == "off" && current_time >= _c.rjAt)
{
    _c.rjLeft--; _c.rjN++; _c.rjAt = current_time + 3000;
    coop_log("RECONNECT: try " + string(_c.rjN) + " to " + _c.ip + ":" + string(_c.port));
    coop_join(_c.ip, _c.port);
    if (_c.rjLeft <= 0) { _c.rjAt = 0; }
}
else if (_c.rjN > 0 && _c.rjLeft <= 0 && _c.mode == "off") { coop_log("RECONNECT: gave up after " + string(_c.rjN) + " tries"); coop_alert("Could not reconnect. F8 -> JOIN to retry", c_red, undefined); _c.rjN = 0; }
// --- host: night start + clock ---
if (room != _c.prevRoom)
{
    coop_log("room " + room_get_name(room));
    if (_c.prevRoom == Office) { coop_anim_night_end(); }
    if (room == NightOpening) { coop_score_reset(); BotWinDone = false; _c.partnerWon = false; _c.partnerWonNight = undefined; } // 0.6.0 fix: stale 6AM flag from the previous night
    if (room == Office && _c.prevRoom != NightOpening && variable_global_exists("Night") && global.Night == "Endless") { BotWinDone = false; _c.partnerWon = false; _c.partnerWonNight = undefined; } // 0.6.0: Endless rounds skip NightOpening
    if (room == Office) { coop_anim_night_start(); coop_feat_office_enter(); global.CoopS.hintUntil = current_time + 8000; global.CoopS.botDieDone = false; global.CoopS.botHelpStep = 0; }
    if (coop_is_host() && _c.connected && room == NightOpening) { coop_send(coop_night_payload()); }
    else if (coop_is_host() && _c.connected && room == Office && _c.prevRoom != NightOpening && variable_global_exists("Night") && global.Night == "Endless") { coop_send(coop_night_payload()); coop_log("ENDLESS: night payload sent on Office entry (round " + string(global.EndlessRound) + ")"); }
    _c.prevRoom = room;
}
if (coop_is_host() && _c.connected && room == Office && current_time - _c.lastClockSend > 500)
{
    _c.lastClockSend = current_time;
    coop_send({ t: "clock", timer: global.Timer });
}
// --- partner snapshot ~10/s ---
if (_c.connected && current_time - _c.lastSnapSend >= 100)
{
    _c.lastSnapSend = current_time;
    coop_send(coop_snapshot());
}
// --- stage 3: shared animatronics, overlay keys, title Co-op screen ---
if (!global.CoopUI.loaded) { coop_ui_load(); IpText = _c.ip; PortText = string(_c.port); }
coop_anim_step();
coop_spec_step();
coop_help_step();
coop_feat_step();
coop_more_step();
coop_sync_step();
coop_s3_step();
coop_ui_keys();
coop_title_step();
// --- ping (P) ---
if (_c.connected && room == Office && keyboard_check_pressed(ord("P"))) { coop_send_ping(); }
// --- bot ---
if (_c.bot)
{
    BotTimer++;
    if (BotTimer mod 60 == 0) { coop_log(coop_bot_line() + " draws=" + string(DrawCount) + " gui=" + string(display_get_gui_width()) + "x" + string(display_get_gui_height())); }
    if (_c.botPing && _c.connected && room == Office && BotTimer mod 150 == 0) { coop_send_ping(); }
    if (_c.botDoors >= 0 && !BotDoorsDone && room == Office && variable_global_exists("Timer") && variable_global_exists("Doors") && global.Timer >= _c.botDoors)
    {
        BotDoorsDone = true;
        global.Doors[0] = 1;
        global.Doors[1] = 1;
        audio_play_sound(sfxDoor, 10, false);
        coop_log("bot: closed both doors at timer " + string(global.Timer));
    }
    BotOfficeFrames = (room == Office) ? BotOfficeFrames + 1 : 0;
    if (_c.botWin >= 0 && !BotWinDone && room == Office && variable_global_exists("Timer") && (is_real(global.Night) ? global.Timer >= _c.botWin : BotOfficeFrames >= _c.botWin * 60)) // 0.6.0: Custom/Endless timer is not a 0-based clock -> use seconds in Office
    {
        BotWinDone = true;
        coop_log("bot: forcing win_night at timer " + string(global.Timer));
        win_night();
    }
    if (room == Office && variable_global_exists("AILevels"))
    {
        // bot AI levels (applied as a floor, every frame, so the hour-change ai_set and our boosts stack on top)
        for (var k = 0; k < array_length(_c.botAI); k++) { var _e = _c.botAI[k]; if (global.AILevels[_e[0]] < _e[1]) { global.AILevels[_e[0]] = _e[1]; } }
        if (_c.botCam && _c.botShot == "") { global.CamUp = 1; global.MonitorSystem = "Cameras"; }
        if (_c.botKick >= 0 && !BotKickDone && global.Timer >= _c.botKick)
        {
            BotKickDone = true;
            coop_log("bot: kick - advancing every active animatronic at timer " + string(global.Timer));
            for (var k = 0; k < array_length(global.CoopA.ids); k++) { var _q = global.CoopA.ids[k]; if (global.AILevels[_q] > 0) { coop_anim_advance(_q, "bot kick"); } }
        }
        if (_c.botLure >= 0 && global.Timer >= _c.botLure && current_time >= _c.botLureNext)
        {
            _c.botLureNext = current_time + 16000;
            global.AudioLureX = choose(-1, 0, 1); global.AudioLureY = (global.AudioLureY == 0) ? 1 : 0;
            coop_log("bot: audio lure at " + string(global.AudioLureX) + "," + string(global.AudioLureY));
        }
    }
    // bot screenshot choreography: each step held 5 s, "SHOT <name>" logged after 2.5 s
    if (array_length(_c.botShots) > 0 && (room == Office || (room == TitleScreenMap && _c.autoNight < 0)) && BotTimer > 240 && (room != Office || global.Coop.connected))
    {
        if (_c.botShotIdx < 0 || current_time - _c.botShotAt > 5000)
        {
            _c.botShotIdx++;
            _c.botShotAt = current_time;
            BotShotLogged = false;
            global.CoopUI.forceMode = -1;
            if (_c.botShotIdx >= array_length(_c.botShots)) { _c.botShots = []; _c.botShot = ""; global.CoopUI.show = true; global.CoopUI.corner = 0; coop_log("SHOTS DONE"); }
            else { _c.botShot = _c.botShots[_c.botShotIdx]; coop_bot_shot_begin(_c.botShot); }
        }
        if (_c.botShot != "") { coop_bot_shot_hold(_c.botShot); }
        if (_c.botShot != "" && !BotShotLogged && current_time - _c.botShotAt > 2500) { BotShotLogged = true; coop_log("SHOT " + _c.botShot); }
    }
    // bot: skip the warning screen the same way pressing space does
    if (room == WarningScreen && BotTimer > 90 && !BotSkippedWarning)
    {
        BotSkippedWarning = true;
        coop_log("bot: skip warning screen");
        apply_settings(false);
        room_goto(TitleScreenMap);
    }
    if (coop_is_host() && _c.connected && (_c.botEndless || _c.botCustom >= 0) && !AutoNightDone && BotTimer > 180 && room == TitleScreenMap)
    {
        AutoNightDone = true;
        if (_c.botEndless)
        {
            // FLAGGED: same globals the Endless difficulty/animatronic pickers set (guard 0, 3 lives, salvages 16,0,1,2)
            initialize_endless_data();
            global.Night = "Endless"; global.NightSpeedup = 3; global.Guard = 0; global.Lives = [0, 0, 0]; global.RunTime = 0;
            global.AllTimeSalvages = [16, 0, 1, 2]; global.AILevels = array_create(201, 0);
            if (_c.botEndlessRound > 1) { global.EndlessRound = _c.botEndlessRound; }
            coop_prepare_night();
            coop_log("bot: ENDLESS round " + string(global.EndlessRound) + " (picker skipped" + (_c.botEndlessRound > 1 ? ", -coop-botendlessround" : "") + ") -> Office");
            room_goto(Office);
        }
        else
        {
            // FLAGGED: like oCustomNightSetButton.start_night with Freddy/Bonnie/Chica/Foxy at the given level
            global.Night = "Custom"; global.Route = 0; global.SummonedAnimatronics = []; reset_challenge_alterations(false); global.Challenge = undefined; global.ChallengeTitle = "None";
            global.CustomNightMusic = undefined; global.NightSpeedup = 1; global.Upgrades = []; global.SavedBossTime = 0;
            if (!variable_global_exists("Cheats")) { global.Cheats = array_create(10, false); }
            global.AILevels = array_create(201, 0); global.AILevels[0] = _c.botCustom; global.AILevels[1] = _c.botCustom; global.AILevels[2] = _c.botCustom; global.AILevels[3] = _c.botCustom;
            global.Cheats = array_create(10, false); if (_c.botPhony) { global.Cheats[7] = true; coop_log("bot: cheat 7 (Fredbear mode) -> Phony Fredbear/Crony on route 0"); }
            coop_prepare_night();
            coop_log("bot: CUSTOM NIGHT AI " + string(_c.botCustom) + " for ids 0-3");
            room_goto(NightOpening);
        }
    }
    if (coop_is_host() && _c.connected && _c.autoNight >= 0 && !AutoNightDone && BotTimer > 180 && room != StartupRoom && room != WarningScreen)
    {
        AutoNightDone = true;
        global.Night = _c.autoNight;
        coop_prepare_night();
        coop_log("bot: auto-start night " + string(_c.autoNight));
        room_goto(NightOpening);
    }
}
// --- menu (F8, not during a night) ---
if (keyboard_check_pressed(vk_f8) && room != Office && !(instance_exists(oTitleMenu) && oTitleMenu.CurMenu == "Co-op")) { _c.menuOpen = !_c.menuOpen; _c.focus = 0; }
if (_c.menuOpen && room == Office) { _c.menuOpen = false; }
if (_c.menuOpen)
{
    var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
    var _gw = display_get_gui_width(), _gh = display_get_gui_height();
    var _x = _gw / 2 - 150, _y = _gh / 2 - 90;
    // 0.6.2: act on the press with a same-frame hit test; if the press missed every control (cursor position not yet
    // updated when move+click land in one frame, e.g. xdotool / remote desktop), try again on release
    var _mpress = mouse_check_button_pressed(mb_left), _mrel = mouse_check_button_released(mb_left) && _c.menuMiss;
    if (_mpress) { _c.menuMiss = false; }
    if (_mpress || _mrel)
    {
        var _hitAny = point_in_rectangle(_mx, _my, _x + 70, _y + 40, _x + 290, _y + 90) || point_in_rectangle(_mx, _my, _x + 10, _y + 110, _x + 290, _y + 135);
        if (_mrel) { _c.menuMiss = false; if (_hitAny) { coop_log("F8 menu: click taken on release (press missed)"); } }
        if (_mpress && !_hitAny) { _c.menuMiss = true; }
        if (_mrel && !_hitAny) { }
        else if (point_in_rectangle(_mx, _my, _x + 70, _y + 40, _x + 290, _y + 60)) { _c.focus = 1; keyboard_string = IpText; }
        else if (point_in_rectangle(_mx, _my, _x + 70, _y + 70, _x + 290, _y + 90)) { _c.focus = 2; keyboard_string = PortText; }
        else if (point_in_rectangle(_mx, _my, _x + 10, _y + 110, _x + 100, _y + 135)) { coop_host(real(PortText)); }
        else if (point_in_rectangle(_mx, _my, _x + 105, _y + 110, _x + 195, _y + 135)) { coop_join(IpText, real(PortText)); }
        else if (point_in_rectangle(_mx, _my, _x + 200, _y + 110, _x + 290, _y + 135)) { coop_disconnect("menu"); }
        else { _c.focus = 0; }
    }
    if (_c.focus == 1)
    {
        // allow host names / IPv4: letters, digits, '.', '-', ':'
        var _s = string_copy(keyboard_string, 1, 64), _o = "";
        for (var i = 1; i <= string_length(_s); i++)
        {
            var _ch = string_char_at(_s, i);
            if (string_lettersdigits(_ch) != "" || _ch == "." || _ch == "-" || _ch == ":") { _o += _ch; }
        }
        IpText = _o;
    }
    else if (_c.focus == 2)
    {
        PortText = string_digits(string_copy(keyboard_string, 1, 5));
        if (PortText == "") { PortText = "7777"; }
    }
    if (keyboard_check_pressed(vk_tab)) { _c.focus = _c.focus == 1 ? 2 : 1; keyboard_string = _c.focus == 1 ? IpText : PortText; }
    if (keyboard_check_pressed(vk_enter)) { coop_join(IpText, real(PortText)); }
    if (keyboard_check_pressed(vk_escape)) { _c.menuOpen = false; }
}
