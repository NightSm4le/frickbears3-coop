# Frickbear's Coop — NOTES

Target: Five Nights at Frickbear's 3 + Four Layers Down v2.0.2 (GameJolt), GameMaker 2023.11 VM, bytecode 17.
Clean data.win sha256 f2cdfb32fabd6b838ecb89bac10bc1cc956a77565fc2530ce1c6f9b9ffd0e38a (CurrentVersion "_v2-0-0").
Tool: UndertaleModCli 0.9.2.0 (Ubuntu) at /workspace/tools/utmt.

## Approved design (2026-10-28)
- Exactly 2 players, two independent offices (each runs its own office locally), host = clock/night authority.
- Death: global.Lives NOT spent; dead player spectates until end of night. Night won for both if survivor reaches 6AM; game over when both die.
- 3D mazes: both enter together, offices paused.
- Transport: ONE TCP port (default 7777), default IP 127.0.0.1 — primary internet path is Porthole (Steam), which forwards one port; friend connects to 127.0.0.1:<port>. No UDP, no broadcast, no extra ports. Keep traffic small (Valve relay); spectator frame stream must be adaptive (later stage).

## Build
- `./build.sh noop|log|full` -> ../build/data.noop.win | data.log.win | data.win. Reads ../clean/data.win (sha-checked). Deterministic (same sha each run).
- noop round-trip = byte-identical to clean (sha f2cdfb32…), so UMT load/save is lossless.
- log: adds gml_GlobalScript_CoopBoot (appends "coop boot ok" to coop_boot.log in the game save dir at startup).
- full: boot + coop core. tests/verify.csx = static checks; tests/decompile_coop.csx dumps decompiled result for review.

## Hooks (full)
- oSuperGameManager (persistent, in StartupRoom) Create: append spawn of persistent oCoopNet.
- SaveData: create_save / save_permanent_data / save_endless_data start with `if (coop_block_save(..)) exit;` (client never writes progress).
- SimpleScripts win_night(): calls coop_on_win_night() (notifies partner).
- Clock: office time = global.Timer, advanced in oCamera Step (360 = 6AM, ~1/s). Client snaps if |diff|>2 else lerps 25%.
- Night start: host entering room NightOpening sends {night, difficulty, ai, speedup, shuffle}; client copies and room_goto(NightOpening).

## Protocol v1 (JSON per GM-framed TCP packet)
hello{proto,modver,game} -> welcome{proto,slot,game} | reject{why}; ping{ts}/pong{ts} every 1 s; timeout 10 s;
night{...}; clock{timer} every 0.5 s in Office (~40 B); win{night}; bye{why}. Host server max 1 client; extra sockets destroyed.

## Launch flags (bot test)
-coop-host | -coop-join [ip]  -coop-port N  -coop-bot (STATE line in log every 60 frames)  -coop-autonight N (host bot starts night N 3 s after connect)  -coop-log file
Menu: F8 outside Office: IP/Port fields (click, type, Tab), HOST / JOIN / LEAVE, Enter = join.

## Compiler gotchas (UMT 0.9.2 for this GM version)
- `mod` can't be a struct field name (keyword).
- `async_load[? "k"]` decompiled as plain `["k"]` -> used ds_map_find_value explicitly; struct `[$ ]` -> variable_struct_get. Unknown identifiers would compile as variables silently: check decompile dump.

## NOT yet verified by running (needs Wine, being installed by another worker)
- game boots with log/full builds; coop_boot.log appears; oCoopNet spawns and survives rooms.
- GM framed TCP through Porthole; network_connect_async on Win runner under Wine.
- night follow on client (global.Night alone may be insufficient for story nights / Custom Night setup), -coop-autonight path.
- menu input: game also receives the keys/clicks while menu is open (no input blocking yet); font global.FontW97White rendering.
- Two instances on one PC share the save dir (%LOCALAPPDATA%\Frickbears3 or Wine equivalent) — client save block protects progress; logs need distinct -coop-log names.
