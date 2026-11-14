#!/usr/bin/env python3
"""Attach existing Flow SVG animations to LIFTLOG originals using controlled aliases.

Never substitutes a different exercise. Exact normalized token match and equipment
checks only. Ambiguous candidates are reported for manual review, not attached.
Run AFTER build_complete_library.py --with-media and complete_gif_coverage.py.
"""
from __future__ import annotations
import csv
import io
import json
import re
import unicodedata
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'mobile/assets/catalog.json'
MOTIONS = ROOT / 'mobile/assets/motion_index.json'
REPORT = ROOT / 'reports'
SOURCE = 'https://github.com/ozansozuozgit/flow-exercise-dataset/archive/refs/heads/main.zip'

# English translations are search ALIASES, not assertions of match.
# Only exact token-equivalent names and equipment checks may automatically attach.
ALIASES = {
'Press inclinado con barra':'barbell incline bench press',
'Press inclinado con mancuernas':'dumbbell incline bench press',
'Press en el suelo':'dumbbell floor press',
'Press de pecho en máquina':'lever chest press',
'Aperturas en poleas':'cable fly',
'Cruce de poleas alto':'cable high fly',
'Pec deck':'lever pec deck fly',
'Flexiones inclinadas':'incline push up',
'Flexiones declinadas':'decline push up',
'Dominadas pronas':'pull up',
'Dominadas supinas':'chin up',
'Dominadas neutras':'parallel grip pull up',
'Dominadas lastradas':'weighted pull up',
'Jalón al pecho':'cable lat pulldown',
'Jalón con agarre neutro':'cable neutral grip lat pulldown',
'Jalón unilateral':'cable one arm lat pulldown',
'Remo con barra':'barbell bent over row',
'Remo con mancuerna':'dumbbell bent over row',
'Remo sentado en polea':'cable seated row',
'Remo con pecho apoyado':'dumbbell incline row',
'Remo en máquina':'lever seated row',
'Remo en barra T':'lever t bar row',
'Remo invertido':'inverted row',
'Pullover en polea':'cable straight arm pulldown',
'Press militar con barra':'barbell military press',
'Press sentado con mancuernas':'dumbbell seated shoulder press',
'Press de hombros en máquina':'lever shoulder press',
'Press de hombro unilateral':'dumbbell one arm shoulder press',
'Elevaciones frontales':'dumbbell front raise',
'Pájaros con mancuernas':'dumbbell rear lateral raise',
'Pec deck inverso':'lever reverse fly',
'Face pull':'cable face pull',
'Curl con barra Z':'ez barbell curl',
'Curl alternado':'dumbbell alternate biceps curl',
'Curl martillo':'dumbbell hammer curl',
'Curl inclinado':'dumbbell incline curl',
'Curl predicador':'ez barbell preacher curl',
'Curl concentrado':'dumbbell concentration curl',
'Curl inverso':'barbell reverse curl',
'Flexión de muñeca':'dumbbell wrist curl',
'Extensión de muñeca':'dumbbell reverse wrist curl',
'Extensión en polea':'cable triceps pushdown',
'Extensión con cuerda':'cable rope triceps pushdown',
'Extensión sobre cabeza':'dumbbell overhead triceps extension',
'Extensión sobre cabeza en polea':'cable overhead triceps extension',
'Press francés':'ez barbell lying triceps extension',
'Fondos en paralelas':'triceps dip',
'Fondos lastrados':'weighted triceps dip',
'Fondos asistidos':'assisted triceps dip',
'Sentadilla trasera':'barbell squat',
'Sentadilla frontal':'barbell front squat',
'Sentadilla goblet':'dumbbell goblet squat',
'Sentadilla a cajón':'barbell box squat',
'Hack squat':'sled hack squat',
'Prensa de piernas':'sled leg press',
'Sentadilla búlgara':'dumbbell bulgarian split squat',
'Zancada inversa':'dumbbell rear lunge',
'Sentadilla sin carga':'bodyweight squat',
'Zancada sin carga':'bodyweight lunge',
'Extensión de rodilla':'lever leg extension',
'Peso muerto convencional':'barbell deadlift',
'Peso muerto sumo':'barbell sumo deadlift',
'Peso muerto rumano':'barbell romanian deadlift',
'Buenos días':'barbell good morning',
'Curl femoral tumbado':'lever lying leg curl',
'Curl femoral sentado':'lever seated leg curl',
'Curl femoral de pie':'lever standing leg curl',
'Hip thrust con barra':'barbell hip thrust',
'Patada de glúteo en polea':'cable glute kickback',
'Pull-through':'cable pull through',
'Puente de glúteos':'glute bridge',
'Puente unilateral':'single leg glute bridge',
'Abducción en máquina':'lever hip abduction',
'Aducción en máquina':'lever hip adduction',
'Gemelos de pie':'lever standing calf raise',
'Gemelos sentado':'lever seated calf raise',
'Gemelos en prensa':'sled calf press',
'Plancha frontal':'front plank',
'Plancha lateral':'side plank',
'Hollow hold':'hollow hold',
'Crunch':'crunch',
'Elevación de rodillas colgado':'hanging knee raise',
'Elevación de piernas tumbado':'lying leg raise',
'Bird dog':'bird dog',
'Rueda abdominal':'wheel rollout',
'Crunch en polea':'cable crunch',
'Pallof press':'cable pallof press',
'Caminata':'walking',
'Carrera continua':'running',
'Cinta de correr':'walking on treadmill',
'Bicicleta estática':'stationary bike',
'Remo ergómetro':'rowing machine',
'Elíptica':'elliptical machine',
'Escaladora':'stepmill machine',
}

