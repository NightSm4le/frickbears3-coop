// ===== Frickbear's Coop 0.6.0: co-op settings, shared boss HP (Plan A), Scraptrap shared tasks,
// 3D maze co-op (both inside, partner billboard, enemy hunts the nearest living player),
// stage 7 economy (one difficulty, own money/upgrades, partner purchases visible, night reward for both),
// player sprites loaded at RUNTIME from <game>/coop_art/*.png (drafts; replace files after approval, nothing baked in data.win).

global.CoopCfg = {
    // host-authoritative (host's values are sent to the client in "cfg")
    repel: 50, revives: 1, jd: 1, bossShared: 1, maze: 1, specReward: 100,
    // local
    mask: 0,              // 0 freddy, 1 bonnie, 2 chica (my own mask, sent to the partner)
    devMode: false,
    partnerMask: 1,
    partnerMaskRaw: -1,
    cchar: "", partnerChar: "",  // 0.7.4: custom character id (Addons/CoopChars/<id>/), "" = default mask art   // 0.6.2: mask the partner chose (partnerMask = what we draw; P2 never looks like P1)
    loaded: false, fromHost: false,
    hostDiff: -1          // 0.7.7 (S9-2): host's shared difficulty as last received by the client (-1 = not synced yet)
};
// 0.6.2: P1 keeps its mask; if P2 picked the same one, P2 is shown with the next mask (freddy->bonnie->chica)
function coop_mask_shown(_slot, _own, _other) { return (_slot == 2 && _own == _other) ? ((_own + 1) mod 3) : _own; }
function coop_mask_fix()
{
    var _g = global.CoopCfg;
    if (_g.partnerMaskRaw < 0) { return; }
    _g.partnerMask = coop_mask_shown(coop_partner_slot(), _g.partnerMaskRaw, _g.mask);
}
function coop_mask_name(_i) { var _n = ["freddy", "bonnie", "chica"]; return _n[clamp(_i, 0, 2)]; }

global.CoopArt = { tried: false, spr: {} };
global.CoopB = { hpKeep: -1, deadDmg: 0, restoreHP: -1, reAggro: 0, lastHP: -1, hostHP: -1, hostPhase: 0, lastSend: 0, dmgOut: 0, dmgIn: 0, aggro: 0, pDeadSeen: false, meDeadSeen: false,
    botBoss: -1, botBossDmg: -1, botBossNext: 0, botBossDone: false, botScrap: -1, botScrapDone: false, scrapDone: false, scrapTitles: [], scrapSent: false, scrapTotal: 0, scrapIn: 0, scrapOut: 0, logAt: 0 };
global.CoopM = { pauseBlockAt: -100000, sync: false, px: 0, py: 0, pdir: 0, pmove: 0, pAlive: true, meCaught: false, peer: noone, lastSend: 0, lastEnemySend: 0, enemies: undefined, enemiesAt: 0,
    caughtP: 0, waitShown: false, botMaze: -1, botMazeDone: false, ghost: false, ghostDone: false, botApproach: -1, botSpawn: -1, botSpawnDone: false, spawnSent: false, puppets: 0, pCaughtAt: 0, botApproachDone: false, botFace: -1, botFaceDone: false, botExit: -1, botExitDone: false, botTxtAt: 0,
    logAt: 0, followed: false, shotAt: 0, targetLog: "", sit: false, psit: 0, botSit: -1, botSitDone: false, botSitUntil: 0, botSitOn: false, mzRoom: -1, mzAt: 0, sitShot: false, sitLog: -1, botSitWait: false, botSitWaitAt: 0 };
global.CoopE = { pMoney: -1, pBuys: [], buysIn: 0, buysOut: 0, partnerEr: -1, botBuy: -1, botBuyDone: false, shown: 0 };
global.CoopMore = { pwAt: 0, botAdv: -1, botAdvAt: 0, roomAt: 0, officeAt: 0, shotReq: "", shotAt: 0, prevRoom: -1, botSet: -1, botSetDone: false, botSetStep: 0, botSetAt: 0 };

function coop_more_parse_args()
{
    var _n = parameter_count(), _B = global.CoopB, _M = global.CoopM, _E = global.CoopE;
    for (var i = 0; i < _n; i++)
    {
        var _p = parameter_string(i);
        var _v = (i + 1 < _n) ? parameter_string(i + 1) : "";
        if (_p == "-coop-botboss") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _B.botBoss = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botbossdmg") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _B.botBossDmg = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botscrap") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _B.botScrap = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botmaze") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _M.botMaze = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botmazeapproach") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _M.botApproach = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botmazeface") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _M.botFace = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botmazeexit") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _M.botExit = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botmazespawn") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _M.botSpawn = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botbuy") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } _E.botBuy = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botadvance") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } global.CoopMore.botAdv = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-botsettings") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } global.CoopMore.botSet = coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0); }
        else if (_p == "-coop-mask") { if (_v != "" && string_char_at(_v, 1) != "-") { i++; } global.CoopCfg.mask = clamp(coop_arg_num((_v != "" && string_char_at(_v, 1) != "-") ? _v : "", 0), 0, 2); global.CoopCfg.loaded = true; }
    }
}

// ---------------- settings ----------------
function coop_cfg_load()
{
    var _g = global.CoopCfg;
    if (_g.loaded) { return; }
    ini_open("coop_settings.ini");
    _g.repel = ini_read_real("coop", "repel", 50);
    _g.revives = ini_read_real("coop", "revives", 1);
    _g.jd = ini_read_real("coop", "jointdoor", 1);
    _g.bossShared = ini_read_real("coop", "bossshared", 1);
    _g.maze = ini_read_real("coop", "maze", 1);
    _g.specReward = ini_read_real("coop", "specreward", 100);
    _g.mask = clamp(ini_read_real("coop", "mask", 0), 0, 2);
    _g.devMode = ini_read_real("coop", "devmode", 0) != 0;
    _g.cchar = ini_read_string("coop", "char", "");
    ini_close();
    _g.loaded = true;
    coop_cfg_apply("load");
}

function coop_cfg_save()
{
    var _g = global.CoopCfg;
    ini_open("coop_settings.ini");
    if (!_g.fromHost)
    {
        ini_write_real("coop", "repel", _g.repel); ini_write_real("coop", "revives", _g.revives); ini_write_real("coop", "jointdoor", _g.jd);
        ini_write_real("coop", "bossshared", _g.bossShared); ini_write_real("coop", "maze", _g.maze); ini_write_real("coop", "specreward", _g.specReward);
    }
    ini_write_real("coop", "mask", _g.mask);
    ini_write_real("coop", "devmode", _g.devMode ? 1 : 0);
    ini_write_string("coop", "char", _g.cchar);
    ini_close();
}

function coop_cfg_msg()
{
    var _g = global.CoopCfg;
    return { t: "cfg", repel: _g.repel, revives: _g.revives, jd: _g.jd, bossShared: _g.bossShared, maze: _g.maze, specReward: _g.specReward, mask: _g.mask, cchar: _g.cchar,
        diff: variable_global_exists("Difficulty") ? global.Difficulty : -1 };
}

function coop_cfg_apply(_why)
{
    var _g = global.CoopCfg;
    global.CoopA.repelChance = _g.repel;
    coop_mask_fix();
    coop_log("CFG (" + _why + "): repel=" + string(_g.repel) + " revives=" + string(_g.revives) + " jd=" + string(_g.jd) + " bossShared=" + string(_g.bossShared)
        + " maze=" + string(_g.maze) + " specReward=" + string(_g.specReward) + " mask=" + coop_mask_name(_g.mask) + ((_g.partnerMaskRaw >= 0 && coop_mask_shown(coop_my_slot(), _g.mask, _g.partnerMaskRaw) != _g.mask) ? " (shown as " + coop_mask_name(coop_mask_shown(coop_my_slot(), _g.mask, _g.partnerMaskRaw)) + ", same as P1)" : "") + " partnerMask=" + coop_mask_name(_g.partnerMask) + ((_g.partnerMaskRaw >= 0 && _g.partnerMaskRaw != _g.partnerMask) ? " (picked " + coop_mask_name(_g.partnerMaskRaw) + ", same as P1)" : "") + " devMode=" + string(_g.devMode) + " fromHost=" + string(_g.fromHost));
}

function coop_cfg_send() { if (global.Coop.connected) { coop_send(coop_cfg_msg()); } }

function coop_set_options()
{
    var _g = global.CoopCfg, _h = coop_is_client() ? " (host)" : "";
    return [
        "Repel chance: " + string(_g.repel) + "%" + _h,
        "Revives per night: " + string(_g.revives) + _h,
        "Both hold the door: " + (_g.jd ? "ON" : "OFF") + _h,
        "Boss HP: " + (_g.bossShared ? "SHARED" : "separate") + _h,
        "3D maze together: " + (_g.maze ? "ON" : "OFF") + _h,
        "Spectator reward: " + string(_g.specReward) + "%" + _h,
        "My mask: " + string_upper(coop_mask_name(_g.mask)) + ((_g.partnerMaskRaw >= 0 && coop_mask_shown(coop_my_slot(), _g.mask, _g.partnerMaskRaw) != _g.mask) ? " (same as P1 -> shown " + string_upper(coop_mask_name(coop_mask_shown(coop_my_slot(), _g.mask, _g.partnerMaskRaw))) + ")" : ""),
        "Developer mode: " + (_g.devMode ? "ON" : "OFF"),
        "Character: " + ((_g.cchar == "") ? "MASK (default)" : string_upper(_g.cchar)) + ((_g.partnerChar != "") ? "  | partner: " + string_upper(_g.partnerChar) : ""),
        "Back"
    ];
}

