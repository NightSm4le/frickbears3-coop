// ===== 0.8.0 (215-boss): real co-op boss roles (Salvage fight, route 3 / Extras > Bosses) =====
// Before 0.8.0 the roles were only a hint panel. Now they change the fight (each player still fights his own local
// Salvage, the HP bar is shared via bdmg/bhp):
//   P1 = DISTRACT: my flashlight on Salvage pushes him back 60% harder (he stays away from MY doors longer),
//        but only does 60% damage. While I flash him, the partner's Salvage slows down (he is "busy with P1").
//   P2 = HIT:      my flashlight does 130% damage; 170% while P1 is distracting (partner's flash on Salvage).
//   SOLO: the partner is dead / spectating / not in the office -> role bonuses off (100%), and the boss is enraged
//        once per death (coop_boss_aggro, also when the HOST dies now). A revive restores the roles.
global.CoopBR = { dmgAdj: 0, logAt: 0, win: false, winSeen: false, solo: false, winN: 0, awayAt: 0 };

// 0.8.1: a clock for the test bots. Boss nights keep global.Timer at (Phase-1)*60 (0 in phase 1), so -coop-botdie /
// -coop-botrevive N there mean "N seconds after I entered the Office"; other nights use global.Timer as before.
function coop_bot_clock()
{
    var _s = (current_time - global.CoopMore.officeAt) / 1000;
    if (variable_global_exists("Night") && boss_fight_night()) { return _s; }
    var _t = variable_global_exists("Timer") ? global.Timer : 0;
    return (_t > 0) ? _t : _s;
}

// 0.8.1 (S13-1): every Office entry starts with roles ON; SOLO only after a confirmed death or a long absence
function coop_boss_roles_enter() { global.CoopBR.solo = false; global.CoopBR.awayAt = 0; }

// 0.8.1 (S13-2): first step back in the Office after a revive (the room restarted, Salvage is a new instance)
function coop_boss_revive_enter()
{
    var _B = global.CoopB;
    _B.pDeadSeen = false; _B.meDeadSeen = false; _B.lastHP = -1;
    _B.reAggro = _B.aggro; // re-apply the enrage to the new Salvage
    if (coop_is_host() && _B.hpKeep >= 0) { _B.restoreHP = max(0.01, _B.hpKeep - _B.deadDmg); } // client: next bhp brings the HP
    coop_log("BOSS: revived -> keep enrage " + string(_B.aggro) + (coop_is_host() ? ", HP back to " + string_format(_B.restoreHP, 1, 2) + " (partner hit " + string_format(_B.deadDmg, 1, 2) + " while I was down)" : ", HP from host") + ", revives left " + string(global.CoopF.revLeft));
    _B.deadDmg = 0;
}
function coop_boss_restore_step()
{
    var _B = global.CoopB;
    if (!instance_exists(oSalvage) || (_B.restoreHP < 0 && _B.reAggro <= 0)) { return; }
    if (_B.restoreHP >= 0) { var _h = _B.restoreHP; with (oSalvage) { HP = min(_h, MaxHP); phase_transition(); } _B.restoreHP = -1; }
    var _n = _B.reAggro; _B.reAggro = 0;
    repeat (_n) { with (oSalvage) { MoveSpeed *= 1.25; SummonSpeed *= 1.25; HPDrainRate *= 0.9; } }
    if (instance_exists(oSalvage)) { coop_log("BOSS: new Salvage after revive: HP " + string_format(oSalvage.HP, 1, 2) + " phase " + string(oSalvage.Phase) + ", enrage x" + string(_n) + " re-applied"); }
}

function coop_boss_role_me() { return (coop_my_slot() == 1) ? "distract" : "hit"; }
function coop_boss_partner_up()
{
    return current_time - global.Coop.partnerSnapAt < 2500 && coop_partner_get("rm", "") == "Office" && coop_partner_get("sp", 0) != 1 && coop_partner_get("alive", true);
}
// 0.8.1 (S13-1): confirmed down = the partner's own fresh snapshot says dead / spectating
function coop_boss_partner_dead()
{
    return current_time - global.Coop.partnerSnapAt < 2500 && (coop_partner_get("sp", 0) == 1 || !coop_partner_get("alive", true));
}
// am I flashing Salvage right now (same test as oSalvage Step)
function coop_boss_flashing()
{
    return instance_exists(oSalvage) && instance_exists(oCamera) && variable_global_exists("Flashlight") && global.Flashlight && global.CamUp && global.Cam == oSalvage.CurrentCam;
}
function coop_boss_roles_active()
{
    return global.Coop.connected && room == Office && instance_exists(oSalvage) && variable_global_exists("Night") && boss_fight_night() && coop_alive() && !global.CoopS.spec;
}

