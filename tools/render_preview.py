"""Render the actual Lua frame-tree fixture with font/icon substitutions.

This is a layout preview, never a live-game screenshot. Requires Pillow.
"""
from pathlib import Path
from functools import lru_cache
import json, re, argparse, math, random
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--layout',default='research/layout.json')
parser.add_argument('--output',default='UpgradeCrossroads/PREVIEW.png')
parser.add_argument('--strict',action='store_true',help='Fail if a fixed-height text region overflows in the offline preview')
args=parser.parse_args()
frames=json.loads((ROOT/args.layout).read_text())
by_id={f['exportID']:f for f in frames}
rects={}
S=2
image=Image.new('RGB',(1280*S,900*S),(10,14,21))
draw=ImageDraw.Draw(image)
font_path=next((p for p in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','C:/Windows/Fonts/arial.ttf'] if Path(p).exists()),None)
def make_font(size,path=''):
    options=['/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf','C:/Windows/Fonts/georgia.ttf'] if 'FRIZQT' in path else [font_path]
    selected=next((p for p in options if p and Path(p).exists()),font_path)
    return ImageFont.truetype(selected,max(1,round(size*S))) if selected else ImageFont.load_default(size=max(1,round(size*S)))
scales={}
def effective(f):
    key=f['exportID']
    if key not in scales:
        parent=by_id.get(f.get('parentID')); scales[key]=f.get('scale',1)*(effective(parent) if parent else 1)
    return scales[key]
def arr(value):
    if isinstance(value,(list,tuple)): return list(value)
    return [value[k] for k in sorted(value,key=lambda k:int(k))] if value else []
def factors(anchor): return (0 if 'LEFT' in anchor else 1 if 'RIGHT' in anchor else .5,0 if 'TOP' in anchor else 1 if 'BOTTOM' in anchor else .5)
def rect(f):
    key=f['exportID']
    if key in rects: return rects[key]
    if f['kind']=='UIParent': r=(0,0,1280,900); rects[key]=r; return r
    p=by_id.get(f.get('parentID')); pr=rect(p) if p else (0,0,1280,900)
    es=effective(f); w,h=f.get('width',0)*es,f.get('height',0)*es
    if f.get('fillParent'): rects[key]=pr; return pr
    if f['kind']=='FontString':
        font=make_font(f.get('fontSize',12)*es,f.get('fontPath',''))
        text=re.sub(r'\|c[0-9a-fA-F]{8}|\|r','',f.get('text',''))
        w=w or max((draw.textlength(line,font=font)/S for line in text.split('\n')),default=0)+1
        h=h or f.get('fontSize',12)*es*1.35
    def target(point):
        point=arr(point); anchor=point[0] if point else 'TOPLEFT'; rel=pr; rel_anchor=anchor; dx=dy=0
        if len(point)>1 and isinstance(point[1],dict) and point[1].get('ref'):
            rel=rect(by_id[point[1]['ref']]); rel_anchor=point[2]; dx=point[3] if len(point)>3 else 0; dy=point[4] if len(point)>4 else 0
        elif len(point)>1 and isinstance(point[1],(int,float)):
            dx=point[1]; dy=point[2] if len(point)>2 else 0
        rx,ry=factors(rel_anchor)
        return factors(anchor), (rel[0]+rel[2]*rx+dx*es,rel[1]+rel[3]*ry-dy*es)
    constraints=[target(p) for p in f.get('points',{}).values()]
    if not constraints: constraints=[target(f.get('point'))]
    (ax,ay),(px,py)=constraints[0]
    for (bx,by),(qx,qy) in constraints[1:]:
        if bx!=ax: w=(qx-px)/(bx-ax)
        if by!=ay: h=(qy-py)/(by-ay)
    r=(px-w*ax,py-h*ay,w,h); rects[key]=r; return r

def color(c,default=(0,0,0)):
    v=arr(c)
    return tuple(round(n*255) for n in v[:3]) if v else default
def box(r):
    x,y,w,h=r; return (round(x*S),round(y*S),round((x+w)*S),round((y+h)*S))

@lru_cache(maxsize=64)
def native_surface(kind,width,height):
    """Substitute a recognizable native skin, without bundling Blizzard art.

    These deterministic gradients only make the offline frame geometry legible;
    the game draws its real textures and atlases when the addon is loaded.
    """
    tile=Image.new('RGBA',(width,height),(0,0,0,0)); skin=ImageDraw.Draw(tile)
    if kind=='parchment':
        for yy in range(height):
            t=yy/max(1,height-1)
            shade=4*math.sin(t*math.pi)-7*t
            skin.line((0,yy,width,yy),fill=(round(216+shade),round(189+shade),round(137+shade),255))
        rng=random.Random(width*100003+height)
        # Faint paper fibres and a worn rim, deliberately unlike an item icon.
        for _ in range(max(40,width*height//2200)):
            x,y=rng.randrange(width),rng.randrange(height)
            skin.line((x,y,min(width,x+rng.randint(4,18)),y),fill=(121,86,45,12),width=1)
        rim=max(2,round(4*S))
        for inset in range(rim):
            skin.rectangle((inset,inset,width-1-inset,height-1-inset),outline=(99,65,30,max(8,65-inset*8)))
    elif kind=='list':
        for yy in range(height):
            shade=round(3*math.cos(yy/max(1,height)*math.pi))
            skin.line((0,yy,width,yy),fill=(18+shade,23+shade,25+shade,255))
        for yy in range(0,height,9*S):
            skin.line((0,yy,width,yy),fill=(51,55,52,30),width=1)
    elif kind=='header':
        # A restrained stand-in for the native carved header art. The live
        # client supplies its own texture; UI text remains a separate region.
        rng=random.Random(width*47+height)
        for yy in range(height):
            t=yy/max(1,height-1)
            shine=13*math.sin(math.pi*t)
            skin.line((0,yy,width,yy),fill=(round(42+shine-13*t),round(28+shine*.65-9*t),round(18+shine*.3-5*t),255))
        for _ in range(max(12,height//3)):
            yy=rng.randrange(height); start=rng.randrange(max(1,width//4))
            skin.line((start,yy,width-rng.randrange(max(1,width//4)),yy),fill=(117,81,36,rng.randrange(12,32)))
        edge=max(1,round(1.2*S))
        skin.line((0,1,width,1),fill=(164,128,65,235),width=edge)
        skin.line((0,height-3,width,height-3),fill=(190,147,68,235),width=edge)
        skin.line((0,height-1,width,height-1),fill=(5,7,9,255),width=edge)
    elif kind=='highlight':
        for xx in range(width):
            strength=math.sin(math.pi*xx/max(1,width-1))**.5
            skin.line((xx,0,xx,height),fill=(223,177,61,round(98*strength)))
    elif kind=='scrollbar':
        skin.rectangle((max(0,width//2-2*S),0,min(width-1,width//2+2*S),height),fill=(48,42,30,235))
        skin.line((width//2,0,width//2,height),fill=(153,125,75,220),width=max(1,S))
    elif kind=='emblem-ring':
        inset=max(1,round(3*S)); thickness=max(1,round(2*S))
        skin.ellipse((inset,inset,width-1-inset,height-1-inset),outline=(22,18,13,255),width=thickness*3)
        skin.ellipse((inset+thickness,inset+thickness,width-1-inset-thickness,height-1-inset-thickness),outline=(182,146,78,255),width=thickness)
        skin.arc((inset,inset,width-1-inset,height-1-inset),190,300,fill=(222,189,113,255),width=max(1,S))
    return tile

def texture_tile(f,width,height):
    asset=str(f.get('texture') or f.get('atlas') or '').replace('\\','/')
    name=asset.lower()
    if f.get('styleRole')=='ornateHeader':
        tile=native_surface('header',width,height).copy()
    elif 'questbg' in name or 'questbackground' in name or 'quest-parchment' in name:
        tile=native_surface('parchment',width,height).copy()
    elif 'ui-questlogtitlehighlight' in name or 'questtitlehighlight' in name:
        tile=native_surface('highlight',width,height).copy()
    elif 'ui-dialogbox-header' in name or 'journal-header' in name:
        tile=native_surface('header',width,height).copy()
    elif 'ui-dialogbox-background' in name or 'questlog-background' in name:
        tile=native_surface('list',width,height).copy()
    elif 'ui-character-scrollbar' in name or 'ui-scrollbar' in name:
        tile=native_surface('scrollbar',width,height).copy()
    elif f.get('styleRole')=='ornateEmblemRing' or 'minimap-trackingborder' in name:
        tile=native_surface('emblem-ring',width,height).copy()
    else:
        # The addon's own approved logo remains an actual asset in previews.
        local=ROOT/asset.replace('Interface/AddOns/','')
        path=next((p for p in [local,Path(str(local)+'.tga'),Path(str(local)+'.png')] if p.is_file()),None)
        if path is None: return None
        tile=Image.open(path).convert('RGBA').resize((width,height),Image.Resampling.LANCZOS)
    tint=arr(f.get('vertexColor'))
    alpha=float(f.get('alpha',1))
    if tint:
        multiplier=Image.new('RGB',tile.size,tuple(round(max(0,min(1,n))*255) for n in tint[:3]))
        original_alpha=tile.getchannel('A')
        tile=ImageChops.multiply(tile.convert('RGB'),multiplier).convert('RGBA')
        tile.putalpha(original_alpha)
        if len(tint)>3: alpha*=tint[3]
    if alpha!=1:
        alpha=max(0,min(1,alpha))
        tile.putalpha(tile.getchannel('A').point(lambda n:round(n*alpha)))
    return tile

def paste_texture(tile,r,target):
    position=(round(r[0]*S),round(r[1]*S))
    if target.mode=='RGBA': target.alpha_composite(tile,position)
    else: target.paste(tile,position,tile)

def native_border(r,f):
    """Approximate Blizzard's thick dialog edge instead of a flat rectangle."""
    left,top,right,bottom=box(r)
    edge_size=float(f.get('backdrop',{}).get('edgeSize',32))
    unit=max(.5,effective(f))*S*edge_size/32
    tint=arr(f.get('border')) or [1,1,1,1]
    def tinted(rgb): return tuple(round(c*tint[i]) for i,c in enumerate(rgb))
    # The alternating dark stone and brass bevel is what distinguishes this
    # native edge from the earlier tooltip-sized hairline.
    rings=[(0,(7,9,10),2),(2,(74,66,48),3),(5,(167,137,79),1),
           (6,(105,90,62),3),(9,(35,32,27),2),(11,(196,160,88),1),
           (12,(20,21,20),2)]
    for inset,c,width in rings:
        k=round(inset*unit); thick=max(1,round(width*unit))
        if right-left>2*k and bottom-top>2*k:
            draw.rectangle((left+k,top+k,right-k,bottom-k),outline=tinted(c),width=thick)
    # Small corner studs follow the border geometry and do not create a new
    # interaction or imply artwork was captured from the live client.
    off=round(7.5*unit); radius=max(2,round(2.1*unit))
    for cx,cy in [(left+off,top+off),(right-off,top+off),(left+off,bottom-off),(right-off,bottom-off)]:
        draw.ellipse((cx-radius,cy-radius,cx+radius,cy+radius),fill=tinted((176,141,75)),outline=tinted((31,27,19)),width=max(1,round(unit)))

def paint_order(f):
    # A texture or font string is a region on its owner, rather than a frame
    # with its own level. Respecting this is essential when shell art is
    # created after the title: BACKGROUND must still stay behind OVERLAY text.
    owner=by_id.get(f.get('parentID')) if f['kind'] in ('Texture','FontString') else f
    level=(owner or f).get('level',0)
    layers={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3,'HIGHLIGHT':4}
    layer=1+layers.get(f.get('drawLayer','OVERLAY' if f['kind']=='FontString' else 'ARTWORK'),2) if f['kind'] in ('Texture','FontString') else 0
    return (level,layer,f['exportID'])
def text_lines(text,font,width):
    lines=[]
    for raw in text.split('\n'):
        line=''
        for word in raw.split(' '):
            attempt=(line+' '+word).strip()
            if line and draw.textlength(attempt,font=font)>width*S: lines.append(line); line=word
            else: line=attempt
        lines.append(line)
    return lines
def scroll_clip(f):
    result=(0,0,1280,900); parent=by_id.get(f.get('parentID'))
    while parent:
        if parent['kind']=='ScrollFrame':
            x,y,w,h=result; a,b,c,d=rect(parent)
            left,top=max(x,a),max(y,b); right,bottom=min(x+w,a+c),min(y+h,b+d)
            result=(left,top,max(0,right-left),max(0,bottom-top))
        parent=by_id.get(parent.get('parentID'))
    return result

overflow=[]
for f in sorted(frames,key=paint_order):
    if not f.get('visible') or f['kind'] in ('UIParent','Tooltip'): continue
    r=rect(f); x,y,w,h=r
    clip=scroll_clip(f); base_draw=draw; layer=None
    if clip!=(0,0,1280,900):
        layer=Image.new('RGBA',image.size,(0,0,0,0)); draw=ImageDraw.Draw(layer)
    if f.get('bg'):
        backdrop=f.get('backdrop',{}); native='UI-DialogBox' in backdrop.get('bgFile','') or 'UI-Tooltip' in backdrop.get('bgFile','')
        tint=color(f['bg']); fill=tuple(round(c*.23) for c in tint) if native else tint
        rgba=arr(f['bg']); alpha=max(0,min(1,float(rgba[3] if len(rgba)>3 else 1)))
        if alpha>=1:
            draw.rectangle(box(r),fill=fill)
        elif alpha>0:
            # Pane surfaces may be border-only above one shared panorama.
            # Composite the actual background alpha on either the main RGB
            # canvas or a scroll-clipped RGBA layer instead of painting it solid.
            tile=Image.new('RGBA',(max(1,round(w*S)),max(1,round(h*S))),fill+(round(alpha*255),))
            paste_texture(tile,r,layer if layer is not None else image)
        draw.rectangle(box(r),outline=color(f.get('border'),(80,68,47)),width=max(1,round((4 if 'UI-DialogBox' in backdrop.get('edgeFile','') else 1)*S*effective(f))))
        if 'UI-DialogBox-Border' in backdrop.get('edgeFile',''):
            native_border(r,f)
    if 'UIPanelButtonTemplate' in f.get('template',''):
        left,top,right,bottom=box(r)
        for yy in range(top,bottom+1):
            t=(yy-top)/max(1,bottom-top); draw.line((left,yy,right,yy),fill=(round(103-52*t),round(29-16*t),round(17-10*t)))
        draw.rectangle((left,top,right,bottom),outline=(148,110,55),width=max(1,round(S*effective(f))))
    if f.get('template')=='UIPanelCloseButton':
        a,b,c,d=box(r); inset=round(9*S*effective(f))
        draw.line((a+inset,b+inset,c-inset,d-inset),fill=(217,204,174),width=max(1,round(2*S*effective(f))))
        draw.line((a+inset,d-inset,c-inset,b+inset),fill=(217,204,174),width=max(1,round(2*S*effective(f))))
    if 'SizeGrabber' in f.get('normalTexture',''):
        for offset in [4,9,14]: draw.line(((x+w-offset)*S,(y+h-3)*S,(x+w-3)*S,(y+h-offset)*S),fill=(174,153,113),width=S)
    if f['kind']=='Slider':
        draw.line(((x+4)*S,(y+h/2)*S,(x+w-4)*S,(y+h/2)*S),fill=(166,134,77),width=3*S)
        fraction=(f.get('value',95)-f.get('minValue',0))/max(1,f.get('maxValue',100)-f.get('minValue',0)); cx=x+fraction*w
        draw.rectangle(box((cx-5,y,10,h)),fill=(214,182,118),outline=(83,60,25),width=S)
    if f['kind']=='Texture':
        if f.get('texture') or f.get('atlas'):
            tile=texture_tile(f,max(1,round(w*S)),max(1,round(h*S)))
            if tile is not None:
                paste_texture(tile,r,layer if layer is not None else image)
            else:
                draw.rectangle(box(r),fill=(36,49,69),outline=(99,115,139),width=S)
                cx,cy=(x+w/2)*S,(y+h/2)*S; radius=min(12,w*.3,h*.3)*S
                draw.polygon([(cx,cy-radius),(cx+radius,cy),(cx,cy+radius),(cx-radius,cy)],fill=(219,182,109))
        elif f.get('color'):
            rgba=arr(f['color']); alpha=rgba[3] if len(rgba)>3 else 1
            alpha*=max(0,min(1,float(f.get('alpha',1))))
            tile=Image.new('RGBA',(max(1,round(w*S)),max(1,round(h*S))),color(f['color'])+(round(alpha*255),))
            paste_texture(tile,r,layer if layer is not None else image)
        owner=by_id.get(f.get('parentID'))
        if owner and 'UI-DialogBox-Border' in owner.get('backdrop',{}).get('edgeFile',''):
            # Backdrop borders are above their owner's background textures.
            # Keep the visible rim when a landscape/veil fills the panel.
            native_border(rect(owner),owner)
    if f['kind']=='CheckButton':
        draw.rectangle(box(r),fill=(16,23,34),outline=(57,69,87),width=S)
        if f.get('checked'):
            draw.line([((x+5)*S,(y+12)*S),((x+10)*S,(y+17)*S),((x+19)*S,(y+6)*S)],fill=(234,190,118),width=2*S)
    if f['kind']=='FontString' and f.get('text'):
        size=f.get('fontSize',12)*effective(f); font=make_font(size,f.get('fontPath',''))
        text=re.sub(r'\|c[0-9a-fA-F]{8}|\|r','',f['text']); lines=text_lines(text,font,w)
        line_h=size*1.35
        if f.get('height',0)>0 and len(lines)*line_h>h+3: overflow.append(dict(id=f['exportID'],text=text[:100],needed=round(len(lines)*line_h),height=h))
        for i,line in enumerate(lines):
            tx=x
            if f.get('justify')=='CENTER': tx=x+(w-draw.textlength(line,font=font)/S)/2
            elif f.get('justify')=='RIGHT': tx=x+w-draw.textlength(line,font=font)/S
            draw.text((round(tx*S),round((y+i*line_h)*S)),line,font=font,fill=color(f.get('color'),(230,235,242)),anchor='lt',stroke_width=1 if f.get('fontFlags')=='OUTLINE' else 0,stroke_fill=(0,0,0))
    if layer is not None:
        region=box(clip); tile=layer.crop(region); image.paste(tile,region,tile)
        draw=base_draw
font=make_font(11)
draw.text((85*S,846*S),'OFFLINE LAYOUT / APPROXIMATE NATIVE SKIN & FONTS / ITEM ICON PLACEHOLDERS / NOT A LIVE GAME CAPTURE',font=font,fill=(131,144,163))
output=ROOT/args.output; image.save(output)
(ROOT/'research'/('layout-review-'+Path(args.layout).stem+'.json')).write_text(json.dumps({'overflow':overflow},indent=2))
print(json.dumps({'preview':str(output),'overflow':overflow},indent=2))

if args.strict and overflow: raise SystemExit('Fixed-height text overflow; review this layout.')
