# Building the Windows installer (Setup.exe)

Requirements: Windows, PowerShell 5.1+, Inno Setup 6 (`winget install --id JRSoftware.InnoSetup -e`),
UndertaleModCli 0.9.2.0, and the supported base `data.win` files (your own game copies / official release assets):

| base name  | SHA-256 (first 12) | where to get it |
|------------|--------------------|-----------------|
| clean215   | c254b690b0e2       | clean Five Nights at Frickbear's 3 + Four Layers Down v2.1.5 |
| coop072    | 12405aa08784       | v0.7.2 release asset `Coop_Install_0.7.2.zip` → `Coop_Install/data.win` |
| std082     | 726022dae9f9       | v0.8.2 release asset `data.win` |
| unlock082  | 73a4675086cc       | v0.8.2 release asset `UnlockAll_data.win` |

The tester base `988a2a95…` was never published; it is not supported. Owners can bridge with the
official v0.8.2 patch (988a → std082) and then install 0.8.5.

Steps (from the repository root, PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\fetch_xdelta.ps1     # official xdelta3 3.1.0, SHA-256 gated
powershell -ExecutionPolicy Bypass -File scripts\build_matrix.ps1    # 8 builds + tests/verify.csx each; writes installer/matrix.iss + installer/patches/manifest.json
powershell -ExecutionPolicy Bypass -File scripts\make_patches.ps1    # 8 xdelta patches, round-trip SHA-256 verified
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer\Freakbear3Coop.iss
powershell -ExecutionPolicy Bypass -File scripts\test_installer.ps1  # silent install/restore/repeat/boot matrix on a game COPY
```

`build_matrix.ps1` expects the base files at the paths listed in the script (edit `$bases` if yours differ).
Output: `dist/Freakbear3Coop-0.8.5-Setup.exe` (two levels above the repo root by default).

`installer/tools/xdelta3.exe` is not stored in git (official third-party binary); `fetch_xdelta.ps1`
downloads it from the xdelta-gpl GitHub release and verifies SHA-256
`6855c01cf4a1662ba421e6f95370cf9afa2b3ab6c148473c63efe60d634dfb9a`.

The patches in `installer/patches/` are committed so the installer can be rebuilt without the game bases.
No original game files are part of this repository, the installer, or the release zip.