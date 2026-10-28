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

## Wine run results (2026-10-28, wine-10.0, Xvfb :99, build sha 9e6f42cf…)
- log build: coop_boot.log appears — PASS.
- full pair (runA host `-coop-host -coop-bot -coop-autonight 1 -coop-botdoors 8`, runB client `-coop-join -coop-bot -coop-botping -coop-botwin 30`):
  connect PASS (rtt 14–137 ms), both in Office night 1 PASS, clock diff 0.00–0.14 s PASS,
  separate power PASS (host 98.68/87.48 with doors closed, client 100), client save block PASS
  (client forced win_night; "save blocked on client" logged; save files sha256 unchanged, host never won).
- stage 2: snap ~10/s (966 snaps / ~95 s), partner HUD (PWR bar, L/R doors red when closed, CAM/OFFICE/MASK, FAN/LIGHT/T, DEAD), ping P (1 s cooldown, sfxBitCollect + 2 s PING! flash) PASS. Sound call not audible in Xvfb.
- screenshots: ../qa/host.png client.png hud.png menu.png

## Fixes found by running
- WarningScreen stalls bots: bot skips it (apply_settings(false); room_goto(TitleScreenMap)).
- oPauser/oPersistentPauser paused on focus loss + instance_deactivate_all -> host froze. In coop: no focus autopause; oCoopNet re-activated on pause.
  LIMITATION: manual pause on host still stops the shared clock (todo: pause = local only, or pause both).
- GUI invisible: game enables z-test; draw in Draw GUI End (Draw_75) with ztest/zwrite off, depth -10000.
- Both copies share one save dir under a single WINEPREFIX -> test save isolation by hash; restore from qa/save_backup.
- Bot flags: -coop-bot, -coop-autonight N, -coop-botping, -coop-botwin N, -coop-botdoors N (xdotool input into Wine game is unreliable).
- Todo small: partner HUD shows "?" after partner reaches NightClear -> show "SURVIVED 6AM".

## Protocol additions (stage 2)
- "snap" every 100 ms: rm alive pw d0 d1 cu cam mk fan fl tp tm (receiver computes clockDiff = Timer - tm).
- "alert": ping, 1 s cooldown.

## Stage 3 (NEXT, after stage 2): SHARED ANIMATRONICS
Rule: one animatronic for both. If Bonnie is attacking / at the door of one player, he cannot attack the other at that moment.
- Host-authoritative "attack token" per animatronic. Intercept points: DoorOccupant / doorway_available / occupy_doorway (SimpleScripts)
  and each animatronic's attack/move step. Before occupying a doorway or starting an attack -> "claim" {anim}; host grants if free -> "grant"/"deny";
  on retreat/jumpscare/night end -> "release". Non-owner: AI frozen or reset to start position (keeps move-timer RNG local).
- Timeouts: token auto-released after N s without heartbeat (disconnect safety).
Promised related mechanics:
1. Repelled animatronic (e.g. Foxy) may run to partner's office + warning on partner's HUD ("FOXY -> YOU").
2. Shared generator: doors closed long on one side add a small extra to Usage for both (hook in oCamera_Step_0 Usage sum; send doorClosedTime in snap).
3. Vent animatronic picks the office whose cameras are off (cu=0 from snap) — host decides.
4. Sound lure at home can pull an animatronic out of partner's office (lure event -> host moves token holder).
5. If one player dies, the killer animatronic becomes more aggressive for the survivor (AILevels[x] += k on survivor).
Night win: night passes for both if at least one survives to 6 AM (spectator mode, no Lives spent).

## Not yet verified by running
- game boots with log/full builds; coop_boot.log appears; oCoopNet spawns and survives rooms.
- GM framed TCP through Porthole; network_connect_async on Win runner under Wine.
- night follow on client (global.Night alone may be insufficient for story nights / Custom Night setup), -coop-autonight path.
- menu input: game also receives the keys/clicks while menu is open (no input blocking yet); font global.FontW97White rendering.
- Two instances on one PC share the save dir (%LOCALAPPDATA%\Frickbears3 or Wine equivalent) — client save block protects progress; logs need distinct -coop-log names.
