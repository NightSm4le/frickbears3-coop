// ===== Frickbear's Coop 0.6.4 (tester session 3 fixes) =====
// S3-1 night guard (client never advances the night twice), boss-win bot for every boss route,
// Salvage defeat log, Clark's letter (TalbertRoom) shared page turns + bot, Endless from round N.

global.CoopS4 = {
    nightVal: undefined, nightAt: -100000,
    bwStart: 0, bwOfficeAt: 0, bwFbDone: false,
    closerLogged: false,
    ltTarget: -1, ltBotAt: 0, ltLogged: -1
};

// ---------------- S3-1: the night number ----------------
// client: the host's "night" packet arrived (host is the authority for the night number)
function coop_s4_host_night(_m)
{
    var _S4 = global.CoopS4;
    _S4.nightVal = variable_struct_get(_m, "night"); _S4.nightAt = current_time;
    // my own end-of-cutscene transition (e.g. Night 5 Vanny -> SalvageResults, which does Night++) would advance it once more
    with (oTransitionMinigame) { if (Destination == SalvageResults) { coop_log("NIGHT GUARD: dropped my pending transition to SalvageResults (host already started night " + string(_S4.nightVal) + ")"); instance_destroy(); } }
}

function coop_s4_host_night_recent()
{
    var _S4 = global.CoopS4;
    return coop_is_client() && global.Coop.connected && is_numeric(_S4.nightVal) && variable_global_exists("Night") && is_numeric(global.Night)
        && global.Night == _S4.nightVal && current_time - _S4.nightAt < 30000;
}

// oSalvageSheet Create in SalvageResults (via coop_maze_hold): the host's night already counts -> go on without Night++
function coop_s4_salvage_results_guard()
{
    if (!coop_s4_host_night_recent()) { return false; }
    coop_log("NIGHT GUARD: SalvageResults after the host already started night " + string(global.Night) + " -> not advancing again (was the night-7 crash)");
    global.StartRoom = NightOpening; create_save(); room_goto(NightOpening); window_set_cursor(cr_default);
    return true;
}

// patched into oCamera Create: last line of defence, the original MusicList has 6 entries (nights 1..6)
function coop_s4_music_idx(_i, _len)
{
    if (_i >= 0 && _i < _len) { return _i; }
    var _c = clamp(_i, 0, _len - 1);
    coop_log("NIGHT GUARD: night " + string(_i + 1) + " has no music entry -> using night " + string(_c + 1));
    if (variable_global_exists("Night") && is_numeric(global.Night) && global.Night > _len) { global.Night = _len; }
    return _c;
}

// ---------------- S3-2: -coop-botbosswin T on every boss route ----------------
function coop_s4_boss_night()
{
    return variable_global_exists("Night") && (global.Night == 6 || global.Night == "Custom") && variable_global_exists("Route") && global.Route != 0;
}