# Matching is intentionally conservative. Synonyms here are equipment forms only.
EQUIP = {
 'barra': {'barbell'}, 'barra z': {'ez barbell'},
 'mancuerna': {'dumbbell'}, 'mancuernas': {'dumbbell'},
 'polea': {'cable'}, 'poleas': {'cable'},
 'máquina': {'leverage machine', 'sled machine', 'smith machine'},
 'peso corporal': {'body weight', 'bodyweight'}, 'lastre': {'weighted'},
 'cinturón de lastre': {'weighted'},
 'barra fija': {'body weight', 'bodyweight', 'weighted'},
 'banco': {'body weight', 'bodyweight'},
 'agarres paralelos': {'body weight', 'bodyweight'},
 'paralelas': {'body weight', 'bodyweight'},
 'rueda': {'wheel roller'}, 'pelota': {'stability ball'},
}

STOP = {'the','a','an','on','with','using','exercise'}
def tokens(s):
 s = ''.join(c for c in unicodedata.normalize('NFKD',str(s).lower()) if not unicodedata.combining(c))
 return tuple(sorted(w for w in re.findall(r'[a-z0-9]+',s) if w not in STOP))

def main():
 catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
 motion = json.loads(MOTIONS.read_text(encoding='utf-8'))
 print('Loading Flow exercise index...',flush=True)
 with urllib.request.urlopen(SOURCE,timeout=180) as r:
  archive=zipfile.ZipFile(io.BytesIO(r.read()))
 path=next((p for p in archive.namelist() if p.endswith('/data/exercises.json')),None)
 if not path: raise RuntimeError('No exercises.json in upstream Flow dataset')
 source=json.loads(archive.read(path))
 prefix=path[:-len('data/exercises.json')]
 lookup={}
 for e in source:
  anim=e.get('animation')
  if anim and anim.get('frames') and len(anim['frames'])>=2:
   lookup.setdefault(tokens(e['name']),[]).append(e)
 report=[]; matched=0; ambiguous=0
 for e in catalog:
  key=str(e['id']); name=e.get('name','')
  if key in motion:continue
  alias=ALIASES.get(name)
  if not alias:continue
  cands=lookup.get(tokens(alias),[])
  allowed=EQUIP.get(str(e.get('equipment','')).lower())
  if allowed:
   cands=[c for c in cands if str(c.get('equipment','')).strip().lower() in allowed]
  if len(cands)!=1:
   report.append({'exercise':name,'alias':alias,'matched':'','reason':'ambiguous' if cands else 'no exact animated match','source_id':'','candidates':len(cands)})
   ambiguous+=bool(cands)
   continue
  cand=cands[0]; sid=str(cand['id']).zfill(4); anim=cand['animation']
  paths=[]
  for i,frame in enumerate(anim['frames']):
   data=archive.read(prefix+frame.lstrip('/'))
   if b'<svg' not in data[:400]: raise ValueError(f'Invalid SVG: {frame}')
   relative=f'assets/flow_frames/original-{sid}-{i}.svg'
   dst=ROOT/'mobile'/relative
   dst.parent.mkdir(parents=True,exist_ok=True)
   dst.write_bytes(data)
   paths.append(relative)
  seq=anim.get('sequence') or [0,1,2,1]
  if not all(isinstance(x,int) and 0<=x<len(paths) for x in seq):continue
  motion[key]={'frames':paths,'sequence':seq,'duration_ms':max(140,int(anim.get('frameDurationMs') or 250)),'source':'flow-svg-exact-match','source_id':sid}
  matched+=1
  report.append({'exercise':name,'alias':alias,'matched':cand['name'],'reason':'exact token + equipment','source_id':sid,'candidates':1})
 MOTIONS.write_text(json.dumps(motion,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
 REPORT.mkdir(parents=True,exist_ok=True)
 # Keep the audit in sync: previous script already generated its summary before
 # we added the safe matches. Update both machine and human-readable results.
 original_summary=REPORT/'motion_priority_summary.json'
 gif_count=sum(bool(motion.get(str(e['id']),{}).get('gif')) for e in catalog)
 svg_count=sum(bool(motion.get(str(e['id']),{}).get('frames')) for e in catalog)
 remaining=[e for e in catalog if str(e['id']) not in motion]
 summary={'total':len(catalog),'authorized_gifs':gif_count,'flow_svg':svg_count,'need_original':len(remaining)}
 original_summary.write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
 queue=[{'id':e['id'],'exercise':e.get('name',''),'category':e.get('category',e.get('muscle','')),
         'equipment':e.get('equipment',''),'source_id':e.get('source_id',''),
         'status':'missing','origin':'needs-original-art'} for e in remaining]
 (REPORT/'needs_original_animation.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 with (REPORT/'motion_priority_report.csv').open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.DictWriter(f,fieldnames=['id','exercise','category','equipment','source_id','status','origin']);w.writeheader()
  for e in catalog:
   m=motion.get(str(e['id']),{})
   status='animated' if m else 'missing'
   origin='provided-gif' if m.get('gif') else ('flow-svg' if m.get('frames') else 'needs-original-art')
   w.writerow({'id':e['id'],'exercise':e.get('name',''),'category':e.get('category',e.get('muscle','')),
               'equipment':e.get('equipment',''),'source_id':e.get('source_id',''),
               'status':status,'origin':origin})
 print('Updated coverage:',summary)
 with (REPORT/'original_motion_reconciliation.csv').open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.DictWriter(f,fieldnames=['exercise','alias','matched','reason','source_id','candidates']);w.writeheader();w.writerows(report)
 print(f'Exact equipment-compatible original matches: {matched}; no match or ambiguous: {len(report)-matched}; ambiguous: {ambiguous}')
 print('The imported instructions-only entries remain unresolved unless separately supplied with licensed media.')

if __name__=='__main__':main()
