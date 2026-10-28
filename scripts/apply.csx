// Applies the coop mod to a CLEAN data.win loaded by UndertaleModCli.
// Env: COOP_MOD_DIR (mod repo root), COOP_STAGE = noop | log | full
using System;
using System.IO;
using System.Linq;
using UndertaleModLib.Compiler;

EnsureDataLoaded();
string modDir = Environment.GetEnvironmentVariable("COOP_MOD_DIR");
string stage = Environment.GetEnvironmentVariable("COOP_STAGE") ?? "full";
if (modDir == null) throw new Exception("COOP_MOD_DIR not set");
Console.WriteLine($"[apply] stage={stage} game={Data.GeneralInfo.DisplayName.Content}");
if (stage == "noop") { Console.WriteLine("[apply] noop: resave only"); return; }

var dirs = new System.Collections.Generic.List<string> { Path.Combine(modDir, "gml", "boot") };
if (stage == "full") dirs.Add(Path.Combine(modDir, "gml", "coop"));

CodeImportGroup g = new(Data, null, Data.ToolInfo.DecompilerSettings) { AutoCreateAssets = true, ThrowOnNoOpFindReplace = true };
foreach (var d in dirs)
    foreach (var f in Directory.GetFiles(d, "*.gml").OrderBy(x => x))
    {
        g.QueueReplace(Path.GetFileNameWithoutExtension(f), File.ReadAllText(f));
        Console.WriteLine("[apply] queue " + Path.GetFileName(f));
    }

if (stage == "full")
{
    // spawn the persistent network object from the persistent game manager (StartupRoom)
    g.QueueAppend("gml_Object_oSuperGameManager_Create_0",
        "\nif (!instance_exists(oCoopNet)) { instance_create_depth(0, 0, -16000, oCoopNet); }\n");
    // client never writes progress saves (savedata / records / endless)
    foreach (var fn in new[] { "create_save", "save_permanent_data", "save_endless_data" })
    {
        string sig = fn == "save_endless_data" ? "function save_endless_data(arg0 = EndlessSelection, arg1 = true)\n{" : $"function {fn}()\n{{";
        g.QueueFindReplace("gml_GlobalScript_SaveData", sig, sig + "\n    if (coop_block_save(\"" + fn + "\")) { exit; }");
    }
    // host: report night win to the partner
    g.QueueFindReplace("gml_GlobalScript_SimpleScripts", "function win_night()\n{", "function win_night()\n{\n    coop_on_win_night();");
}

var res = g.Import();
Console.WriteLine("[apply] import done");

if (stage == "full")
{
    var o = Data.GameObjects.ByName("oCoopNet");
    if (o == null) throw new Exception("oCoopNet not created");
    o.Persistent = true;
    o.Visible = true;
    Console.WriteLine("[apply] oCoopNet persistent, events: " + string.Join(",", o.Events.Select((ev, i) => i + ":" + ev.Count)));
}
