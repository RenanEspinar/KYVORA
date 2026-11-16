"""KYVORA external identity login (Google ID tokens and classic Facebook tokens).

No OAuth token may be used as a KYVORA API token. Provider/subject are verified
before assigning an existing account. Email is never used for auto-linking.
"""
import hashlib
import hmac
import os
import smtplib
from email.message import EmailMessage
import secrets
import time
import httpx
import jwt
import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, EmailStr
from sqlalchemy.exc import IntegrityError
from .db import db, auth_identities, email_challenges, users, profiles, one, uid
from . import auth

router=APIRouter(prefix='/auth',tags=['auth'])

class SocialToken(BaseModel):
    token: str=Field(min_length=30,max_length=8192)

_jwks = jwt.PyJWKClient('https://www.googleapis.com/oauth2/v3/certs', cache_jwk_set=True, lifespan=3600, timeout=5)

def configured(provider):
    if provider=='google': return bool(os.getenv('GOOGLE_WEB_CLIENT_ID'))
    if provider=='facebook': return bool(os.getenv('FACEBOOK_APP_ID') and os.getenv('FACEBOOK_APP_SECRET'))
    if provider=='email': return all(os.getenv(x) for x in ('SMTP_HOST','SMTP_USER','SMTP_PASSWORD','SMTP_FROM','AUTH_CODE_PEPPER'))
    return False

@router.get('/providers')
def providers():
    return {p:configured(p) for p in ('google','facebook','email')}

def verify_google(token):
    client=os.getenv('GOOGLE_WEB_CLIENT_ID')
    if not client: raise HTTPException(503,'Google aún no está configurado')
    try:
        key=_jwks.get_signing_key_from_jwt(token).key
        claims=jwt.decode(token,key,algorithms=['RS256'],audience=client,
            issuer=['https://accounts.google.com','accounts.google.com'],leeway=30,
            options={'require':['iss','sub','aud','exp','iat']})
    except (jwt.PyJWTError,ValueError,KeyError,OSError) as exc:
        raise HTTPException(401,'Identidad de Google no válida') from exc
    sub=str(claims['sub'])
    if not sub or len(sub)>255: raise HTTPException(401,'Identidad de Google no válida')
    return sub, str(claims.get('name') or 'Atleta KYVORA')[:60]

def verify_facebook(token):
    app_id=os.getenv('FACEBOOK_APP_ID')
    secret=os.getenv('FACEBOOK_APP_SECRET')
    if not app_id or not secret: raise HTTPException(503,'Facebook aún no está configurado')
    proof=hmac.new(secret.encode(),token.encode(),hashlib.sha256).hexdigest()
    try:
        with httpx.Client(timeout=7) as client:
            debug=client.get('https://graph.facebook.com/v27.0/debug_token',params={
                'input_token':token,'access_token':f'{app_id}|{secret}'})
            debug.raise_for_status()
            data=debug.json().get('data') or {}
            if not data.get('is_valid') or str(data.get('app_id'))!=app_id or not data.get('user_id'):
                raise HTTPException(401,'Token de Facebook no válido')
            expires=data.get('expires_at')
            if expires and int(expires)<=int(time.time()):
                raise HTTPException(401,'Token de Facebook vencido')
            profile=client.get('https://graph.facebook.com/v27.0/me',params={
                'fields':'id,name','access_token':token,'appsecret_proof':proof})
            profile.raise_for_status()
            person=profile.json()
    except (httpx.HTTPError, ValueError, KeyError) as exc:
        raise HTTPException(401,'No se pudo verificar Facebook') from exc
    if str(person.get('id'))!=str(data['user_id']):
        raise HTTPException(401,'Identidad de Facebook inconsistente')
    return str(data['user_id']),str(person.get('name') or 'Atleta KYVORA')[:60]

def find_or_create_user(c,provider,sub,name):
    ident=one(c,sa.select(auth_identities).where(auth_identities.c.provider==provider,auth_identities.c.subject==sub))
    if ident:return ident['user_id']
    # Never link by matching email; its verified status varies by provider.
    uid_new=uid()
    name=name.strip() or 'Atleta KYVORA'
    suffix=hashlib.sha256(f'{provider}:{sub}'.encode()).hexdigest()[:15]
    username=f'{provider[:2]}_{suffix}_{secrets.token_hex(2)}'
    recovery_hash=auth.digest(secrets.token_urlsafe(32))
    c.execute(users.insert().values(id=uid_new,username=username,
        password_hash=auth.hasher.hash(secrets.token_urlsafe(40)),recovery_hash=recovery_hash))
    c.execute(profiles.insert().values(user_id=uid_new,display_name=name[:60],
        personal={'units':'metric','category':'abierta'}))
    c.execute(auth_identities.insert().values(provider=provider,subject=sub,user_id=uid_new))
    return uid_new

