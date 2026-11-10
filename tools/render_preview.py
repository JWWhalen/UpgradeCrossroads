"""Render the actual Lua frame-tree fixture with font/icon substitutions.

This is a layout preview, never a live-game screenshot. Requires Pillow.
"""
from pathlib import Path
import json, re, argparse
from PIL import Image, ImageDraw, ImageFont

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
def arr(value): return [value[k] for k in sorted(value,key=lambda k:int(k))] if value else []
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
for f in frames:
    if not f.get('visible') or f['kind'] in ('UIParent','Tooltip'): continue
    r=rect(f); x,y,w,h=r
    clip=scroll_clip(f); base_draw=draw; layer=None
    if clip!=(0,0,1280,900):
        layer=Image.new('RGBA',image.size,(0,0,0,0)); draw=ImageDraw.Draw(layer)
    if f.get('bg'):
        backdrop=f.get('backdrop',{}); native='UI-DialogBox' in backdrop.get('bgFile','') or 'UI-Tooltip' in backdrop.get('bgFile','')
        tint=color(f['bg']); fill=tuple(round(c*.23) for c in tint) if native else tint
        draw.rectangle(box(r),fill=fill,outline=color(f.get('border'),(80,68,47)),width=max(1,round((4 if 'UI-DialogBox' in backdrop.get('edgeFile','') else 1)*S*effective(f))))
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
        if f.get('texture'):
            asset=f['texture'].replace('\\','/').replace('Interface/AddOns/','')
            path=ROOT/(asset+'.tga')
            if path.is_file():
                tile=Image.open(path).convert('RGBA').resize((max(1,round(w*S)),max(1,round(h*S))),Image.Resampling.LANCZOS)
                target=layer if layer is not None else image; target.paste(tile,(round(x*S),round(y*S)),tile)
            else:
                draw.rectangle(box(r),fill=(36,49,69),outline=(99,115,139),width=S)
                cx,cy=(x+w/2)*S,(y+h/2)*S; radius=min(12,w*.3,h*.3)*S
                draw.polygon([(cx,cy-radius),(cx+radius,cy),(cx,cy+radius),(cx-radius,cy)],fill=(219,182,109))
        elif f.get('color'):
            rgba=arr(f['color']); alpha=rgba[3] if len(rgba)>3 else 1
            tile=Image.new('RGBA',(max(1,round(w*S)),max(1,round(h*S))),color(f['color'])+(round(alpha*255),))
            if layer is not None: layer.alpha_composite(tile,(round(x*S),round(y*S)))
            else: image.paste(tile,(round(x*S),round(y*S)),tile)
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
