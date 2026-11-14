#!/usr/bin/env python3
"""Build LIFTLOG offline exercise library from a pinned Flow Exercise Dataset revision.

Modes:
  python scripts/build_complete_library.py --catalog-only
  python scripts/build_complete_library.py --with-media

Downloads source ZIP, preserves the original 114 LIFTLOG IDs, and generates
UUIDv5 IDs for new entries. Run on server with --catalog-only, then rebuild API.
"""
import argparse
import difflib
import io
import json
import re
import urllib.request
import uuid
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / 'mobile/assets/catalog.json'
BACKEND = ROOT / 'backend/app/data/catalog.json'
MOTION_DATA = ROOT / 'mobile/assets/motion_index.json'
MOTION_DIR = ROOT / 'mobile/assets/flow_frames'
SOURCE = 'https://github.com/ozansozuozgit/flow-exercise-dataset/archive/refs/heads/main.zip'
NAMESPACE = uuid.UUID('d178177f-1294-4587-b0f8-7a32ffda722c')
MUSCLES = {
    'chest': 'pecho', 'back': 'espalda', 'upper back': 'espalda',
    'shoulders': 'hombros', 'upper arms': 'brazos', 'lower arms': 'antebrazos',
    'upper legs': 'piernas', 'lower legs': 'pantorrillas', 'waist': 'abdomen',
    'cardio': 'cardio', 'neck': 'cuello', 'hips': 'glúteos',
    'glutes': 'glúteos', 'core': 'abdomen', 'abs': 'abdomen',
    'quadriceps': 'cuádriceps', 'hamstrings': 'isquiotibiales',
    'biceps': 'bíceps', 'triceps': 'tríceps', 'lats': 'espalda',
    'calves': 'pantorrillas', 'forearms': 'antebrazos',
}
EQUIPMENT = {
    'barbell': 'barra', 'dumbbell': 'mancuernas', 'cable': 'polea',
    'body weight': 'peso corporal', 'bodyweight': 'peso corporal',
    'machine': 'máquina', 'leverage machine': 'máquina',
    'smith machine': 'máquina Smith', 'kettlebell': 'kettlebell',
    'resistance band': 'banda elástica', 'band': 'banda elástica',
    'medicine ball': 'balón medicinal', 'stability ball': 'pelota',
    'ez barbell': 'barra Z', 'weighted': 'lastre', 'assisted': 'asistencia',
}
IMAGES = {'pecho': 'press', 'espalda': 'pull', 'hombros': 'press', 'piernas': 'squat',
          'cuádriceps': 'squat', 'isquiotibiales': 'hinge', 'glúteos': 'hinge',
          'pantorrillas': 'calf', 'cardio': 'cardio', 'abdomen': 'plank',
          'brazos': 'arms', 'bíceps': 'arms', 'tríceps': 'arms', 'antebrazos': 'arms'}


def norm(value):
    return ' '.join(re.findall(r'[a-z0-9]+', str(value).lower()))


def map_group(value):
    text = str(value or '').strip().lower()
    return MUSCLES.get(text, text or 'otros')


def map_equipment(value):
    text = str(value or '').strip().lower()
    return EQUIPMENT.get(text, text or 'otro')


def matching_original(src, original):
    title = norm(src.get('name'))
    choices = [(difflib.SequenceMatcher(None, title, norm(e.get('name_en'))).ratio(), e)
               for e in original if norm(e.get('name_en')) and e.get('name_en')]
    choices.sort(key=lambda pair: pair[0], reverse=True)
    if not choices or choices[0][0] < .96:
        return None
    if len(choices)>1 and choices[0][0]-choices[1][0]<.045:
        return None
    e = choices[0][1]
    # Avoid equating bodyweight with weighted and machine with free weights.
    if norm(src.get('equipment')) not in norm(e.get('name_en')) and norm(e.get('equipment')) not in ('', norm(map_equipment(src.get('equipment')))):
        return None
    return e