@router.post('/social/{provider}')
def social_login(provider:str,body:SocialToken,request:Request,c=Depends(db)):
    if provider not in ('google','facebook'):
        raise HTTPException(404,'Proveedor no admitido')
    auth.throttle(c,'social:'+request.client.host,40,3600)
    # All remote verification happens before writing a user.
    sub,name=verify_google(body.token) if provider=='google' else verify_facebook(body.token)
    try:
        user_id=find_or_create_user(c,provider,sub,name)
        session=auth.issue(c,user_id)
        c.commit()
        return session
    except IntegrityError:
        c.rollback()
        # Concurrent first login: resolve only an already linked provider-subject.
        ident=one(c,sa.select(auth_identities).where(auth_identities.c.provider==provider,auth_identities.c.subject==sub))
        if not ident: raise HTTPException(409,'Vuelve a intentarlo')
        session=auth.issue(c,ident['user_id']);c.commit();return session


class EmailRequest(BaseModel):
    email: EmailStr

class EmailVerify(EmailRequest):
    code: str=Field(pattern=r'^[0-9]{8}$')

def email_digest(email,code):
    return hmac.new(os.environ['AUTH_CODE_PEPPER'].encode(),f'{email}|{code}'.encode(),hashlib.sha256).hexdigest()

@router.post('/email/request')
def request_email_code(body:EmailRequest,request:Request,c=Depends(db)):
    if not configured('email') or len(os.environ['AUTH_CODE_PEPPER'])<32:
        raise HTTPException(503,'Correo todavía no está configurado')
    email=str(body.email).lower()
    auth.throttle(c,'email-ip:'+request.client.host,10,3600)
    auth.throttle(c,'email-target:'+email,5,3600)
    code=f'{secrets.randbelow(100000000):08d}'
    c.execute(email_challenges.delete().where(email_challenges.c.email==email))
    c.execute(email_challenges.insert().values(email=email,code_hash=email_digest(email,code),expires_at=int(time.time())+600,attempts=0))
    msg=EmailMessage()
    msg['Subject']='KYVORA · código de acceso'
    msg['From']=os.environ['SMTP_FROM']
    msg['To']=email
    msg.set_content(f'Tu código de acceso a KYVORA es: {code}\nVence en 10 minutos. Si no lo pediste, ignora este mensaje.')
    try:
        with smtplib.SMTP(os.environ['SMTP_HOST'],int(os.getenv('SMTP_PORT','587')),timeout=12) as server:
            server.starttls()
            server.login(os.environ['SMTP_USER'],os.environ['SMTP_PASSWORD'])
            server.send_message(msg)
    except (OSError,smtplib.SMTPException) as exc:
        c.rollback()
        raise HTTPException(503,'No se pudo enviar el correo') from exc
    c.commit()
    return {'sent':True,'expires_in':600}

@router.post('/email/verify')
def verify_email_code(body:EmailVerify,request:Request,c=Depends(db)):
    if not configured('email') or len(os.environ['AUTH_CODE_PEPPER'])<32:
        raise HTTPException(503,'Correo todavía no está configurado')
    auth.throttle(c,'email-verify:'+request.client.host,20,3600)
    email=str(body.email).lower()
    challenge=one(c,sa.select(email_challenges).where(email_challenges.c.email==email).with_for_update())
    if challenge is None or challenge['expires_at']<int(time.time()) or challenge['attempts']>=5:
        raise HTTPException(401,'Código inválido o vencido')
    if not hmac.compare_digest(challenge['code_hash'],email_digest(email,body.code)):
        c.execute(email_challenges.update().where(email_challenges.c.email==email).values(attempts=challenge['attempts']+1))
        c.commit()
        raise HTTPException(401,'Código inválido o vencido')
    c.execute(email_challenges.delete().where(email_challenges.c.email==email))
    user_id=find_or_create_user(c,'email',email,email.split('@')[0][:60])
    session=auth.issue(c,user_id)
    c.commit()
    return session
