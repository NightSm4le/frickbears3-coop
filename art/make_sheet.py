from PIL import Image, ImageDraw, ImageFont
import glob, os
O='/workspace/frickbears/art/out'; E='/workspace/frickbears/stage/sprites/exp'
fp=[f for f in glob.glob('/usr/share/fonts/**/*Mono*.ttf',recursive=True)]
F=ImageFont.truetype(fp[0],14) if fp else ImageFont.load_default(); FB=ImageFont.truetype(fp[0],18) if fp else F
W=1400; sheet=Image.new('RGB',(W,1180),(24,24,28)); d=ImageDraw.Draw(sheet)
def put(img,x,y,s): img=img.resize((img.width*s,img.height*s),Image.NEAREST); sheet.paste(img,(x,y),img); return img.width
y=10; d.text((10,y),"FNaFb3 CO-OP — sprite SKETCHES (not in game). Palette = game's 4 GB greens + player accent (P1 blue, P2 orange)",fill=(240,240,240),font=FB); y+=34
d.text((10,y),"Game reference (exported from data.win): sMinigamePlayer x3, sMazeFreddy x2, sCustomNightGuardFaces",fill=(180,180,180),font=F); y+=20
x=10
for i in (0,4,8,12): x+=put(Image.open(f'{E}/sMinigamePlayer_{i}.png'),x,y,3)+6
x+=put(Image.open(f'{E}/sMazeFreddy_0.png'),x+10,y,2)+20
for i in (1,2): x+=put(Image.open(f'{E}/sCustomNightGuardFaces_{i}.png'),x+10,y,2)+14
y+=200
for who in ('P1','P2'):
    d.text((10,y),f"{who} billboard 32x64 (shown x3): front / back / left / right — idle, walk1, walk2",fill=(240,240,240),font=F); y+=20; x=10
    for dr in ('front','back','left','right'):
        d.text((x,y),dr,fill=(160,200,160),font=F)
        for i in range(3): x+=put(Image.open(f'{O}/bill_{who}_{dr}_{i}.png'),x,y+18,3)+4
        x+=22
    y+=18+64*3+14
d.text((10,y),"Small 16x32 (x4) for top-down/minimap · HUD icons 16x16 (x4): head, ping, dead · portraits 48x48 (x2)",fill=(240,240,240),font=F); y+=20; x=10
for who in ('P1','P2'):
    for dr in ('front','right','back'): x+=put(Image.open(f'{O}/guard_{who}_{dr}_0.png'),x,y,4)+6
    x+=14
for who in ('P1','P2'):
    for m in ('head','ping','dead'): x+=put(Image.open(f'{O}/icon_{who}_{m}.png'),x,y,4)+8
    x+=10
for who in ('P1','P2'): x+=put(Image.open(f'{O}/portrait_{who}.png'),x,y,2)+10
sheet=sheet.crop((0,0,W,y+140)); sheet.save('/workspace/frickbears/qa/sprites_sheet.png'); print(sheet.size)