def main():
    arg = argparse.ArgumentParser()
    arg.add_argument('--with-media', action='store_true', help='Copy licensed SVG frames as Flutter assets')
    arg.add_argument('--catalog-only', action='store_true', help='Generate catalogs only (server)')
    opts = arg.parse_args()
    if not MOBILE.exists() or not BACKEND.exists():
        raise SystemExit('Run from full LIFTLOG repository: missing base catalog(s)')
    original = json.loads(BACKEND.read_text(encoding='utf-8'))
    # The catalog script is idempotent; keep the original definitions, not previously generated ones.
    original = [e for e in original if not e.get('source_dataset')]
    print('Downloading Flow Exercise Dataset...', flush=True)
    with urllib.request.urlopen(SOURCE,timeout=180) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    path = next((p for p in archive.namelist() if p.endswith('/data/exercises.json')),None)
    if path is None: raise SystemExit('Upstream dataset missing exercises.json')
    prefix = path[:-len('data/exercises.json')]
    source = json.loads(archive.read(path))
    if len(source)<1200: raise SystemExit('Unexpectedly small upstream dataset; refusing incomplete catalog')
    merged=list(original)
    ids={e['id'] for e in original}
    motion={}
    retained=0
    for source_e in source:
        source_id=str(source_e['id']).zfill(4)
        original_e=matching_original(source_e,original)
        uid=original_e['id'] if original_e is not None else str(uuid.uuid5(NAMESPACE,source_id))
        if original_e is not None: retained+=1
        if uid not in ids:
            group=map_group(source_e.get('bodyPart'))
            target=map_group(source_e.get('target'))
            equipment=map_equipment(source_e.get('equipment'))
            en=str(source_e.get('name') or f'Exercise {source_id}').strip()
            instructions=source_e.get('instructions') or []
            if isinstance(instructions,list): description=' '.join(str(x) for x in instructions)
            else: description=str(instructions)
            # English upstream names are kept when no trusted Spanish translation is available.
            mode = ('bodyweight_reps' if equipment=='peso corporal' else
                    'assisted_reps' if equipment=='asistencia' else
                    'weighted_reps' if equipment=='lastre' else 'weight_reps')
            e={'id':uid,'name':en,'name_en':en,'muscle':group,'secondary':[
                map_group(x) for x in source_e.get('secondaryMuscles',[])],
               'equipment':equipment,'recording':mode,'modality':'fuerza',
               'category':group,'target':target,'movement_pattern':str(source_e.get('movementPattern') or ''),
               'description':description or 'Consulta la técnica específica antes de realizar el ejercicio.',
               'technique':description or 'Realiza el movimiento con control.',
               'errors':'Evita movimientos bruscos y ajusta la carga a tu capacidad.',
               'image':'assets/maps/'+IMAGES.get(group,'arms')+'.svg',
               'source_dataset':'flow-exercise-dataset','source_id':source_id}
            merged.append(e)
            ids.add(uid)
        anim=source_e.get('animation')
        if anim and source_e.get('mediaStatus')!='instructions-only':
            frames=anim.get('frames') or []
            if len(frames)<2:continue
            paths=[]
            for i,frame in enumerate(frames):
                rel=f'assets/flow_frames/{source_id}-{i}.svg'
                if opts.with_media:
                    data=archive.read(prefix+frame.lstrip('/'))
                    if b'<svg' not in data[:400]: raise ValueError(f'Not SVG: {frame}')
                    dst=ROOT/'mobile'/rel
                    dst.parent.mkdir(parents=True,exist_ok=True)
                    dst.write_bytes(data)
                paths.append(rel)
            seq=anim.get('sequence') or [0,1,2,1]
            if not all(isinstance(i,int) and 0<=i<len(paths) for i in seq):continue
            motion[uid]={'frames':paths,'sequence':seq,'duration_ms':max(140,int(anim.get('frameDurationMs') or 250))}
    for e in merged:
        e.setdefault('category',e.get('muscle','otros'))
    for filename in (MOBILE,BACKEND):
        filename.parent.mkdir(parents=True,exist_ok=True)
        filename.write_text(json.dumps(merged,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if opts.with_media:
        MOTION_DATA.write_text(json.dumps(motion,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    print(f'LIFTLOG catalog: {len(merged)} exercises ({len(source)} source, {retained} matched existing); {len(motion)} animations indexed.')
    print('WARNING: English names for imported entries; upstream animations are illustrative, not verified coaching.')

if __name__ == '__main__':main()
