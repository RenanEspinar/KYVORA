#!/usr/bin/env python3
"""KYVORA exercise vocabulary: stable custom variants and bilingual search tags.

No external media is copied. Reference URLs are optional links to exercise guides.
The command is idempotent, and is also imported by build_complete_library.py.
"""
from __future__ import annotations
import argparse
import json
import re
import unicodedata
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VARIANTS = Path(__file__).with_name('kyvora_variants.json')
NAMESPACE = uuid.UUID('0a6c2438-f516-4d7c-a98d-925df1cfce8a')
MOBILE = ROOT/'mobile/assets/catalog.json'
BACKEND = ROOT/'backend/app/data/catalog.json'
# Longer keys first so 'single-arm' resolves before 'arm'. These are search tokens,
# not medical translations or promises of equivalence between different exercises.
TERMS = {
    'dumbbells':'mancuernas', 'dumbbell':'mancuerna', 'barbell':'barra',
    'single arm':'unilateral', 'one arm':'unilateral', 'one leg':'unilateral',
    'single leg':'unilateral', 'cables':'poleas', 'cable':'polea',
    'chest':'pecho', 'back':'espalda', 'shoulder':'hombro', 'shoulders':'hombros',
    'lat':'dorsal', 'leg':'pierna', 'legs':'piernas', 'hamstring':'femoral',
    'triceps':'triceps', 'biceps':'biceps', 'glutes':'gluteos', 'glute':'gluteo',
    'flyes':'aperturas', 'fly':'apertura', 'row':'remo', 'pulldown':'jalon',
    'curl':'curl', 'raise':'elevacion', 'press':'press', 'machine':'maquina',
    'incline':'inclinado', 'decline':'declinado', 'seated':'sentado',
    'standing':'de pie', 'lying':'tumbado', 'kneeling':'de rodillas',
    'reverse':'inverso', 'front':'frontal', 'rear':'posterior',
    'low to high':'abajo arriba', 'high to low':'arriba abajo',
    'unilateral':'single arm',
}
ALIASES = {
    'pec deck': ['peck deck','contractora','contractora de pecho','butterfly','butterfly machine','pec dec','maquina mariposa'],
    'reverse pec deck': ['peck deck inverso','contractora inversa','maquina deltoides posterior','rear delt machine'],
    'aperturas en poleas': ['cable fly','cable flies','cross over','cable crossover','cruces polea','aperturas cable'],
    'cruce de poleas alto': ['high cable fly','high to low cable crossover','polea alta pecho'],
    'jalon al pecho': ['lat pulldown','pulley','jalon dorsal','polea al pecho'],
    'sentadilla trasera': ['barbell squat','back squat','squat'],
    'press de banca': ['bench press','chest bench','press plano','press banca'],
    'press con mancuernas': ['dumbbell chest press','press pecho mancuernas'],
    'dominadas pronas': ['pull ups','pullup','pull-ups'],
    'extensión en polea': ['triceps pushdown','tricep cable pushdown','jalon triceps'],
    'elevacion lateral en polea': ['cable lateral raise','polea lateral deltoides'],
    'apertura unilateral en polea de pie': ['cable chest fly one arm','single arm cable fly'],
}

def normalize(value):
    s = unicodedata.normalize('NFKD', str(value or '').lower())
    s = ''.join(ch for ch in s if not unicodedata.combining(ch))
    return ' '.join(re.findall(r'[a-z0-9]+',s))


def translation_tokens(text):
    words = normalize(text).split()
    replaced=[]
    i=0
    keys = {tuple(k.split()): v for k,v in TERMS.items()}
    while i < len(words):
        found=False
        for size in (3,2,1):
            needle=tuple(words[i:i+size])
            if needle in keys:
                replaced.extend(normalize(keys[needle]).split())
                i+=size
                found=True
                break
        if not found:
            replaced.append(words[i]);i+=1
    return ' '.join(replaced)


