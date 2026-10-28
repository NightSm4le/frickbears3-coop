# Mock (NOT in game): mask characters P1/P2 on the CURRENT 0.5.0 office (no door buttons) + 3D maze billboards
from PIL import Image, ImageDraw, ImageFont
import glob
M='/workspace/frickbears/art/out_masks'; E='/workspace/frickbears/stage/sprites/exp'; Q='/workspace/frickbears/qa'
fp=glob.glob('/usr/share/fonts/**/*Mono*.ttf',recursive=True); F=ImageFont.truetype(fp[0],11)
ld=lambda p,s=1: (lambda i: i.resize((i.width*s,i.height*s),Image.NEAREST))(Image.open(p).convert('RGBA'))
P1=(96,152,232); P2=(240,152,64); Y=(255,230,0)
def tag(d,x,y,t,c):
    w=d.textlength(t,font=F); d.rectangle((x-2,y-1,x+w+2,y+12),fill=(0,0,0)); d.text((x,y),t,fill=c,font=F)
# --- panel A: host view of current office, partner = P2 Bonnie mask
off=Image.open(f'{Q}/v050/r1_revived.png').convert('RGBA').crop((0,0,640,360)); d=ImageDraw.Draw(off)
ic=ld(f'{M}/iconmask_P2_bonnie.png',2); off.paste(ic,(486,22),ic)        # head icon in the co-op panel
po=ld(f'{M}/portraitmask_P1_freddy.png',1); d.rectangle((3,262,54,313),outline=P1); off.paste(po,(5,264),po)
tag(d,58,282,"YOU: P1 Freddy mask",P1)
pb=ld(f'{M}/portraitmask_P2_bonnie.png',1); d.rectangle((585,262,636,313),outline=P2); off.paste(pb,(587,264),pb)
tag(d,470,282,"P2 Bonnie mask",P2)
tag(d,6,46,"MOCK: mask icons in the current 0.5.0 office",Y)
# --- panel B: client view, partner = P1 Freddy mask, plus Chica variant
off2=Image.open(f'{Q}/v050/r1_revived.png').convert('RGBA').crop((640,0,1280,360)); d2=ImageDraw.Draw(off2)
ic=ld(f'{M}/iconmask_P1_freddy.png',2); off2.paste(ic,(486,22),ic)
for k,(p,c,t) in enumerate([('P2_bonnie',P2,'YOU: P2 Bonnie'),('P2_chica',P2,'alt: P2 Chica'),('P1_chica',P1,'alt: P1 Chica')]):
    x=6+k*120; im=ld(f'{M}/portraitmask_{p}.png',1); d2.rectangle((x-2,262,x+49,313),outline=c); off2.paste(im,(x,264),im); tag(d2,x,316,t,c)
tag(d2,6,46,"MOCK: client side, partner head = P1 Freddy",Y)
# --- panel C: maze billboards (pseudo-3D from game textures)
G=(0,47,51); mz=Image.new('RGBA',(1280,300),G+(255,)); dm=ImageDraw.Draw(mz)
fl=Image.open(f'{E}/sMazeTex_Flooring_0.png').convert('RGBA')
for x in range(0,1280,32):
    for y in range(170,300,32): mz.paste(fl,(x,y))
x=20
for p,c in [('P1_freddy',P1),('P1_bonnie',P1),('P1_chica',P1),('P2_freddy',P2),('P2_bonnie',P2),('P2_chica',P2)]:
    for s in ('front_1','back_1'):
        im=ld(f'{M}/billmask_{p}_{s}.png',3); mz.paste(im,(x,290-im.height),im); x+=100
    tag(dm,x-190,8,p.replace('_',' ')+' mask',c)
tag(dm,6,30,"MOCK: maze billboards front/back (x3), not in game",Y)
out=Image.new('RGBA',(1280,660)); out.paste(off,(0,0)); out.paste(off2,(640,0)); out.paste(mz,(0,360))
out.convert('RGB').save(f'{Q}/sprites_masks_mock.png'); print('ok', out.size)
