"""SQLAlchemy 2 schema. Identifiers are canonical UUID strings on both engines."""
import os
from datetime import datetime, timezone
from uuid import uuid4
import sqlalchemy as s
from sqlalchemy import Table, Column as C, Integer as I, String as S, Float as F, Boolean as B, JSON as J, ForeignKey as FK

meta = s.MetaData()
now = lambda: datetime.now(timezone.utc)
uid = lambda: str(uuid4())
def identity():
    return [C('id',S(36),primary_key=True,default=uid), C('created_at',s.DateTime(timezone=True),default=now,nullable=False), C('updated_at',s.DateTime(timezone=True),default=now,onupdate=now,nullable=False), C('version',I,default=1,nullable=False)]
def ref(name,target='users',**kwargs):
    return C(name,S(36),FK(target+'.id',ondelete='CASCADE'),**kwargs)
def entity(name,*cols):
    return Table(name,meta,*identity(),*cols)
users=entity('users',C('username',S(24),unique=True,nullable=False),C('password_hash',S(255),nullable=False),C('recovery_hash',S(64),nullable=False))
profiles=Table('profiles',meta,ref('user_id',primary_key=True),C('display_name',S(60),nullable=False),C('bio',S(300),nullable=False,default=''),C('private',B,default=True,nullable=False),C('rankings_opt_in',B,default=False,nullable=False),C('personal',J,nullable=False,default=dict))
sessions=entity('auth_sessions',ref('user_id',nullable=False,index=True),C('access_hash',S(64),unique=True,nullable=False),C('access_until',s.BigInteger,nullable=False),C('expires',s.BigInteger,nullable=False),C('revoked',B,default=False,nullable=False))
refreshes=Table('refresh_tokens',meta,C('digest',S(64),primary_key=True),ref('session_id','auth_sessions',nullable=False,index=True),C('used',B,nullable=False,default=False))
limits=Table('rate_limits',meta,C('key',S(64),primary_key=True),C('window',s.BigInteger,nullable=False),C('count',I,nullable=False))
exercises=entity('exercises',ref('owner_id',nullable=True,index=True),C('definition',J,nullable=False))
workouts=entity('workout_sessions',ref('owner_id',nullable=False,index=True),C('name',S(100),nullable=False),C('started_at',s.DateTime(timezone=True),nullable=False),C('ended_at',s.DateTime(timezone=True),nullable=False),C('bodyweight_kg',F),C('notes',S(2000),nullable=False,default=''))
moves=entity('workout_exercises',ref('workout_id','workout_sessions',index=True,nullable=False),C('exercise_id',S(36),FK('exercises.id'),nullable=False),C('position',I,nullable=False),C('superset',S(24)),s.UniqueConstraint('workout_id','position'))
sets=entity('workout_sets',ref('move_id','workout_exercises',index=True,nullable=False),C('position',I,nullable=False),C('kind',S(16),nullable=False),C('method',S(16),nullable=False,default='straight'),C('block_id',S(36)),C('phase',I,nullable=False,default=0),C('load_kg',F,nullable=False),C('reps',I),C('seconds',F),C('distance_m',F),C('rpe',F),C('rir',I),C('rest_seconds',I,nullable=False),s.CheckConstraint('load_kg >= 0'),s.UniqueConstraint('move_id','position'))
records=entity('personal_records',ref('owner_id',index=True,nullable=False),ref('exercise_id','exercises',index=True,nullable=False),ref('set_id','workout_sets',index=True,nullable=False),C('kind',S(24),nullable=False),C('value',F,nullable=False),C('load_kg',F,nullable=False),C('reps',I,nullable=False),C('bodyweight_kg',F),C('achieved_at',s.DateTime(timezone=True),nullable=False),C('status',S(20),default='self_declared',nullable=False),s.UniqueConstraint('set_id','kind'))
ops=Table('sync_operations',meta,ref('owner_id',primary_key=True),C('operation_id',S(36),primary_key=True),C('digest',S(64),nullable=False),C('response',J,nullable=False))
requests=entity('verification_requests',ref('record_id','personal_records',index=True,nullable=False),ref('owner_id',index=True,nullable=False),ref('witness_id',index=True,nullable=False),C('state',S(16),default='pending',nullable=False),C('reason',S(500),default='',nullable=False),C('flag',B,default=False,nullable=False),s.UniqueConstraint('record_id','witness_id'),s.CheckConstraint('owner_id <> witness_id'))
audit=entity('audit_events',C('actor_id',S(36),FK('users.id',ondelete='SET NULL')),C('action',S(50),nullable=False),C('resource_id',S(36),nullable=False),C('detail',J,nullable=False,default=dict))
media=entity('media',ref('owner_id',index=True,nullable=False),C('bytes',I,nullable=False))
posts=entity('posts',ref('owner_id',index=True,nullable=False),C('text',S(2000),nullable=False),C('visibility',S(12),nullable=False),C('workout_id',S(36),FK('workout_sessions.id',ondelete='SET NULL')),C('record_id',S(36),FK('personal_records.id',ondelete='SET NULL')),C('media_id',S(36),FK('media.id',ondelete='SET NULL')))
s.Index('ix_posts_time',posts.c.created_at,posts.c.id)
comments=entity('comments',ref('post_id','posts',index=True,nullable=False),ref('owner_id',nullable=False),C('text',S(1000),nullable=False))
likes=Table('reactions',meta,ref('post_id','posts',primary_key=True),ref('owner_id',primary_key=True))
follows=Table('follows',meta,ref('follower',primary_key=True),ref('followed',primary_key=True),C('approved',B,nullable=False),s.CheckConstraint('follower <> followed'))
blocks=Table('blocks',meta,ref('blocker',primary_key=True),ref('target',primary_key=True))
notices=entity('notifications',ref('owner_id',index=True,nullable=False),ref('actor_id',nullable=False),C('kind',S(30),nullable=False),C('resource_id',S(36),nullable=False),C('seen',B,default=False,nullable=False))
reports=entity('reports',ref('owner_id',nullable=False),C('resource_type',S(20),nullable=False),C('resource_id',S(36),nullable=False),C('reason',S(1000),nullable=False))
measurements=entity('body_measurements',ref('owner_id',index=True,nullable=False),C('weight_kg',F,nullable=False))
templates=entity('workout_templates',ref('owner_id',index=True,nullable=False),C('definition',J,nullable=False))
url=os.environ.get('DATABASE_URL','postgresql+psycopg://liftlog@db/liftlog')
engine=s.create_engine(url,pool_pre_ping=True)
if engine.dialect.name=='sqlite':
    @s.event.listens_for(engine,'connect')
    def foreign_keys(conn,_):
        conn.execute('PRAGMA foreign_keys=ON')
def db():
    with engine.connect() as conn:
        yield conn
def rows(conn,statement):
    return [dict(r) for r in conn.execute(statement).mappings()]
def one(conn,statement):
    row=conn.execute(statement).mappings().first()
    return dict(row) if row else None
def by_id(conn,table,id):
    return one(conn,s.select(table).where(table.c.id==str(id)))
