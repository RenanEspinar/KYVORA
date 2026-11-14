from pathlib import Path
from uuid import NAMESPACE_URL,uuid5
import json
root=Path(__file__).resolve().parents[1]
items=[]
for line in (root/'scripts/catalog.txt').read_text().splitlines():
    if line.startswith('#'):
        muscle,secondary,mode,figure,technique,errors=line[1:].split('|')
        continue
    name,english,equipment,cue=line.split('|')
    id=str(uuid5(NAMESPACE_URL,'https://liftlog.local/exercises/'+english.lower().replace(' ','-')))
    items.append(dict(id=id,name=name,name_en=english,muscle=muscle,secondary=secondary.split(',') if secondary else [],equipment=equipment,recording=mode,modality='cardio' if muscle=='cardio' else 'fuerza',description=cue,technique=technique,errors=errors,image='assets/maps/'+figure+'.svg'))
for path in ['mobile/assets/catalog.json','backend/app/data/catalog.json']:
    dest=root/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(json.dumps(items,ensure_ascii=False,indent=2))
regions={'press':[(64,49,18,7)],'pull':[(64,59,15,13)],'arms':[(40,65,6,11),(88,65,6,11)],'row':[(64,56,16,9)],'squat':[(54,106,7,13),(74,106,7,13)],'hinge':[(54,94,8,13),(74,94,8,13)],'calf':[(54,135,5,10),(74,135,5,10)],'plank':[(64,72,11,11)],'cardio':[(64,52,7,6)]}
folder=root/'mobile/assets/maps';folder.mkdir(exist_ok=True)
for name,points in regions.items():
    accents=''.join(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#B5FF39"/>' for x,y,rx,ry in points)
    (folder/(name+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 160"><rect width="128" height="160" rx="16" fill="#1C2024"/><circle cx="64" cy="24" r="11" fill="#637078"/><path d="M48 40 Q64 34 80 40 L79 86 77 146 67 146 64 102 61 146 51 146 49 86Z" fill="#637078"/><path d="M48 45L39 67 34 91M80 45L89 67 94 91" fill="none" stroke="#637078" stroke-width="9" stroke-linecap="round"/>'+accents+'</svg>')
rule={'version':'LL-2026.1','labels':['Bronce','Plata','Oro','Platino','Diamante','Élite'],'exercises':{next(e['id'] for e in items if e['name']==n):{'name':n,'thresholds':vals} for n,vals in [('Press de banca',[0,.5,.8,1.1,1.4,1.7]),('Sentadilla trasera',[0,.75,1.1,1.5,1.9,2.3]),('Peso muerto convencional',[0,1,1.4,1.8,2.2,2.6])]}}
for p in ['backend/app/data/levels.json','mobile/assets/levels.json']:(root/p).write_text(json.dumps(rule,ensure_ascii=False,indent=2))
assert len(items)>=100 and len({e['id'] for e in items})==len(items)
print(len(items),'exercises')
