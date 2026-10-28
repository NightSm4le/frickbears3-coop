from PIL import Image, ImageDraw, ImageFont
import glob
O='/workspace/frickbears/art/out_masks'; E='/workspace/frickbears/stage/sprites/exp'
fp=glob.glob('/usr/share/fonts/**/*Mono*.ttf',recursive=True); F=ImageFont.truetype(fp[0],14); FB=ImageFont.truetype(fp[0],18)
W=1500; sheet=Image.new('RGB',(W,1700),(24,24,28)); d=ImageDraw.Draw(sheet)
def put(img,x,y,s):
    img=img.resize((img.width*s,img.height*s),Image.NEAREST); sheet.paste(img,(x,y),img); return img.width
y=10; d.text((10,y),"FNaFb3 CO-OP — guard in ANIMATRONIC MASK, sketches v2 (NOT in game). Game GB palette + accent: P1 blue, P2 orange (eyes, collar, hat band)",fill=(240,240,240),font=FB); y+=34
d.text((10,y),"Reference from data.win: sMinigamePlayer x3, sMazeFreddy x2",fill=(180,180,180),font=F); y+=20; x=10
for i in (0,4): x+=put(Image.open(f'{E}/sMinigamePlayer_{i}.png'),x,y,3)+6
put(Image.open(f'{E}/sMazeFreddy_0.png'),x+10,y,2); y+=200
for who in ('P1','P2'):
    for mask in ('freddy','bonnie','chica'):
        d.text((10,y),f"{who} · {mask.upper()} mask — billboard 32x64 (x3): front idle/walk1/walk2 · back idle/walk1/walk2 · HUD 16x16 (x4) · portrait 48x48 (x2)",fill=(240,240,240),font=F); y+=20; x=10
        for dr in ('front','back'):
            for i in range(3): x+=put(Image.open(f'{O}/billmask_{who}_{mask}_{dr}_{i}.png'),x,y,3)+4
            x+=20
        x+=put(Image.open(f'{O}/iconmask_{who}_{mask}.png'),x,y,4)+20
        x+=put(Image.open(f'{O}/portraitmask_{who}_{mask}.png'),x,y,2)+20
        for dr in ('front','back'): x+=put(Image.open(f'{O}/mask_{who}_{mask}_{dr}_0.png'),x,y,3)+8
        y+=64*3+12
sheet=sheet.crop((0,0,W,y+10)); sheet.save('/workspace/frickbears/qa/sprites_masks_sheet.png'); print(sheet.size)
