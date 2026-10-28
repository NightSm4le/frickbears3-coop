# Exports the CURRENT DRAFT mask sprites (make_masks.py) as runtime files for the mod: mod/coop_art/*.png
# These are DRAFTS / placeholders. They are NOT compiled into data.win: the game loads them with sprite_add()
# from <game dir>/coop_art/ at runtime. To replace after approval: overwrite the PNGs with the same names/sizes.
#   <P>_<mask>_bill.png      192x64 strip, 6 frames of 32x64: front0..2, back0..2 (3D billboard)
#   <P>_<mask>_icon.png      16x16 HUD head (P1/P2 icons)
#   <P>_<mask>_portrait.png  48x48 portrait (partner window / spectator)
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from make_masks import frames, icon, portrait, HEADS, ACC
from make_sprites import scale2x
from PIL import Image
OUT = os.path.join(os.path.dirname(__file__), '..', 'coop_art')
os.makedirs(OUT, exist_ok=True)
for who in ACC:
    for mask in HEADS:
        f = frames(who, mask)
        strip = Image.new('RGBA', (32 * 6, 64), (0, 0, 0, 0))
        for i, im in enumerate(f['front'] + f['back']):
            strip.paste(scale2x(im), (32 * i, 0))
        strip.save(f'{OUT}/{who}_{mask}_bill.png')
        icon(who, mask).save(f'{OUT}/{who}_{mask}_icon.png')
        portrait(who, mask).save(f'{OUT}/{who}_{mask}_portrait.png')
open(f'{OUT}/README.txt', 'w').write('DRAFT sprites (not final, not approved). Loaded at runtime by the co-op mod; replace files with same names/sizes.\n')
print('ok', sorted(os.listdir(OUT)))
