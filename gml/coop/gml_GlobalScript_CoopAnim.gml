// ===== Frickbear's Coop, stage 3: SHARED ANIMATRONICS =====
// Each player has an own office and own animatronic instances. An animatronic ID is "shared":
// only ONE player may be threatened by it at a time (attack token, host-arbitrated, 3 s timeout).
// Hooks (apply.csx): jumpscare() gate, block_tokens() -> repelled, occupy_doorway() log, power Usage += coop_gen_extra().

global.CoopA = {
    objOf: array_create(201, -1),
    ids: [],
    scanAt: -100000,
    tok: array_create(201, 0),      // host arbitration table: 0 free, 1 host, 2 client
    tokAt: array_create(201, 0),
    threat: array_create(201, false),
    pendAt: array_create(201, 0),   // client: claim sent at
    boostAmt: array_create(201, 0),
    boostUntil: array_create(201, 0),
    aggro: array_create(201, 0),
    alertText: "",
    alertAt: -100000,
    alertCol: c_yellow,
    doorSince: -1,
    myDc: 0,
    genExtra: 0,
    lureX: -99,
    lureY: -99,
    lureSentAt: -100000,
    lastKiller: -1,
    diedSent: false,
    repelChance: 50,
    lureChance: 50,
    st: { claims: 0, grants: 0, denies: 0, localDenies: 0, retreats: 0, timeouts: 0, repelledOut: 0, repelledIn: 0, redirectsOut: 0, redirectsIn: 0, luresOut: 0, luredIn: 0, lureHits: 0, diedOut: 0, aggro: 0, occupy: 0, jumpscares: 0, gateBlocks: 0, blocks: 0 }
};

function coop_anim_name(_id)
{
    if (_id >= 0 && variable_global_exists("Descriptions") && _id < array_length(global.Descriptions) && is_array(global.Descriptions[_id])) { return string(global.Descriptions[_id][0]); }
    return "#" + string(_id);
}

function coop_anim_build()
{
    var _a = global.CoopA;
    for (var i = 0; i < 201; i++)
    {
        _a.objOf[i] = -1;
        var _d = undefined;
        try { _d = get_animatronic_data(i); } catch (_e) { _d = undefined; }
        if (is_struct(_d) && variable_struct_exists(_d, "Object") && object_exists(_d.Object)) { _a.objOf[i] = _d.Object; }
    }
}

function coop_anim_inst(_id)
{
    var _o = global.CoopA.objOf[_id];
    if (_o < 0 || !instance_exists(_o)) { return noone; }
    return instance_find(_o, 0);
}

function coop_anim_kind(_i)
{
    if (_i == noone || !instance_exists(_i)) { return "none"; }
    if (object_is_ancestor(_i.object_index, oVentParent)) { return "vent"; }
    if (variable_instance_exists(_i, "Stage") && is_string(_i.Stage)) { return "stage"; }
    if (variable_instance_exists(_i, "Mode") && variable_instance_exists(_i, "Phase") && variable_instance_exists(_i, "WaitTime")) { return "foxy"; }
    return "other";
}

function coop_anim_id_of(_inst)
{
    if (variable_instance_exists(_inst, "ID") && is_numeric(_inst.ID)) { return _inst.ID; }
    var _a = global.CoopA;
    for (var i = 0; i < 201; i++) { if (_a.objOf[i] == _inst.object_index) { return i; } }
    return -1;
}

// new night in Office: reset per-night state, list who is present
function coop_anim_night_start()
{
    var _a = global.CoopA;
    if (_a.objOf[1] == -1) { coop_anim_build(); }
    for (var i = 0; i < 201; i++) { _a.tok[i] = 0; _a.threat[i] = false; _a.boostAmt[i] = 0; _a.aggro[i] = 0; _a.pendAt[i] = 0; }
    _a.doorSince = -1; _a.myDc = 0; _a.genExtra = 0; _a.lastKiller = -1; _a.diedSent = false;
    _a.lureX = variable_global_exists("AudioLureX") ? global.AudioLureX : -99;
    _a.lureY = variable_global_exists("AudioLureY") ? global.AudioLureY : -99;
    _a.scanAt = -100000;
    coop_anim_scan(true);
}

