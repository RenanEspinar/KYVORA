"""Privacy, published views and witness decisions are enforced on the server."""
import io,os
from pathlib import Path
from datetime import datetime,timezone
from typing import Literal
from uuid import UUID
import sqlalchemy as s
from fastapi import APIRouter,Depends,HTTPException,Query,File,UploadFile
from fastapi.responses import FileResponse
from PIL import Image,ImageOps,UnidentifiedImageError
from .db import *
from .auth import me,throttle
from .training import view_workout,public_record,rules
from .types import Publish,Comment,Witness,Decision,Report

router=APIRouter(tags=['comunidad'])
media_root=Path(os.environ.get('MEDIA_DIR','./media'))
def blocked(c,a,b):
    return bool(c.scalar(s.select(s.exists().where(s.or_(s.and_(blocks.c.blocker==a,blocks.c.target==b),s.and_(blocks.c.blocker==b,blocks.c.target==a))))))
def profile(c,owner):
    return one(c,s.select(users.c.id,users.c.username,profiles.c.display_name,profiles.c.bio,profiles.c.private).join(profiles,profiles.c.user_id==users.c.id).where(users.c.id==owner))
def permitted(viewer):
    approved=s.exists().where(follows.c.follower==viewer,follows.c.followed==posts.c.owner_id,follows.c.approved.is_(True))
    denied=s.exists().where(s.or_(s.and_(blocks.c.blocker==viewer,blocks.c.target==posts.c.owner_id),s.and_(blocks.c.target==viewer,blocks.c.blocker==posts.c.owner_id)))
    public=s.exists().where(profiles.c.user_id==posts.c.owner_id,profiles.c.private.is_(False))
    return s.and_(~denied,s.or_(posts.c.owner_id==viewer,s.and_(posts.c.visibility!='private',approved),s.and_(posts.c.visibility=='public',public)))
def require_post(c,pid,viewer):
    p=one(c,s.select(posts).where(posts.c.id==str(pid),permitted(viewer)))
    if not p:raise HTTPException(404,'Publicación no encontrada')
    return p
def notify(c,target,actor,kind,resource):
    if actor!=target and not blocked(c,target,actor):c.execute(notices.insert().values(owner_id=target,actor_id=actor,kind=kind,resource_id=resource))
def public_post(c,p,viewer):
    result={k:p[k] for k in ('id','text','visibility','created_at','media_id')}
    result['author']=profile(c,p['owner_id'])
    result['reactions']=c.scalar(s.select(s.func.count()).select_from(likes).where(likes.c.post_id==p['id']))
    result['reacted']=bool(c.scalar(s.select(s.exists().where(likes.c.post_id==p['id'],likes.c.owner_id==viewer))))
    result['comments']=c.scalar(s.select(s.func.count()).select_from(comments).where(comments.c.post_id==p['id']))
    if p['record_id']:result['record']=public_record(by_id(c,records,p['record_id']))
    if p['workout_id']:
        w=view_workout(c,by_id(c,workouts,p['workout_id']))
        result['workout']={'name':w['name'],'exercises':[{'name':by_id(c,exercises,m['exercise_id'])['definition']['name'],'sets':[{k:st[k] for k in ('load_kg','reps','seconds','distance_m')} for st in m['sets']]} for m in w['exercises']]}
    return result
def paginate(c,table,query,before,limit):
    if before:
        try:time,id=before.rsplit('|',1);time=datetime.fromisoformat(time);UUID(id)
        except ValueError:raise HTTPException(422,'Cursor incorrecto')
        query=query.where(s.or_(table.c.created_at<time,s.and_(table.c.created_at==time,table.c.id<id)))
    rr=rows(c,query.order_by(table.c.created_at.desc(),table.c.id.desc()).limit(limit+1))
    cursor=rr[limit-1]['created_at'].isoformat()+'|'+rr[limit-1]['id'] if len(rr)>limit else None
    return rr[:limit],cursor
