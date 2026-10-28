# Stage 5b sketches (NOT injected into the game): guard wearing an ANIMATRONIC MASK.
# Palette = game's 4 GB greens (sMinigamePlayer/sMazeFreddy) + per-player accent (P1 blue, P2 orange).
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from make_sprites import rows, FRONT, BACK, walk, scale2x, D, M, L, H, ACC
from PIL import Image, ImageDraw
OUT = '/workspace/frickbears/art/out_masks'; os.makedirs(OUT, exist_ok=True)
HEADS = {  # 14 rows x 16 (rows 0..13 of the 16x32 guard); a/b = player accent dark/light
 'freddy': ["......oooo......", ".oo...oooo...oo.", "omlo..oaao..olmo", "ommoooooooooommo",
            ".ommmmmmmmmmmmo.", ".ommmmmmmmmmmmo.", ".omhhbmmmmhhbmo.", ".omhhommmmhhomo.",
            ".ommllloolllmmo.", ".ommllllllllmmo.", ".omlloooooollmo.", ".ommllllllllmmo.",
            "..ommmmmmmmmmo..", "....oobaaboo...."],
 'bonnie': ["...oo......oo...", "..omlo....olmo..", "..omlo....olmo..", "..omlo....olmo..",
            "..oomoooooomoo..", ".ommmmmmmmmmmmo.", ".ommhhbmmhhbmmo.", ".ommhhommhhommo.",
            ".ommmmmoommmmmo.", ".ommllllllllmmo.", ".omlhhhhhhhhlmo.", ".ommllllllllmmo.",
            "..ommmmmmmmmmo..", "....oobaaboo...."],
 'chica':  ["......olol......", ".....oolloo.....", "...oooommoooo...", "..ollllllllllo..",
            ".ollllllllllllo.", ".olhhbllllhhblo.", ".olhholllhholo..", ".ollommmmmmollo.",
            ".olommhhhhmmolo.", ".olomoooooomolo.", ".ollommmmmmollo.", "..olloooooollo..",
            "...ollllllllo...", "....oohhhhoo...."],
}
BASE = {'freddy': 'm', 'bonnie': 'm', 'chica': 'l'}
for k, v in HEADS.items():
    for i, r in enumerate(v): assert len(r) == 16, (k, i, r)

def back_head(name):  # same silhouette, face features painted over with the mask base colour
    h = [list(r) for r in HEADS[name]]; b = BASE[name]
    for y in range(4, 12):
        row = h[y]; idx = [i for i, c in enumerate(row) if c != '.']
        if len(idx) < 4: continue
        for x in range(idx[0] + 2, idx[-1] - 1): row[x] = b
    h[13] = "....oooooooo...."
    return [''.join(r) for r in h]

def compose(head, body):
    r = list(head) + list(body[14:])
    return [x.ljust(16, '.')[:16] for x in r]

def render(r, who):
    a, b = ACC[who]; pal = {'o': D, 'm': M, 'l': L, 'h': H, 'a': a, 'b': b}
    im = Image.new('RGBA', (16, 32), (0, 0, 0, 0))
    for y, row in enumerate(r):
        for x, c in enumerate(row):
            if c in pal: im.putpixel((x, y), pal[c] + (255,))
    return im

def frames(who, mask):
    f = compose(HEADS[mask], rows(FRONT)); bk = compose(back_head(mask), rows(BACK))
    return {'front': [render(x, who) for x in (f, walk(f, 1), walk(f, 2))],
            'back': [render(x, who) for x in (bk, walk(bk, 1), walk(bk, 2))]}

def icon(who, mask):  # 16x16 HUD head with player number tab
    a, b = ACC[who]; im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    head = render(compose(HEADS[mask], rows(FRONT)), who).crop((0, 0, 16, 14)); im.paste(head, (0, 1), head)
    d.rectangle((11, 10, 15, 15), fill=D); d.text((12, 9), who[1], fill=b); return im

def portrait(who, mask):
    head = render(compose(HEADS[mask], rows(FRONT)), who).crop((0, 0, 16, 16))
    p = scale2x(scale2x(head)).resize((44, 44), Image.NEAREST)
    im = Image.new('RGBA', (48, 48), D + (255,)); im.paste(p, (2, 3), p); return im

if __name__ == '__main__':
    for who in ACC:
        for mask in HEADS:
            for d, fl in frames(who, mask).items():
                for i, im in enumerate(fl):
                    im.save(f'{OUT}/mask_{who}_{mask}_{d}_{i}.png'); scale2x(im).save(f'{OUT}/billmask_{who}_{mask}_{d}_{i}.png')
            icon(who, mask).save(f'{OUT}/iconmask_{who}_{mask}.png'); portrait(who, mask).save(f'{OUT}/portraitmask_{who}_{mask}.png')
    print('ok', len(os.listdir(OUT)))
