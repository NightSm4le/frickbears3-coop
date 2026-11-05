// Static checks on a built data.win (no game run).
using System; using System.Linq;
EnsureDataLoaded();
string stage = Environment.GetEnvironmentVariable("COOP_STAGE") ?? "full";
bool adminCheats = Environment.GetEnvironmentVariable("COOP_CHEATS") == "1";
var bad = new System.Collections.Generic.List<string>();
void need(bool c, string m) { if (!c) bad.Add(m); }
need(Data.Code.ByName("gml_Object_oSuperGameManager_Create_0") != null, "SGM create missing");
if (stage != "noop") need(Data.Code.ByName("gml_GlobalScript_CoopBoot") != null, "CoopBoot missing");
if (stage == "full")
{
    var o = Data.GameObjects.ByName("oCoopNet");
    need(o != null && o.Persistent, "oCoopNet missing/not persistent");
    foreach (var n in new[] { "gml_GlobalScript_CoopNet", "gml_Object_oCoopNet_Create_0", "gml_Object_oCoopNet_Step_0", "gml_Object_oCoopNet_Other_68", "gml_Object_oCoopNet_Draw_75" })
        need(Data.Code.ByName(n) != null, n + " missing");
    var dec = new Underanalyzer.Decompiler.DecompileContext(new UndertaleModLib.Decompiler.GlobalDecompileContext(Data), Data.Code.ByName("gml_GlobalScript_SaveData"), Data.ToolInfo.DecompilerSettings).DecompileToString();
    need(dec.Split("coop_block_save").Length - 1 == 3, "save guards != 3");
    var sgm = new Underanalyzer.Decompiler.DecompileContext(new UndertaleModLib.Decompiler.GlobalDecompileContext(Data), Data.Code.ByName("gml_Object_oSuperGameManager_Create_0"), Data.ToolInfo.DecompilerSettings).DecompileToString();
    need(sgm.Contains("oCoopNet"), "spawn hook missing");
    foreach (var n in new[] { "gml_GlobalScript_CoopAnim", "gml_GlobalScript_CoopUI", "gml_Object_oCoopNet_Step_2" })
        need(Data.Code.ByName(n) != null, n + " missing");
    string D(string n) => new Underanalyzer.Decompiler.DecompileContext(new UndertaleModLib.Decompiler.GlobalDecompileContext(Data), Data.Code.ByName(n), Data.ToolInfo.DecompilerSettings).DecompileToString();
    var ss = D("gml_GlobalScript_SimpleScripts");
    need(ss.Contains("coop_jumpscare_gate(arg0)"), "jumpscare gate missing");
    need(ss.Contains("coop_on_block("), "block_tokens hook missing");
    need(ss.Contains("coop_on_occupy("), "occupy hook missing");
    need(D("gml_Object_oCamera_Step_0").Contains("coop_gen_extra()"), "generator hook missing");
    need(D("gml_Object_oTitleMenu_Create_0").Split("\"Co-op\"").Length - 1 >= 3, "title Co-op entries missing");
    need(D("gml_Object_oTitleMenu_Step_0").Contains("coop_title_select()"), "title select hook missing");
    foreach (var n in new[] { "gml_GlobalScript_CoopSpec", "gml_Object_oCoopNet_Step_1" })
        need(Data.Code.ByName(n) != null, n + " missing");
    need(ss.Contains("coop_spec_skip_count(arg0)"), "count_jumpscare spectator hook missing");
    need(D("gml_Object_oGameOver_Create_0").Contains("coop_spec_gameover_create()"), "GameOver create hook missing");
    need(D("gml_Object_oGameOver_Draw_0").Contains("CoopSpec"), "GameOver draw hook missing");
    need(D("gml_Object_oGameOver_CleanUp_0").Contains("CoopSpec"), "GameOver cleanup hook missing");
    need(D("gml_Object_oCoopNet_Other_68").Contains("coop_stream_on_frame"), "binary frame branch missing");
    var endlessPicker = D("gml_Object_oEndless_DifficultyPicker_Draw_0");
    need(endlessPicker.Contains("while (array_length(global.RunsAttempted) <= GuardID)") && endlessPicker.Contains("while (array_length(global.RunsWon) <= GuardID)"), "Endless custom-guard run-history bounds fix missing");
    // 0.5.0: co-op save redirect + features
    need(dec.Split("global.CoopSaveTag").Length - 1 >= 9, "co-op save tag not on every save file name");
    need(!dec.Contains("global.CurrentVersion + \".wario\"") && !dec.Contains("global.CurrentVersion + \".txt\""), "untagged save file name left");
    foreach (var n in new[] { "gml_GlobalScript_CoopFeat", "gml_GlobalScript_CoopIcons" })
        need(Data.Code.ByName(n) != null, n + " missing");
    var net = D("gml_GlobalScript_CoopNet");
    need(net.Split("coop_save_enter()").Length - 1 >= 2, "coop_save_enter not called from host+join");
    need(net.Contains("coop_feat_packet("), "feature packets not dispatched");
    need(net.Contains("case \"clockrewind\"") && net.Contains("function coop_clock_rewind()"), "Ultra Clock timer effect is not synchronized through the host");
    need(D("gml_Object_oShopItemUltra_Clock_Draw_77").Contains("coop_clock_rewind()"), "Ultra Clock use hook missing");
    need(net.Contains("client used Ultra Clock; host timer reset"), "host did not apply the client's Ultra Clock effect");
    var more = D("gml_GlobalScript_CoopMore");
    need(more.Contains("devmode") && more.Contains("Developer mode: "), "saved developer mode setting missing");
    need(more.Contains("var _g = global.CoopCfg;") && more.Contains("Co-op settings. Host decides for both;"), "Co-op Settings description scope guard missing");
    need(more.Contains("expected six 32x64 frames"), "custom co-op art validation missing");
    var spec = D("gml_GlobalScript_CoopSpec");
    need(spec.Contains("DEV STREAM") && spec.Contains("Frames received"), "spectator developer diagnostics missing");
    need(spec.Contains("budget: 512"), "spectator bandwidth budget missing");
    need(spec.Contains("level: 3") && spec.Contains("if (_inflight >= 2)"), "spectator stream is not rate-limited to protect control traffic");
    need(spec.Contains("1920, 1080") && spec.Contains("1280, 720"), "1080p adaptive spectator levels missing");
    need(spec.Contains("specgiveack") && spec.Contains("POWER USED"), "spectator once-per-night power assist missing");
    need(spec.Contains("Lure sent to partner; it only works on a nearby animatronic") && spec.Contains("L (partner)"), "L action purpose is unclear");
    need(!spec.Contains("keyboard_check_pressed(ord(\"H\"))") && !spec.Contains("\"H !\""), "H warning binding still exposed");
    var anim = D("gml_GlobalScript_CoopAnim");
    need(anim.Contains("no nearby target or the lure missed"), "L lure failure feedback missing");
    need(anim.Contains("attack token is reserved for partner") && anim.Contains("cancelled until host grants token"), "shared animatronic token race guards missing");
    need(anim.Contains("emergency claim at jumpscare gate") && anim.Contains("_a.granted[_id]") && anim.Contains("client is using host grant"), "jumpscare gate does not require and retain host token grant");
    need(anim.Contains("name: coop_anim_name(_a.lastKiller)") && anim.Contains("Partner killed by \" + _name"), "killer name is not preserved across clients");
    var sync = D("gml_GlobalScript_CoopSync");
    need(sync.Contains("tbreq") && sync.Contains("coop_tb_request(arg1)"), "host-authoritative dialogue input missing");
    need(sync.Contains("method(id, game_text)"), "dialogue branch does not bind game_text to its textbox");
    var moreChecks = D("gml_GlobalScript_CoopMore");
    need(moreChecks.Contains("SCRAPTRAP: ") && moreChecks.Contains("instance_find(oCamera3DMaze"), "shared task explanation or guarded maze HUD missing");
    var ui = D("gml_GlobalScript_CoopUI");
    need(ui.Contains("coop_draw_scene_participants") && (ui.Contains("P\" + string(_me)") || ui.Contains("PLAYER \" + string(_me)")), "co-op participants are not shown during story dialogs");
    need(ui.Contains("function coop_draw_night_participants()") && ui.Contains("coop_scene_mod_sprite(_otherName)"), "both players are not drawn on the night location card");
    need(ui.Contains("addons/") && ui.Contains("/selection.png") && ui.Contains("sprite_add(_path, 2"), "location card does not load a modded guard selection sprite");
    need(ui.Contains("string_pos(\"..\", arg0)") && ui.Contains("string_pos(\"\\\\\", arg0)"), "remote mod sprite path is not validated");
    need(ui.Contains(": \"SEATED\""), "co-op HUD does not indicate the partner is seated in the Office");
    need(net.Contains("_s.gn = guard_name(global.Guard)"), "partner guard name is not sent for mod sprite lookup");
    need(net.Contains("function coop_pause_packet") && net.Contains("t: \"pause\""), "synchronized pause protocol missing");
    need(net.Contains("array_create(_need, 0)") && net.Contains("while (array_length(global.Deaths) < _need)"), "Deaths array is not initialized for the selected character");
    need(ss.Contains("coop_prepare_night();\n    if (coop_spec_skip_count(arg0))"), "death path does not initialize the Deaths array");
    foreach (var n in new[] { "gml_Object_oPauser_Step_2", "gml_Object_oPersistentPauser_Step_2" })
    {
        var pz = D(n);
        need(pz.Contains("coop_pause_requested(") && pz.Contains("coop_pause_on_close()"), n + " pause sync hooks missing");
    }
    if (adminCheats)
    {
        need(Data.Code.ByName("gml_GlobalScript_CoopAdmin") != null, "admin cheats script missing");
        need(D("gml_Object_oCoopNet_Step_0").Contains("coop_admin_step()"), "admin cheats step hook missing");
        need(D("gml_Object_oCoopNet_Draw_75").Contains("coop_admin_draw()"), "admin cheats HUD hook missing");
        need(D("gml_Object_oCoopNet_Create_0").Contains("saveTagArg = \"_admin\""), "admin save slot is not isolated");
        need(D("gml_GlobalScript_CoopFeat").Contains("!coop_admin_save_active()"), "admin save slot is not retained");
        Console.WriteLine(bad.Count == 0 ? "VERIFY OK full-admin" : "VERIFY FAIL: " + string.Join("; ", bad));
        return;
    }
    need(Data.Code.ByName("gml_GlobalScript_CoopAdmin") == null, "admin cheats leaked into the standard build");
}
Console.WriteLine(bad.Count == 0 ? "VERIFY OK " + stage : "VERIFY FAIL: " + string.Join("; ", bad));