function coop_s4_bosswin_step()
{
    var _S = global.CoopS3, _S4 = global.CoopS4, _c = global.Coop;
    if (_S.bossWin < 0 || !coop_is_host()) { return; }
    var _rn = room_get_name(room);
    var _in = coop_s4_boss_night() && (room == Office || (string_pos("Fredbear", _rn) == 1 && room != Fredbear_GameOver));
    if (!_in) { if (_S4.bwStart != 0) { _S4.bwStart = 0; _S4.bwOfficeAt = 0; _S4.bwFbDone = false; _S.bossWinDone = false; } return; }
    if (_S4.bwStart == 0) { _S4.bwStart = current_time; coop_log("bot: boss-win timer starts in " + room_get_name(room) + " (route " + string(global.Route) + ", " + string(_S.bossWin) + " s)"); }
    if (room == Office) { if (_S4.bwOfficeAt == 0) { _S4.bwOfficeAt = current_time; } } else { _S4.bwOfficeAt = 0; }
    if (_S.bossWinDone || current_time - _S4.bwStart < _S.bossWin * 1000) { return; }
    // Fredbear (route 4): skip to the final "SURVIVE!" stage the same way the original does for boss phase 2
    // (MicrogameNumber = MaxMicrogames, SpecialFlag 3); the host's launch packet takes the partner along
    if (room == FredbearHome && instance_exists(oFredbearManager))
    {
        if (_S4.bwFbDone) { return; }
        var _did = false;
        with (oFredbearManager)
        {
            if (Endless || SpecialFlag == 3 || Lives <= 0 || _S.fbGoneN == MicrogameNumber) { break; }
            var _from = MicrogameNumber;
            MicrogameNumber = MaxMicrogames; global.MicrogameLevel = 0; global.MicrogameSpeed = 1; SpecialFlag = 3; alarm[1] = 30;
            choose_microgame();
            _did = true;
            coop_log("bot: FORCED boss win (Fredbear): microgame #" + string(_from) + " -> #" + string(MicrogameNumber) + " '" + ChosenCommand + "' (final stage, lives " + string(Lives) + ")");
        }
        if (_did) { _S4.bwFbDone = true; }
        return;
    }
    if (room != Office || !coop_alive() || current_time - _S4.bwOfficeAt < 5000) { return; }
    _S.bossWinDone = true;
    if (instance_exists(oSalvage))
    {
        coop_log("bot: FORCED boss win (boss 3 Salvage): HP " + string_format(oSalvage.HP, 1, 2) + " -> 0 via lose_hp (original phase 6 -> closing scene -> win_night)");
        with (oSalvage) { lose_hp((HP + 1) / max(HPDrainRate, 0.0001), true); }
        coop_log("bot: boss 3 Salvage HP now " + (instance_exists(oSalvage) ? string_format(oSalvage.HP, 1, 2) + " phase " + string(oSalvage.Phase) : "(gone)"));
    }
    else if (instance_exists(oHappiestDayDrawer)) { coop_log("bot: FORCED boss win (boss 2 Happiest Day): level 5 kid reached"); oHappiestDayDrawer.Level = 5; _S.hdFred = true; coop_hd_win_apply(); if (_c.connected) { coop_send({ t: "hdwin" }); } }
    else if (global.Route == 4) { coop_log("bot: FORCED boss win (route 4 Fredbear): final SURVIVE! in the Office -> win_night() (as oFredbear_EndingScare does at 6AM, partner follows via 6AM)"); win_night(); }
    else if (instance_exists(oScraptrap))
    {
        var _n = array_length(oScraptrap.Tasks);
        oScraptrap.Tasks = [];
        coop_log("bot: FORCED boss win (route 1 Scraptrap): " + string(_n) + " shared tasks cleared -> win_night() (partner follows via 6AM)");
        win_night();
    }
    else { coop_log("bot: FORCED boss win: win_night() (route " + string(global.Route) + ")"); win_night(); }
}

// ---------------- S3-5: Clark's letter (oTalbertCutscene, TalbertRoom) ----------------
// patched over "var Flip = input_check_pressed(5) - input_check_pressed(3);" (cutscene scope): both players see the same page
function coop_talbert_flip(_f)
{
    var _S4 = global.CoopS4, _c = global.Coop, _X = global.CoopMore;
    if (!coop_active() || Frame <= 60) { return _f; } // the original opens the folder itself at Frame 60
    var _len = array_length(PageTurn), _who = "me";
    if (_f == 0 && _c.bot && _X.botAdv >= 0 && (coop_is_host() || !_c.connected) && CurrentPage < _len && current_time - _S4.ltBotAt > max(1500, _X.botAdv)) { _S4.ltBotAt = current_time; _f = 1; _who = "bot"; }
    if (_f != 0)
    {
        _S4.ltTarget = clamp(CurrentPage + _f, 0, _len);
        if (_c.connected) { coop_send({ t: "ltflip", p: _S4.ltTarget }); }
        coop_log("LETTER: page " + string(_S4.ltTarget) + "/" + string(_len) + " (" + _who + ")" + (_S4.ltTarget >= _len ? " -> folder closes" : ""));
        return _f;
    }
    if (_S4.ltTarget >= 0 && _S4.ltTarget != CurrentPage)
    {
        var _d = sign(_S4.ltTarget - CurrentPage);
        if (_S4.ltLogged != _S4.ltTarget) { _S4.ltLogged = _S4.ltTarget; coop_log("LETTER: partner turned to page " + string(_S4.ltTarget) + "/" + string(_len) + " -> same here"); }
        return _d;
    }
    return 0;
}

// ---------------- packets / step ----------------
function coop_s4_packet(_t, _m)
{
    switch (_t)
    {
        case "ltflip":
            global.CoopS4.ltTarget = _m.p;
            return true;
    }
    return false;
}

function coop_s4_step()
{
    var _S4 = global.CoopS4;
    // S3-3: the original shows no separate "boss defeated" screen; Salvage at HP 0 plays its closing scene, then 6AM / NightClear
    if (instance_exists(oSalvageCloser_Window)) { if (!_S4.closerLogged) { _S4.closerLogged = true; coop_log("BOSS 3: Salvage defeated -> original closing scene (oSalvageCloser_Window), then win_night -> NightClear (no separate boss-defeated screen in the original)"); } }
    else if (room != Office) { _S4.closerLogged = false; }
    if (room == TitleScreenMap || room == Office) { _S4.ltTarget = -1; _S4.ltLogged = -1; }
}