function coop_set_desc()
{
    var _g = global.CoopCfg;
    // 0.7.7 (S9-1): at most 3 header lines, so the rows above the cursor have room below it
    var _s = "Co-op settings. Host decides for both;\n" + (_g.devMode ? "mask, dev mode (stream stats ON): local." : "your mask and developer mode are local.");
    // 0.7.7 (S9-2): the client shows the host's synced value, not its own save's (the title screen reloads the client save)
    if (coop_is_client()) { _s += "\nFrom host. Difficulty (shared): " + ((_g.hostDiff >= 0) ? string(_g.hostDiff) : "waiting..."); }
    else if (variable_global_exists("Difficulty")) { _s += "\nDifficulty (shared, host save): " + string(global.Difficulty); }
    return _s;
}

// oTitleMenu scope
function coop_set_select()
{
    var _g = global.CoopCfg, _k = SelectedOption, _locked = coop_is_client() && _k < 6;
    if (_locked) { audio_play_sound(sfxBump, 5, false); goto_menu("Co-op Settings", _k); return; }
    switch (_k)
    {
        case 0: _g.repel = (_g.repel + 25) mod 125; break;
        case 1: _g.revives = (_g.revives + 1) mod 3; break;
        case 2: _g.jd = !_g.jd; break;
        case 3: _g.bossShared = !_g.bossShared; break;
        case 4: _g.maze = !_g.maze; break;
        case 5: _g.specReward = (_g.specReward == 100) ? 50 : ((_g.specReward == 50) ? 0 : 100); break;
        case 6: _g.mask = (_g.mask + 1) mod 3; if (_g.partnerMaskRaw >= 0 && _g.mask == _g.partnerMaskRaw) { _g.mask = (_g.mask + 1) mod 3; } break; // 0.7.3: never the partner's skin (same difficulty for both)
        case 7: _g.devMode = !_g.devMode; break;
        case 8: _g.cchar = coop_char_next(_g.cchar, _g.partnerChar); global.CoopArt.spr = {}; break;
        default: goto_menu("Co-op", 4); return;
    }
    coop_cfg_save(); coop_cfg_apply("menu"); coop_cfg_send();
    goto_menu("Co-op Settings", _k);
}

function coop_set_back() { goto_menu("Co-op", 4); }

// 0.7.7 (S9-1), oTitleMenu Draw_77 scope: in Co-op Settings, an option row scrolled up into the header text
// (CurrentDesc, drawn from y=16) is not drawn. The selected row (resting at y=168) always stays visible.
function coop_set_row_visible(_y, _i)
{
    if (CurMenu != "Co-op Settings" || _i == SelectedOption) { return true; }
    var _top = min(16 + string_height_ext(CurrentDesc, 32, 612) + 6, 160);
    return _y >= _top;
}

// ---------------- runtime art (drafts) ----------------
function coop_art_get(_slot, _mask, _kind)
{
    var _A = global.CoopArt;
    var _key = "P" + string(_slot) + "_" + coop_mask_name(clamp(_mask, 0, 2)) + "_" + _kind;
    if (variable_struct_exists(_A.spr, _key)) { return variable_struct_get(_A.spr, _key); }
    // 0.7.4: custom character (ready set or Addons/CoopChars/<id>/{portrait,maze,icon}.png)
    var _ch = (_slot == coop_my_slot()) ? global.CoopCfg.cchar : global.CoopCfg.partnerChar;
    if (_ch != "")
    {
        var _cf = coop_char_dir(_ch) + ((_kind == "bill") ? "maze" : _kind) + ".png";
        if (file_exists(_cf))
        {
            var _cs = sprite_add(_cf, (_kind == "bill") ? 6 : 1, false, false, 0, 0);
            if (_cs >= 0 && _kind == "bill" && (sprite_get_number(_cs) != 6 || sprite_get_height(_cs) != 64)) { coop_log("CHAR: " + _cf + " must be 6 frames of 32x64 (192x64 strip)"); sprite_delete(_cs); _cs = -1; }
            if (_cs >= 0) { coop_log("CHAR: loaded " + _cf); variable_struct_set(_A.spr, _key, _cs); return _cs; }
        }
    }
    var _f = working_directory + "coop_art/" + _key + ".png";
    var _s = -1;
    if (file_exists(_f))
    {
        _s = sprite_add(_f, (_kind == "bill") ? 6 : 1, false, false, 0, 0);
        if (_s >= 0 && _kind == "bill" && (sprite_get_number(_s) != 6 || sprite_get_width(_s) != 32 || sprite_get_height(_s) != 64))
        {
            coop_log("art: invalid " + _f + " (expected six 32x64 frames); using embedded art");
            sprite_delete(_s); _s = -1;
        }
    }
    // 0.6.3: no coop_art folder -> the same draft art embedded in data.win (written once to the save folder)
    if (_s < 0)
    {
        var _b64 = coop_art_embedded(_key);
        if (_b64 != "")
        {
            var _tmp = game_save_id + "coop_art_" + _key + ".png";
            if (!file_exists(_tmp)) { var _buf = buffer_base64_decode(_b64); buffer_save(_buf, _tmp); buffer_delete(_buf); }
            if (file_exists(_tmp)) { _s = sprite_add(_tmp, (_kind == "bill") ? 6 : 1, false, false, 0, 0); }
            if (_s >= 0) { coop_log("art: " + _key + " from the art embedded in data.win (" + string(sprite_get_width(_s)) + "x" + string(sprite_get_height(_s)) + " x" + string(sprite_get_number(_s)) + ")"); variable_struct_set(_A.spr, _key, _s); return _s; }
        }
    }
    if (_s < 0) { _s = coop_art_placeholder(_slot, _kind); coop_log("art: " + _f + " missing -> generated placeholder"); }
    else { coop_log("art: loaded draft " + _f + " (" + string(sprite_get_width(_s)) + "x" + string(sprite_get_height(_s)) + " x" + string(sprite_get_number(_s)) + ")"); }
    variable_struct_set(_A.spr, _key, _s);
    return _s;
}

function coop_art_placeholder(_slot, _kind)
{
    var _w = (_kind == "bill") ? 32 : ((_kind == "icon") ? 16 : 48), _h = (_kind == "bill") ? 64 : _w;
    var _n = (_kind == "bill") ? 6 : 1;
    var _sf = surface_create(_w * _n, _h);
    surface_set_target(_sf); draw_clear_alpha(c_black, 0);
    var _col = (_slot == 1) ? make_color_rgb(96, 152, 232) : make_color_rgb(240, 152, 64);
    for (var i = 0; i < _n; i++) { draw_set_color(_col); draw_rectangle(i * _w + 2, 2, i * _w + _w - 3, _h - 3, false); draw_set_color(c_black); draw_rectangle(i * _w + 2, 2, i * _w + _w - 3, _h - 3, true); }
    surface_reset_target();
    var _s = sprite_create_from_surface(_sf, 0, 0, _w * _n, _h, false, false, 0, 0);
    if (_n > 1) { sprite_set_offset(_s, 0, 0); }
    surface_free(_sf);
    draw_set_color(c_white);
    return _s;
}

function coop_my_slot() { return coop_is_client() ? 2 : 1; }
function coop_partner_slot() { return coop_is_client() ? 1 : 2; }

// partner portrait for the office partner window / spectator HUD (never a full body in the office)
function coop_art_partner_portrait(_x, _y, _sz, _alpha)
{
    var _s = coop_art_get(coop_partner_slot(), global.CoopCfg.partnerMask, "portrait");
    if (_s < 0) { return; }
    draw_sprite_ext(_s, 0, _x, _y, _sz / sprite_get_width(_s), _sz / sprite_get_height(_s), 0, c_white, _alpha);
}

function coop_art_icon(_slot, _mask, _x, _y, _alpha)
{
    var _s = coop_art_get(_slot, _mask, "icon");
    if (_s >= 0) { draw_sprite_ext(_s, 0, _x, _y, 1, 1, 0, c_white, _alpha); }
}

