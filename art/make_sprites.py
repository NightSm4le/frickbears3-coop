# Stage 5 sketches (NOT injected into the game). Pixel style + 4-shade GB palette of sMinigamePlayer/sMazeFreddy.
from PIL import Image, ImageDraw, ImageFont
import os
OUT = '/workspace/frickbears/art/out'; os.makedirs(OUT, exist_ok=True)
D, M, L, H = (0,47,51), (52,104,86), (136,192,112), (224,248,208)   # game palette
ACC = {'P1': ((40,72,160), (96,152,232)), 'P2': ((168,72,16), (240,152,64))}  # accent dark/light per player

FRONT = """
................
.....oooooo.....
...oobbbbbboo...
..oabbbhhbbbao..
..oaaaaaaaaaao..
.oooooooooooooo.
..ohhhhhhhhhho..
..ohhhhhhhhhho..
..ohhohhhhohho..
..ohhohhhhohho..
..olhhhhhhhhlo..
..olhhhoohhhlo..
...olhhhhhhlo...
....oooooooo....
...oaaohhoaao...
..oaaaohhoaaao..
.oabaaaoboaabao.
.oabaaaoboaabao.
.oabahaaaaaabao.
.oabaaaaaaaabao.
.ohoaaaaaaaaoho.
.ohommmmmmmmoho.
..oo.ommmmo.oo..
....ommmmmmo....
....ommoommo....
....ommoommo....
....ommoommo....
....ommoommo....
....ommoommo....
...oooo..oooo...
...oooo..oooo...
................"""
BACK = """
................
.....oooooo.....
...oobbbbbboo...
..oabbbbbbbbao..
..oaaaaaaaaaao..
..oooooooooooo..
..ommmmmmmmmmo..
..ommmmmmmmmmo..
..ommmmmmmmmmo..
..ommmmmmmmmmo..
..olmmmmmmmmlo..
..olmmmmmmmmlo..
...ollllllllo...
....oooooooo....
...oaaaaaaaao...
..oaaaaaaaaaao..
.oabaaaaaaaabao.
.oabaaaaaaaabao.
.oabaaaaaaaabao.
.oabaaaaaaaabao.
.ohoaaaaaaaaoho.
.ohommmmmmmmoho.
..oo.ommmmo.oo..
....ommmmmmo....
....ommoommo....
....ommoommo....
....ommoommo....
....ommoommo....
....ommoommo....
...oooo..oooo...
...oooo..oooo...
................"""
SIDE = """
................
.....oooooo.....
....obbbbbboo...
...obbbbbbhbao..
...oaaaaaaaaaoo.
...oooooooooooooo
...ommhhhhhhho..
...ommhhhhhhho..
...ommhhhhohho..
...ommhhhhohho..
...omlhhhhhhhho.
...omlhhhhhoo.o.
....omlhhhhhlo..
.....ooooooooo..
.....oaaaohho...
....oaaaaaoho...
....oabaaaaao...
....oabaaaaao...
....oabaaaaao...
....oabaaaaao...
....ohoaaaaao...
....ohommmmmo...
.....oommmmo....
.....ommmmmo....
.....ommmmo.....
.....ommmmo.....
.....ommmmo.....
.....ommmmo.....
.....ommmmo.....
.....oooooooo...
.....oooooooo...
................"""

def rows(s):
    r = [l.ljust(16, '.')[:16] for l in s.strip('\n').split('\n')]
    assert len(r) == 32, len(r); return r

def walk(r, phase, side=False):
    r = list(r)
    if side:  # stride: legs apart / together
        if phase == 1:
            r[24:31] = ["....ommoomm.....", "...ommo.omm.....", "...omm..ommo....", "..omm....omm....", "..omm....omm....", ".ooooo...ooooo..", ".ooooo...ooooo.."]
        else:
            r[24:31] = [".....ommmmo.....", ".....ommmmo.....", ".....ommmmo.....", "......ommo......", "......ommo......", "....ooooooo.....", "....ooooooo....."]
        return [x.ljust(16, '.')[:16] for x in r]
    # front/back: one leg lifted a pixel, other planted
    L_, R_ = (1, 0) if phase == 1 else (0, 1)
    out = r[:24] + ["................"] * 8
    for y in range(24, 32):
        row = list(out[y])
        for side_i, lift in ((0, L_), (1, R_)):
            src = r[y + lift] if y + lift < 32 else "................"
            xs = range(0, 8) if side_i == 0 else range(8, 16)
            for x in xs: row[x] = src[x]
        out[y] = ''.join(row)
    return out

