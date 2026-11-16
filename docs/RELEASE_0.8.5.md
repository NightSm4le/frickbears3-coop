# Freakbear 3 Co-op — 0.8.5

Unofficial Co-op Modification for Freakbear 3. (Five Nights at Frickbear's 3 + Four Layers Down v2.1.5)

### What's New

- Real Windows installer: `Freakbear3Coop-0.8.5-Setup.exe` (Inno Setup). Wizard with game-folder selection and validation, base-version check by SHA-256, Standard / Unlock All variant choice, progress display, clear error messages, cancel support, install log (`coop_install_log.txt` in the game folder).
- Safe by design: your original `data.win` is backed up as `data.win.coop-original` (an existing backup is never overwritten); the xdelta patch is applied to a staged copy and SHA-256-verified before `data.win` is replaced; uninstalling restores the original from the backup.
- Multi-base upgrades: clean v2.1.5, Coop_Install 0.7.2 (2.1.5), co-op 0.8.2 and 0.8.2 UnlockAll are all supported, plus reinstall / variant switch on an existing 0.8.5 install. Repeat installs are idempotent.
- The legacy zip mechanism (`install.bat` / `install.ps1`, copies the game to a sibling folder) now uses the same base matrix and a `-Variant unlock` option.
- No original game files are distributed: the installer and the zip contain only xdelta patches, the official xdelta3 tool, launchers, docs and co-op character art.

### Bug Fixes

- Scraptrap night crash: when the host's task list arrived, the client's `TaskRunning` index could point past the end of the new list (`oControlPanel` reads `Tasks[TaskRunning]` every frame). The running task is now remapped by title before the list is replaced.
- Scraptrap desync on a second night in the same session: the task list and the shared task total are now reset and re-synchronized on Office entry.
- Returning from a maze or from SalvageResults no longer wipes same-night boss state (enrage, shared HP, revive counter).
- Wrong "Boss enraged" reason on host death: the enrage message now correctly reports the host down instead of the partner.
- Retained and re-verified in this build (fixed in 0.8.4): `oGameOver_Create` "illegal array use" crash on Endless (`Deaths` array/number handling) and the `oTextBox_Fredbear.CGPFunction not set` crash in textbox forwarding.
- Network protocol unchanged (proto 8). Both players must run 0.8.5.

### Installer

- Bases are identified by SHA-256 of `data.win`; unsupported versions produce a clear error listing the supported bases. Owners of the old tester base `988a…` should first apply the official v0.8.2 patch (it converts 988a to 0.8.2), then run this installer.
- Install steps: backup (once) → stage base → xdelta decode → SHA-256 verify → atomic replace → add `Host.bat`, `Join.bat`, docs and `Addons/CoopChars` (existing user files are never overwritten).
- Uninstall (Windows "Apps & features" or `unins000.exe` in the game folder) restores `data.win` from `data.win.coop-original` and removes only the files the installer added.
- Silent mode for automation: `Setup.exe /SILENT /SUPPRESSMSGBOXES /DIR="<game folder>" /VARIANT=std|unlock /LOG="<file>"`.

### Installation

1. Download `Freakbear3Coop-0.8.5-Setup.exe` from this release (both players).
2. Close the game and run the installer; choose Standard or Unlock All (same variant on both PCs).
3. Select your game folder (the one containing `Frickbears3.exe` and `data.win`, v2.1.5).
4. Finish the wizard; the installer verifies the patched file by SHA-256 and keeps your original as `data.win.coop-original`.
5. Launch via `Host.bat` (host) / `Join.bat` (join), or the in-game Co-op menu (F8). See `CONNECT_RU.md` for playing over the internet with Porthole.

### Testing

- All 8 build targets (4 bases × Standard/UnlockAll) pass the static verification suite (`tests/verify.csx`, `VERIFY OK full`), including checks for every fix listed above.
- All 8 xdelta patches round-trip verified: decode(base, patch) SHA-256 equals the verified build hash.
- Installer tested on a copy of the game: clean-base install (both variants), upgrade from 0.8.2 UnlockAll, repeat install, variant switch, uninstall restore (hash-exact), wrong-folder and unsupported-base rejection, added-file cleanup, and a boot test of the patched copy (title screen reached, no Code Error).
- Not tested: a live two-player co-op session (requires two game instances and a network link); boss-fight fixes are verified statically and by single-instance boot only.