@router.get('/users/search')
def search(username:str=Query(min_length=3,max_length=24),owner=Depends(me),c=Depends(db)):
    u=c.scalar(s.select(users.c.id).where(users.c.username==username.lower()))
    return [profile(c,u)] if u and not blocked(c,u,owner) else []
@router.post('/posts',status_code=201)
def publish(body:Publish,owner=Depends(me),c=Depends(db)):
    throttle(c,'post:'+owner,40,3600)
    if not(body.text.strip() or body.workout_id or body.record_id or body.media_id):raise HTTPException(422,'Publicación vacía')
    for table,key in [(workouts,body.workout_id),(records,body.record_id),(media,body.media_id)]:
        if key:
            r=by_id(c,table,key)
            if not r or r['owner_id']!=owner:raise HTTPException(404,'Recurso no encontrado')
    pid=uid();c.execute(posts.insert().values(id=pid,owner_id=owner,**body.model_dump(mode='json')));c.commit()
    return public_post(c,by_id(c,posts,pid),owner)
@router.get('/posts')
def feed(before:str|None=None,limit:int=Query(20,ge=1,le=50),owner=Depends(me),c=Depends(db)):
    rr,cursor=paginate(c,posts,s.select(posts).where(permitted(owner)),before,limit)
    return {'items':[public_post(c,r,owner) for r in rr],'next_cursor':cursor}
@router.delete('/posts/{pid}',status_code=204)
def delete_post(pid:UUID,owner=Depends(me),c=Depends(db)):
    n=c.execute(posts.delete().where(posts.c.id==str(pid),posts.c.owner_id==owner)).rowcount
    if not n:raise HTTPException(404,'Publicación no encontrada')
    c.commit()
@router.put('/posts/{pid}/reaction',status_code=204)
def react(pid:UUID,owner=Depends(me),c=Depends(db)):
    from sqlalchemy.dialects.postgresql import insert as pg
    from sqlalchemy.dialects.sqlite import insert as sq
    p=require_post(c,pid,owner)
    added=c.execute((pg if c.dialect.name=='postgresql' else sq)(likes).values(post_id=p['id'],owner_id=owner).on_conflict_do_nothing()).rowcount
    if added:notify(c,p['owner_id'],owner,'reaction',p['id'])
    c.commit()
@router.delete('/posts/{pid}/reaction',status_code=204)
def unreact(pid:UUID,owner=Depends(me),c=Depends(db)):
    require_post(c,pid,owner);c.execute(likes.delete().where(likes.c.post_id==str(pid),likes.c.owner_id==owner));c.commit()
@router.post('/posts/{pid}/comments',status_code=201)
def comment(pid:UUID,body:Comment,owner=Depends(me),c=Depends(db)):
    throttle(c,'comment:'+owner,90,3600);p=require_post(c,pid,owner);id=uid()
    c.execute(comments.insert().values(id=id,post_id=str(pid),owner_id=owner,text=body.text));notify(c,p['owner_id'],owner,'comment',str(pid));c.commit();return {'id':id}
@router.get('/posts/{pid}/comments')
def get_comments(pid:UUID,before:str|None=None,owner=Depends(me),c=Depends(db)):
    require_post(c,pid,owner)
    rr,cursor=paginate(c,comments,s.select(comments).where(comments.c.post_id==str(pid)),before,50)
    return {'items':[{'id':r['id'],'text':r['text'],'author':profile(c,r['owner_id']),'created_at':r['created_at']} for r in rr if not blocked(c,owner,r['owner_id'])],'next_cursor':cursor}
@router.delete('/comments/{id}',status_code=204)
def delete_comment(id:UUID,owner=Depends(me),c=Depends(db)):
    r=by_id(c,comments,id)
    if not r or owner not in (r['owner_id'],by_id(c,posts,r['post_id'])['owner_id']):raise HTTPException(404,'Comentario no encontrado')
    c.execute(comments.delete().where(comments.c.id==str(id)));c.commit()
