# frickbears-coop

Two-player co-op mod for Five Nights at Frickbear's 3 + Four Layers Down v2.1.5 (GameMaker VM). The repository contains mod source and UndertaleModTool scripts, not the game's `data.win` or other game assets.

On Windows, build from a clean v2.1.5 `data.win` with UndertaleModTool CLI:

```powershell
.\scripts\build.ps1 -BaseData "C:\path\to\clean\data.win" -UndertaleModCli "C:\path\to\UndertaleModCli.exe"
```

An optional, separate local admin build is available with `-AdminCheats`. It writes to a different output file and uses an isolated save slot. It is not a secure account-based admin system; do not share that build.

For a ready-to-run installer, put `scripts\install_build.bat` and the built file renamed to `data.win` together in an install folder directly inside the game folder, then double-click the BAT. It backs up the original as `data.win.coop-backup` before replacing it. Keep separate folders for the standard and admin builds.

See [Руководство по коопу](Гайд_коопа/README_RU.md) for installation, custom character art, admin-build details, and the upgrade process for future game versions. See [custom co-op skin formats](coop_art/README.md) for PNG dimensions and the add-on importer.
