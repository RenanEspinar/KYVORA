#!/usr/bin/env python3
"""Create offline per-exercise quick-reference cards for entries without motions.

All photos are original AI-produced illustrative references licensed for use here.
No web scraping or third-party exercise photos are bundled. These cards indicate a
broad movement/equipment family, never a medically or biomechanically validated form.
Run AFTER motion reconciliation; reuses motion index as coverage source.
"""
from pathlib import Path
import json, re, unicodedata, textwrap
from PIL import Image, ImageDraw, ImageFont, ImageOps
from kyvora_visual_types_extra import visual_type_extra

ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/'mobile/assets/catalog.json'
MOTIONS=ROOT/'mobile/assets/motion_index.json'
OUT=ROOT/'mobile/assets/guides'
SOURCES=ROOT/'scripts/guide_photos'
INDEX=ROOT/'mobile/assets/guide_index.json'

def normalize(s):
    return ''.join(c for c in unicodedata.normalize('NFKD',str(s or '').lower()) if not unicodedata.combining(c))

def visual_type(ex):
    """Use a realistic pose photo ONLY for an accurately matching movement."""
    n=normalize(' '.join(str(ex.get(k) or '') for k in ('name','name_en')))
    e=normalize(ex.get('equipment') or '')
    if 'reverse pec deck' in n or 'pec deck invers' in n:return 'reverse_pec_deck'
    if 'pec deck' in n or 'peck deck' in n or 'contractora' in n:return 'pec_deck'
    if 'face pull' in n:return 'face_pull'
    if 'bulgar' in n:return 'bulgarian_split_squat'
    if 'hip thrust' in n:return 'hip_thrust'
    if 'peso muerto rumano' in n or 'romanian deadlift' in n:return 'romanian_deadlift'
    if 'step up' in n or 'step-up' in n:return 'stepup'
    if ('single arm' in n or 'one arm' in n or 'unilateral' in n) and ('fly' in n or 'apertura' in n) and ('cable' in n or 'polea' in n):return 'single_cable_fly'
    if 'high to low cable fly' in n or 'cable fly high' in n:return 'high_cable_fly'
    if ('apertura' in n or 'fly' in n) and ('polea' in n or 'cable' in n):return 'cable_crossover'
    if ('elevacion lateral' in n or 'lateral raise' in n) and ('polea' in n or 'cable' in n):return 'lateral_raise'
    if ('triceps pushdown' in n or 'extension en polea' in n) and ('triceps' in n or 'tríceps' in n):return 'triceps_pushdown'
    if 'curl' in n and ('polea' in n or 'cable' in n):return 'cable_curl'
    if ('remo sentado en polea' in n or 'seated cable row' in n):return 'cable_row'
    if 'band pull apart' in n:return 'band_pullapart'
    if ('sentadilla sin peso' in n or 'bodyweight squat' in n):return 'squat'
    return visual_type_extra(ex)

def equipment_diagram(im,ex):
    """Neutral icon for unknown movements; never portray a different exercise."""
    draw=ImageDraw.Draw(im)
    eq=normalize(ex.get('equipment') or '')
    muscle=normalize(ex.get('muscle') or '')
    draw.rounded_rectangle((34,45,340,385),25,fill='#101e33',outline='#25456b',width=3)
    draw.text((55,75),'EQUIPO / REFERENCIA',font=font(15,True),fill='#60a5fa')
    cx,cy=185,223
    steel='#c8d4e2'; blue='#3b82f6'
    if any(x in eq for x in ('barra','barbell','smith')):
        draw.rounded_rectangle((64,cy-6,307,cy+6),5,fill=steel)
        for a,b in ((76,101),(110,124),(246,260),(269,294)):
            draw.rounded_rectangle((a,cy-47,b,cy+47),4,fill=blue)
    elif any(x in eq for x in ('mancuern','dumbbell','kettlebell')):
        for xc in (112,255):
            draw.rounded_rectangle((xc-40,cy-7,xc+40,cy+7),6,fill=steel)
            draw.rounded_rectangle((xc-44,cy-40,xc-25,cy+40),5,fill=blue)
            draw.rounded_rectangle((xc+25,cy-40,xc+44,cy+40),5,fill=blue)
    elif any(x in eq for x in ('polea','cable','pulley')):
        draw.line((75,330,75,150,290,150,290,330),fill=steel,width=7)
        for xc in (75,290):draw.ellipse((xc-15,135,xc+15,165),outline=blue,width=6)
        draw.line((75,150,167,260),fill=blue,width=5)
        draw.line((290,150,201,260),fill=blue,width=5)
        draw.arc((163,248,206,294),0,180,fill=steel,width=6)
    elif any(x in eq for x in ('maquina','machine','prensa')):
        draw.line((80,330,80,125,275,125,275,330),fill=steel,width=9)
        draw.rounded_rectangle((128,170,225,260),10,fill=blue)
        draw.line((180,260,180,330),fill=steel,width=10)
    else:
        draw.ellipse((131,141,233,243),outline=blue,width=7)
        draw.line((182,245,182,335),fill=steel,width=10)
        draw.line((182,268,102,300),fill=steel,width=8)
        draw.line((182,268,261,300),fill=steel,width=8)
    label=(str(ex.get('equipment') or ex.get('muscle') or 'Referencia general'))[:28]
    draw.text((58,347),label,font=font(17),fill='#bfdbfe')