// ---------------- packets ----------------
function coop_more_packet(_t, _m)
{
    var _g = global.CoopCfg, _B = global.CoopB, _M = global.CoopM, _E = global.CoopE;
    switch (_t)
    {
        case "salv": coop_salv_in(_m); break;
        case "cfg":
            _g.partnerMaskRaw = clamp(_m.mask, 0, 2); // never our own mask
            var _pc = variable_struct_exists(_m, "cchar") ? string(_m.cchar) : "";
            if (_pc != _g.partnerChar) { _g.partnerChar = _pc; global.CoopArt.spr = {}; coop_log("CHAR: partner character " + ((_pc == "") ? "default" : _pc)); }
            if (coop_is_client() && _g.cchar != "" && _g.cchar == _pc) { _g.cchar = coop_char_next(_g.cchar, _pc); global.CoopArt.spr = {}; coop_log("CHAR: same character as the host -> mine is now " + _g.cchar); coop_send(coop_cfg_packet_safe()); }
            if (coop_is_client() && _g.mask == _g.partnerMaskRaw) { _g.mask = (_g.mask + 1) mod 3; coop_log("SKIN: same skin as the host -> mine is now " + coop_mask_name(_g.mask)); coop_send(coop_cfg_packet_safe()); }
            if (coop_is_client())
            {
                _g.repel = _m.repel; _g.revives = _m.revives; _g.jd = _m.jd; _g.bossShared = _m.bossShared; _g.maze = _m.maze; _g.specReward = _m.specReward; _g.fromHost = true;
                if (_m.diff >= 0) { _g.hostDiff = _m.diff; }
                if (_m.diff >= 0 && variable_global_exists("Difficulty") && global.Difficulty != _m.diff) { coop_log("ECON: difficulty " + string(global.Difficulty) + " -> host " + string(_m.diff) + " (one difficulty for both)"); global.Difficulty = _m.diff; }
            }
            coop_cfg_apply("from partner");
            if (instance_exists(oTitleMenu)) { with (oTitleMenu) { if (CurMenu == "Co-op Settings") { CurrentOptions = coop_set_options(); CurrentDesc = coop_set_desc(); } } }
            return true;
        case "bdmg": // host: partner damaged the boss
            if (coop_is_host() && !instance_exists(oSalvage) && global.CoopS.spec) { _B.deadDmg += _m.d; return true; } // 0.8.1: I am dead, kept for my revive
            if (coop_is_host() && instance_exists(oSalvage))
            {
                _B.dmgIn += _m.d;
                with (oSalvage) { HP -= _m.d; HPBarSpeed = max(HPBarSpeed, _m.d * 2); phase_transition(); }
                if (instance_exists(oSalvage)) { coop_log("BOSS: partner damage " + string_format(_m.d, 1, 3) + " -> HP " + string_format(oSalvage.HP, 1, 2) + " phase " + string(oSalvage.Phase)); }
                else { coop_log("BOSS: partner damage " + string_format(_m.d, 1, 3) + " -> boss defeated"); }
            }
            return true;
        case "bhp": // client: authoritative HP / phase
            _B.hostHP = _m.hp; _B.hostPhase = _m.ph;
            if (coop_is_client() && instance_exists(oSalvage) && global.CoopCfg.bossShared)
            {
                with (oSalvage) { HP = min(_m.hp, MaxHP); phase_transition(); }
                _B.lastHP = instance_exists(oSalvage) ? oSalvage.HP : -1;
            }
            return true;
        case "baggro":
            coop_boss_aggro(_m.why, false);
            return true;
        case "stasks": // client: host's Scraptrap task list (same titles/durations on both sides)
            if (coop_is_client() && instance_exists(oScraptrap)) { _B.scrapGotAt = current_time; oScraptrap.Tasks = _m.tasks; _B.scrapTotal = array_length(_m.tasks); _B.scrapTitles = coop_scrap_titles(); coop_log("SCRAP: task list from host (" + string(array_length(_m.tasks)) + " tasks)"); }
            return true;
        case "stask": // partner finished a task
            _B.scrapIn++;
            coop_scrap_remove(_m.title);
            // 0.8.3 (UX-S16-S1): short toast with the task's name instead of a permanent egocentric counter
            if (room == Office && instance_exists(oScraptrap)) { coop_alert("Partner finished: " + string(_m.title), c_yellow, undefined); }
            return true;
        case "mz": // partner maze position
            _M.px = _m.x; _M.py = _m.y; _M.pdir = _m.d; _M.pmove = _m.mv; _M.pAlive = _m.al && !(current_time - _M.pCaughtAt < 2000); _M.prm = _m.rm; _M.pAt = current_time;
            var _ps = variable_struct_exists(_m, "s") ? _m.s : 0; if (_ps != _M.psit) { coop_log("MAZE: partner " + (_ps ? "sat down" : "stood up")); } _M.psit = _ps;
            return true;
        case "mzen": // client: host's enemy states
            _M.enemies = _m.e; _M.enemiesAt = current_time;
            if (coop_is_client() && instance_exists(oCamera3DMaze) && !_M.meCaught && instance_number(oMazeEnemy) < array_length(_m.e))
            {
                // host's maze has enemies (e.g. the host took the Marionette mask): spawn puppets here
                for (var i = instance_number(oMazeEnemy); i < array_length(_m.e); i++) { var _s = _m.e[i]; with (instance_create_depth(_s[0], _s[1], 0, oMazeEnemy)) { PatrolID = (array_length(_s) > 5) ? _s[5] : 0; } }
                _M.puppets = instance_number(oMazeEnemy);
                coop_log("MAZE: host has " + string(array_length(_m.e)) + " enemies -> puppets created here");
            }
            return true;
        case "mzspawn": // host: the client's maze spawned enemies (client took the mask) -> spawn the real ones here
            if (coop_is_host() && instance_exists(oCamera3DMaze) && instance_number(oMazeEnemy) == 0) { coop_maze_spawn_enemies("partner's maze spawned enemies"); }
            return true;
        case "mzgo": // client: follow host into the maze room
            if (coop_is_client() && global.CoopCfg.maze)
            {
                var _r = asset_get_index(_m.rm);
                if (_r >= 0 && room != _r) { global.Night = _m.night; _M.followed = true; coop_log("MAZE: following host into " + _m.rm + " (night " + string(_m.night) + ")"); room_goto(_r); }
            }
            return true;
        case "mzcaught": // client: host's enemy caught me
            if (instance_exists(oCamera3DMaze) && !_M.meCaught) { coop_maze_die_local("host enemy " + string(_m.e)); }
            return true;
        case "money":
            _E.pMoney = max(0, _m.m); // 0.6.3: never show a negative partner balance
            return true;
        case "buy":
            _E.buysIn++;
            array_push(_E.pBuys, _m.name);
            if (_m.money < 0) { coop_log("ECON: partner balance " + string(_m.money) + " < 0 in a buy packet -> shown as 0"); }
            _E.pMoney = max(0, _m.money);
            coop_log("ECON: partner bought " + _m.name + " (id " + string(_m.id) + "), partner money " + string(_m.money) + "; my money " + string(global.RunEarnings) + " untouched");
            coop_alert("Partner bought: " + _m.name, c_aqua, undefined);
            global.CoopA.alertAt = current_time;
            return true;
    }
    return false;
}

// ---------------- bosses ----------------
function coop_boss_step()
{
    var _B = global.CoopB, _c = global.Coop;
    if (!_c.connected || room != Office || !global.CoopCfg.bossShared) { _B.lastHP = -1; return; }
    coop_boss_roles_step(); // 0.8.0 (215-boss): roles change damage / pushback (before the HP delta below)
    coop_boss_restore_step(); // 0.8.1 (S13-2): after a revive, once the new Salvage exists
    if (instance_exists(oSalvage))
    {
        var _hp = oSalvage.HP;
        if (coop_is_host()) { _B.hpKeep = _hp; }
        if (coop_is_client())
        {
            if (_B.lastHP >= 0 && _hp < _B.lastHP - 0.00001) { var _d = _B.lastHP - _hp; _B.dmgOut += _d; coop_send({ t: "bdmg", d: _d }); }
            _B.lastHP = _hp;
        }
        else if (current_time - _B.lastSend >= 200)
        {
            _B.lastSend = current_time;
            coop_send({ t: "bhp", hp: _hp, ph: oSalvage.Phase });
        }
        if (_c.bot && _hp < 85 && !variable_struct_exists(_B, "shotHP")) { _B.shotHP = true; global.CoopMore.shotReq = "boss_shared_hp"; global.CoopMore.shotAt = current_time + 300; }
        if (current_time - _B.logAt > 3000) { _B.logAt = current_time; coop_log("BOSS: Salvage HP " + string_format(_hp, 1, 2) + " phase " + string(oSalvage.Phase) + (coop_is_client() ? " hostHP " + string_format(_B.hostHP, 1, 2) + " sentDmg " + string_format(_B.dmgOut, 1, 2) : " partnerDmg " + string_format(_B.dmgIn, 1, 2))); }
    }
    // a death raises the boss's aggression (host side; once per death)
    if (coop_is_host() && boss_fight_night())
    {
        var _pd = coop_partner_get("sp", 0) == 1;
        if (_pd && !_B.pDeadSeen) { _B.pDeadSeen = true; coop_boss_aggro("partner died", true); }
        if (!_pd) { _B.pDeadSeen = false; }
    }
    coop_scrap_step();
}

function coop_boss_aggro(_why, _bcast)
{
    var _B = global.CoopB;
    _B.aggro++;
    with (oSalvage) { MoveSpeed *= 1.25; SummonSpeed *= 1.25; HPDrainRate *= 0.9; }
    with (oFredbear) { Difficulty = min(1, Difficulty + 0.15); }
    coop_log("BOSS: aggression +1 (" + _why + "), level " + string(_B.aggro));
    coop_alert("Boss enraged: " + _why, c_red, undefined);
    global.CoopA.alertAt = current_time;
    if (_bcast && global.Coop.connected) { coop_send({ t: "baggro", why: _why }); }
}