function coop_anim_scan(_verbose)
{
    var _a = global.CoopA;
    var _old = array_length(_a.ids);
    _a.ids = [];
    var _txt = "";
    for (var i = 0; i < 201; i++)
    {
        var _in = coop_anim_inst(i);
        if (_in == noone) { continue; }
        array_push(_a.ids, i);
        _txt += " " + coop_anim_name(i) + "(" + string(i) + "," + object_get_name(_in.object_index) + "," + coop_anim_kind(_in) + ",AI" + string(global.AILevels[i]) + ")";
    }
    _a.scanAt = current_time;
    if (_verbose || array_length(_a.ids) != _old) { coop_log("anim roster:" + _txt); }
}

function coop_anim_threat(_id)
{
    var _i = coop_anim_inst(_id);
    if (_i == noone) { return false; }
    var _k = coop_anim_kind(_i);
    if (_k == "vent") { return _i.Mode == "Office" || _i.Mode == "InOffice"; }
    if (_k == "stage") { return _i.Stage == "Doorway" || _i.Stage == "Kill" || _i.Stage == "Blocked"; }
    if (_k == "foxy") { return _i.Mode == "Run"; }
    return global.DoorOccupant[0] == _id || global.DoorOccupant[1] == _id;
}

// send this animatronic back to its start, without killing / scoring
function coop_anim_retreat(_id, _why)
{
    var _a = global.CoopA;
    var _i = coop_anim_inst(_id);
    if (_i == noone) { return false; }
    var _k = coop_anim_kind(_i);
    if (_k == "vent") { with (_i) { Mode = "Vents"; VentX = irandom_range(-2, 2); VentY = -1; Frame = 0; } }
    else if (_k == "stage")
    {
        with (_i)
        {
            Stage = "ShowStage"; Frame = 0;
            if (variable_instance_exists(id, "EyeSize")) { EyeSize = 0; }
            if (variable_instance_exists(id, "Growl") && !is_undefined(Growl) && audio_is_playing(Growl)) { audio_stop_sound(Growl); }
        }
    }
    else if (_k == "foxy") { with (_i) { Mode = "Wait"; Phase = 0; } }
    else { var _o = _i.object_index; instance_destroy(_i); instance_create_layer(0, 0, "Room", _o); }
    for (var s = 0; s < 2; s++) { if (global.DoorOccupant[s] == _id) { global.DoorOccupant[s] = -1; } }
    _a.threat[_id] = false;
    _a.st.retreats++;
    coop_log("retreat " + coop_anim_name(_id) + " (" + _k + "): " + _why);
    return true;
}

// make it come to this office soon (partner repelled it / vent redirect)
function coop_anim_advance(_id, _why)
{
    var _i = coop_anim_inst(_id);
    if (_i == noone) { coop_log("advance " + coop_anim_name(_id) + ": not in my roster (" + _why + ")"); return false; }
    if (global.AILevels[_id] <= 0) { coop_anim_boost(_id, 5, 60000, "inactive here, woken by " + _why); }
    var _k = coop_anim_kind(_i);
    var _from = "";
    if (_k == "vent") { with (_i) { _from = Mode + " y" + string(VentY); if (Mode == "Vents") { VentY = max(VentY, 1); if (VentX == 0) { VentX = choose(-1, 1); } Frame = 0; } } }
    else if (_k == "stage") { with (_i) { _from = Stage; if (Stage == "ShowStage" || Stage == "TransitionA" || Stage == "DiningArea" || Stage == "TransitionB") { Stage = "Hallway"; Frame = 0; } } }
    else if (_k == "foxy") { with (_i) { _from = Mode + " " + string(Phase); if (Mode == "Wait") { Phase = max(Phase, WaitTime - 5); } } }
    else { coop_anim_boost(_id, 5, 60000, _why); }
    coop_log("advance " + coop_anim_name(_id) + " (" + _k + ", was " + _from + "): " + _why);
    return true;
}

function coop_anim_boost(_id, _amt, _ms, _why)
{
    var _a = global.CoopA;
    var _add = clamp(20 - global.AILevels[_id], 0, _amt);
    _a.boostAmt[_id] += _add;
    global.AILevels[_id] += _add;
    _a.boostUntil[_id] = current_time + _ms;
    coop_log("AI boost " + coop_anim_name(_id) + " +" + string(_add) + " for " + string(_ms div 1000) + "s -> " + string(global.AILevels[_id]) + " (" + _why + ")");
}

function coop_alert(_txt, _col, _snd)
{
    var _a = global.CoopA;
    _a.alertText = _txt; _a.alertAt = current_time; _a.alertCol = _col;
    if (_snd != undefined) { audio_play_sound(_snd, 10, false); }
    coop_log("ALERT " + _txt);
}