def infer_laterality(e):
    explicit = str(e.get('laterality') or '')
    if explicit in ('unilateral','bilateral','alternado'):
        return explicit
    s = normalize(' '.join(str(e.get(k) or '') for k in ('name','name_en')))
    if any(t in s for t in ('single arm','one arm','single leg','one leg','unilateral','una mano','un brazo','una pierna','un lado')):
        return 'unilateral'
    if 'alternad' in s or 'alternat' in s:
        return 'alternado'
    return 'bilateral'


def enrich(catalog):
    # Name-equivalent entries from Flow take priority over duplicate curated rows.
    by_en={normalize(e.get('name_en') or e.get('name')): e for e in catalog}
    added=0; reused=0
    for v in json.loads(VARIANTS.read_text(encoding='utf-8')):
        en=normalize(v['name_en'])
        existing=by_en.get(en)
        if existing:
            e=existing; reused+=1
            if e.get('source_dataset')=='flow-exercise-dataset':
                e['name']=v['name']
        else:
            uid=str(uuid.uuid5(NAMESPACE,en))
            e={
                'id':uid, 'name':v['name'], 'name_en':v['name_en'],
                'muscle':v['muscle'], 'secondary':[], 'equipment':v['equipment'],
                'category':v['muscle'], 'recording':'weight_reps', 'modality':'fuerza',
                'image': 'assets/maps/'+('pull' if v['muscle']=='espalda' else 'press' if v['muscle'] in ('pecho','hombros') else 'arms' if v['muscle'] in ('bíceps','tríceps') else 'hinge' if v['muscle'] in ('glúteos','isquiotibiales','cadena posterior') else 'plank' if v['muscle']=='abdomen' else 'squat')+'.svg',
                'description':v['technique'], 'technique':v['technique'],
                'errors':'Evita compensaciones, movimientos bruscos y cargas que alteren el recorrido.',
                'source_dataset':'kyvora-curated',
            }
            if v['name_en']=='Single-leg standing calf raise':
                e['recording']='bodyweight_reps'
            catalog.append(e);by_en[en]=e;added+=1
        # Do not overwrite genuine names/technique of prior entries; add aliases.
        e.setdefault('name_es',v['name'])
        e.setdefault('laterality','unilateral' if any(x in en for x in ('single arm','single leg','one arm','one leg')) or v['name_en']=='Suitcase carry' else 'bilateral')
        e.setdefault('exercise_type',v['type'])
        if v.get('angle'): e.setdefault('angle',v['angle'])
        if v.get('reference_url'): e.setdefault('visual_reference_url',v['reference_url'])
        e['search_aliases']=list(dict.fromkeys([*e.get('search_aliases',[]),*v.get('aliases',[]),v['name'],v['name_en']]))
    for e in catalog:
        e['laterality']=infer_laterality(e)
        variants=[str(e.get(key) or '') for key in ('name','name_en','name_es')]
        known=[*e.get('search_aliases',[])]
        for s in variants:
            if s:
                known.append(translation_tokens(s))
        for s in variants:
            known.extend(ALIASES.get(normalize(s), []))
        # Do not advertise derived typos as the official display name.
        result={normalize(x):str(x).strip() for x in known if len(normalize(x))>=3}
        result={k:v for k,v in result.items() if k not in {normalize(y) for y in variants}}
        e['search_aliases']=sorted(result.values(), key=lambda x: normalize(x))[:24]
        # Use a flag for morphology-specific filters without altering canonical categories.
        e.setdefault('exercise_type','aislamiento' if any(p in normalize(e.get('name_en')) for p in (' fly',' raise',' curl',' extension',' pushdown',' kickback')) else 'otro')
    return {'added':added,'matched_existing':reused,'total':len(catalog)}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--catalog-only',action='store_true')
    ap.add_argument('--check',action='store_true')
    args=ap.parse_args()
    data=json.loads(MOBILE.read_text(encoding='utf-8'))
    result=enrich(data)
    assert len({x['id'] for x in data})==len(data)
    assert all(x.get('search_aliases') is not None for x in data)
    if not args.check:
        from assign_load_profiles import annotate
        annotate(data)
        for dst in (MOBILE,BACKEND):
            dst.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('KYVORA catalog enrichment:',result)

if __name__=='__main__':main()
