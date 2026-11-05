FB3 Co-op: custom characters (0.7.4)

Put the CoopChars folder into <game>/Addons/  ->  <game>/Addons/CoopChars/<id>/
  portrait.png  48x48   partner HUD / night card portrait
  maze.png      192x64  3D maze billboard: 6 frames of 32x64 left->right
                         (0 front stand, 1-2 front walk, 3 back stand, 4-5 back walk)
  icon.png      16x16   small icon (top-right HUD)
  mask.png      optional, reserved (not used yet)
<id> = folder name, latin letters/digits, no spaces.
In game: Co-op -> Co-op Settings -> "Character: ..." (Enter cycles). The partner
sees your character only if THEY have the same folder too; otherwise the default mask art.
Two players can't pick the same character (the client switches to the next one).
Ready set (drafts, recoloured): golden, shadow, toy.
