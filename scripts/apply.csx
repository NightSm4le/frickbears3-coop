// Applies the coop mod to a CLEAN data.win loaded by UndertaleModCli.
// Env: COOP_MOD_DIR (mod repo root), COOP_STAGE = noop | log | full, COOP_CHEATS = 0 | 1
using System;
using System.IO;
using System.Linq;
using UndertaleModLib.Compiler;

EnsureDataLoaded();
string modDir = Environment.GetEnvironmentVariable("COOP_MOD_DIR");
string stage = Environment.GetEnvironmentVariable("COOP_STAGE") ?? "full";
bool adminCheats = Environment.GetEnvironmentVariable("COOP_CHEATS") == "1";
if (modDir == null) throw new Exception("COOP_MOD_DIR not set");
Console.WriteLine($"[apply] stage={stage} adminCheats={adminCheats} game={Data.GeneralInfo.DisplayName.Content}");
if (stage == "noop") { Console.WriteLine("[apply] noop: resave only"); return; }

var dirs = new System.Collections.Generic.List<string> { Path.Combine(modDir, "gml", "boot") };
if (stage == "full") dirs.Add(Path.Combine(modDir, "gml", "coop"));
if (stage == "full" && adminCheats) dirs.Add(Path.Combine(modDir, "gml", "admin"));

// v2.1.5 changed several vanilla code bodies; verify the resulting hooks with tests/verify.csx
// instead of aborting on the first optional legacy replacement that no longer matches.
CodeImportGroup g = new(Data, null, Data.ToolInfo.DecompilerSettings) { AutoCreateAssets = true, ThrowOnNoOpFindReplace = false };
foreach (var d in dirs)
    foreach (var f in Directory.GetFiles(d, "*.gml").OrderBy(x => x))
    {
        g.QueueReplace(Path.GetFileNameWithoutExtension(f), File.ReadAllText(f));
        Console.WriteLine("[apply] queue " + Path.GetFileName(f));
    }