function coop_partner_fresh()
{
    var _c = global.Coop;
    return _c.connected && current_time - _c.partnerSnapAt < 3000 && coop_partner_get("rm", "") == "Office" && coop_partner_get("alive", false);
}

function coop_partner_holds(_id)
{
    var _c = global.Coop, _a = global.CoopA;
    if (!_c.connected) { return false; }
    if (coop_is_host()) { return _a.tok[_id] == 2 && current_time - _a.tokAt[_id] < 3000; }
    if (current_time - _c.partnerSnapAt > 3000) { return false; }
    var _tk = coop_partner_get("tk", []);
    if (!is_array(_tk)) { return false; }
    for (var i = 0; i < array_length(_tk); i++) { if (_tk[i] == _id) { return true; } }
    return false;
}

function coop_anim_held_list()
{
    var _a = global.CoopA, _r = [];
    for (var i = 0; i < array_length(_a.ids); i++) { if (_a.threat[_a.ids[i]]) { array_push(_r, _a.ids[i]); } }
    return _r;
}

// ---- per-frame (oCoopNet Step) ----
function coop_anim_step()
{
    var _c = global.Coop, _a = global.CoopA;
    if (room != Office || !variable_global_exists("AILevels")) { return; }
    if (current_time - _a.scanAt > 2000) { coop_anim_scan(false); }
    var _alive = coop_alive();
    // host: client tokens expire (even if I am dying / link silent) if not refreshed by its snapshots
    if (coop_is_host())
    {
        for (var i = 0; i < 201; i++)
        {
            if (_a.tok[i] == 2 && current_time - _a.tokAt[i] > 3000)
            {
                _a.tok[i] = 0; _a.st.timeouts++;
                coop_log("token: TIMEOUT " + coop_anim_name(i) + " (client silent > 3s), released");
            }
        }
    }
    if (_c.connected && _alive)
    {
        var _pf = coop_partner_fresh();
        for (var n = 0; n < array_length(_a.ids); n++)
        {
            var _id = _a.ids[n];
            var _t = coop_anim_threat(_id);
            if (_t && !_a.threat[_id])
            {
                if (coop_partner_holds(_id))
                {
                    _a.st.localDenies++;
                    coop_log("token: " + coop_anim_name(_id) + " busy at partner -> deny here");
                    coop_anim_retreat(_id, "token held by partner");
                    _t = false;
                }
                else if (coop_anim_kind(coop_anim_inst(_id)) == "vent" && global.CamUp && _pf && coop_partner_get("cu", 1) == 0)
                {
                    // vent crawler picks the office whose guard is NOT on cameras
                    _a.st.redirectsOut++;
                    coop_send({ t: "redirect", id: _id });
                    coop_anim_retreat(_id, "redirected to partner (I am on cams, partner is not)");
                    _t = false;
                }
                else if (coop_is_host())
                {
                    _a.tok[_id] = 1; _a.tokAt[_id] = current_time;
                    coop_log("token: host takes " + coop_anim_name(_id));
                }
                else
                {
                    _a.st.claims++; _a.pendAt[_id] = current_time;
                    coop_send({ t: "claim", id: _id });
                    coop_log("token: claim " + coop_anim_name(_id));
                }
            }
            else if (!_t && _a.threat[_id])
            {
                if (coop_is_host()) { if (_a.tok[_id] == 1) { _a.tok[_id] = 0; } }
                else { coop_send({ t: "release", id: _id }); }
                coop_log("token: release " + coop_anim_name(_id));
            }
            if (_t && coop_is_host()) { _a.tok[_id] = 1; _a.tokAt[_id] = current_time; }
            _a.threat[_id] = _t;
        }
        // lure: my audio lure changed -> offer it to the partner office too
        if (variable_global_exists("AudioLureX") && (global.AudioLureX != _a.lureX || global.AudioLureY != _a.lureY))
        {
            _a.lureX = global.AudioLureX; _a.lureY = global.AudioLureY;
            if (_a.lureX != -99 && current_time - _a.lureSentAt > 15000 && _pf)
            {
                _a.lureSentAt = current_time; _a.st.luresOut++;
                coop_send({ t: "lure", x: _a.lureX, y: _a.lureY });
                coop_log("lure: played at " + string(_a.lureX) + "," + string(_a.lureY) + " -> offered to partner");
            }
        }
    }
    // death report (once): who killed me
    if (!_alive && !_a.diedSent && _c.connected)
    {
        _a.diedSent = true; _a.st.diedOut++;
        coop_send({ t: "died", id: _a.lastKiller });
        coop_log("died: killed by " + coop_anim_name(_a.lastKiller));
    }
    // generator: doors closed for a long time load the SHARED generator
    if (global.Doors[0] || global.Doors[1]) { if (_a.doorSince < 0) { _a.doorSince = current_time; } _a.myDc = (current_time - _a.doorSince) / 1000; }
    else { _a.doorSince = -1; _a.myDc = 0; }
    // boosts expire
    for (var n = 0; n < array_length(_a.ids); n++)
    {
        var _b = _a.ids[n];
        if (_a.boostAmt[_b] > 0 && current_time > _a.boostUntil[_b])
        {
            global.AILevels[_b] = max(0, global.AILevels[_b] - _a.boostAmt[_b]);
            coop_log("AI boost over " + coop_anim_name(_b) + " -> " + string(global.AILevels[_b]));
            _a.boostAmt[_b] = 0;
        }
    }
}

