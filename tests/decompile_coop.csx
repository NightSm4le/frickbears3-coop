// Dump decompiled coop entries for review (checks constants resolved, hooks placed).
using System; using System.IO; using System.Linq;
EnsureDataLoaded();
string outDir = Environment.GetEnvironmentVariable("COOP_DUMP") ?? "/tmp/coopdump";
Directory.CreateDirectory(outDir);
foreach (var c in Data.Code.Where(c => c.Name.Content.Contains("Coop") || c.Name.Content == "gml_GlobalScript_SaveData" || c.Name.Content == "gml_Object_oSuperGameManager_Create_0"))
{
    if (c.ParentEntry != null) continue;
    File.WriteAllText(Path.Combine(outDir, c.Name.Content + ".gml"), new Underanalyzer.Decompiler.DecompileContext(new UndertaleModLib.Decompiler.GlobalDecompileContext(Data), c, Data.ToolInfo.DecompilerSettings).DecompileToString());
}
Console.WriteLine("dumped to " + outDir);
