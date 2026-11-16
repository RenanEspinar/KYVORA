import os,time
from collections import deque
from contextlib import asynccontextmanager
from uuid import UUID
import sqlalchemy as s
from fastapi import FastAPI,Depends,HTTPException,APIRouter
from fastapi.encoders import jsonable_encoder
from . import auth,training,social,social_login
from .db import *
from .types import Profile,Login
from .auth import me
@asynccontextmanager
async def lifecycle(app):
    with engine.connect() as c:training.seed(c)
    yield
app=FastAPI(title='KYVORA',version='1.0.0-preview.1',docs_url='/api/v1/docs',openapi_url='/api/v1/openapi.json',redoc_url=None,lifespan=lifecycle)
api=APIRouter(prefix='/api/v1')
history=deque(maxlen=100000)
@api.get('/health')
def health():return {'status':'ok','service':'liftlog','version':app.version}
@api.get('/ready')
def ready(c=Depends(db)):
    try:c.execute(s.text('SELECT version_num FROM alembic_version'))
    except s.exc.SQLAlchemyError:raise HTTPException(503,'La base de datos necesita migración')
    return {'status':'ready','service':'liftlog'}
@app.middleware('http')
async def measure(request,call_next):
    start=time.monotonic()
    try:r=await call_next(request)
    except Exception:
        history.append((start,500,time.monotonic()-start));raise
    elapsed=time.monotonic()-start;history.append((start,r.status_code,elapsed));r.headers.update({'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Server-Timing':f'app;dur={elapsed*1000:.1f}'})
    return r
@app.get('/internal/metrics',include_in_schema=False)
def metrics(c=Depends(db)):
    recent=[entry for entry in list(history) if entry[0]>time.monotonic()-60]
    return {'requests_last_minute':len(recent),'errors_5xx_last_minute':sum(status>=500 for _,status,_ in recent),'mean_ms_last_minute':round(1000*sum(duration for _,_,duration in recent)/max(1,len(recent)),2),'users':c.scalar(s.select(s.func.count()).select_from(users)),'media_bytes':c.scalar(s.select(s.func.coalesce(s.func.sum(media.c.bytes),0)))}
def private_profile(c,owner):
    p=one(c,s.select(profiles).where(profiles.c.user_id==owner))
    return {**social.profile(c,owner),'rankings_opt_in':p['rankings_opt_in'],**p['personal']}
@api.get('/profiles/me')
def get_me(owner=Depends(me),c=Depends(db)):return private_profile(c,owner)
@api.patch('/profiles/me')
def edit_me(body:Profile,owner=Depends(me),c=Depends(db)):
    p=one(c,s.select(profiles).where(profiles.c.user_id==owner).with_for_update())
    values=body.model_dump(mode='json',exclude_unset=True)
    fields={k:values.pop(k) for k in list(values) if k in ('display_name','bio','private','rankings_opt_in')}
    if any(v is None for v in fields.values()):raise HTTPException(422,'Campo obligatorio')
    if values.get('bodyweight_kg') and values['bodyweight_kg']!=p['personal'].get('bodyweight_kg'):
        c.execute(measurements.insert().values(owner_id=owner,weight_kg=values['bodyweight_kg']))
    c.execute(profiles.update().where(profiles.c.user_id==owner).values(**fields,personal={**p['personal'],**values}));c.commit();return private_profile(c,owner)
@api.get('/profiles/me/export')
def export(owner=Depends(me),c=Depends(db)):
    result={'profile':private_profile(c,owner),'workouts':[training.view_workout(c,w) for w in rows(c,s.select(workouts).where(workouts.c.owner_id==owner))]}
    for table in [records,posts,comments,likes,media,notices,reports,measurements,templates,exercises]:result[table.name]=rows(c,s.select(table).where(table.c.owner_id==owner))
    result['witness_decisions']=rows(c,s.select(requests).where(s.or_(requests.c.owner_id==owner,requests.c.witness_id==owner)))
    result['follows']=rows(c,s.select(follows).where(s.or_(follows.c.follower==owner,follows.c.followed==owner)))
    return result
@api.delete('/profiles/me',status_code=204)
def erase(body:Login,owner=Depends(me),c=Depends(db)):
    u=by_id(c,users,owner)
    if u['username']!=body.username or not auth.hasher.verify(body.password,u['password_hash']):raise HTTPException(401,'Confirma tus credenciales')
    files=list(c.scalars(s.select(media.c.id).where(media.c.owner_id==owner)))
    affected=list(c.scalars(s.select(requests.c.record_id).where(requests.c.witness_id==owner)))
    c.execute(audit.delete().where(audit.c.actor_id==owner));c.execute(users.delete().where(users.c.id==owner))
    for id in set(affected):social.recount(c,id)
    c.commit()
    for id in files:
        for suffix in ('.jpg','-thumb.jpg'):(social.media_root/(id+suffix)).unlink(missing_ok=True)
for module in (auth,training,social,social_login):api.include_router(module.router)
app.include_router(api)