// leaving the office: undo temporary AI changes
function coop_anim_night_end()
{
    var _a = global.CoopA;
    for (var i = 0; i < 201; i++)
    {
        var _d = _a.boostAmt[i] + _a.aggro[i];
        if (_d > 0 && variable_global_exists("AILevels")) { global.AILevels[i] = max(0, global.AILevels[i] - _d); }
        _a.boostAmt[i] = 0; _a.aggro[i] = 0; _a.tok[i] = 0; _a.threat[i] = false;
    }
    coop_log("anim stats: " + json_stringify(_a.st));
}

function coop_gen_extra()
{
    if (!coop_active() || !global.Coop.connected) { return 0; }
    var _a = global.CoopA;
    var _x = 0;
    var _pdc = (current_time - global.Coop.partnerSnapAt < 3000) ? coop_partner_get("dc", 0) : 0;
    if (_a.myDc > 15) { _x += 0.25; }
    if (_pdc > 15) { _x += 0.25; }
    if (_x != _a.genExtra)
    {
        coop_log("generator: shared extra load " + string(_a.genExtra) + " -> " + string(_x) + " (my doors closed " + string(floor(_a.myDc)) + "s, partner " + string(floor(_pdc)) + "s)");
        _a.genExtra = _x;
    }
    return _x + coop_help_usage_comp();
}

// ---- hooks ----
function coop_jumpscare_gate(_id)
{
    if (!coop_active() || !global.Coop.connected || room != Office || !is_numeric(_id) || _id < 0 || _id > 200) { return false; }
    var _a = global.CoopA;
    if (global.CoopF.forceJs) { _a.lastKiller = _id; coop_log("jumpscare(" + coop_anim_name(_id) + ") forced (joint door event)"); return false; }
    if (current_time < global.CoopF.invulUntil)
    {
        coop_log("GATE: jumpscare by " + coop_anim_name(_id) + " cancelled - revived player is invulnerable");
        coop_anim_retreat(_id, "revive invulnerability");
        return true;
    }
    _a.st.jumpscares++;
    if (coop_partner_holds(_id))
    {
        _a.st.gateBlocks++;
        coop_log("GATE: jumpscare by " + coop_anim_name(_id) + " cancelled - token is at partner");
        coop_anim_retreat(_id, "jumpscare gate");
        return true;
    }
    _a.lastKiller = _id;
    coop_log("jumpscare(" + coop_anim_name(_id) + ") passes gate");
    return false;
}

function coop_on_occupy(_id, _side)
{
    if (!coop_active()) { return; }
    var _a = global.CoopA;
    _a.st.occupy++;
    if (_a.st.occupy <= 40) { coop_log("occupy_doorway(" + coop_anim_name(_id) + ", side " + string(_side) + ")"); }
}

function coop_on_block(_inst)
{
    if (!coop_active() || room != Office) { return; }
    var _a = global.CoopA;
    var _id = -1;
    try { _id = coop_anim_id_of(_inst); } catch (_e) { _id = -1; }
    _a.st.blocks++; global.CoopF.sc.rep++;
    coop_log("block_tokens by " + coop_anim_name(_id));
    if (_id < 0 || !coop_partner_fresh()) { return; }
    if (irandom(99) < _a.repelChance)
    {
        _a.st.repelledOut++;
        coop_send({ t: "repelled", id: _id });
        coop_log("repelled " + coop_anim_name(_id) + " -> runs to partner");
    }
}

