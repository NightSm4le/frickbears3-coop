// ===== 0.8.0 (215-sync): host-authoritative story state =====
// The original reads story branches (dialogs, maze location, phone calls, endings) from LOCAL globals that come from
// each player's own save: Route, ShuffleMode/ShuffleData, Deaths, Guard, SalvagedMasks/Scraps/Minigames,
// UnlockFlags, UnlockedAnimatronics[128..], ClearedEndings, ShuffleCallsHeard. Different saves -> different text ->
// the textbox page sync keys no longer match -> the two players see different branches.
// Now the HOST's values are mirrored to the client (story nights 1..6 only):
//   * on connect (full), inside every night payload (full), and on every change (~0.5 s poll, changed fields only);
//   * the client re-applies the latest host state when it enters a story room (maze, cutscenes, endings).
// The client's OWN gains in the session (mask / scrap / minigame picked in its local maze, new unlock flags,
// endings) are sent up ("stup") and merged into the host (union), so nothing a player earns is lost.
// NOT synced on purpose: shop (RunEarnings, Upgrades, CCStory_* shop-story flags), maze-run state (SalvagesCurrent,
// MinigameCleared, HasGift), menu dialog paging. The client's permanent unlocks are kept: at save_permanent_data
// its own UnlockedAnimatronics/UnlockFlags/ClearedEndings/... are merged back (union) before the file is written.
global.CoopStory = { sig: "", pollAt: 0, last: undefined, base: undefined, own: undefined, pend: [], conn: false, inN: 0, outN: 0, upN: 0, applyN: 0, reapply: false, prevRoom: -1 };

function coop_story_g(_n) { return variable_global_exists(_n) ? variable_global_get(_n) : undefined; }
function coop_story_numnight() { return variable_global_exists("Night") && is_numeric(global.Night); }
function coop_story_local_flag(_f) { return is_string(_f) && string_pos("CCStory", _f) == 1; } // local shop story (by design)

// everything that decides a story branch (deep copies)
function coop_story_collect()
{
    var _s = { n: coop_story_g("Night") };
    var _ex = ["Route", "route", "ShuffleMode", "shm", "ShuffleData", "shd", "Deaths", "dth"];
    for (var i = 0; i < array_length(_ex); i += 2) { var _v = coop_story_g(_ex[i]); if (!is_undefined(_v)) { variable_struct_set(_s, _ex[i + 1], coop_story_copy(_v)); } }
    if (coop_story_numnight() && variable_global_exists("Guard")) { _s.g = global.Guard; }
    var _un = coop_story_union_names();
    for (var i = 0; i < array_length(_un); i += 2) { var _v = coop_story_g(_un[i]); if (is_array(_v)) { variable_struct_set(_s, _un[i + 1], coop_story_copy(_v)); } }
    if (variable_struct_exists(_s, "uf")) { var _f = []; for (var k = 0; k < array_length(_s.uf); k++) { if (!coop_story_local_flag(_s.uf[k])) { array_push(_f, _s.uf[k]); } } _s.uf = _f; }
    return _s;
}
// fields a player can GAIN in the session (merged up to the host)
function coop_story_union_names() { return ["UnlockFlags", "uf", "UnlockedAnimatronics", "ua", "UnlockedMinigames", "um", "SalvagedMasks", "sm", "SalvagedScraps", "ss", "SalvagedMinigames", "smg", "ClearedEndings", "ce", "ShuffleCallsHeard", "sch"]; }
function coop_story_perm_names() { return ["UnlockFlags", "uf", "UnlockedAnimatronics", "ua", "UnlockedMinigames", "um", "ClearedEndings", "ce", "ShuffleCallsHeard", "sch"]; }

// union of two arrays: numbers/bools element-wise max (nested too), strings as a set
function coop_story_merge(_a, _b)
{
    if (!is_array(_a)) { return _b; }
    if (!is_array(_b)) { return _a; }
    var _str = false;
    for (var i = 0; i < array_length(_a); i++) { if (is_string(_a[i])) { _str = true; break; } }
    for (var i = 0; i < array_length(_b) && !_str; i++) { if (is_string(_b[i])) { _str = true; } }
    var _r = [];
    if (_str)
    {
        array_copy(_r, 0, _a, 0, array_length(_a));
        for (var i = 0; i < array_length(_b); i++) { if (!array_contains(_r, _b[i])) { array_push(_r, _b[i]); } }
        return _r;
    }
    var _n = max(array_length(_a), array_length(_b));
    for (var i = 0; i < _n; i++)
    {
        var _x = (i < array_length(_a)) ? _a[i] : undefined, _y = (i < array_length(_b)) ? _b[i] : undefined;
        if (is_undefined(_x)) { _r[i] = _y; }
        else if (is_undefined(_y)) { _r[i] = _x; }
        else if (is_array(_x) || is_array(_y)) { _r[i] = coop_story_merge(_x, _y); }
        else if ((is_numeric(_x) || is_bool(_x)) && (is_numeric(_y) || is_bool(_y))) { _r[i] = (_y > _x) ? _y : _x; }
        else { _r[i] = _x; }
    }
    return _r;
}
function coop_story_copy(_v) { return is_array(_v) || is_struct(_v) ? json_parse(json_stringify(_v)) : _v; }