@router.post('/follows/{id}')
def follow(id:UUID,owner=Depends(me),c=Depends(db)):
    id=str(id);throttle(c,'follow:'+owner,50,3600);p=profile(c,id)
    if id==owner or not p or blocked(c,owner,id):raise HTTPException(404,'Usuario no disponible')
    c.execute(s.select(users.c.id).where(users.c.id==owner).with_for_update())
    f=one(c,s.select(follows).where(follows.c.follower==owner,follows.c.followed==id))
    approved=f['approved'] if f else not p['private']
    if not f:
        c.execute(follows.insert().values(follower=owner,followed=id,approved=approved));notify(c,id,owner,'follow' if approved else 'follow_request',owner)
    c.commit();return {'approved':approved}
@router.get('/follows/requests')
def incoming(owner=Depends(me),c=Depends(db)):
    return [profile(c,id) for id in c.scalars(s.select(follows.c.follower).where(follows.c.followed==owner,follows.c.approved.is_(False)))]
@router.put('/follows/{id}/approve',status_code=204)
def approve(id:UUID,owner=Depends(me),c=Depends(db)):
    n=c.execute(follows.update().where(follows.c.follower==str(id),follows.c.followed==owner).values(approved=True)).rowcount
    if not n:raise HTTPException(404,'Solicitud no encontrada')
    c.commit()
@router.delete('/follows/{id}',status_code=204)
def unfollow(id:UUID,owner=Depends(me),c=Depends(db)):
    c.execute(follows.delete().where(follows.c.follower==owner,follows.c.followed==str(id)));c.commit()
@router.put('/users/{id}/block',status_code=204)
def block(id:UUID,owner=Depends(me),c=Depends(db)):
    id=str(id)
    if owner==id or not by_id(c,users,id):raise HTTPException(422,'Usuario no disponible')
    from sqlalchemy.dialects.postgresql import insert as pg
    from sqlalchemy.dialects.sqlite import insert as sq
    c.execute((pg if c.dialect.name=='postgresql' else sq)(blocks).values(blocker=owner,target=id).on_conflict_do_nothing())
    c.execute(follows.delete().where(follows.c.follower.in_([owner,id]),follows.c.followed.in_([owner,id])))
    c.execute(notices.delete().where(notices.c.owner_id.in_([owner,id]),notices.c.actor_id.in_([owner,id])));c.commit()
@router.get('/notifications')
def notifications(owner=Depends(me),c=Depends(db)):
    return [{**n,'actor':profile(c,n['actor_id'])} for n in rows(c,s.select(notices).where(notices.c.owner_id==owner).order_by(notices.c.created_at.desc()).limit(100))]
@router.post('/reports',status_code=201)
def report(body:Report,owner=Depends(me),c=Depends(db)):
    throttle(c,'report:'+owner,20,3600)
    if body.resource_type=='post':require_post(c,body.resource_id,owner)
    id=uid();c.execute(reports.insert().values(id=id,owner_id=owner,**body.model_dump(mode='json')));c.commit();return {'id':id}
def request_view(c,v):
    return {**v,'record':public_record(by_id(c,records,v['record_id'])),'requester':profile(c,v['owner_id']),'witness':profile(c,v['witness_id'])}
def recount(c,id):
    count=c.scalar(s.select(s.func.count()).select_from(requests).where(requests.c.record_id==id,requests.c.state=='approved'))
    needed=int(os.environ.get('REQUIRED_CONFIRMERS','1'))
    if not 1<=needed<=5:raise RuntimeError('REQUIRED_CONFIRMERS must be 1..5')
    c.execute(records.update().where(records.c.id==id).values(status='confirmed' if count>=needed else 'self_declared'))