// called every step from coop_boss_step (before the client measures its HP delta)
function coop_boss_roles_step()
{
    var _R = global.CoopBR, _B = global.CoopB;
    // the HOST's own death also enrages the survivor's boss (before: only the client's death did)
    if (coop_is_host() && global.Coop.connected && variable_global_exists("Night") && boss_fight_night())
    {
        if (global.CoopS.spec && !_B.meDeadSeen) { _B.meDeadSeen = true; coop_boss_aggro("partner died", true); }
        if (!global.CoopS.spec) { _B.meDeadSeen = false; }
    }
    if (!coop_boss_roles_active()) { _R.win = false; return; }
    var _up = coop_boss_partner_up();
    // 0.8.1 (S13-1): the partner still loading the Office (NightOpening / opener / stale snapshot) is not "down".
    // SOLO = confirmed death/spectate (at once) or away from the Office for more than 4 s.
    var _soloNow;
    if (_up) { _R.awayAt = 0; _soloNow = false; }
    else if (coop_boss_partner_dead()) { _soloNow = true; }
    else { if (_R.awayAt == 0) { _R.awayAt = current_time; } _soloNow = current_time - _R.awayAt > 4000; }
    if (_soloNow != _R.solo) { _R.solo = _soloNow; coop_log("BOSS ROLES: " + (_R.solo ? "SOLO (partner down) - role bonuses off" : "partner back - role " + coop_boss_role_me())); }
    var _role = coop_boss_role_me();
    var _pfl = _up && coop_partner_get("bf", 0) == 1; // partner flashes HIS Salvage
    _R.win = (_role == "hit" && _pfl);
    if (_R.win && !_R.winSeen) { _R.winN++; }
    _R.winSeen = _R.win;
    with (oSalvage)
    {
        // partner (P1) distracting -> my Salvage is busy: slower towards me
        if (_role == "hit" && _pfl && MoveTimer < 1000) { MoveTimer += (1 / 240); }
        if (!coop_boss_flashing() || _R.solo) { break; }
        var _base = (oCamera.FlashlightPower / 180) * HPDrainRate; // what oSalvage Step takes this frame
        var _mul = (_role == "distract") ? 0.6 : (_pfl ? 1.7 : 1.3);
        var _adj = _base * (_mul - 1);
        if (HP - _adj > MaxHP) { _adj = HP - MaxHP; }
        if (HP > 0) { HP -= _adj; _R.dmgAdj += _adj; }
        if (_role == "distract" && MoveTimer < 1000) { MoveTimer -= (oCamera.FlashlightPower / 60) * 1.5 * 0.6; }
    }
    if (current_time - _R.logAt > 4000)
    {
        _R.logAt = current_time;
        coop_log("BOSS ROLES: me " + _role + (_R.solo ? " SOLO" : "") + " flashing " + string(coop_boss_flashing()) + " partnerFlash " + string(_pfl) + " window " + string(_R.win) + " extraDmg " + string_format(_R.dmgAdj, 1, 2) + " HP " + string_format(oSalvage.HP, 1, 2));
    }
}

// native panel (same place as the 0.7.4 hint: centre, y=84, below SHARED BOSS HP; Tokens/HUD are left/right/bottom)
function coop_boss_roles_draw()
{
    if (!global.Coop.connected || room != Office || !variable_global_exists("Night") || !boss_fight_night() || !instance_exists(oSalvage)) { return; }
    var _R = global.CoopBR, _gw = display_get_gui_width();
    var _dis = coop_boss_role_me() == "distract";
    var _t1, _t2, _col;
    if (global.CoopS.spec) { _t1 = "YOU ARE DOWN"; _t2 = "Watch and mark for the partner - a revive brings you back"; _col = make_color_rgb(200, 196, 188); }
    else if (_R.solo) { _t1 = "SOLO - PARTNER DOWN"; _t2 = "Role bonus off, the boss is enraged - flash him yourself"; _col = make_color_rgb(230, 70, 60); }
    else if (_dis) { _t1 = "YOUR ROLE: DISTRACT"; _t2 = coop_boss_flashing() ? "Holding him: pushback +60%, P2's Salvage is slowed" : "Flash Salvage: +60% pushback, 60% damage"; _col = make_color_rgb(230, 120, 40); }
    else { _t1 = _R.win ? "YOUR ROLE: HIT  -  WINDOW x1.7" : "YOUR ROLE: HIT"; _t2 = _R.win ? "P1 holds Salvage - flash him NOW" : "Flash Salvage: 130% damage, 170% while P1 distracts"; _col = make_color_rgb(120, 200, 90); }
    var _t3 = "Boss HP is SHARED  |  a death enrages the boss for the survivor";
    var _w = max(string_width(_t2), string_width(_t3)) + 16, _x = (_gw - _w) / 2;
    var _ry = 84;
    coop_ui_panel(_x, _ry, _x + _w, _ry + 48);
    draw_set_halign(fa_center);
    draw_set_color(_col); draw_text(_gw / 2, _ry + 2, _t1);
    draw_set_color(c_white); draw_text(_gw / 2, _ry + 17, _t2);
    draw_set_color(make_color_rgb(200, 196, 188)); draw_text(_gw / 2, _ry + 32, _t3);
    draw_set_halign(fa_left); draw_set_color(c_white);
}