function coop_scrap_titles()
{
    var _o = [];
    if (instance_exists(oScraptrap)) { var _t = oScraptrap.Tasks; for (var i = 0; i < array_length(_t); i++) { array_push(_o, _t[i].Title); } }
    return _o;
}

function coop_scrap_remove(_title)
{
    if (!instance_exists(oScraptrap)) { return; }
    var _B = global.CoopB, _t = oScraptrap.Tasks;
    for (var i = 0; i < array_length(_t); i++)
    {
        if (_t[i].Title != _title) { continue; }
        with (oControlPanel)
        {
            if (variable_instance_exists(id, "TaskRunning")) { if (TaskRunning == i) { TaskRunning = -1; TaskProgress = 0; } else if (TaskRunning > i) { TaskRunning--; } }
        }
        array_delete(oScraptrap.Tasks, i, 1);
        for (var k = 0; k < array_length(oScraptrap.Tasks); k++) { oScraptrap.Tasks[k].Offset = k * 27; }
        _B.scrapTitles = coop_scrap_titles();
        coop_log("SCRAP: partner finished '" + _title + "' -> removed here, " + string(array_length(oScraptrap.Tasks)) + " left");
        return;
    }
}

function coop_scrap_step()
{
    var _B = global.CoopB;
    if (!instance_exists(oScraptrap)) { _B.scrapSent = false; _B.scrapTitles = []; _B.scrapTotal = 0; return; }
    if (coop_is_host() && !_B.scrapSent) { _B.scrapSent = true; _B.scrapTotal = array_length(oScraptrap.Tasks); coop_send({ t: "stasks", tasks: oScraptrap.Tasks }); _B.scrapTitles = coop_scrap_titles(); coop_log("SCRAP: task list sent (" + string(array_length(_B.scrapTitles)) + ")"); return; }
    var _now = coop_scrap_titles();
    if (array_length(_now) < array_length(_B.scrapTitles))
    {
        for (var i = 0; i < array_length(_B.scrapTitles); i++)
        {
            if (!array_contains(_now, _B.scrapTitles[i])) { _B.scrapOut++; coop_send({ t: "stask", title: _B.scrapTitles[i] }); coop_log("SCRAP: I finished '" + _B.scrapTitles[i] + "' -> sent, " + string(array_length(_now)) + " left"); }
        }
    }
    _B.scrapTitles = _now;
}

// bot: boss night like Extras > Bosses (route 3 Salvage, 2 Happiest Day, 4 Fredbear), difficulty 1
function coop_bot_boss_start(_route)
{
    global.Night = "Custom";
    global.NightSpeedup = 1;
    global.CustomNightMusic = undefined;
    global.Route = _route;
    global.SummonedAnimatronics = [];
    global.Challenge = undefined;
    global.ChallengeTitle = "None";
    global.Difficulty = 1;
    global.AILevels = array_create(array_length(global.AILevels), 0);
    global.Upgrades = [];
    global.Cheats = array_create(10, false);
    global.SavedBossTime = 0;
    global.AllTimeSalvages = [20, 33, 35, 34, 0, 1, 2, 3, 16, 11, 13, 14, 7, 18, 30, 31, 38, 36];
    if (_route == 3) { array_delete(global.AllTimeSalvages, 0, 4); }
    coop_prepare_night();
    coop_log("bot: BOSS night route " + string(_route) + " (Extras>Bosses setup, difficulty 1)");
    room_goto(NightOpening);
}

// ---------------- maze ----------------
function coop_is_maze_room(_r) { return _r == MinigameMaze_1 || _r == MinigameMaze_2 || _r == MinigameMaze_3 || _r == MinigameMaze_4 || _r == MinigameMaze_5; }

function coop_maze_die_local(_why)
{
    var _M = global.CoopM;
    _M.meCaught = true;
    coop_log("MAZE: I was caught (" + _why + ")");
    var _e = instance_nearest(oCamera3DMaze.x, oCamera3DMaze.y, oMazeEnemy);
    with (instance_create_depth(0, 0, 0, oTextBox)) { game_text("Endo_Death"); }
    if (_e != noone) { with (oCamera3DMaze) { LockOnTarget = _e; LockX = _e.x; LockY = _e.y; LockZ = 96; } }
    instance_create_depth(0, 0, 0, oMinigameJumpscare);
    instance_destroy(oMazeEnemy);
    coop_send({ t: "mz", x: oCamera3DMaze.x, y: oCamera3DMaze.y, d: 0, mv: 0, al: false, rm: room_get_name(room) });
}

// oMazeEnemy Step: replaces place_meeting(x, y, Player)
function coop_maze_hit()
{
    var _M = global.CoopM;
    if (!_M.sync) { return place_meeting(x, y, Player); }
    if (coop_is_client()) { return false; } // host decides catches
    if (!_M.meCaught && place_meeting(x, y, oCamera3DMaze))
    {
        _M.meCaught = true;
        if (_M.pAlive)
        {
            // keep the maze (and its enemies) running for the partner: I become a ghost until the partner leaves
            _M.ghost = true;
            coop_log("MAZE: enemy " + string(coop_maze_enemy_index(id)) + " caught ME (host) at " + string(round(x)) + "," + string(round(y)) + ", partner still in the maze -> ghost until partner leaves");
            Mode = "Pause"; Frame = 0;
            return false;
        }
        coop_log("MAZE: enemy " + string(coop_maze_enemy_index(id)) + " caught ME (host), partner already out/caught -> normal death");
        return true;
    }
    if (_M.pAlive && point_distance(x, y, _M.px, _M.py) < 14)
    {
        _M.pAlive = false; _M.caughtP++; _M.pCaughtAt = current_time;
        coop_send({ t: "mzcaught", e: coop_maze_enemy_index(id) });
        coop_log("MAZE: enemy " + string(coop_maze_enemy_index(id)) + " caught the PARTNER at " + string(round(x)) + "," + string(round(y)));
        Mode = "Pause"; Frame = 0; Player = oCamera3DMaze;
    }
    return false;
}

function coop_maze_spawn_enemies(_why)
{
    with (oEnemySpawnPoint) { with (instance_create_depth(x, y, 0, oMazeEnemy)) { PatrolID = other.PatrolID; } }
    coop_log("MAZE: spawned " + string(instance_number(oMazeEnemy)) + " enemies (" + _why + ")");
}

function coop_maze_enemy_index(_inst)
{
    for (var i = 0; i < instance_number(oMazeEnemy); i++) { if (instance_find(oMazeEnemy, i) == _inst) { return i; } }
    return -1;
}