def font(size, bold=False):
    path='/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if bold else '')+'.ttf'
    try:return ImageFont.truetype(path,size)
    except OSError:return ImageFont.load_default()

def wrap_lines(draw,txt,size,width,max_lines=4):
    f=font(size)
    words=txt.split()
    rows=[];line=''
    for word in words:
        test=(line+' '+word).strip()
        if draw.textbbox((0,0),test,font=f)[2]>width and line:
            rows.append(line);line=word
        else: line=test
    if line:rows.append(line)
    if len(rows)>max_lines: rows=rows[:max_lines];rows[-1]=(rows[-1][:35]+'…')
    return rows

def render(ex,source,dest):
    w,h=800,440
    im=Image.new('RGB',(w,h),'#0b1424')
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((12,12,w-12,h-12),20,fill='#152439',outline='#294465',width=2)
    if source is None:
        equipment_diagram(im,ex)
    else:
        img=Image.open(source).convert('RGB')
        cover=ImageOps.fit(img,(350,412),method=Image.Resampling.LANCZOS,centering=(.5,.5))
        im.paste(cover,(14,14))
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((363,14,786,426),14,fill='#152439')
    d.text((384,32),'KYVORA / GUÍA RÁPIDA',font=font(17,True),fill='#60a5fa')
    name=str(ex.get('name') or ex.get('name_en') or 'Ejercicio')
    title=wrap_lines(d,name,25,370,3)
    y=74
    for row in title:
        d.text((384,y),row,font=font(25,True),fill='#f1f5f9');y+=31
    y=max(180,y+6)
    muscles=str(ex.get('muscle') or ex.get('category') or 'Ejercicio')
    equipment=str(ex.get('equipment') or 'Equipo variable')
    d.text((384,y),'MÚSCULO · EQUIPO',font=font(13,True),fill='#60a5fa');y+=22
    for row in wrap_lines(d,f'{muscles} · {equipment}',16,374,2):
        d.text((384,y),row,font=font(16),fill='#dbeafe');y+=22
    y=max(274,y+14)
    d.line((384,y,762,y),fill='#37618c',width=2);y+=10
    # When an exercise has its own technique description, show one short cue.
    cue=str(ex.get('technique') or ex.get('description') or '').replace('\n',' ').strip()
    if cue and len(cue)>16:
        for line in wrap_lines(d,cue,13,375,3):
            d.text((384,y),line,font=font(13),fill='#dbeafe');y+=21
    else:
        d.text((384,y),'Consulta la ficha técnica antes de cargar.',font=font(13),fill='#dbeafe');y+=21
    d.text((384,397),'Ilustración orientativa · verificar técnica',font=font(11),fill='#94a3b8')
    im.save(dest,'JPEG',quality=82,optimize=True,progressive=True)

def main():
    catalog=json.loads(CATALOG.read_text(encoding='utf8'))
    motions=json.loads(MOTIONS.read_text(encoding='utf8')) if MOTIONS.exists() else {}
    OUT.mkdir(parents=True,exist_ok=True)
    for old in OUT.glob('guide_*.jpg'):old.unlink()
    index={}
    for ex in catalog:
        eid=str(ex['id'])
        if eid in motions:continue
        kind=visual_type(ex)
        source=SOURCES/(kind+'.jpg') if kind else None
        if source is not None and not source.is_file():raise RuntimeError(f'Falta el recurso original {source}')
        dest=OUT/('guide_'+eid+'.jpg')
        render(ex,source,dest)
        index[eid]='assets/guides/'+dest.name
    INDEX.write_text(json.dumps(index,ensure_ascii=False,sort_keys=True,indent=2)+'\n',encoding='utf8')
    assert len(index)+len(set(motions)&{str(x['id']) for x in catalog})==len(catalog)
    print(f'KYVORA guide cards: {len(index)} / {len(catalog)} exercises without motion; verified index.')
if __name__=='__main__':main()
