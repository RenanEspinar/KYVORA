from datetime import datetime,date,timezone,timedelta
from typing import Literal
from uuid import UUID
from pydantic import BaseModel,ConfigDict,Field,model_validator

class Strict(BaseModel):
    model_config=ConfigDict(extra='forbid',allow_inf_nan=False)
class Login(Strict):
    username:str=Field(pattern=r'^[a-z0-9_]{3,24}$')
    password:str=Field(min_length=1,max_length=128)
class Register(Login):
    display_name:str=Field(min_length=1,max_length=60)
    password:str=Field(min_length=12,max_length=128)
class Refresh(Strict):
    refresh_token:str=Field(min_length=30,max_length=128)
class Recover(Strict):
    username:str=Field(max_length=24)
    recovery_code:str=Field(max_length=128)
    new_password:str=Field(min_length=12,max_length=128)
class Profile(Strict):
    display_name:str|None=Field(None,min_length=1,max_length=60)
    bio:str|None=Field(None,max_length=300)
    private:bool|None=None
    rankings_opt_in:bool|None=None
    bodyweight_kg:float|None=Field(None,ge=25,le=450)
    height_cm:float|None=Field(None,ge=80,le=250)
    birth_date:date|None=None
    units:Literal['metric','imperial']|None=None
    category:Literal['abierta','femenina','masculina']|None=None
    city:str|None=Field(None,max_length=80)
    country:str|None=Field(None,max_length=80)
    gym:str|None=Field(None,max_length=80)
    goals:str|None=Field(None,max_length=200)
    experience:str|None=Field(None,max_length=40)
class Set(Strict):
    id:UUID
    kind:Literal['normal','warmup','failure']='normal'
    load_kg:float=Field(0,ge=0,le=1000)
    reps:int|None=Field(None,ge=1,le=1000)
    seconds:float|None=Field(None,gt=0,le=86400)
    distance_m:float|None=Field(None,gt=0,le=1000000)
    rpe:float|None=Field(None,ge=1,le=10)
    rir:int|None=Field(None,ge=0,le=20)
    rest_seconds:int=Field(90,ge=0,le=3600)
class Move(Strict):
    id:UUID
    exercise_id:UUID
    superset:str|None=Field(None,max_length=24)
    sets:list[Set]=Field(max_length=100)
class Workout(Strict):
    id:UUID
    base_version:int=Field(0,ge=0)
    name:str=Field(min_length=1,max_length=100)
    started_at:datetime
    ended_at:datetime
    bodyweight_kg:float|None=Field(None,ge=25,le=450)
    notes:str=Field('',max_length=2000)
    exercises:list[Move]=Field(min_length=1,max_length=40)
    @model_validator(mode='after')
    def validate_workout(self):
        if not self.started_at.tzinfo or not self.ended_at.tzinfo or self.ended_at<self.started_at or self.ended_at>datetime.now(timezone.utc)+timedelta(minutes=10):
            raise ValueError('Intervalo de entrenamiento inválido')
        ids=[m.id for m in self.exercises]+[s.id for m in self.exercises for s in m.sets]
        if len(ids)!=len(set(ids)) or not any(m.sets for m in self.exercises):
            raise ValueError('Revisa los identificadores y las series')
        return self
class Sync(Strict):
    operation_id:UUID
    workout:Workout
class Publish(Strict):
    text:str=Field('',max_length=2000)
    visibility:Literal['private','followers','public']='followers'
    workout_id:UUID|None=None
    record_id:UUID|None=None
    media_id:UUID|None=None
class Comment(Strict):
    text:str=Field(min_length=1,max_length=1000)
class Witness(Strict):
    record_id:UUID
    witness_username:str=Field(pattern=r'^[a-z0-9_]{3,24}$')
class Decision(Strict):
    decision:Literal['approved','rejected','revoked']
    reason:str=Field(min_length=5,max_length=500)
class Report(Strict):
    resource_type:Literal['post','record','user']
    resource_id:UUID
    reason:str=Field(min_length=5,max_length=1000)