function coop_maze_step()
{
    var _M = global.CoopM, _c = global.Coop;
    var _inMaze = coop_is_maze_room(room) && instance_exists(oCamera3DMaze);
    var _pFresh = variable_struct_exists(_M, "pAt") && current_time - _M.pAt < 1500;
    _M.sync = _c.connected && global.CoopCfg.maze && _inMaze && _pFresh && _M.prm == room_get_name(room);
    if (!_inMaze) { _M.ghost = false; _M.ghostDone = false; _M.meCaught = false; _M.pAlive = true; _M.spawnSent = false; _M.puppets = 0; _M.botSpawnDone = false; if (instance_exists(_M.peer)) { instance_destroy(_M.peer); } _M.peer = noone; }
    // host pulls the partner into its maze room
    if (coop_is_host() && _c.connected && global.CoopCfg.maze && _inMaze && current_time - _M.lastSend > 1000 && !(_pFresh && _M.prm == room_get_name(room)))
    {
        coop_send({ t: "mzgo", rm: room_get_name(room), night: global.Night });
    }
    if (!_inMaze) { return; }
    // my position ~15/s
    if (_c.connected && current_time - _M.lastSend >= 66)
    {
        _M.lastSend = current_time;
        var _cam = oCamera3DMaze;
        var _ms = coop_maze_me_sitting();
        if (_ms != _M.sitLog) { if (_M.sitLog != -1 || _ms) { coop_log("MAZE: my pose -> " + (_ms ? "sitting" : "standing") + " (sent to partner)"); } _M.sitLog = _ms; }
        coop_send({ t: "mz", s: _ms, x: _cam.x, y: _cam.y, d: _cam.CameraRotationH + 180, mv: (_cam.Loudness > 0) ? 1 : 0, al: !_M.meCaught && !instance_exists(oMinigameJumpscare), rm: room_get_name(room) });
    }
    // host ghost: run the normal death once the partner is out of the maze or caught
    if (_M.ghost && !_M.ghostDone && (!_M.sync || !_M.pAlive)) { _M.ghostDone = true; coop_maze_die_local("deferred: partner out of the maze or caught"); }
    if (!_M.sync) { return; }
    // client got its own enemies (it took the mask): ask the host to spawn the real ones
    if (coop_is_client() && !_M.spawnSent && instance_number(oMazeEnemy) > _M.puppets) { _M.spawnSent = true; coop_send({ t: "mzspawn" }); coop_log("MAZE: my maze spawned enemies -> host spawns the real ones"); }
    // partner billboard object (draws in the 3D pass)
    if (!instance_exists(_M.peer)) { _M.peer = instance_create_depth(_M.px, _M.py, 0, oCoopMazePeer); coop_log("MAZE: partner billboard created at " + string(round(_M.px)) + "," + string(round(_M.py))); }
    with (_M.peer) { x = _M.px; y = _M.py; Loudness = _M.pmove ? 512 : 0; visible = _M.pAlive; }
    if (coop_is_host())
    {
        // enemy hunts the NEAREST living player
        var _list = [];
        with (oMazeEnemy)
        {
            var _dMe = global.CoopM.meCaught ? 999999 : point_distance(x, y, oCamera3DMaze.x, oCamera3DMaze.y);
            var _dP = global.CoopM.pAlive ? point_distance(x, y, global.CoopM.px, global.CoopM.py) : 999999;
            var _nt = (_dP < _dMe) ? global.CoopM.peer : oCamera3DMaze;
            if (Player != _nt) { Player = _nt; global.CoopM.targetLog = "enemy " + string(coop_maze_enemy_index(id)) + " -> " + ((_nt == oCamera3DMaze) ? "HOST" : "PARTNER") + " (dHost " + string(round(_dMe)) + ", dPartner " + string(round(_dP)) + ")"; coop_log("MAZE: target " + global.CoopM.targetLog); }
            array_push(_list, [round(x * 10) / 10, round(y * 10) / 10, Mode, round(Direction), round(AnimFrame), PatrolID]);
        }
        if (current_time - _M.lastEnemySend >= 100) { _M.lastEnemySend = current_time; coop_send({ t: "mzen", e: _list }); }
    }
    else if (is_array(_M.enemies) && current_time - _M.enemiesAt < 1500)
    {
        // client: enemies are puppets of the host's
        var _n = min(instance_number(oMazeEnemy), array_length(_M.enemies));
        for (var i = 0; i < _n; i++)
        {
            var _e = instance_find(oMazeEnemy, i), _s = _M.enemies[i];
            with (_e) { path_end(); x = _s[0]; y = _s[1]; xprevious = x; yprevious = y; Mode = _s[2]; Direction = _s[3]; AnimFrame = _s[4]; }
        }
    }
    if (current_time - _M.logAt > 3000)
    {
        _M.logAt = current_time;
        var _ne = instance_nearest(oCamera3DMaze.x, oCamera3DMaze.y, oMazeEnemy);
        coop_log("MAZE: sync me=" + string(round(oCamera3DMaze.x)) + "," + string(round(oCamera3DMaze.y)) + " partner=" + string(round(_M.px)) + "," + string(round(_M.py)) + " pAlive=" + string(_M.pAlive)
            + " enemies=" + string(instance_number(oMazeEnemy)) + (_ne != noone ? " nearestEnemy=" + string(round(_ne.x)) + "," + string(round(_ne.y)) + " mode=" + _ne.Mode : "") + " " + _M.targetLog);
    }
}

// oCoopNet End Step (client): keep enemies where the host says, after their own Step moved them
function coop_maze_endstep()
{
    var _M = global.CoopM;
    if (!_M.sync || !coop_is_client() || !is_array(_M.enemies)) { return; }
    var _n = min(instance_number(oMazeEnemy), array_length(_M.enemies));
    for (var i = 0; i < _n; i++) { var _e = instance_find(oMazeEnemy, i), _s = _M.enemies[i]; with (_e) { x = _s[0]; y = _s[1]; } }
}

// leaving the maze first (escaped, quit or caught): wait in SalvageResults (office paused) until the partner leaves too
function coop_partner_in_maze()
{
    var _M = global.CoopM;
    return global.Coop.connected && variable_struct_exists(_M, "pAt") && current_time - _M.pAt < 1500 && string_pos("MinigameMaze_", _M.prm) == 1;
}

// oSalvageSheet Create in SalvageResults: true = don't go to the next night yet
function coop_maze_hold()
{
    var _M = global.CoopM;
    if (coop_s4_salvage_results_guard()) { return true; }
    if (!global.CoopCfg.maze || !coop_partner_in_maze()) { return false; }
    _M.waitShown = true; _M.waitAt = current_time;
    coop_log("MAZE: out of the maze first -> waiting for partner (night not advanced yet)");
    return true;
}

function coop_maze_wait_step()
{
    var _M = global.CoopM;
    if (room != SalvageResults || !_M.waitShown) { return; }
    if (!coop_partner_in_maze() && current_time - _M.waitAt > 500)
    {
        _M.waitShown = false;
        coop_log("MAZE: partner left the maze -> continue (as oSalvageSheet does)");
        if (coop_s4_host_night_recent()) { coop_log("NIGHT GUARD: host already set night " + string(global.Night) + " -> not advancing again"); } else { global.Night++; }
        global.StartRoom = NightOpening; create_save(); room_goto(NightOpening); window_set_cursor(cr_default);
    }
}

function coop_bot_textbox_forward()
{
    with (oTextBox)
    {
        // 0.8.4 (CRASH-TB): guarded field reads (same object list as coop_tb_list may include Fredbear-style boxes)
        if (ExternalPause || coop_tb_arr_at(id, "Delay", TextPage, 0) != 0 || coop_tb_arr_at(id, "Lock", TextPage, false)) { continue; }
        if (TextDrawChar != TextLength[TextPage]) { TextDrawChar = TextLength[TextPage]; continue; }
        if (TextPage < (TextPageNumber - 1))
        {
            if (TextPage == (TextPageNumber - 2) && TextOptionNumber > 0) { var _dst = TextOptionLink[TextOptionPosition]; initialize(); game_text(_dst); }
            TextPage += 1; TextDrawChar = 0;
            coop_tb_run_page_funcs(); // 0.8.4 (CRASH-TB): no CGPFunction read on objects that lack it
            Frame = 0;
        }
        else { instance_destroy(); }
    }
}

// oCoopMazePeer Draw (3D pass, same billboard method as oMazeEnemy)
function coop_maze_peer_draw()
{
    if (!visible || !instance_exists(oCamera3DMaze)) { return; }
    var _M = global.CoopM;
    var _spr = coop_art_get(coop_partner_slot(), global.CoopCfg.partnerMask, "bill");
    var _cx = oCamera3DMaze.x, _cy = oCamera3DMaze.y;
    var _va = point_direction(x, y, _cx, _cy) + 90;
    var _front = abs(angle_difference(_M.pdir, point_direction(x, y, _cx, _cy))) < 90;
    var _wf = _M.pmove ? (1 + ((current_time div 180) mod 2)) : 0;
    var _sub = (_front ? 0 : 3) + _wf;
    var _uv = sprite_get_uvs(_spr, _sub);
    // 0.7.3: sitting partner = lower, slightly wider billboard (feet stay on the floor)
    var _hw = _M.psit ? 27 : 24;
    var _x1 = x - lengthdir_x(_hw, _va), _y1 = y - lengthdir_y(_hw, _va), _x2 = x + lengthdir_x(_hw, _va), _y2 = y + lengthdir_y(_hw, _va);
    var _H = _M.psit ? 58 : 96;
    shader_set(TransparencyShader);
    var _vb = vertex_create_buffer();
    vertex_begin(_vb, global.VertexFormat);
    vertex_set_point(_vb, _x1, _y1, _H, _uv[0], _uv[1]);
    vertex_set_point(_vb, _x2, _y2, 0, _uv[2], _uv[3]);
    vertex_set_point(_vb, _x1, _y1, 0, _uv[0], _uv[3]);
    vertex_set_point(_vb, _x1, _y1, _H, _uv[0], _uv[1]);
    vertex_set_point(_vb, _x2, _y2, 0, _uv[2], _uv[3]);
    vertex_set_point(_vb, _x2, _y2, _H, _uv[2], _uv[1]);
    vertex_end(_vb);
    vertex_submit(_vb, pr_trianglelist, sprite_get_texture(_spr, _sub));
    vertex_delete_buffer(_vb);
    shader_reset();
    DrawN++;
}

// ---------------- stage 7: economy ----------------
// 0.6.3: one balance check (the original shop also requires RunEarnings >= price)
function coop_can_afford(_price) { return variable_global_exists("RunEarnings") && global.RunEarnings >= _price; }

function coop_on_upgrade(_id)
{
    var _E = global.CoopE, _name = "upgrade " + string(_id);
    try { _name = get_upgrades(_id).Name; } catch (_e) { }
    _E.buysOut++;
    coop_log("ECON: I bought " + _name + " (id " + string(_id) + "), my money " + string(global.RunEarnings));
    if (coop_active() && global.Coop.connected) { coop_send({ t: "buy", id: _id, name: _name, money: global.RunEarnings }); }
}

function coop_win_earnings()
{
    var _er = 0;
    if (variable_global_exists("Power") && variable_global_exists("Tokens")) { _er = max(round(global.Power * 0.1 * 100) / 100, 0) + (round(global.Tokens * 0.1 * 10) / 10); }
    return _er;
}