if (stage == "full")
{
    if (adminCheats)
    {
        g.QueueFindReplace("gml_Object_oCoopNet_Create_0", "coop_parse_args();",
            "global.CoopF.saveTagArg = \"_admin\";\ncoop_parse_args();");
        g.QueueAppend("gml_Object_oCoopNet_Step_0", "\ncoop_admin_step();\n");
        g.QueueAppend("gml_Object_oCoopNet_Draw_75", "\ncoop_admin_draw();\n");
    }
    // spawn the persistent network object from the persistent game manager (StartupRoom)
    g.QueueAppend("gml_Object_oSuperGameManager_Create_0",
        "\nif (!instance_exists(oCoopNet)) { instance_create_depth(0, 0, -10000, oCoopNet); }\n");
    // client never writes progress saves (savedata / records / endless)
    foreach (var fn in new[] { "create_save", "save_permanent_data", "save_endless_data" })
    {
        string sig = fn == "save_endless_data" ? "function save_endless_data(arg0 = EndlessSelection, arg1 = true)\n{" : $"function {fn}()\n{{";
        g.QueueFindReplace("gml_GlobalScript_SaveData", sig, sig + "\n    if (coop_block_save(\"" + fn + "\")) { exit; }");
    }
    // 0.5.0 co-op saves: every save file name gets global.CoopSaveTag ("" normally, "_coop" in co-op)
    foreach (var bn in new[] { "\"savedata\" + global.CurrentVersion + \".wario\"", "\"records\" + global.CurrentVersion + \".wario\"", "\"endlessdata\" + global.CurrentVersion + \".txt\"" })
    {
        string ext = bn.Contains(".txt") ? "\".txt\"" : "\".wario\"";
        string head = bn.Substring(0, bn.Length - ext.Length);
        g.QueueFindReplace("gml_GlobalScript_SaveData", bn, head + "(variable_global_exists(\"CoopSaveTag\") ? global.CoopSaveTag : \"\") + " + ext);
    }
    // pausers: no auto-pause on focus loss during coop, keep networking alive, and synchronize explicit pause/resume.
    foreach (var pz in new[] { "gml_Object_oPauser_Step_2", "gml_Object_oPersistentPauser_Step_2" })
    {
        g.QueueFindReplace(pz, "|| !window_has_focus())", "|| (!window_has_focus() && !coop_active()))");
        g.QueueFindReplace(pz, "instance_activate_object(oSuperGameManager);", "instance_activate_object(oSuperGameManager);\n    instance_activate_object(oCoopNet);");
        g.QueueFindReplace(pz, "input_check_pressed(UnknownEnum.Value_1) && !Cooldown",
            "(input_check_pressed(UnknownEnum.Value_1) && !Cooldown) || coop_pause_requested()");
        g.QueueFindReplace(pz, "    Paused = true;", "    coop_pause_on_open();\n    Paused = true;");
        g.QueueFindReplace(pz, "    Paused = false;", "    coop_pause_on_close();\n    Paused = false;");
    }
    // host: report night win to the partner
    g.QueueFindReplace("gml_GlobalScript_SimpleScripts", "function win_night()\n{", "function win_night()\n{\n    coop_on_win_night();");
    // Ultra Clock is used locally; ask the host to apply the same fixed timer reset before its next clock sync.
    g.QueueFindReplace("gml_Object_oShopItemUltra_Clock_Draw_77",
        "global.Timer = 360 - (360 / global.NightSpeedup);", "coop_clock_rewind();");
    // Endless picker can select custom guard 21; extend both history arrays before indexing it.
    g.QueueFindReplace("gml_Object_oEndless_DifficultyPicker_Draw_0",
        "if (GuardID >= array_length(global.RunsAttempted))\n            {\n                for (var g = 21; g < 22; g++)\n                {\n                    for (var d = 0; d < 5; d++)\n                    {\n                        global.RunsAttempted[g][d] = 0;\n                        global.RunsWon[g][d] = 0;\n                    }\n                }\n            }",
        "while (array_length(global.RunsAttempted) <= GuardID) { array_push(global.RunsAttempted, array_create(5, 0)); }\n            while (array_length(global.RunsWon) <= GuardID) { array_push(global.RunsWon, array_create(5, 0)); }");
    // 0.6.0: maze co-op (host decides catches, enemy hunts the nearest living player), partner purchases
    g.QueueFindReplace("gml_Object_oMazeEnemy_Step_0", "if (place_meeting(x, y, Player))\n{\n    var NearestPoint = self;", "if (coop_maze_hit())\n{\n    var NearestPoint = self;");
    g.QueueFindReplace("gml_Object_oSalvageSheet_Create_0", "if (room == SalvageResults)\n{\n    global.Night++;", "if (room == SalvageResults && !coop_maze_hold())\n{\n    global.Night++;");
    g.QueueFindReplace("gml_GlobalScript_UpgradeData", "function acquire_upgrade(arg0)\n{", "function acquire_upgrade(arg0)\n{\n    try { coop_on_upgrade(arg0); } catch (_coopErr) { }");
    // stage 3: shared animatronics
    g.QueueFindReplace("gml_GlobalScript_SimpleScripts", "function jumpscare(arg0, arg1 = 0, arg2 = 0, arg3 = true, arg4 = true)\n{",
        "function jumpscare(arg0, arg1 = 0, arg2 = 0, arg3 = true, arg4 = true)\n{\n    if (coop_jumpscare_gate(arg0)) { exit; }");
    g.QueueFindReplace("gml_GlobalScript_SimpleScripts", "function block_tokens(arg0 = 1)\n{",
        "function block_tokens(arg0 = 1)\n{\n    try { coop_on_block(id); } catch (_coopErr) { }");
    g.QueueFindReplace("gml_GlobalScript_SimpleScripts", "function occupy_doorway(arg0, arg1)\n{",
        "function occupy_doorway(arg0, arg1)\n{\n    coop_on_occupy(arg0, arg1);");
    g.QueueFindReplace("gml_Object_oCamera_Step_0", "Usage = global.CamUp + global.Doors[0] + global.Doors[1] + global.Flashlight + global.Fan;",
        "Usage = global.CamUp + global.Doors[0] + global.Doors[1] + global.Flashlight + global.Fan + coop_gen_extra();");
    // stage 4: spectator - a coop death while the partner lives is not counted and GameOver becomes the spectator view
    g.QueueFindReplace("gml_GlobalScript_SimpleScripts", "function count_jumpscare(arg0)\n{",
        "function count_jumpscare(arg0)\n{\n    coop_prepare_night();\n    if (coop_spec_skip_count(arg0)) { exit; }");
    g.QueueFindReplace("gml_Object_oGameOver_Create_0", "Frame = 0;\nAlpha = 0;\nVoiceLineID = -1;",
        "if (coop_spec_gameover_create()) { CoopSpec = true; exit; }\nFrame = 0;\nAlpha = 0;\nVoiceLineID = -1;");
    g.QueueFindReplace("gml_Object_oGameOver_Draw_0", "if (global.Jumpscare == -1)\n{\n    draw_sprite_ext(sJumpscareDeathscreen",
        "if (variable_instance_exists(id, \"CoopSpec\")) { exit; }\nif (global.Jumpscare == -1)\n{\n    draw_sprite_ext(sJumpscareDeathscreen");
    g.QueueFindReplace("gml_Object_oGameOver_CleanUp_0", "texturegroup_unload(\"DeathScreen\");",
        "if (variable_instance_exists(id, \"CoopSpec\")) { exit; }\ntexturegroup_unload(\"DeathScreen\");");
    // title menu: real "Co-op" entry before "Quit Game" + its own screen, rendered by the game's own menu code
    g.QueueFindReplace("gml_Object_oTitleMenu_Create_0", "array_push(CurrentOptions, \"Quit Game\");",
        "array_push(CurrentOptions, \"Co-op\");\n                array_push(CurrentOptions, \"Quit Game\");");
    g.QueueFindReplace("gml_Object_oTitleMenu_Create_0", "case \"Null\":",
        "case \"Co-op Settings\":\n            CurrentOptions = coop_set_options();\n            CurrentDesc = coop_set_desc();\n            break;\n        case \"Co-op\":\n            CurrentOptions = coop_title_options();\n            CurrentDesc = coop_title_desc();\n            break;\n        case \"Null\":");
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "var Selection = CurrentOptions[SelectedOption];",
        "var Selection = CurrentOptions[SelectedOption];\n    if (CurMenu == \"Co-op\") { Selection = \"__coop\"; }\n    if (CurMenu == \"Co-op Settings\") { Selection = \"__coopset\"; }");
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "case \"Back\":",
        "case \"__coopset\":\n            coop_set_select();\n            break;\n        case \"__coop\":\n            coop_title_select();\n            break;\n        case \"Co-op\":\n            goto_menu(\"Co-op\", 0);\n            break;\n        case \"Back\":");
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "if (input_check_pressed(UnknownEnum.Value_1) && !Transitioning && CurMenu != \"Remap In Progress\")",
        "if (CurMenu == \"Co-op Settings\" && input_check_pressed(UnknownEnum.Value_1) && !Transitioning)\n{\n    audio_play_sound(sfxBump, 5, false);\n    coop_set_back();\n    input_clear(UnknownEnum.Value_1);\n}\nelse if (CurMenu == \"Co-op\" && input_check_pressed(UnknownEnum.Value_1) && !Transitioning)\n{\n    audio_play_sound(sfxBump, 5, false);\n    coop_title_back();\n    input_clear(UnknownEnum.Value_1);\n}\nif (input_check_pressed(UnknownEnum.Value_1) && !Transitioning && CurMenu != \"Remap In Progress\")");
    // 0.6.1 synced start: whoever starts, the partner starts the same thing (see CoopSync)
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "function new_game(arg0)\n{\n    save_permanent_data();", "function new_game(arg0)\n{\n    coop_sync_menu(\"new\", arg0);\n    save_permanent_data();");
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "RoomDestination = global.StartRoom;", "RoomDestination = global.StartRoom;\n            coop_sync_menu(\"cont\", 0);");
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "case \"Quit to Menu\":\n            Transitioning = true;", "case \"Quit to Menu\":\n            Transitioning = true;\n            coop_sync_menu(\"quit\", 0);");
    g.QueueFindReplace("gml_Object_oTitleMenu_Step_0", "if (TransitionFrame >= 60)\n{", "if (Transitioning && TransitionFrame == 1)\n{\n    coop_sync_menu(\"room\", RoomDestination);\n}\nif (TransitionFrame >= 60)\n{");
    // 0.6.2: no "RAGE: n" stdout spam every frame; Phone Guy subtitles centred on the camera feed while the monitor is up (not over the cam map)
    g.QueueFindReplace("gml_Object_oHappyFrog_Draw_77", "show_debug_message($\"RAGE: {KillTimer}\");", "// 0.6.2: RAGE debug print removed");
    g.QueueFindReplace("gml_Object_oPhoneGuy_Draw_77", "draw_text_ext(320 + round(lengthdir_x(1, FontDirection)), 300 + round(lengthdir_y(1, FontDirection)), Text, 15, 400);", "draw_text_ext(coop_sub_x() + round(lengthdir_x(1, FontDirection)), 300 + round(lengthdir_y(1, FontDirection)), Text, 15, coop_sub_w());");
    g.QueueFindReplace("gml_Object_oPhoneGuy_Draw_77", "draw_text_ext(320, 300, Text, 15, 400);", "draw_text_ext(coop_sub_x(), 300, Text, 15, coop_sub_w());");
    // 0.6.3: Fredbear microgames - host picks the microgame, shared lives
    g.QueueFindReplace("gml_Object_oFredbearManager_Draw_73", "Frame += global.MicrogameSpeed;", "Frame += coop_fb_frame_step(WaitTime);");
    g.QueueFindReplace("gml_Object_oFredbearManager_Draw_73", "        Lives--;\n        FailMode = true;", "        coop_fb_fail();");
    // 0.6.4: night-number guard for the music list (S3-1) and Clark's letter page sync (S3-5)
    g.QueueFindReplace("gml_Object_oCamera_Create_0", "SongID = MusicList[global.Night - 1];", "SongID = MusicList[coop_s4_music_idx(global.Night - 1, array_length(MusicList))];");
    g.QueueFindReplace("gml_Object_oTalbertCutscene_Draw_0", "var Flip = input_check_pressed(UnknownEnum.Value_5) - input_check_pressed(UnknownEnum.Value_3);", "var Flip = coop_talbert_flip(input_check_pressed(UnknownEnum.Value_5) - input_check_pressed(UnknownEnum.Value_3));");
    // 0.6.3: maze dialog opened for the partner too
    g.QueueFindReplace("gml_Object_oCamera3DMaze_Cursor_Draw_0", "        LockZ = NearestPoint.Height;\n    }\n}", "        LockZ = NearestPoint.Height;\n    }\n    coop_maze_tb_open(NearestPoint.Text, NearestPoint.x, NearestPoint.y);\n}");
    // 0.6.3: team "Time Lasted" from the host
    g.QueueFindReplace("gml_Object_oGameOver_Draw_0", "format_as_timer(min(global.TimeOfDeath, 359.99), true);", "format_as_timer(min(coop_tod(), 359.99), true);");
}

var res = g.Import();
Console.WriteLine("[apply] import done");

if (stage == "full")
{
    var o = Data.GameObjects.ByName("oCoopNet");
    if (o == null) throw new Exception("oCoopNet not created");
    o.Persistent = true;
    o.Visible = true;
    var pe = Data.GameObjects.ByName("oCoopMazePeer");
    if (pe == null) throw new Exception("oCoopMazePeer not created");
    pe.Visible = true; pe.Persistent = false;
    Console.WriteLine("[apply] oCoopMazePeer visible");
    Console.WriteLine("[apply] oCoopNet persistent, events: " + string.Join(",", o.Events.Select((ev, i) => i + ":" + ev.Count)));
}