// client: apply host state. _full = every field, otherwise only fields that changed since the previous host packet
function coop_story_apply(_s, _full, _why)
{
    var _St = global.CoopStory;
    if (!coop_is_client() || !is_struct(_s)) { return; }
    var _prev = _St.last;
    _St.last = _s;
    if (!coop_story_numnight() || !is_numeric(variable_struct_get(_s, "n"))) { return; } // Custom / Endless / menus: own sync paths
    if (is_undefined(_St.own)) { _St.own = {}; var _pn = coop_story_perm_names(); for (var i = 0; i < array_length(_pn); i += 2) { var _v = coop_story_g(_pn[i]); if (is_array(_v)) { variable_struct_set(_St.own, _pn[i + 1], coop_story_copy(_v)); } } coop_log("STORY: kept my own permanent unlocks (merged back into my co-op save)"); }
    coop_story_push(); // my own fresh gains go up first, so the host copy below does not drop them
    var _map = ["route", "Route", "shm", "ShuffleMode", "shd", "ShuffleData", "dth", "Deaths", "g", "Guard", "uf", "UnlockFlags", "ua", "UnlockedAnimatronics", "um", "UnlockedMinigames", "sm", "SalvagedMasks", "ss", "SalvagedScraps", "smg", "SalvagedMinigames", "ce", "ClearedEndings", "sch", "ShuffleCallsHeard"];
    var _ch = "";
    for (var i = 0; i < array_length(_map); i += 2)
    {
        var _k = _map[i], _gn = _map[i + 1];
        if (!variable_struct_exists(_s, _k)) { continue; }
        var _v = variable_struct_get(_s, _k);
        if (!_full && is_struct(_prev) && variable_struct_exists(_prev, _k) && json_stringify(variable_struct_get(_prev, _k)) == json_stringify(_v)) { continue; }
        var _cur = coop_story_g(_gn);
        if (_k == "uf") { var _loc = []; if (is_array(_cur)) { for (var q = 0; q < array_length(_cur); q++) { if (coop_story_local_flag(_cur[q])) { array_push(_loc, _cur[q]); } } } _v = coop_story_merge(coop_story_copy(_v), _loc); }
        else if (_k == "ua" && is_array(_cur)) { _v = coop_story_copy(_v); for (var q = 0; q < min(128, array_length(_cur), array_length(_v)); q++) { _v[q] = _v[q] || _cur[q]; } } // [0..127] roster unlocks: union; [128..] story flags: host
        else if (_k == "um") { _v = coop_story_merge(coop_story_copy(_v), _cur); }
        else { _v = coop_story_copy(_v); }
        if (json_stringify(_cur) == json_stringify(_v)) { continue; }
        variable_global_set(_gn, _v);
        _ch += _gn + " ";
    }
    // gains that are still on their way to the host stay mine
    for (var i = array_length(_St.pend) - 1; i >= 0; i--)
    {
        var _p = _St.pend[i];
        if (current_time - _p.at > 4000) { array_delete(_St.pend, i, 1); continue; }
        var _gn = coop_story_gname(_p.k);
        if (_gn != "") { variable_global_set(_gn, coop_story_merge(coop_story_g(_gn), _p.v)); }
    }
    _St.base = coop_story_collect();
    _St.applyN++;
    if (_ch != "") { coop_log("STORY: " + _why + " -> from host: " + _ch); }
    else if (_full) { coop_log("STORY: " + _why + " -> already the same as the host"); }
}
function coop_story_gname(_k) { var _u = coop_story_union_names(); for (var i = 1; i < array_length(_u); i += 2) { if (_u[i] == _k) { return _u[i - 1]; } } return ""; }

// client: send what I gained myself since the last host state (maze mask/scrap/minigame, new flags, endings...)
function coop_story_push()
{
    var _St = global.CoopStory;
    if (!coop_is_client() || !global.Coop.connected || !is_struct(_St.base) || !coop_story_numnight()) { return; }
    var _cur = coop_story_collect(), _up = { t: "stup" }, _any = "";
    var _u = coop_story_union_names();
    for (var i = 1; i < array_length(_u); i += 2)
    {
        var _k = _u[i];
        if (!variable_struct_exists(_cur, _k)) { continue; }
        var _now = variable_struct_get(_cur, _k), _was = variable_struct_exists(_St.base, _k) ? variable_struct_get(_St.base, _k) : undefined;
        if (json_stringify(coop_story_merge(_was, _now)) == json_stringify(_was)) { continue; } // nothing new (a loss is never sent)
        variable_struct_set(_up, _k, _now);
        array_push(_St.pend, { k: _k, v: coop_story_copy(_now), at: current_time });
        if (is_struct(_St.own)) { variable_struct_set(_St.own, _k, coop_story_merge(variable_struct_exists(_St.own, _k) ? variable_struct_get(_St.own, _k) : undefined, _now)); }
        _any += _k + " ";
    }
    _St.base = _cur;
    if (_any != "") { coop_send(_up); _St.upN++; coop_log("STORY: my own progress -> host (" + _any + ")"); }
}