// spectator side: called around win_night in coop_spec_win
function coop_spec_reward(_before)
{
    var _E = global.CoopE, _pct = global.CoopCfg.specReward;
    var _got = global.RunEarnings - _before;
    var _want = (_E.partnerEr >= 0) ? _E.partnerEr * _pct / 100 : _got;
    if (_pct == 0) { if (_got > 0) { global.RunEarnings -= _got; global.RunEarningsTotal -= _got; } coop_log("ECON: spectator reward 0% -> removed " + string(_got)); }
    else if (_want > _got) { earn_money(_want - _got); coop_log("ECON: spectator reward " + string(_pct) + "% of partner's " + string(_E.partnerEr) + " -> +" + string(_want - _got) + " on top of own " + string(_got)); }
    else { coop_log("ECON: spectator reward: own earnings " + string(_got) + " >= " + string(_want) + " (kept)"); }
    if (is_numeric(global.Night)) { create_save(); }
}

function coop_econ_draw()
{
    var _E = global.CoopE, _c = global.Coop;
    if (!_c.connected || room == Office || room == GameOver || coop_is_maze_room(room) || room == StartupRoom || room == WarningScreen || coop_sync_is_menu(room) || instance_exists(oTitleMenu)) { return; } // 0.7.6 S7-3: never over title menus / Co-op Settings
    if (_E.pMoney < 0 && array_length(_E.pBuys) == 0) { return; }
    if (room == NightOpening || instance_exists(oTextBox) || instance_exists(oTextBox_Fredbear)) { return; } // 0.6.2: not over the night card portraits / story
    var _gw = display_get_gui_width();
    var _t = "PARTNER $" + string(_E.pMoney);
    if (array_length(_E.pBuys) > 0) { _t += "  bought: "; for (var i = max(0, array_length(_E.pBuys) - 3); i < array_length(_E.pBuys); i++) { _t += _E.pBuys[i] + ((i < array_length(_E.pBuys) - 1) ? ", " : ""); } }
    var _w = string_width(_t) + 26;
    var _ey = display_get_gui_height() - 40; // 0.7.5: bottom-left (top-right is the native money / Tokens box)
    coop_ui_panel(4, _ey, 4 + _w, _ey + 17);
    coop_art_icon(coop_partner_slot(), global.CoopCfg.partnerMask, 7, _ey + 1, 1);
    draw_set_color(c_aqua); draw_text(24, _ey + 2, _t); draw_set_color(c_white);
}

// ---------------- step / draw ----------------
function coop_more_step()
{
    var _c = global.Coop, _X = global.CoopMore, _B = global.CoopB, _M = global.CoopM, _E = global.CoopE, _g = global.CoopCfg;
    if (!_g.loaded) { coop_cfg_load(); }
    if (room != _X.prevRoom)
    {
        if (room == Office)
        {
            _X.officeAt = current_time;
            global.CoopA.repelChance = _g.repel;
            coop_boss_roles_enter(); // 0.8.1 (S13-1): SOLO grace on every Office entry
            if (global.CoopF.revivedEnter)
            {
                // 0.8.1 (S13-2): back from a revive -> same night, same boss: keep the revive counter and the enrage level,
                // take the shared boss HP back (host: own last HP minus what the partner hit while I was dead)
                global.CoopF.revivedEnter = false;
                coop_boss_revive_enter();
            }
            else
            {
                global.CoopF.revLeft = _g.revives;
                if (!_g.jd) { global.CoopF.jd.done = true; }
                _B.aggro = 0; _B.pDeadSeen = false; _B.meDeadSeen = false; global.CoopBR.dmgAdj = 0; global.CoopBR.solo = false; global.CoopBR.winN = 0; _B.dmgIn = 0; _B.dmgOut = 0; _B.lastHP = -1; _B.botBossDone = false; _B.botScrapDone = false;
                _B.hpKeep = -1; _B.deadDmg = 0; _B.restoreHP = -1; _B.reAggro = 0;
            }
            _E.partnerEr = -1; _E.botBuyDone = false;
        }
        if (coop_is_maze_room(room)) { _M.mzRoom = room; _M.mzAt = current_time; _M.botSitOn = false; _M.botSitWait = false; _M.sitLog = -1; _M.sit = false; _M.psit = 0; _M.meCaught = false; _M.pAlive = true; _M.botApproachDone = false; _M.botFaceDone = false; _M.botExitDone = false; _M.targetLog = ""; coop_log("MAZE: entered " + room_get_name(room) + (_c.connected ? " (co-op)" : "")); }
        _X.prevRoom = room;
    }
    // money in the snapshot-free channel: send on change
    if (_c.connected && variable_global_exists("RunEarnings") && (!variable_struct_exists(_E, "lastMoney") || _E.lastMoney != global.RunEarnings || current_time - _E.moneyAt > 5000))
    {
        _E.lastMoney = global.RunEarnings; _E.moneyAt = current_time;
        coop_send({ t: "money", m: global.RunEarnings });
    }
    coop_boss_step();
    coop_maze_step();
    coop_maze_wait_step();
    if (_c.bot) { coop_more_bot(); }
}