def render(r, who, scale=1):
    a, b = ACC[who]; pal = {'o': D, 'm': M, 'l': L, 'h': H, 'a': a, 'b': b}
    im = Image.new('RGBA', (16, 32), (0, 0, 0, 0))
    for y, row in enumerate(r):
        for x, c in enumerate(row):
            if c in pal: im.putpixel((x, y), pal[c] + (255,))
    return im

def scale2x(im):  # EPX: smoother pixel upscale, stays inside the palette
    w, h = im.size; o = Image.new('RGBA', (w * 2, h * 2)); p = im.load(); q = o.load()
    g = lambda x, y: p[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]
    for y in range(h):
        for x in range(w):
            P, A, B, C, Dd = g(x, y), g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            e = [P] * 4
            if C == A and C != Dd and A != B: e[0] = A
            if A == B and A != C and B != Dd: e[1] = B
            if Dd == C and Dd != B and C != A: e[2] = C
            if B == Dd and B != A and Dd != C: e[3] = Dd
            q[2*x, 2*y], q[2*x+1, 2*y], q[2*x, 2*y+1], q[2*x+1, 2*y+1] = e
    return o

def frames(who):
    f, b, s = rows(FRONT), rows(BACK), rows(SIDE)
    dirs = {'front': [f, walk(f, 1), walk(f, 2)], 'back': [b, walk(b, 1), walk(b, 2)],
            'right': [s, walk(s, 1, True), walk(s, 2, True)]}
    out = {}
    for d, fl in dirs.items():
        out[d] = [render(x, who) for x in fl]
    out['left'] = [im.transpose(Image.FLIP_LEFT_RIGHT) for im in out['right']]
    return out

def icon(who, mark):
    a, b = ACC[who]
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if mark == 'head':
        head = render(rows(FRONT), who).crop((1, 1, 15, 14)); im.paste(head, (1, 2), head)
        d.rectangle((11, 10, 15, 15), fill=D); d.text((12, 9), who[1], fill=b)
    elif mark == 'ping':
        d.ellipse((1, 1, 14, 12), fill=D); d.ellipse((2, 2, 13, 11), fill=b); d.polygon([(4, 11), (8, 11), (3, 15)], fill=D)
        d.rectangle((7, 4, 8, 7), fill=D); d.rectangle((7, 9, 8, 9), fill=D)
    elif mark == 'dead':
        head = render(rows(FRONT), who).convert('LA').convert('RGBA').crop((1, 1, 15, 14)); im.paste(head, (1, 2), head)
        d.line((3, 3, 13, 13), fill=(200, 30, 30), width=2); d.line((13, 3, 3, 13), fill=(200, 30, 30), width=2)
    return im

def portrait(who):  # 48x48 face like sCustomNightGuardFaces (dark frame, big head)
    head = render(rows(FRONT), who).crop((1, 0, 15, 16))
    p = scale2x(scale2x(head)).resize((42, 48), Image.NEAREST)
    im = Image.new('RGBA', (48, 48), (0, 0, 0, 0)); im.paste(p, (3, 2), p); return im

if __name__ == '__main__':
    allf = {w: frames(w) for w in ACC}
    for w, fr in allf.items():
        for d, fl in fr.items():
            for i, im in enumerate(fl):
                im.save(f'{OUT}/guard_{w}_{d}_{i}.png'); scale2x(im).save(f'{OUT}/bill_{w}_{d}_{i}.png')
        for m in ('head', 'ping', 'dead'): icon(w, m).save(f'{OUT}/icon_{w}_{m}.png')
        portrait(w).save(f'{OUT}/portrait_{w}.png')
    print('ok', len(os.listdir(OUT)))
