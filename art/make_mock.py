from PIL import Image, ImageDraw, ImageFont
import glob
O='/workspace/frickbears/art/out'; E='/workspace/frickbears/stage/sprites/exp'; Q='/workspace/frickbears/qa'
fp=glob.glob('/usr/share/fonts/**/*Mono*.ttf',recursive=True); F=ImageFont.truetype(fp[0],12)
ld=lambda p,s=1: (lambda i: i.resize((i.width*s,i.height*s),Image.NEAREST))(Image.open(p).convert('RGBA'))
# office: real stage-4 screenshot (host half) + sketch icons in the co-op panel
off=Image.open(f'{Q}/stage4_run6_help_buttons.png').convert('RGBA').crop((0,0,640,360)); d=ImageDraw.Draw(off)
ic=ld(f'{O}/icon_P2_head.png',2); off.paste(ic,(386,2),ic)
pg=ld(f'{O}/icon_P2_ping.png',2); off.paste(pg,(300,40),pg); d.text((236,76),"partner ping (P)",fill=(240,152,64),font=F)
d.text((8,330-14),"MOCK: P2 head icon in co-op panel + ping bubble",fill=(255,255,0),font=F)
# maze: pseudo-3D corridor from game textures, partner billboard + Freddy
G=(0,47,51); mz=Image.new('RGBA',(640,360),G+(255,)); d2=ImageDraw.Draw(mz)
fl=Image.open(f'{E}/sMazeTex_Flooring_0.png').convert('RGBA'); wl=Image.open(f'{E}/sMazeWall_HouseLivingRoom_0.png').convert('RGBA')
floor=Image.new('RGBA',(640,180)); 
for x in range(0,640,32):
    for y in range(0,180,32): floor.paste(fl,(x,y))
floor=floor.transform((640,180),Image.QUAD,(250,0,0,180,640,180,390,0),Image.NEAREST)  # perspective-ish
mz.paste(floor,(0,180))
def wall(x0,x1,h0,h1):
    t=wl.resize((max(1,x1-x0),128),Image.NEAREST)
    for x in range(x1-x0):
        h=int(h0+(h1-h0)*x/(x1-x0)); col=t.crop((x,0,x+1,128)).resize((1,h*2),Image.NEAREST); mz.paste(col,(x0+x,180-h))
wall(0,250,180,40); wall(390,640,40,180); d2.rectangle((250,140,390,220),fill=(10,30,32,255))
fr=ld(f'{E}/sMazeFreddy_0.png',1).resize((48,72),Image.NEAREST); mz.paste(fr,(296,150),fr)
pb=ld(f'{O}/bill_P2_front_1.png',3); mz.paste(pb,(380,360-64*3-6),pb)
d2.text((392,128),"P2 (partner)",fill=(240,152,64),font=F); d2.text((290,128),"Freddy",fill=(224,248,208),font=F)
rt=ld(f'{E}/sMazeReticle_0.png'); mz.paste(rt,(288,148),rt)
ic=ld(f'{O}/icon_P2_head.png',2); mz.paste(ic,(600,6),ic); d2.text((470,12),"PARTNER 12m  OK",fill=(240,152,64),font=F)
d2.text((8,344),"MOCK (pseudo-3D from game textures): partner billboard in MinigameMaze",fill=(255,255,0),font=F)
out=Image.new('RGBA',(1280,360)); out.paste(off,(0,0)); out.paste(mz,(640,0)); out.convert('RGB').save(f'{Q}/sprites_mock.png'); print('ok')
