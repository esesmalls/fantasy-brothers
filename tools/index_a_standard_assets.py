"""Index unmodified source PNG regions. No raster edits or re-sampling occur.

Coordinates are measured from alpha and manually inspected source regions. The
same source-pixel scale is shared by every state in an armor/head/arm family.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'game/assets/art/a-standard'
ARMORS = ['armor_padded','armor_leather','armor_brigandine','armor_mail']
WEAPONS = ['weapon_guard_sword','weapon_guard_cleaver','weapon_skirmisher_blade','weapon_skirmisher_axe','weapon_spear_long','weapon_spear_hooked','weapon_archer_bow','weapon_archer_longbow','weapon_hunter_bow','weapon_hunter_recurve']

def part(name, rect, size, pivot=(.5,.5), **extra):
    return dict(atlas=f'res://assets/art/a-standard/{name}.png',rect=list(rect),size=list(size),pivot=list(pivot),position=[0,0],**extra)

def grid(name,cols,rows,col,row,size,pivot):
    with Image.open(ASSETS / f'{name}.png') as im:
        w,h=im.width/cols,im.height/rows
    return part(name,[col*w,row*h,w,h],size,pivot)

def build():
    data={'schema':1,'version':'a-standard-1','status':'production-review','weapons':{},'shields':{},'armors':{},'faces':[],'arms':{},'terminal':{},'dog':[]}
    rects=[(128,4,132,416),(412,4,108,416),(711,87,94,333),(986,26,183,394),(155,424,56,430),(438,424,87,430),(720,465,107,370),(1035,424,94,428),(130,862,126,395),(431,867,102,393),(646,891,256,343),(970,852,226,405)]
    grips=[(194,348),(466,342),(757,347),(1019,325),(184,714),(465,714),(798,650),(1101,648),(226,1055),(493,1055),(800,1060),(1117,1070)]
    lengths=[46,46,32,37,77,77,49,62,52,48,32,36]
    for i,(rect,grip,length) in enumerate(zip(rects,grips,lengths)):
        x,y,w,h=rect
        size=[w*length/h,length]
        entry=part('weapons',rect,size,[(grip[0]-x)/w,(grip[1]-y)/h])
        if 6<=i<=9:
            endpoints=[[(738,478),(738,822)],[(1057,434),(1056,839)],[(154,879),(149,1240)],[(467,880),(449,1246)]][i-6]
            entry['string_ends']=[[(px-grip[0])*length/h,(py-grip[1])*length/h] for px,py in endpoints]
        if i<10:data['weapons'][WEAPONS[i]]=entry
        else:data['shields']['round' if i==10 else 'heavy']=entry
    for row,key in enumerate(ARMORS):
        data['armors'][key]=[grid('armor-shells',4,4,col,row,[46,44],[.5,.95]) for col in range(4)]
    data['underlayer']=grid('armor-underlayers',4,4,0,0,[46,44],[.5,.95])
    with Image.open(ASSETS/'inner-linen.png') as im:
        x0,y0,x1,y1=im.getchannel('A').point(lambda v:255 if v>64 else 0).getbbox()
    data['linen']=part('inner-linen',[x0,y0,x1-x0,y1-y0],[38,38],[.5,1.0])
    data['trim']={key:grid('armor-underlayers',4,4,0,row,[46,44],[.5,.95]) for row,key in enumerate(ARMORS)}
    for name in ['faces-01-06','faces-07-12']:
        im=Image.open(ASSETS/f'{name}.png')
        alpha=im.getchannel('A')
        row_edges=[0,241,482,730,969,1232,1536] if name=='faces-01-06' else [0,240,488,735,990,1238,1536]
        for row in range(6):
            states=[]
            for col in range(4):
                y0,y1=row_edges[row],row_edges[row+1]
                region=(col*256,y0,(col+1)*256,y1)
                tile=alpha.crop(region)
                bounds=tile.point(lambda v:255 if v>64 else 0).getbbox()
                if bounds is None:raise ValueError(f'Empty head {name}/{row}/{col}')
                bottom=bounds[3]-1
                sample_y=range(max(bounds[1],bottom-20),max(bounds[1]+1,bottom-5))
                xs=[x for y in sample_y for x in range(bounds[0],bounds[2]) if tile.getpixel((x,y))>180]
                anchor_x=sum(xs)/len(xs) if xs else (bounds[0]+bounds[2])/2
                states.append(part(name,[col*256,y0,256,y1-y0],[37,(y1-y0)*37/256],[anchor_x/256,(bottom-3)/(y1-y0)]))
            data['faces'].append(states)
    # Regions are deliberately NOT equal thirds: generated arms cross grid lines.
    arm_rects=[(4,199,461,308),(466,192,395,318),(887,196,339,258),(7,697,433,300),(447,691,436,316),(887,697,364,306)]
    shoulder=[(88,266),(552,266),(974,281),(86,764),(527,758),(974,764)]
    grip=[(424,398),(819,306),(1160,265),(399,927),(823,914),(1178,808)]
    for key,rect,s,g in zip(['bow_front','bow_rest','bow_pull','spear_rear','spear_front','command'],arm_rects,shoulder,grip):
        x,y,w,h=rect
        scale=.046
        data['arms'][key]=part('grip-arms',rect,[w*scale,h*scale],[(s[0]-x)/w,(s[1]-y)/h],grip=[(g[0]-s[0])*scale,(g[1]-s[1])*scale])
    for key,rect,s,g in zip(['bow_string_rest','bow_string_half','bow_string_full'],[(15,200,990,310),(1080,200,570,330),(1680,200,475,330)],[(130,365),(1180,365),(1960,367)],[(922,350),(1584,351),(2100,362)]):
        x,y,w,h=rect;scale=.034
        data['arms'][key]=part('bow-string-arms',rect,[w*scale,h*scale],[(s[0]-x)/w,(s[1]-y)/h],grip=[(g[0]-s[0])*scale,(g[1]-s[1])*scale])
    # Fallen bodies have an offset row boundary; exact regions preserve every boot.
    for row,key in enumerate(ARMORS):
        starts=[99,428,765,1140]; ends=[416,762,1127,1502]
        data['terminal'][key]=[]
        for col in range(2):
            x=col*512;y=starts[row];w=512;h=ends[row]-y
            entry=part('terminal-bodies',[x,y,w,h],[70,h*70/512],[.52,.74])
            entry['neck']=[-24,-24 if col==0 else -20]
            entry['intact_atlas']='res://assets/art/a-standard/terminal-intact.png'
            data['terminal'][key].append(entry)
    # Uniform cell scale keeps a lunge longer than idle rather than shrinking it.
    for row in range(2):
        for col in range(3):
            data['dog'].append(grid('warhound',3,2,col,row,[60,60],[.50,.92]))
    (ASSETS/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Indexed 10 weapons, 2 shields, 16 outer armors, linen and padded inner layers, 48 heads, 9 arms, 16 fallen body variants, 6 dog states.')

if __name__=='__main__':build()
