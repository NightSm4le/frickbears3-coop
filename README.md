# frickbears-coop

Two-player co-op mod for Five Nights at Frickbear's 3 + Four Layers Down v2.1.5 (GameMaker VM). **Exactly 2 players (только 2 игрока):** one host and one friend; there is no 3-4 player mode. The repository contains mod source and UndertaleModTool scripts, not the game's `data.win` or other game assets.

On Windows, build from a clean v2.1.5 `data.win` with UndertaleModTool CLI:

```powershell
.\scripts\build.ps1 -BaseData "C:\path\to\clean\data.win" -UndertaleModCli "C:\path\to\UndertaleModCli.exe"
```

For a ready-to-run Windows installer, download `Freakbear3Coop-0.8.5-Setup.exe` from the GitHub release (v0.8.5+). It validates your game folder and base `data.win` by SHA-256, backs up the original as `data.win.coop-original`, applies an xdelta patch to a staged copy, verifies the result hash, and can restore the original on uninstall. Supported bases: clean v2.1.5, Coop_Install 0.7.2 (2.1.5), co-op 0.8.2 / 0.8.2 UnlockAll. See [installer/README.md](installer/README.md) for rebuilding it and [docs/RELEASE_0.8.5.md](docs/RELEASE_0.8.5.md) for the release notes. The legacy `INSTALL_COOP.bat` mechanism (bat + locally built co-op `data.win` in a subfolder of the game, backup `data.win.coop-backup`) still works for self-built files. No game-containing `data.win` is included in the public releases.

See [Итог изменений v0.7.2](ИТОГ_0.7.2_RU.md) for the full Russian changelog and key list. See [Руководство по коопу](Гайд_коопа/README_RU.md) for building, custom character art, and updating for future game versions. See [custom co-op skin formats](coop_art/README.md) for PNG dimensions and the add-on importer.