@router.post('/verifications',status_code=201)
def verification(body:Witness,owner=Depends(me),c=Depends(db)):
    throttle(c,'witness:'+owner,40,3600)
    r=one(c,s.select(records).where(records.c.id==str(body.record_id),records.c.owner_id==owner).with_for_update())
    if not r:raise HTTPException(404,'PR no encontrado')
    witness=c.scalar(s.select(users.c.id).where(users.c.username==body.witness_username))
    if not witness or owner==witness or blocked(c,owner,witness):raise HTTPException(422,'Testigo no disponible')
    old=one(c,s.select(requests).where(requests.c.record_id==r['id'],requests.c.witness_id==witness))
    if old:return request_view(c,old)
    id=uid();flag=bool(c.scalar(s.select(s.exists().where(requests.c.owner_id==witness,requests.c.witness_id==owner,requests.c.state=='approved'))))
    c.execute(requests.insert().values(id=id,record_id=r['id'],owner_id=owner,witness_id=witness,flag=flag))
    notify(c,witness,owner,'verification_request',id)
    c.execute(audit.insert().values(actor_id=owner,action='request',resource_id=id));c.commit()
    return request_view(c,by_id(c,requests,id))
@router.get('/verifications')
def verifications(owner=Depends(me),c=Depends(db)):
    return [request_view(c,r) for r in rows(c,s.select(requests).where(s.or_(requests.c.owner_id==owner,requests.c.witness_id==owner)).order_by(requests.c.created_at.desc()).limit(100)) if not blocked(c,r['owner_id'],r['witness_id'])]
@router.post('/verifications/{id}/decision')
def decide(id:UUID,body:Decision,owner=Depends(me),c=Depends(db)):
    v=by_id(c,requests,id)
    if not v or v['witness_id']!=owner or blocked(c,owner,v['owner_id']):raise HTTPException(404,'Solicitud no encontrada')
    c.execute(s.select(records.c.id).where(records.c.id==v['record_id']).with_for_update())
    v=by_id(c,requests,id)
    if v['state']==body.decision:return request_view(c,v)
    if (v['state'],body.decision) not in [('pending','approved'),('pending','rejected'),('approved','revoked')]:raise HTTPException(409,'Decisión incompatible con el estado actual')
    flag=v['flag'] or bool(c.scalar(s.select(s.exists().where(requests.c.owner_id==owner,requests.c.witness_id==v['owner_id'],requests.c.state=='approved'))))
    c.execute(requests.update().where(requests.c.id==str(id)).values(state=body.decision,reason=body.reason,flag=flag))
    recount(c,v['record_id'])
    c.execute(audit.insert().values(actor_id=owner,action='witness_decision',resource_id=str(id),detail={'from':v['state'],'to':body.decision,'reason':body.reason,'evidence':'in_person_attestation','reciprocal':flag}))
    notify(c,v['owner_id'],owner,'verification_decision',str(id));c.commit()
    return request_view(c,by_id(c,requests,id))
@router.get('/rankings/rules')
def levels():return rules
@router.get('/rankings')
def ranking(exercise_id:UUID,status:Literal['self_declared','confirmed','verified']='self_declared',season:int|None=Query(None,ge=2000,le=2199),category:str|None=None,city:str|None=None,country:str|None=None,gym:str|None=None,owner=Depends(me),c=Depends(db)):
    rule=rules['exercises'].get(str(exercise_id));result={'items':[],'rules_version':rules['version']}
    if not rule or status=='verified':return result
    ratio=records.c.load_kg/records.c.bodyweight_kg
    allowed=~s.exists().where(s.or_(s.and_(blocks.c.blocker==owner,blocks.c.target==records.c.owner_id),s.and_(blocks.c.target==owner,blocks.c.blocker==records.c.owner_id)))
    q=s.select(records.c.id,ratio.label('ratio'),s.func.row_number().over(partition_by=records.c.owner_id,order_by=[ratio.desc(),records.c.achieved_at,records.c.id]).label('rownum')).join(profiles,profiles.c.user_id==records.c.owner_id).where(records.c.kind=='max_weight',records.c.exercise_id==str(exercise_id),records.c.bodyweight_kg>0,profiles.c.rankings_opt_in.is_(True),allowed)
    if status=='confirmed':q=q.where(records.c.status=='confirmed')
    if season:q=q.where(records.c.achieved_at>=datetime(season,1,1,tzinfo=timezone.utc),records.c.achieved_at<datetime(season+1,1,1,tzinfo=timezone.utc))
    for k,value in [('category',category),('city',city),('country',country),('gym',gym)]:
        if value:q=q.where(profiles.c.personal[k].as_string()==value)
    best=q.subquery()
    for index,r in enumerate(rows(c,s.select(best).where(best.c.rownum==1).order_by(best.c.ratio.desc(),best.c.id).limit(100)),1):
        rec=by_id(c,records,r['id']);ratio=float(r['ratio']);level=max(i for i,v in enumerate(rule['thresholds']) if ratio>=v)
        result['items'].append({'rank':index,'athlete':profile(c,rec['owner_id']),'record':public_record(rec),'ratio':round(ratio,3),'level':rules['labels'][level]})
    return result
