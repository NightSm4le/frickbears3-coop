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

## Stage 3 — shared animatronics (2026-10-28)
Hooks (apply.csx): jumpscare -> coop_jumpscare_gate; block_tokens -> coop_on_block; occupy_doorway -> coop_on_occupy; oCamera Usage += coop_gen_extra(); title menu "Co-op".
Door path check: kills go through jumpscare(), door blocks through block_tokens (both hooked, seen in logs). occupy_doorway is NOT called by Bonnie/Chica/Withered Chica/Marionette in tests (occupy=0) — hook kept, not relied on.
Fixes: global.Deaths is 0 when a night starts outside New Game/Continue -> coop_prepare_night() makes it an array (fixed Code Error in count_jumpscare / oNightClear). UnknownEnum ids are int64 -> is_numeric, not is_real. Token TIMEOUT runs even when host is dying/link silent; coop_drop_partner releases client tokens.
Results: qa/stage3_run1..3 logs+png. PASS: roster, advance, lure, shared generator, token claim/grant/deny, repelled->partner w/ alert, vent redirect, killer + aggro alert, jumpscare gate, TIMEOUT (client SIGSTOP), client save blocked, no Code Error.
Known: client GameOver on death (observer mode not implemented yet); aggro capped at AI 20; overlay BR corner overlaps subtitle band, BL covers poster; Wine timer ~0.3x with two copies.
Bot flags: -coop-botai id=lvl,... -coop-botdoors 0|1 -coop-botcam -coop-botrepel N -coop-botkick S -coop-botlure S -coop-botshots a,b,...

## Stage 4 — spectator + help (modver 0.4.0, proto 2)
Build: sha256 704cb413b9f4a190220ded828b02b6f8c2dff29b228f49f3b0b516e9cfdd0248, VERIFY OK full.
- Death in coop while partner alive in Office: count_jumpscare skipped (no lives/Deaths spent), oGameOver Create hijacked
  (CoopSpec) -> spectator view: partner's frame streamed over the same TCP socket (binary [u8 1][u32 seq][u16 w][u16 h][u8 lvl][zlib]),
  per-frame ack, adaptive levels 256x144@5fps .. 96x54@1fps by RTT/in-flight/bandwidth budget (-coop-budget KB/s, default 96).
  HUD of partner on top, P = ping. Partner reaches 6 AM -> spectator also gets win_night (normal progress on host).
  Both dead -> skipped death is counted, real GameOver on both.
- Help (Office, partner alive & fresh): G give 10% power (needs >=15, cd 20s, refunded part not accepted),
  H/J close partner's L/R door 8s for 6% (cd 15s shared, refunded if already closed), L remote lure 3% (cd 15s).
  Buttons in coop panel (click, Begin Step, mouse_clear only on hit); keys skipped if bound in ControlsOptions; 8s key hint banner.
- Bot flags: -coop-botlag ms, -coop-bothelp T, -coop-botdie T, -coop-budget KB.
- Runs: qa/stage4_run{2..6}_{host,client}.log (run1 crashed on builtin `fps` name, artefacts removed).
- Limitations: relay lag simulated (botlag); xdotool clicks don't reach the game under Wine (button path untested by real input);
  remote lure only verified as delivered (no active animatronic near on test nights); Endless mode lives untested.

## 0.4.1 — H warn replaces door help (2026-10-28)
Door help (H/J close partner's door) REMOVED. H = warn partner: free, cd 20 s; partner sees for 2.8 s a red edge frame+arrow at L/R door,
"VENT: name" box, or "PARTNER: ALL CLEAR" (coop_warn_threat: DoorOccupant first, then near-by-kind). J is free. Buttons "G+pw" "H !" "L lure".
Build d69818939bdb08ec555e8e0a9680b582e9a66c71d6d0f12e2e93813bf076bf7f VERIFY OK. Test run7: warn PASS (client "threat L (Bonnie)", qa/help_warn.png),
give+refund PASS, spectator win PASS. qa/help_door*_OBSOLETE.png = old door help. Lure with active AI: still not proven (host died to Foxy first).

## Stage 5 (A) — sprite SKETCHES only, not in data.win
art/make_sprites.py (16x32 guard pixel maps in GB palette D(0,47,51) M(52,104,86) L(136,192,112) H(224,248,208), P1 blue / P2 orange accents,
4 dirs x (idle+2 walk), 32x64 billboard via scale2x, 16x16 icons head/ping/dead, 48x48 portraits), make_sheet.py -> qa/sprites_sheet.png,
make_mock.py -> qa/sprites_mock.png. References: sMinigamePlayer (16x32 f16), sTitleTex_GuardSilhouettes, sCustomNightGuardFaces, sMazeFreddy.

## Stage C — test package (release_src/, output /workspace/frickbears/release/FB3-Coop-test.zip, no game files)
make_release.sh: official xdelta3 3.1.0 exe (GPG-verified, sha 6855c01c…) under Wine creates fb3coop.xdelta clean->build; install.ps1 (BOM) checks
hashes of xdelta3/patch/source data.win, copies game to sibling frickbears3-coop[-N], patches only copy, verifies output sha, re-checks source.
Tested: pwsh 7.6.9 (linux) + xdelta3.exe under Wine on a read-only game copy — see qa/installer_test.txt. install.bat path / Windows PS 5.1 untested.

## LATER (user notes, do not do yet)
- Sprites: players in animatronic masks, game pixel style, P1/P2 different colors; always 2–3 drafts first, final only after approval.
- Stage 7: host sets one difficulty for both; money/upgrades per player, shop shows partner's purchases; night reward for both incl. spectator;
  co-op progress in a SEPARATE save per player, normal saves untouched.
- Co-op settings screen (host, game style), sent in welcome, applies to both, stored in separate co-op config: wallet shared/separate (default separate);
  spectator reward full/50%/0; revives off/1/2 per night; toggles: animatronic crossover, shared generator, "both hold the door" event,
  vent animatronic chooses office without cameras; survivor killer-rage weak/normal/strong.
- Approved features queue: camera marks (~8 s, also spectator), revive (once/night, 3 s hold, reviver vulnerable), joint "both hold the door" event
  (host, warning, 3 s window), night score at 6 AM/GameOver, shared boss HP (analysis first). Stage 6: 3D co-op in MinigameMaze_1.
