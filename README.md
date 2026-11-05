# frickbears-coop

Two-player co-op mod for Five Nights at Frickbear's 3 + Four Layers Down v2.1.5 (GameMaker VM). **Exactly 2 players (только 2 игрока):** one host and one friend; there is no 3-4 player mode. The repository contains mod source and UndertaleModTool scripts, not the game's `data.win` or other game assets.

On Windows, build from a clean v2.1.5 `data.win` with UndertaleModTool CLI:

```powershell
.\scripts\build.ps1 -BaseData "C:\path\to\clean\data.win" -UndertaleModCli "C:\path\to\UndertaleModCli.exe"
```

For a ready-to-run installer, download `INSTALL_COOP.bat` from the GitHub release. Put it and the locally built co-op file renamed to `data.win` together in a subfolder directly inside the game folder, then double-click the BAT. It backs up the original as `data.win.coop-backup` before replacing it. The game-containing `data.win` is not included in the public release.

See [Итог изменений v0.7.2](ИТОГ_0.7.2_RU.md) for the full Russian changelog and key list. See [Руководство по коопу](Гайд_коопа/README_RU.md) for building, custom character art, and updating for future game versions. See [custom co-op skin formats](coop_art/README.md) for PNG dimensions and the add-on importer.