@router.post('/media',status_code=201)
def upload(file:UploadFile=File(),owner=Depends(me),c=Depends(db)):
    throttle(c,'media:'+owner,20,3600)
    raw=file.file.read(5*1024**2+1)
    if len(raw)>5*1024**2:raise HTTPException(413,'Máximo 5 MiB')
    try:
        with Image.open(io.BytesIO(raw)) as im:
            if im.format not in ('PNG','JPEG','WEBP') or im.width*im.height>20_000_000 or getattr(im,'n_frames',1)>1:raise ValueError()
            im=ImageOps.exif_transpose(im).convert('RGB');im.thumbnail((1600,1600));out=io.BytesIO();im.save(out,'JPEG',quality=82)
            im.thumbnail((320,320));thumb=io.BytesIO();im.save(thumb,'JPEG',quality=74)
    except (OSError,ValueError,UnidentifiedImageError,Image.DecompressionBombError):raise HTTPException(415,'Imagen no válida')
    c.execute(s.select(users.c.id).where(users.c.id==owner).with_for_update())
    # A shared row serializes disk allocation across simultaneous uploads.
    from sqlalchemy.dialects.postgresql import insert as pg
    from sqlalchemy.dialects.sqlite import insert as sq
    allocation=(pg if c.dialect.name=='postgresql' else sq)(limits).values(key='media-global-budget',window=0,count=0)
    c.execute(allocation.on_conflict_do_update(index_elements=['key'],set_={'count':limits.c.count}))
    size=out.tell()+thumb.tell();used=c.scalar(s.select(s.func.coalesce(s.func.sum(media.c.bytes),0)).where(media.c.owner_id==owner))
    if used+size>int(os.environ.get('MEDIA_QUOTA_BYTES',50*1024**2)):raise HTTPException(413,'Cuota personal alcanzada')
    total=c.scalar(s.select(s.func.coalesce(s.func.sum(media.c.bytes),0)))
    if total+size>int(os.environ.get('MEDIA_TOTAL_BYTES',5*1024**3)):raise HTTPException(507,'Almacenamiento de medios completo')
    id=uid();media_root.mkdir(parents=True,exist_ok=True);paths=[media_root/(id+'.jpg'),media_root/(id+'-thumb.jpg')]
    try:
        paths[0].write_bytes(out.getvalue());paths[1].write_bytes(thumb.getvalue())
        c.execute(media.insert().values(id=id,owner_id=owner,bytes=size));c.commit()
    except Exception:
        for p in paths:p.unlink(missing_ok=True)
        raise
    return {'id':id,'bytes':size}
@router.get('/media/{id}')
def get_media(id:UUID,thumbnail:bool=False,owner=Depends(me),c=Depends(db)):
    m=by_id(c,media,id)
    if not m or (m['owner_id']!=owner and not c.scalar(s.select(posts.c.id).where(posts.c.media_id==str(id),permitted(owner)).limit(1))):raise HTTPException(404,'Imagen no encontrada')
    path=media_root/(str(id)+('-thumb.jpg' if thumbnail else '.jpg'))
    if not path.is_file():raise HTTPException(404,'Imagen no encontrada')
    return FileResponse(path,media_type='image/jpeg',headers={'Cache-Control':'private, no-store'})