// host: merge the client's gains (union), the next poll sends the result back
function coop_story_merge_in(_m)
{
    if (!coop_is_host()) { return; }
    var _u = coop_story_union_names(), _got = "";
    for (var i = 0; i < array_length(_u); i += 2)
    {
        var _gn = _u[i], _k = _u[i + 1];
        if (!variable_struct_exists(_m, _k)) { continue; }
        var _v = variable_struct_get(_m, _k);
        if (_k == "uf" && is_array(_v)) { var _f = []; for (var q = 0; q < array_length(_v); q++) { if (!coop_story_local_flag(_v[q])) { array_push(_f, _v[q]); } } _v = _f; }
        var _cur = coop_story_g(_gn), _new = coop_story_merge(_cur, _v);
        if (json_stringify(_new) != json_stringify(_cur)) { variable_global_set(_gn, _new); _got += _gn + " "; }
    }
    coop_log("STORY: partner's own progress merged into the host" + (_got != "" ? ": " + _got : " (nothing new)"));
}

function coop_story_send(_full, _why)
{
    var _St = global.CoopStory;
    var _s = coop_story_collect();
    _St.sig = json_stringify(_s);
    coop_send({ t: "story", s: _s, full: _full, why: _why });
    _St.outN++;
    if (_full) { coop_log("STORY: host state -> partner (" + _why + ", " + string(variable_struct_exists(_s, "uf") ? array_length(_s.uf) : 0) + " flags, route " + string(variable_struct_exists(_s, "route") ? _s.route : "-") + ")"); }
}

// client: save_permanent_data writes my own unlocks back (union), then the host state is re-applied
function coop_story_save_merge(_what)
{
    var _St = global.CoopStory;
    if (!coop_is_client() || _what != "save_permanent_data" || !is_struct(_St.own)) { return; }
    var _pn = coop_story_perm_names(), _n = "";
    for (var i = 0; i < array_length(_pn); i += 2)
    {
        if (!variable_struct_exists(_St.own, _pn[i + 1])) { continue; }
        var _cur = coop_story_g(_pn[i]), _new = coop_story_merge(_cur, variable_struct_get(_St.own, _pn[i + 1]));
        if (json_stringify(_new) != json_stringify(_cur)) { variable_global_set(_pn[i], _new); _n += _pn[i] + " "; }
    }
    if (_n != "") { coop_log("STORY: save keeps my own unlocks too: " + _n); _St.reapply = true; _St.base = coop_story_collect(); } // not a gain: never sent up
}

function coop_story_packet(_t, _m)
{
    switch (_t)
    {
        case "story": global.CoopStory.inN++; coop_story_apply(_m.s, variable_struct_exists(_m, "full") && _m.full, "host " + string(variable_struct_exists(_m, "why") ? _m.why : "")); return true;
        case "stup": coop_story_merge_in(_m); return true;
        case "streq": if (coop_is_host()) { coop_story_send(true, "partner asked"); } return true;
    }
    return false;
}

// a room where a story branch is read (not menus / shop / office night start: those have their own sync)
function coop_story_room(_r)
{
    return _r != Office && _r != NightOpening && !coop_sync_is_menu(_r) && !instance_exists(oTitleMenu);
}

function coop_story_step()
{
    var _St = global.CoopStory, _c = global.Coop;
    if (!_c.connected) { _St.conn = false; _St.base = undefined; _St.pend = []; return; }
    if (coop_is_host())
    {
        if (!_St.conn) { _St.conn = true; coop_story_send(true, "connect"); }
        if (current_time - _St.pollAt > 500)
        {
            _St.pollAt = current_time;
            if (json_stringify(coop_story_collect()) != _St.sig) { coop_story_send(false, "change"); }
        }
        return;
    }
    // client
    if (!_St.conn) { _St.conn = true; coop_send({ t: "streq" }); }
    if (room != _St.prevRoom)
    {
        _St.prevRoom = room;
        if (is_struct(_St.last) && coop_story_room(room)) { coop_story_apply(_St.last, true, "entered " + room_get_name(room)); }
    }
    if (_St.reapply && is_struct(_St.last)) { _St.reapply = false; coop_story_apply(_St.last, true, "after my save"); }
    if (current_time - _St.pollAt > 500) { _St.pollAt = current_time; coop_story_push(); }
}
