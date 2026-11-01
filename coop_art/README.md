# Custom co-op skins

The co-op maze draws the other player as a 2D billboard in the 3D maze. Custom skins are PNG files loaded at runtime from the game's `coop_art` folder; no game data file needs to be patched. Both players should install the same skin files so each sees the same partner art.

## Files and dimensions

The filenames encode the co-op seat (`P1` or `P2`), the mask slot (`freddy`, `bonnie`, or `chica`), and the image kind:

| Kind | Example | PNG layout |
|---|---|---|
| Maze billboard | `P1_freddy_bill.png` | Six 32x64 frames in a horizontal strip (192x64 total), transparent background |
| Portrait | `P1_freddy_portrait.png` | One square PNG; 48x48 is recommended |
| Icon | `P1_freddy_icon.png` | One 16x16 PNG |

Repeat the names for `P1` and `P2` and for the mask slot the player chooses in Co-op Settings. The six billboard frames are, from left to right: facing camera idle, walk frame 1, walk frame 2, facing away idle, walk frame 1, walk frame 2. A non-moving player uses the idle frame for the direction they face.

Use the supplied `P1_*` and `P2_*` PNGs in this folder as editable examples. Keep each billboard frame exactly 32x64 pixels. If a custom billboard is missing or has the wrong dimensions/frame count, the game logs a warning and falls back to its embedded art.

## Import a custom guard add-on

The included `scripts/import_addon_skin.py` converts a game's custom-guard folder into the three co-op PNGs. Run it from the game folder (Python and Pillow required):

```powershell
python path\to\frickbears3-coop\scripts\import_addon_skin.py addons\Grike --seat P2 --mask freddy
```

It reads the first panel of `selection.png` for the static maze character, and uses `portrait.png` and `icon.png` when present. The selection art is repeated across all six frames, so the resulting billboard is static; draw over those frames to animate it. Change the seat and mask arguments to match the player and selected mask. Both players need matching files.

The Grike/SEAR archive uses this separate game add-on format. Its character-selection art can be imported as a static skin; the archive does not include directional walk frames, so animation requires editing the six-frame PNG.

## Night location card

When both players are connected, the pre-night location card displays a small labeled avatar for each player. For a character add-on, the game looks up that player's selected guard name and loads `addons/<guard name>/selection.png` as the avatar. Install the same guard add-on on both computers so each game can display the other player's sprite. If the add-on image is not present locally, the card falls back to the player's configured co-op portrait skin. This does not change the game's underlying guard selection or add-on data.

## Install

1. Make a folder named `coop_art` beside the game's executable.
2. Copy your PNGs into it using the filenames above.
3. Have both players install the same files, then restart the game.
4. Choose the matching mask slot in Co-op Settings; the selected slot determines which skin is shown.

This is a sprite-skin format, not a 3D mesh format. The supplied Grike/SEAR add-on archive uses a different game add-on layout; its portrait or icon cannot be used as the six-frame maze billboard without converting/drawing that billboard sheet first.
