"""Immutable completed workouts. The client keeps mutable drafts on its device."""
import hashlib,json
from pathlib import Path
from uuid import UUID
import sqlalchemy as s
from fastapi import APIRouter,Depends,HTTPException,Query
from fastapi.encoders import jsonable_encoder
from sqlalchemy.exc import IntegrityError
from .db import *
from .auth import me,throttle
from .types import Sync

router=APIRouter(tags=['entrenamientos'])
DATA=Path(__file__).with_name('data')
catalog=json.loads((DATA/'catalog.json').read_text())
rules=json.loads((DATA/'levels.json').read_text())
def seed(c):
    from sqlalchemy.dialects.postgresql import insert as pg
    from sqlalchemy.dialects.sqlite import insert as sq
    stmt=(pg if c.dialect.name=='postgresql' else sq)(exercises)
    c.execute(stmt.on_conflict_do_nothing(index_elements=['id']),[{'id':e['id'],'definition':e} for e in catalog])
    c.commit()
def view_workout(c,w):
    result={k:w[k] for k in ['id','name','notes','bodyweight_kg','started_at','ended_at','version','created_at','updated_at']}
    result['exercises']=[]
    for m in rows(c,s.select(moves).where(moves.c.workout_id==w['id']).order_by(moves.c.position)):
        fields=['id','load_kg','kind','method','block_id','phase','reps','seconds','distance_m','rpe','rir','rest_seconds']
        result['exercises'].append({'id':m['id'],'exercise_id':m['exercise_id'],'superset':m['superset'],'sets':rows(c,s.select(*(sets.c[k] for k in fields)).where(sets.c.move_id==m['id']).order_by(sets.c.position))})
    return jsonable_encoder(result)
def public_record(r):
    return {k:r[k] for k in ['id','owner_id','exercise_id','kind','value','load_kg','reps','achieved_at','status']}
def validate_mode(mode,v):
    if mode in ('time','distance_time'):
        if v.seconds is None or v.load_kg or v.reps is not None:raise HTTPException(422,'La modalidad requiere tiempo, sin carga ni repeticiones')
        if mode=='distance_time' and not v.distance_m:raise HTTPException(422,'Distancia requerida')
    elif v.reps is None or v.seconds is not None or v.distance_m is not None:
        raise HTTPException(422,'Esta modalidad requiere repeticiones')
    if mode=='bodyweight_reps' and v.load_kg:raise HTTPException(422,'Usa la variante lastrada para añadir masa')
def candidates(mode,st):
    # Do not turn short drop/rest-pause mini-sets into standalone PRs.
    if st.kind=='warmup' or st.method!='straight' or not st.reps:return []
    if mode=='bodyweight_reps':return [('bodyweight_reps',st.reps)]
    if mode not in ('weight_reps','weighted_reps') or not st.load_kg:return []
    result=[('max_weight',st.load_kg),('reps_at_weight',st.reps)]
    if mode=='weight_reps' and st.reps<=10:
        result.append(('estimated_1rm',st.load_kg if st.reps==1 else st.load_kg*(1+st.reps/30)))
    return result
@router.get('/exercises')
def library(owner=Depends(me),c=Depends(db)):
    return list(c.scalars(s.select(exercises.c.definition).where(s.or_(exercises.c.owner_id==None,exercises.c.owner_id==owner))))
@router.post('/sync/workouts')
def sync(body:Sync,owner=Depends(me),c=Depends(db)):
    throttle(c,'sync:'+owner,180)
    c.execute(s.select(users.c.id).where(users.c.id==owner).with_for_update())
    op_id,w=str(body.operation_id),body.workout
    fingerprint=hashlib.sha256(json.dumps(w.model_dump(mode='json'),sort_keys=True).encode()).hexdigest()
    old=one(c,s.select(ops).where(ops.c.owner_id==owner,ops.c.operation_id==op_id))
    if old:
        if old['digest']!=fingerprint:raise HTTPException(409,{'code':'operation_reused'})
        return old['response']
    existing=by_id(c,workouts,w.id)
    if existing:
        if existing['owner_id']!=owner:raise HTTPException(404,'Entrenamiento no encontrado')
        raise HTTPException(409,{'code':'finalized','server':view_workout(c,existing)})
    if w.base_version!=0:raise HTTPException(409,{'code':'missing_base'})
    wid=str(w.id)
    created=[]
    try:
        c.execute(workouts.insert().values(id=wid,owner_id=owner,**w.model_dump(exclude={'id','base_version','exercises'})))
        for i,m in enumerate(w.exercises):
            ex=by_id(c,exercises,m.exercise_id)
            if not ex or ex['owner_id'] not in (None,owner):raise HTTPException(422,'Ejercicio no disponible')
            mode=ex['definition']['recording']
            c.execute(moves.insert().values(id=str(m.id),workout_id=wid,exercise_id=str(m.exercise_id),position=i,superset=m.superset))
            for j,st in enumerate(m.sets):
                validate_mode(mode,st)
                c.execute(sets.insert().values(**st.model_dump(mode='json'),move_id=str(m.id),position=j))
                for kind,value in candidates(mode,st):
                    match=[records.c.owner_id==owner,records.c.exercise_id==str(m.exercise_id),records.c.kind==kind]
                    if kind=='reps_at_weight':match.append(records.c.load_kg==st.load_kg)
                    previous=c.scalar(s.select(s.func.max(records.c.value)).where(*match))
                    if previous is None or value>previous+1e-6:
                        rid=uid()
                        c.execute(records.insert().values(id=rid,owner_id=owner,exercise_id=str(m.exercise_id),set_id=str(st.id),kind=kind,value=round(value,4),load_kg=st.load_kg,reps=st.reps,bodyweight_kg=w.bodyweight_kg,achieved_at=w.ended_at))
                        created.append(public_record(by_id(c,records,rid)))
        result=jsonable_encoder({'workout':view_workout(c,by_id(c,workouts,wid)),'new_records':created})
        c.execute(ops.insert().values(owner_id=owner,operation_id=op_id,digest=fingerprint,response=result));c.commit()
        return result
    except IntegrityError:
        c.rollback();raise HTTPException(409,{'code':'uuid_in_use'})
@router.get('/workouts')
def history(after:UUID|None=None,limit:int=Query(50,ge=1,le=100),owner=Depends(me),c=Depends(db)):
    q=s.select(workouts).where(workouts.c.owner_id==owner)
    if after:q=q.where(workouts.c.id>str(after))
    rr=rows(c,q.order_by(workouts.c.id).limit(limit+1))
    return {'items':[view_workout(c,r) for r in rr[:limit]],'next_cursor':rr[limit-1]['id'] if len(rr)>limit else None}
@router.get('/workouts/{workout_id}')
def get_workout(workout_id:UUID,owner=Depends(me),c=Depends(db)):
    w=by_id(c,workouts,workout_id)
    if not w or w['owner_id']!=owner:raise HTTPException(404,'Entrenamiento no encontrado')
    return view_workout(c,w)
@router.get('/records')
def my_records(owner=Depends(me),c=Depends(db)):
    return [public_record(r) for r in rows(c,s.select(records).where(records.c.owner_id==owner).order_by(records.c.achieved_at.desc(),records.c.created_at.desc()).limit(500))]