function coop_more_bot()
{
    var _c = global.Coop, _X = global.CoopMore, _B = global.CoopB, _M = global.CoopM, _E = global.CoopE;
    // boss night start (host)
    if (_B.botBoss >= 0 && coop_is_host() && _c.connected && !_B.botBossDone && room == TitleScreenMap && oCoopNet.BotTimer > 180) { _B.botBossDone = true; coop_bot_boss_start(_B.botBoss); }
    // boss damage (both sides, FLAGGED: direct lose_hp calls, 2 HP every 3 s from timer T)
    if (_B.botBossDmg >= 0 && room == Office && instance_exists(oSalvage) && coop_alive() && current_time - _X.officeAt >= _B.botBossDmg * 1000 && current_time >= _B.botBossNext)
    {
        _B.botBossNext = current_time + 2000;
        var _hpb = oSalvage.HP;
        with (oSalvage) { lose_hp(2, true); }
        coop_log("bot: FORCED boss damage lose_hp(2) -> local HP " + (instance_exists(oSalvage) ? string_format(oSalvage.HP, 1, 2) : "(boss gone, was " + string_format(_hpb, 1, 2) + ")"));
    }
    // Scraptrap (FLAGGED: spawned directly, AI 10; client "finishes" the first task at timer T)
    if (_B.botScrap >= 0 && room == Office && variable_global_exists("AILevels"))
    {
        if (global.AILevels[63] < 10) { global.AILevels[63] = 10; }
        if (!instance_exists(oScraptrap) && !instance_exists(oSalvage) && !_B.botScrapDone && global.Timer > 3) { _B.botScrapDone = true; var _st = instance_create_depth(0, 0, 0, oScraptrap); coop_log("bot: FORCED spawn oScraptrap (AI 10), tasks " + (instance_exists(_st) ? string(array_length(_st.Tasks)) : "(gone)")); }
        if (coop_is_client() && instance_exists(oScraptrap) && variable_struct_exists(_B, "scrapGotAt") && current_time - _B.scrapGotAt >= _B.botScrap * 1000 + 2000 && !_B.scrapDone && array_length(oScraptrap.Tasks) > 0 && array_length(_B.scrapTitles) > 0)
        {
            _B.scrapDone = true;
            coop_log("bot: FORCED task finish '" + oScraptrap.Tasks[0].Title + "' (as the control panel does: array_delete)");
            array_delete(oScraptrap.Tasks, 0, 1);
            global.CoopMore.shotReq = "scrap_client"; global.CoopMore.shotAt = current_time + 1500;
        }
        if (coop_is_host() && _B.scrapIn > 0 && global.CoopMore.shotReq == "" && !variable_struct_exists(_B, "shotDone")) { _B.shotDone = true; global.CoopMore.shotReq = "scrap_host"; global.CoopMore.shotAt = current_time + 2500; }
    }
    // maze (host): straight into MinigameMaze_N for night N
    if (_M.botMaze >= 0 && coop_is_host() && _c.connected && !_M.botMazeDone && room == TitleScreenMap && oCoopNet.BotTimer > 180)
    {
        _M.botMazeDone = true;
        // 0.8.4: "-coop-botmaze" without a night number (or out of range) -> night 1..5 clamp instead of index -1
        var _mn = clamp(floor(_M.botMaze), 1, 5);
        if (_mn != _M.botMaze) { coop_log("bot: -coop-botmaze night " + string(_M.botMaze) + " invalid -> using night " + string(_mn)); }
        global.Night = _mn; coop_prepare_night();
        var _rooms = [MinigameMaze_1, MinigameMaze_2, MinigameMaze_3, MinigameMaze_4, MinigameMaze_5];
        coop_log("bot: FORCED room jump to " + room_get_name(_rooms[_mn - 1]) + " (night " + string(_mn) + ")");
        room_goto(_rooms[_mn - 1]);
    }
    // maze dialogs (FLAGGED: the bot "presses" forward like input_check_pressed(0) in oTextBox.draw_everything)
    if (_M.botMaze >= 0 || _M.botFace >= 0 || _M.botApproach >= 0 || global.CoopMore.botAdv >= 0) { if (coop_is_maze_room(room) && instance_exists(oTextBox) && current_time - _M.botTxtAt > 700)
    {
        _M.botTxtAt = current_time;
        // 0.6.3: shared maze dialogs -> only the host bot presses, as a real press (sent to the partner like coop_tb_step does)
        if (_c.connected && coop_tb_sync_room())
        {
            if (coop_is_host()) { var _l = coop_tb_list(); for (var k = 0; k < array_length(_l); k++) { if (coop_tb_can(_l[k])) { coop_tb_send_press(_l[k]); coop_tb_forward_inst(_l[k]); break; } } }
            // 0.7.3 bot only: a client box the host never shows (different story flags in the test save) would block the client bot forever
            else if (_M.botFace >= 0 && current_time - global.CoopS3.mzIn > 25000) { coop_bot_textbox_forward(); }
        }
        else { coop_bot_textbox_forward(); }
    } }
    if (_M.sync && instance_exists(oCamera3DMaze) && !instance_exists(oTextBox))
    {
        var _t = oCamera3DMaze.Frame; // not a clock; use time in room
        if (!variable_struct_exists(_M, "inAt") || _M.inRoom != room) { _M.inAt = current_time; _M.inRoom = room; }
        var _sec = (current_time - _M.inAt) / 1000;
        // client stands in front of the host so the host sees the billboard (FLAGGED teleport)
        if (_M.botFace >= 0 && coop_is_client() && !_M.botFaceDone && _sec >= _M.botFace)
        {
            _M.botFaceDone = true;
            var _hd = _M.pdir;
            oCamera3DMaze.x = _M.px + lengthdir_x(120, _hd); oCamera3DMaze.y = _M.py + lengthdir_y(120, _hd);
            oCamera3DMaze.CameraRotationH = _hd; // face the host (look dir = rot + 180)
            coop_log("bot: FORCED teleport in front of the host (120 px) for the billboard shot");
            global.CoopMore.shotReq = "maze_billboard"; global.CoopMore.shotAt = current_time + 2500;
        }
        // client walks to the nearest enemy (FLAGGED teleport next to it), host's enemy must switch to the partner and catch it
        if (_M.botApproach >= 0 && coop_is_client() && !_M.botApproachDone && _sec >= _M.botApproach && !_M.meCaught && instance_number(oMazeEnemy) > 0)
        {
            var _ne = instance_nearest(oCamera3DMaze.x, oCamera3DMaze.y, oMazeEnemy);
            if (_ne != noone) { _M.botApproachDone = true; oCamera3DMaze.x = _ne.x + 40; oCamera3DMaze.y = _ne.y; coop_log("bot: FORCED teleport 40 px from enemy at " + string(round(_ne.x)) + "," + string(round(_ne.y))); }
        }
        if (_M.botSpawn >= 0 && coop_is_host() && !_M.botSpawnDone && _sec >= _M.botSpawn && instance_number(oMazeEnemy) == 0) { _M.botSpawnDone = true; coop_maze_spawn_enemies("bot: FORCED, as TakeMask does, without the palette/wall change"); }
        if (_M.botExit >= 0 && !_M.botExitDone && _sec >= _M.botExit)
        {
            _M.botExitDone = true;
            coop_log("bot: FORCED maze exit (same as Psychic Fredbear 'quit': oTransitionMinigame -> SalvageResults)");
            audio_stop_all(); instance_destroy(oPauser);
            with (instance_create_depth(0, 0, 1000, oTransitionMinigame)) { Destination = SalvageResults; }
            global.DiedToEndo = false;
        }
    }
    // stage 7: client buys an upgrade (FLAGGED: acquire_upgrade + price taken like the shop)
    if (_E.botBuy >= 0 && coop_is_client() && !_E.botBuyDone && room == Office && global.Timer >= _E.botBuy)
    {
        _E.botBuyDone = true;
        var _before = global.RunEarnings;
        if (coop_can_afford(1)) // 0.6.3: same balance check as the shop (RunEarnings >= price)
        {
            global.RunEarnings -= 1;
            acquire_upgrade(1);
            coop_log("bot: FORCED purchase of upgrade 1 for $1 (money " + string(_before) + " -> " + string(global.RunEarnings) + ")");
        }
        else { coop_log("bot: purchase of upgrade 1 for $1 REFUSED - not enough money (" + string(_before) + ")"); coop_alert("Not enough money", c_gray, undefined); }
    }
    // partner reached 6 AM while I am still alive in my office (clock drift / forced win): clear the night here too
    if (room == Office && _c.connected && _c.partnerWon && string(_c.partnerWonNight) == string(global.Night) && coop_alive() && (is_numeric(global.Night) || global.Night == "Custom" || global.Night == "Endless"))
    {
        if (_X.pwAt == 0) { _X.pwAt = current_time; }
        else if (_X.pwAt > 0 && current_time - _X.pwAt > 4000) { _X.pwAt = -1; coop_log("partner reached 6AM 4s ago, I am alive -> win_night here too (timer " + string(global.Timer) + ")"); win_night(); }
    }
    else if (room != Office) { _X.pwAt = 0; }
    // playthrough bot (FLAGGED): auto-advance story textboxes outside Office/maze, every botAdv ms
    if (_X.botAdv >= 0 && room != Office && !coop_is_maze_room(room) && instance_exists(oTextBox) && current_time - _X.botAdvAt > max(300, _X.botAdv)) { _X.botAdvAt = current_time; coop_bot_textbox_forward(); }
    // settings screen screenshots
    if (_X.botSet >= 0 && !_X.botSetDone && room == TitleScreenMap && !instance_exists(oTitleMenu)) { coop_bot_shot_hold(""); }
    if (_X.botSet >= 0 && !_X.botSetDone && room == TitleScreenMap && instance_exists(oTitleMenu) && oCoopNet.BotTimer > 200 + _X.botSet * 60)
    {
        if (_X.botSetStep == 0) { with (oTitleMenu) { PreviousOptions = CurrentOptions; goto_menu("Co-op Settings", 0); } _X.botSetAt = current_time; _X.botSetStep = 1; coop_log("bot: open Co-op Settings"); }
        else if (_X.botSetStep == 1 && current_time - _X.botSetAt > 2500) { coop_log("SHOT settings"); _X.botSetStep = 2; _X.botSetAt = current_time; }
        else if (_X.botSetStep == 2 && current_time - _X.botSetAt > 2500) { with (oTitleMenu) { SelectedOption = coop_is_client() ? 6 : 0; coop_set_select(); } coop_log("bot: settings select option " + (coop_is_client() ? "6 (mask)" : "0 (repel)")); _X.botSetStep = 3; _X.botSetAt = current_time; }
        else if (_X.botSetStep == 3 && current_time - _X.botSetAt > 2500) { coop_log("SHOT settings2"); _X.botSetStep = 4; _X.botSetDone = true; }
    }
    if (global.CoopMore.shotReq != "" && current_time >= global.CoopMore.shotAt) { coop_log("SHOT " + global.CoopMore.shotReq); global.CoopMore.shotReq = ""; }
}

function coop_more_draw()
{
    coop_econ_draw();
    var _c = global.Coop, _M = global.CoopM, _B = global.CoopB;
    var _gw = display_get_gui_width(), _salvage = instance_find(oSalvage, 0), _scraptrap = instance_find(oScraptrap, 0);
    if (room == Office && _c.connected && _salvage != noone && global.CoopCfg.bossShared)
    {
        coop_ui_panel(_gw / 2 - 70, 48, _gw / 2 + 70, 62);
        draw_set_color(c_red); draw_set_halign(fa_center); draw_text(_gw / 2, 49, "SHARED BOSS HP " + string(max(0, round(_salvage.HP))) + "%  P" + string(_salvage.Phase) + (_B.aggro > 0 ? "  RAGE " + string(_B.aggro) : "")); draw_set_halign(fa_left);
    }
    // 0.8.3 (UX-S16-S1/S2): one shared progress line, identical on both sides (total = list size when the host sent /
    // the client received the task list, left = shared remaining tasks); only once the list was synced this night.
    // Note: oScraptrap itself is spawned by the vanilla AI setup (e.g. Unlock All on Night 1), the mod does not add spawns.
    if (room == Office && _c.connected && _scraptrap != noone && _B.scrapTotal > 0)
    {
        var _ty = (_salvage != noone && global.CoopCfg.bossShared) ? 64 : 48; // below the cam strip and alert banner
        // 0.6.4 (S3-4): with the cams up, centre it over the camera view (right of the cam map and clear of its corner marks)
        var _tx = (variable_global_exists("CamUp") && global.CamUp) ? round(_gw * 0.6875) : _gw / 2;
        var _left = array_length(_scraptrap.Tasks), _tot = max(_B.scrapTotal, _left);
        var _tt = "SCRAPTRAP  done " + string(_tot - _left) + "/" + string(_tot) + "  (" + string(_left) + " left)", _tw = string_width(_tt) / 2 + 4;
        coop_ui_panel(_tx - _tw, _ty, _tx + _tw, _ty + 14);
        draw_set_color(c_yellow); draw_set_halign(fa_center); draw_text(_tx, _ty + 1, _tt); draw_set_halign(fa_left);
    }
    var _mazeCam = instance_find(oCamera3DMaze, 0);
    if (coop_is_maze_room(room) && _c.connected && _mazeCam != noone)
    {
        coop_ui_panel(4, 4, 190, 22); // 0.7.5: top-left corner is free in the maze (money box is top-right)
        coop_art_icon(coop_partner_slot(), global.CoopCfg.partnerMask, 6, 5, 1);
        draw_set_color(_M.sync ? (_M.pAlive ? c_lime : c_red) : c_gray);
        if (_M.ghost && !_M.ghostDone) { draw_set_color(c_red); draw_text(6, 26, "CAUGHT - you are a ghost until your partner leaves the maze"); }
        draw_set_color(_M.sync ? (_M.pAlive ? c_lime : c_red) : c_gray);
        draw_text(26, 6, _M.sync ? ("PARTNER " + (_M.pAlive ? string(round(point_distance(_mazeCam.x, _mazeCam.y, _M.px, _M.py) / 32)) + " m" : "CAUGHT")) : "partner not in this maze");
        draw_set_color(c_white);
    }
    // 0.8.3 (UX-S16-M2): ESC was refused because a dialog is open (see coop_pause_requested)
    if (coop_is_maze_room(room) && current_time - _M.pauseBlockAt < 2500)
    {
        var _pt = "Finish the dialog first, then ESC to pause both games", _pw2 = string_width(_pt) / 2 + 6;
        coop_ui_panel(_gw / 2 - _pw2, 26, _gw / 2 + _pw2, 41);
        draw_set_color(c_yellow); draw_set_halign(fa_center); draw_text(_gw / 2, 27, _pt); draw_set_halign(fa_left); draw_set_color(c_white);
    }
    if (room == SalvageResults && _M.waitShown)
    {
        draw_set_halign(fa_center); draw_set_color(c_yellow); draw_text(_gw / 2, 100, "Waiting for your partner to leave the maze..."); draw_set_halign(fa_left); draw_set_color(c_white);
    }
}


