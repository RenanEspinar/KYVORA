#!/usr/bin/env python3
"""Assign a human-readable resistance-entry rule to *every* catalog exercise.

The recorded load_kg stays compatible with LIFTLOG/KYVORA's existing API:
* bar: bar + 2 * plates per side, or direct total
* paired dumbbells: combined external mass of both dumbbells
* single implement: mass of the implement in one hand
* machines: nominal selected resistance, not measured mechanical output
* dual cables: sum of the two displayed stacks
* weighted/assisted bodyweight: additional load / indicated assistance only

No body mass is silently added. Avoid rating loads across unlike machines.
Every entry is classified deterministically; ambiguous cases are tagged for review,
and the mobile form allows overriding the entry method per exercise.
"""
from __future__ import annotations
import argparse
import csv
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / 'mobile/assets/catalog.json'
BACKEND = ROOT / 'backend/app/data/catalog.json'
REPORTS = ROOT / 'reports'
VALID = {'barbell', 'dumbbell_pair', 'dumbbell_single', 'cable_pair',
         'cable_single', 'machine', 'plate_machine', 'single', 'bodyweight', 'added', 'assisted', 'none'}


def norm(x):
    s = unicodedata.normalize('NFKD', str(x or '').lower())
    return re.sub(r'\s+', ' ', re.sub('[^a-z0-9]+', ' ', ''.join(ch for ch in s if not unicodedata.combining(ch)))).strip()


def has(x, parts):
    return any(re.search(p, x) for p in parts)


def classify(ex):
    mode = str(ex.get('recording') or '').strip().lower()
    eq = norm(ex.get('equipment'))
    title = norm(' '.join(str(ex.get(k) or '') for k in ('name', 'name_en')))
    unilateral = has(title, [r'\bunilateral\b', r'\bone arm\b', r'\bsingle arm\b',
                            r'\bone hand\b', r'\bsingle hand\b', r'\buna mano\b',
                            r'\bun brazo\b', r'\bunilateral\b', r'\bone leg\b',
                            r'\bsingle leg\b', r'\buna pierna\b'])
    alternating = has(title, [r'\balternad', r'\balternat'])
    meta = {'kind': 'none', 'confidence': 'rule', 'unilateral': unilateral,
            'alternating': alternating, 'default_bar_kg': 0}

    if mode in ('time', 'distance_time'):
        meta['kind'] = 'none'
    elif mode == 'bodyweight_reps':
        meta['kind'] = 'bodyweight'
    elif mode == 'weighted_reps':
        meta['kind'] = 'added'
    elif mode == 'assisted_reps':
        meta['kind'] = 'assisted'
    elif has(eq, [r'\bsmith\b', r'\bmaquina\b', r'\bmachine\b', r'\bleverage\b',
                       r'\bselectorized\b', r'\bsled\b', r'\bprensa\b']):
        plate_loaded = has(title, [r'\bplate loaded\b', r'\bprensa de piernas\b',
                                   r'\bleg press\b', r'\bhack squat\b', r'\bsled leg press\b'])
        meta['kind'] = 'plate_machine' if plate_loaded else 'machine'
        meta['confidence'] = 'needs_review' if plate_loaded or 'sled' in eq else 'rule'
    elif has(eq, [r'\bpoleas\b', r'\bcables\b']) or has(title, [r'\bcable crossover\b',
                    r'\bcable fly\b', r'\bcruce de poleas\b', r'\baperturas en poleas\b']):
        meta['kind'] = 'cable_pair' if not unilateral else 'cable_single'
    elif has(eq, [r'\bpolea\b', r'\bcable\b']):
        meta['kind'] = 'cable_single'
    elif has(eq, [r'\bmancuernas\b', r'\bdumbbells\b', r'\bdumbbell\b', r'\bmancuerna\b']):
        # Name/specific equipment takes precedence. Alternating curls generally use two weights.
        single = unilateral or ('mancuerna' in eq.split() and 'mancuernas' not in eq) or has(title, [
            r'\bconcentrado\b', r'\bconcentration\b', r'\bremo con mancuerna\b',
            r'\bsingle dumbbell\b', r'\bfront raise one\b'])
        if alternating:
            single = False
        meta['kind'] = 'dumbbell_single' if single else 'dumbbell_pair'
        # Imported "dumbbell" doesn't always identify number; users can override per exercise.
        if eq in ('dumbbell', 'dumbbells') and not unilateral and not alternating:
            meta['confidence'] = 'needs_review'
    elif has(eq, [r'\bbarra\b', r'\bbarbell\b', r'\bez bar\b', r'\bolympic bar\b']):
        meta['kind'] = 'barbell'
        # A 20 kg bar is only a suggested default for standard Olympic bars.
        meta['default_bar_kg'] = 0 if has(eq + ' ' + title, [r'\bz\b', r'\bez\b',
            r'\bhexagonal\b', r'\btrap\b', r'\bbarra t\b', r'\bt bar\b', r'\bfixed\b']) else 20
        if meta['default_bar_kg'] == 0:
            meta['confidence'] = 'needs_review'
    elif has(eq, [r'\bkettlebell\b', r'\bdisco\b', r'\bplate\b', r'\bmedicine ball\b',
                 r'\bbalon\b', r'\bweighted\b', r'\blast re\b']):
        meta['kind'] = 'single'
    elif has(eq, [r'\bpeso corporal\b', r'\bbodyweight\b', r'\bbody weight\b',
                  r'\bbarra fija\b', r'\bparalelas\b', r'\bbanco\b', r'\bninguno\b']):
        meta['kind'] = 'bodyweight' if mode == 'bodyweight_reps' else 'single'
        if mode == 'weight_reps':
            meta['confidence'] = 'needs_review'
    else:
        meta['kind'] = 'single'
        meta['confidence'] = 'needs_review'
    return meta


def annotate(exercises):
    for ex in exercises:
        ex['load_profile'] = classify(ex)
    return exercises


def audit(exercises):
    REPORTS.mkdir(parents=True, exist_ok=True)
    with (REPORTS / 'load_profiles.csv').open('w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['id', 'exercise', 'equipment', 'recording', 'entry_method', 'confidence', 'unilateral'])
        for ex in exercises:
            p = ex['load_profile']
            w.writerow([ex['id'], ex.get('name', ''), ex.get('equipment', ''),
                       ex.get('recording', ''), p['kind'], p['confidence'], p['unilateral']])
    c = Counter(e['load_profile']['kind'] for e in exercises)
    summary = {'total': len(exercises), 'methods': dict(c),
               'needs_review': sum(e['load_profile']['confidence'] == 'needs_review' for e in exercises),
               'unassigned': sum(e['load_profile']['kind'] not in VALID for e in exercises)}
    (REPORTS / 'load_profiles.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    catalog = json.loads(MOBILE.read_text(encoding='utf-8'))
    assert isinstance(catalog, list) and catalog
    assert len({x['id'] for x in catalog}) == len(catalog)
    if args.check:
        missing = [e.get('id') for e in catalog if not isinstance(e.get('load_profile'), dict) or e['load_profile'].get('kind') not in VALID]
        if missing:
            raise SystemExit(f'Missing or invalid load profiles: {len(missing)}; sample {missing[:4]}')
    else:
        annotate(catalog)
        for file in [MOBILE, BACKEND]:
            file.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Load profiles:', audit(catalog))


if __name__ == '__main__':
    main()
