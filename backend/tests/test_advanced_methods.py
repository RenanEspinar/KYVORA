from datetime import datetime, timezone
from uuid import uuid4
import pytest
from pydantic import ValidationError
from app.types import Workout
from app.training import candidates
from app.types import Set

def make_workout(method='drop_set', loads=(40,32,24), phases=(0,1,2), block=None):
    block = str(block or uuid4())
    return dict(
        id=str(uuid4()), name='Métodos avanzados', base_version=0,
        started_at=datetime(2026,11,14,tzinfo=timezone.utc).isoformat(),
        ended_at=datetime(2026,11,14,tzinfo=timezone.utc).isoformat(),
        exercises=[dict(id=str(uuid4()),exercise_id=str(uuid4()),superset='A',sets=[
            dict(id=str(uuid4()),kind='normal',method=method,block_id=block,
                 phase=i,load_kg=load,reps=8,rest_seconds=0)
            for i,load in zip(phases,loads)
        ])],
    )

def test_valid_drop_set_and_no_false_records():
    w=Workout.model_validate(make_workout())
    assert len(w.exercises[0].sets)==3
    assert candidates('weight_reps',w.exercises[0].sets[0])==[]

def test_drop_set_rejects_equal_or_increasing_load():
    with pytest.raises(ValidationError):
        Workout.model_validate(make_workout(loads=(40,40,24)))

def test_invalid_phase_and_orphan_block():
    with pytest.raises(ValidationError):
        Workout.model_validate(make_workout(phases=(0,2,3)))
    data=make_workout()
    data['exercises'][0]['sets'][0]['block_id']=None
    with pytest.raises(ValidationError):
        Workout.model_validate(data)

def test_other_methods_keep_same_load():
    for method in ['rest_pause','myo_reps','cluster','pyramid']:
        w=Workout.model_validate(make_workout(method=method,loads=(45,45,45)))
        assert w.exercises[0].sets[0].method==method

def test_legacy_set_defaults_and_still_creates_records():
    s=Set.model_validate(dict(id=str(uuid4()),load_kg=40,reps=8))
    assert s.method=='straight' and s.phase==0 and s.block_id is None
    assert candidates('weight_reps',s)
