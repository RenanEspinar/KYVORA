#!/usr/bin/env python3
"""Prefer matching exercise-specific GIFs; preserve Flow SVG when unavailable.

Primary source: user-supplied GIF files licensed for LIFTLOG (matching Exercises Dataset metadata).
Secondary source: existing Flow Exercise Dataset SVG sequences.
Final fallback: static image, exported to a production queue.

The upstream Exercises Dataset metadata is MIT, but the GIFs are copyright Gym visual;
this tool does not fetch or relicense media from their repository.
"""
import argparse
import csv
import json
import re
import shutil
import unicodedata
from collections import defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/'mobile/assets/catalog.json'
MOTIONS=ROOT/'mobile/assets/motion_index.json'
MEDIA=ROOT/'media/exercise_gifs'   # user-provided, authorized media only
GIF_ASSETS=ROOT/'mobile/assets/exercise_gifs'
REPORTS=ROOT/'reports'


def normalized(s):
    x=unicodedata.normalize('NFKD',str(s or '').lower())
    x=''.join(c for c in x if not unicodedata.combining(c))
    return ' '.join(re.findall('[a-z0-9]+',x))


def accepted_gif(p):
    if not p.is_file() or p.stat().st_size<32 or p.stat().st_size>30*1024*1024:
        return False
    with p.open('rb') as f:
        return f.read(6) in (b'GIF87a',b'GIF89a')


def load_source_metadata(path):
    if not path: return {}
    source=json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(source,list): raise ValueError('Metadata must be a JSON list')
    by_id={}; by_name=defaultdict(list)
    for x in source:
        i=str(x.get('id','')).zfill(4)
        if i:by_id[i]=x
        by_name[normalized(x.get('name'))].append(x)
    return {'id':by_id,'name':by_name}


def choose_source(entry,src):
    if not src:return None
    # IDs alone are not sufficient: independently named datasets can have different ID assignments.
    sid=str(entry.get('source_id') or '').zfill(4)
    name=normalized(entry.get('name_en') or entry.get('name'))
    candidate=src['id'].get(sid)
    if candidate and normalized(candidate.get('name'))==name:return candidate
    unique=src['name'].get(name,[])
    if len(unique)!=1:return None
    return unique[0]


def candidate_files(e,external):
    keys=[str(e['id'])]
    if e.get('source_id'):keys.append(str(e['source_id']).zfill(4))
    if external:
        keys.append(str(external.get('id','')).zfill(4))
        media_id=str(external.get('media_id') or '')
        if media_id and re.fullmatch('[a-zA-Z0-9_-]{1,120}',media_id): keys.append(media_id)
        gif=external.get('gif_url')
        if gif:
            filename=Path(str(gif)).name
            if re.fullmatch('[a-zA-Z0-9_.-]{1,160}',filename):keys.append(filename.removesuffix('.gif'))
    result=[]
    for key in dict.fromkeys(keys):
        if not re.fullmatch('[a-zA-Z0-9_-]{1,120}',key):continue
        result.append(MEDIA/(key+'.gif'))
    return result


def build(metadata):
    catalog=json.loads(CATALOG.read_text(encoding='utf-8'))
    motions=json.loads(MOTIONS.read_text(encoding='utf-8'))
    src=load_source_metadata(metadata)
    GIF_ASSETS.mkdir(parents=True,exist_ok=True)
    REPORTS.mkdir(parents=True,exist_ok=True)
    rows=[]; primary=0; secondary=0; static=0
    for e in catalog:
        eid=str(e['id'])
        source=choose_source(e,src)
        status='missing'; origin='none'
        # Priority 1: exercise-specific authorized GIF from Exercises Dataset or custom media.
        for candidate in candidate_files(e,source):
            if not accepted_gif(candidate):continue
            target=GIF_ASSETS/(eid+'.gif')
            shutil.copyfile(candidate,target)
            motions[eid]={'gif':'assets/exercise_gifs/'+target.name,'source':'user-supplied-gif'}
            status='animated'; origin='provided-gif';primary+=1
            break
        else:
            # Priority 2: actual Flow frames (already prepared by existing builder).
            existing=motions.get(eid,{})
            if existing.get('frames') and existing.get('sequence'):
                status='animated';origin='flow-svg';secondary+=1
            else:
                # Priority 3: queue for custom animation, keep a static thumbnail.
                motions.pop(eid,None)
                status='missing';origin='needs-original-art';static+=1
        rows.append({'id':eid,'exercise':e.get('name',''),'category':e.get('category',e.get('muscle','')),
                     'equipment':e.get('equipment',''),'source_id':e.get('source_id',''),
                     'primary_match_id':source.get('id','') if source else '',
                     'status':status,'origin':origin})
    MOTIONS.write_text(json.dumps(motions,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    with (REPORTS/'motion_priority_report.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    queue=[r for r in rows if r['status']=='missing']
    (REPORTS/'needs_original_animation.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2),encoding='utf-8')
    summary={'total':len(rows),'authorized_gifs':primary,'flow_svg':secondary,'need_original':static}
    (REPORTS/'motion_priority_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(summary)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--exercises-dataset-json',type=Path,help='Optional metadata file from Exercises Dataset (MIT); GIFs must be supplied separately with rights')
    a=p.parse_args()
    build(a.exercises_dataset_json)