// ================= 0.7.3: sit / crouch in the 3D maze =================
// Patched into oCamera3DMaze Step: Crouching = (coop_maze_crouch(<original Sneak hold>) && no lock-on).
// C or Ctrl toggles sitting; the original held Sneak key still works. Uses the original crouch height / walls.
function coop_maze_crouch(_held)
{
    var _M = global.CoopM;
    if (!instance_exists(oTextBox) && (keyboard_check_pressed(ord("C")) || keyboard_check_pressed(vk_control)))
    {
        _M.botSitOn = false; // 0.7.7 (S9-3): a manual C/Ctrl takes over; the bot timer never cancels it
        coop_maze_set_sit(!_M.sit, "C/Ctrl");
    }
    // 0.7.7 (S9-3): the bot sit only starts once the maze room was entered (oCoopNet saw it) and has been up for 1 s,
    // the delay counts from that entry, and only the bot's own sit is ended by the bot.
    if (_M.botSit >= 0 && instance_exists(oCamera3DMaze) && coop_is_maze_room(room) && _M.mzRoom == room && current_time - _M.mzAt >= 1000)
    {
        var _sec = (current_time - _M.mzAt) / 1000;
        // 0.7.8 (S10-1): the game only crouches when nothing is locked on (LockOnTarget == -4) and C/Ctrl only works with no
        // dialog open; the maze opens with a dialog/lock-on, so the forced sit used to flip _M.sit while the pose (and the
        // "s" sent to the partner) stayed standing. The bot now waits for the same conditions and goes through coop_maze_set_sit.
        var _free = !instance_exists(oTextBox) && !instance_exists(oMinigameJumpscare) && oCamera3DMaze.LockOnTarget == -4;
        if (!_M.botSitDone && _sec >= max(1, _M.botSit))
        {
            if (!_free)
            {
                if (!_M.botSitWait) { _M.botSitWait = true; _M.botSitWaitAt = current_time; coop_log("bot: sit waits for dialog / lock-on to end"); }
                // like -coop-botlook (0.6.4): a dialog nobody closes (opening NPC) is closed 5 s later, bot flag only
                else if (instance_exists(oTextBox) && !instance_exists(oMinigameJumpscare) && current_time - _M.botSitWaitAt > 5000) { coop_log("bot: dialog still open -> closed for -coop-botsit"); with (oTextBox) { instance_destroy(); } _M.botSitWaitAt = current_time; }
            }
            else if (_M.sit) { _M.botSitDone = true; coop_log("bot: already sitting (manual), -coop-botsit skipped"); }
            else { _M.botSitDone = true; _M.botSitOn = true; _M.botSitUntil = current_time + 15000; coop_log("bot: FORCED sit for 15 s (-coop-botsit)"); coop_maze_set_sit(true, "bot"); }
        }
        else if (_M.botSitOn && current_time > _M.botSitUntil) { _M.botSitOn = false; coop_log("bot: stand up"); coop_maze_set_sit(false, "bot"); }
        if (_M.botSitDone && !_M.sitShot && current_time > _M.botSitUntil - 7000) { _M.sitShot = true; global.CoopMore.shotReq = "maze_sit"; global.CoopMore.shotAt = current_time; }
    }
    return _held || _M.sit;
}

// 0.7.8 (S10-1): the one path for every sit/stand (C/Ctrl and -coop-botsit): flag, log, and an immediate "mz" to the partner
function coop_maze_set_sit(_on, _why)
{
    var _M = global.CoopM;
    if (_M.sit == _on) { return; }
    _M.sit = _on;
    _M.lastSend = 0; // next coop_maze_step sends "mz" right away (s follows the real pose, see coop_maze_me_sitting)
    coop_log("MAZE: I " + (_on ? "sat down" : "stood up") + " (" + _why + ")");
}

function coop_maze_me_sitting()
{
    if (!instance_exists(oCamera3DMaze)) { return 0; }
    var _c = oCamera3DMaze;
    return (_c.HeightOffset < (_c.CustomHeight + _c.CustomSneakHeight) / 2) ? 1 : 0;
}

// ===== 0.7.3: maze salvage pick is shared WITHOUT the cutscene (partner gets the same animatronic + an icon top-right) =====
global.CoopSalv = { icon: -1, iconAt: 0, inN: 0, outN: 0 };
function coop_cfg_packet_safe() { return { t: "cfg", repel: global.CoopCfg.repel, revives: global.CoopCfg.revives, jd: global.CoopCfg.jd, bossShared: global.CoopCfg.bossShared, maze: global.CoopCfg.maze, specReward: global.CoopCfg.specReward, mask: global.CoopCfg.mask, cchar: global.CoopCfg.cchar, diff: -1 }; }
function coop_salv_out(_id)
{
    if (!global.Coop.connected || !coop_is_maze_room(room)) { return; }
    global.CoopSalv.outN++;
    coop_send({ t: "salv", id: _id });
    coop_log("SALV: I salvaged " + string(_id) + " -> partner gets it (no cutscene)");
}
function coop_salv_in(_m)
{
    var _id = real(_m.id);
    if (!variable_global_exists("SalvagesCurrent") || array_contains(global.SalvagesCurrent, _id)) { coop_log("SALV: partner salvaged " + string(_id) + " (already mine)"); return; }
    array_push(global.SalvagesCurrent, _id);
    array_push(global.AllTimeSalvages, _id);
    global.SalvageRecord[_id]++;
    with (oInteraction_Animatronic) { if (variable_instance_exists(id, "AnimatronicID") && AnimatronicID == _id) { Text = "Destroy"; } }
    global.CoopSalv.icon = _id; global.CoopSalv.iconAt = current_time; global.CoopSalv.inN++;
    coop_log("SALV: partner salvaged " + string(_id) + " -> added here silently (" + string(array_length(global.SalvagesCurrent)) + "/" + string(global.SalvageQuota) + ")");
}
function coop_salv_draw()
{
    var _S = global.CoopSalv;
    if (_S.icon < 0 || current_time - _S.iconAt > 6000 || !coop_is_maze_room(room)) { return; }
    var _gw = display_get_gui_width(), _t = "PARTNER SALVAGED  " + string(array_length(global.SalvagesCurrent)) + "/" + string(global.SalvageQuota);
    var _w = string_width(_t) + 12;
    var _py = 44; // 0.7.5: below the native money box; 0.7.7 (S9-5): text follows the box (was still at y=27, over the money box)
    coop_ui_panel(_gw - _w - 4, _py, _gw - 4, _py + 16);
    draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_color(make_color_rgb(244, 240, 232)); draw_text(_gw - _w + 2, _py + 2, _t); draw_set_color(c_white);
}

// ---------------- 0.7.4: custom characters ----------------
function coop_char_dir(_id) { return working_directory + "Addons/CoopChars/" + _id + "/"; }
function coop_char_list()
{
    var _l = [""];
    var _f = file_find_first(working_directory + "Addons/CoopChars/*", fa_directory);
    while (_f != "") { if (_f != "." && _f != ".." && file_exists(coop_char_dir(_f) + "portrait.png")) { array_push(_l, _f); } _f = file_find_next(); }
    file_find_close();
    return _l;
}
function coop_char_next(_cur, _partner)
{
    var _l = coop_char_list(), _n = array_length(_l), _i = 0;
    for (var k = 0; k < _n; k++) { if (_l[k] == _cur) { _i = k; } }
    for (var k = 1; k <= _n; k++) { var _c = _l[(_i + k) mod _n]; if (_c == "" || _c != _partner) { return _c; } }
    return "";
}

// 0.7.4 boss roles panel moved to CoopBoss (0.8.0: real role mechanics)
