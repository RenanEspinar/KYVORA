import hashlib,secrets,time
import sqlalchemy as s
from fastapi import APIRouter,Depends,HTTPException,Request
from fastapi.security import HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy.dialects.postgresql import insert as pg
from sqlalchemy.dialects.sqlite import insert as sq
from sqlalchemy.exc import IntegrityError
from .db import db,users,profiles,sessions,refreshes,limits,one,by_id,uid
from .types import Login,Register,Recover,Refresh

router=APIRouter(prefix='/auth',tags=['auth'])
hasher=PasswordHash.recommended()
dummy=hasher.hash(secrets.token_urlsafe(24))
bearer=HTTPBearer(auto_error=False)
def digest(value): return hashlib.sha256(value.encode()).hexdigest()
def throttle(c,key,maximum,period=60):
    bucket=int(time.time())//period
    stmt=(pg if c.dialect.name=='postgresql' else sq)(limits).values(key=digest(key),window=bucket,count=1)
    n=c.scalar(stmt.on_conflict_do_update(index_elements=['key'],set_={'window':bucket,'count':s.case((limits.c.window==bucket,limits.c.count+1),else_=1)}).returning(limits.c.count))
    c.commit()
    if n>maximum:raise HTTPException(429,'Demasiados intentos',headers={'Retry-After':str(period)})
def issue(c,user_id,session_id=None):
    access,refresh=secrets.token_urlsafe(36),secrets.token_urlsafe(48)
    expiry=int(time.time())
    if session_id is None:
        session_id=uid()
        c.execute(sessions.insert().values(id=session_id,user_id=user_id,access_hash=digest(access),access_until=expiry+900,expires=expiry+30*86400))
    else:
        c.execute(sessions.update().where(sessions.c.id==session_id).values(access_hash=digest(access),access_until=expiry+900))
    c.execute(refreshes.insert().values(digest=digest(refresh),session_id=session_id))
    return {'access_token':access,'refresh_token':refresh,'token_type':'bearer','expires_in':900,'user_id':user_id}
def me(token=Depends(bearer),c=Depends(db)):
    row=one(c,s.select(sessions).where(sessions.c.access_hash==digest(token.credentials),sessions.c.access_until>int(time.time()),sessions.c.expires>int(time.time()),sessions.c.revoked.is_(False))) if token else None
    if row is None:raise HTTPException(401,'Sesión expirada o no válida',headers={'WWW-Authenticate':'Bearer'})
    return row['user_id']
@router.post('/register',status_code=201)
def register(body:Register,request:Request,c=Depends(db)):
    throttle(c,'reg:'+request.client.host,30,3600)
    user_id,code=uid(),secrets.token_urlsafe(32)
    try:c.execute(users.insert().values(id=user_id,username=body.username,password_hash=hasher.hash(body.password),recovery_hash=digest(code)))
    except IntegrityError:raise HTTPException(409,'El nombre de usuario ya existe')
    c.execute(profiles.insert().values(user_id=user_id,display_name=body.display_name,personal={'units':'metric','category':'abierta'}))
    result=issue(c,user_id);c.commit()
    return {**result,'recovery_code':code}
@router.post('/login')
def login(body:Login,request:Request,c=Depends(db)):
    throttle(c,'login-ip:'+request.client.host,100)
    throttle(c,'login:'+body.username,10)
    u=one(c,s.select(users).where(users.c.username==body.username))
    valid=hasher.verify(body.password,u['password_hash'] if u else dummy)
    if not u or not valid:raise HTTPException(401,'Credenciales incorrectas')
    result=issue(c,u['id']);c.commit();return result
@router.post('/refresh')
def refresh(body:Refresh,c=Depends(db)):
    t=one(c,s.select(refreshes).where(refreshes.c.digest==digest(body.refresh_token)).with_for_update())
    if not t:raise HTTPException(401,'Sesión inválida')
    sess=one(c,s.select(sessions).where(sessions.c.id==t['session_id']).with_for_update())
    if not sess or sess['revoked'] or sess['expires']<=int(time.time()):raise HTTPException(401,'Sesión expirada')
    if t['used']:
        c.execute(sessions.update().where(sessions.c.id==sess['id']).values(revoked=True));c.commit();raise HTTPException(401,'Reutilización de token')
    c.execute(refreshes.update().where(refreshes.c.digest==t['digest']).values(used=True))
    result=issue(c,sess['user_id'],sess['id']);c.commit();return result
@router.post('/logout',status_code=204)
def logout(owner=Depends(me),c=Depends(db)):
    c.execute(sessions.update().where(sessions.c.user_id==owner).values(revoked=True));c.commit()
@router.post('/recover')
def recover(body:Recover,request:Request,c=Depends(db)):
    throttle(c,'recover:'+request.client.host,10,3600)
    u=one(c,s.select(users).where(users.c.username==body.username).with_for_update())
    if not u or not secrets.compare_digest(digest(body.recovery_code),u['recovery_hash']):raise HTTPException(400,'Código o usuario incorrecto')
    code=secrets.token_urlsafe(32)
    c.execute(users.update().where(users.c.id==u['id']).values(password_hash=hasher.hash(body.new_password),recovery_hash=digest(code)))
    c.execute(sessions.update().where(sessions.c.user_id==u['id']).values(revoked=True));c.commit()
    return {'recovery_code':code}
