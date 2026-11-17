#!/usr/bin/env python3
"""Bind curated KYVORA illustrations to exact exercise names and verify APK packaging.

Never guess semantic matches: a visual is added only if the normalized
exercise name is an exact match. Existing GIF/Flow motions retain priority.
"""
import argparse
import json
import unicodedata
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'mobile/assets'
CATALOG = ASSETS / 'catalog.json'
RULES = ASSETS / 'illustration_rules.json'
INDEX = ASSETS / 'illustration_index.json'

def normalize(value):
    return ' '.join(''.join(
        c for c in unicodedata.normalize('NFKD', str(value or '').lower())
        if not unicodedata.combining(c)
    ).split())

def build():
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    rules = json.loads(RULES.read_text(encoding='utf-8'))
    names = {normalize(k): v for k,v in rules.items()}
    if len(names) != len(rules):
        raise ValueError('Ambiguous, duplicate normalized illustration names')
    for label,path in rules.items():
        asset = ROOT / 'mobile' / path
        if not asset.is_file() or asset.stat().st_size < 500:
            raise ValueError(f'Invalid illustration {label}: {asset}')
        with asset.open('rb') as f:
            header=f.read(12)
            if header[:4] != b'RIFF' or header[8:12] != b'WEBP':
                raise ValueError(f'Not a valid WebP container: {asset}')
    assigned={}
    matched_names=set()
    for ex in catalog:
        matches={names[n] for n in (normalize(ex.get('name')),normalize(ex.get('name_en'))) if n in names}
        if len(matches)>1:
            raise ValueError(f'Conflicting illustration candidates: {ex["name"]}')
        if matches:
            assigned[str(ex['id'])]=matches.pop()
            matched_names.update(n for n in (normalize(ex.get('name')),normalize(ex.get('name_en'))) if n in names)
    # Every manually curated name must still exist in the source catalog.
    missed=sorted(set(names)-matched_names)
    if missed:
        raise ValueError(f'Catalog exercises renamed; fix illustration rules: {missed}')
    INDEX.write_text(json.dumps(assigned,indent=2,ensure_ascii=False,sort_keys=True)+'\n',encoding='utf-8')
    print(f'KYVORA: {len(assigned)} exact illustrations bound; {len(catalog)} total exercises')
    return assigned

def apk_check(apk, index):
    with zipfile.ZipFile(apk,'r') as z:
        entries=set(z.namelist())
        missing=[p for p in index.values() if 'assets/flutter_assets/'+p not in entries]
        if missing:
            raise ValueError(f'APK is missing {len(missing)} illustrations: {missing[:5]}')
    print(f'APK verified: all {len(index)} exact KYVORA illustrations are included')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--apk',type=Path)
    args=parser.parse_args()
    index=build()
    if args.apk: apk_check(args.apk,index)