// ---- packets (returns true when handled) ----
function coop_anim_packet(_t, _m)
{
    var _c = global.Coop, _a = global.CoopA;
    var _id = variable_struct_exists(_m, "id") ? _m.id : -1;
    switch (_t)
    {
        case "claim": // host
            if (_a.tok[_id] == 1 && _a.threat[_id]) { _a.st.denies++; coop_send({ t: "deny", id: _id }); coop_log("token: DENY client " + coop_anim_name(_id) + " (host holds)"); }
            else { _a.st.grants++; _a.tok[_id] = 2; _a.tokAt[_id] = current_time; coop_send({ t: "grant", id: _id }); coop_log("token: GRANT client " + coop_anim_name(_id)); }
            return true;
        case "release": // host
            if (_a.tok[_id] == 2) { _a.tok[_id] = 0; coop_log("token: client released " + coop_anim_name(_id)); }
            return true;
        case "grant": // client
            _a.pendAt[_id] = 0;
            coop_log("token: granted " + coop_anim_name(_id));
            return true;
        case "deny": // client
            _a.pendAt[_id] = 0;
            coop_log("token: denied " + coop_anim_name(_id));
            if (room == Office && _a.threat[_id]) { coop_anim_retreat(_id, "host denied token"); }
            return true;
        case "repelled":
            _a.st.repelledIn++;
            if (room == Office && coop_alive())
            {
                coop_alert(string_upper(coop_anim_name(_id)) + " -> YOU! (repelled by partner)", c_red, sfxError);
                coop_anim_advance(_id, "repelled by partner");
            }
            return true;
        case "redirect":
            _a.st.redirectsIn++;
            if (room == Office && coop_alive())
            {
                coop_alert(string_upper(coop_anim_name(_id)) + " crawls to YOU (vents)", c_red, sfxError);
                coop_anim_advance(_id, "vent redirect from partner");
            }
            return true;
        case "lure":
            _a.st.luredIn++;
            if (room != Office || !coop_alive()) { return true; }
            var _best = -1;
            for (var n = 0; n < array_length(_a.ids); n++)
            {
                var _i = coop_anim_inst(_a.ids[n]);
                var _k = coop_anim_kind(_i), _near = false;
                if (_k == "stage") { _near = _i.Stage == "Hallway" || _i.Stage == "TransitionC" || _i.Stage == "Doorway"; }
                else if (_k == "vent") { _near = _i.Mode != "Vents" || _i.VentY >= 1; }
                else if (_k == "foxy") { _near = _i.Mode == "Run" || _i.Phase > _i.WaitTime * 0.6; }
                if (_near) { _best = _a.ids[n]; break; }
            }
            if (_best >= 0 && irandom(99) < _a.lureChance)
            {
                _a.st.lureHits++;
                coop_anim_retreat(_best, "lured away by partner's audio lure");
                coop_alert("Partner's lure pulled " + coop_anim_name(_best) + " away", c_lime, sfxBitCollect);
                coop_send({ t: "lured", id: _best });
            }
            else { coop_log("lure from partner: no effect (candidate " + coop_anim_name(_best) + ")"); coop_send({ t: "lured", id: -1 }); }
            return true;
        case "lured":
            if (_id >= 0)
            {
                global.CoopF.rlureHit = true; coop_log("LURE PROOF: partner reports my lure pulled " + coop_anim_name(_id)); coop_log("SHOT lure_proof");
                coop_alert("Your lure pulled " + coop_anim_name(_id) + " from partner!", c_lime, sfxBitCollect);
                if (room == Office && coop_anim_inst(_id) != noone) { coop_anim_boost(_id, 3, 30000, "came for my lure"); }
            }
            else { coop_log("my lure had no effect at partner"); }
            return true;
        case "died":
            coop_log("partner died, killer " + coop_anim_name(_id));
            if (room == Office && coop_alive() && _id >= 0 && coop_anim_inst(_id) != noone)
            {
                var _add = clamp(20 - global.AILevels[_id], 0, 5);
                _a.aggro[_id] += _add; global.AILevels[_id] += _add; _a.st.aggro++;
                coop_alert("Partner killed by " + coop_anim_name(_id) + "! It is hungrier (AI " + string(global.AILevels[_id]) + ")", c_red, sfxError);
            }
            else if (room == Office && coop_alive()) { coop_alert("Partner died (" + coop_anim_name(_id) + ")", c_red, sfxError); }
            return true;
    }
    return false;
}
