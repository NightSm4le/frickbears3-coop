// Static checks on a built data.win (no game run).
using System; using System.Linq;
EnsureDataLoaded();
string stage = Environment.GetEnvironmentVariable("COOP_STAGE") ?? "full";
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
}
Console.WriteLine(bad.Count == 0 ? "VERIFY OK " + stage : "VERIFY FAIL: " + string.Join("; ", bad));
