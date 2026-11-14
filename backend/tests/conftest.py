import os
import tempfile
from datetime import datetime, timezone
from uuid import uuid4
import pytest
from fastapi.testclient import TestClient

workspace = tempfile.TemporaryDirectory(prefix="liftlog-tests-")
if "DATABASE_URL" in os.environ and os.environ.get("ALLOW_DISPOSABLE_TEST_DB") != "1":
    raise RuntimeError("Selecciona una BD desechable y ALLOW_DISPOSABLE_TEST_DB=1")
os.environ.setdefault("DATABASE_URL", "sqlite:///" + workspace.name + "/test.db")
os.environ["MEDIA_DIR"] = workspace.name + "/media"
from app.db import meta, engine
from app.main import app
from app.training import catalog

@pytest.fixture
def api():
    meta.drop_all(engine)
    meta.create_all(engine)
    with TestClient(app, base_url="http://testserver/api/v1/") as client:
        yield client

def register(api, name="atleta_a"):
    response = api.post("auth/register", json={
        "username": name, "password": "local-ensayo-8374", "display_name": name.title()
    })
    assert response.status_code == 201, response.text
    user = response.json()
    return user, {"Authorization": "Bearer " + user["access_token"]}

def uid():
    return str(uuid4())

def wire(count=1):
    choices = sorted(
        [e for e in catalog if e["recording"] == "weight_reps"],
        key=lambda e: e["name"] != "Press de banca",
    )[:count]
    now = datetime.now(timezone.utc).isoformat()
    return {"operation_id": uid(), "workout": {
        "id": uid(), "name": "Fuerza", "started_at": now, "ended_at": now,
        "bodyweight_kg": 75, "notes": "Nota privada",
        "exercises": [{
            "id": uid(), "exercise_id": e["id"], "sets": [{
                "id": uid(), "kind": kind, "load_kg": kg, "reps": reps,
                "rpe": 7, "rir": 3, "rest_seconds": 90,
            } for kind, kg, reps in [("warmup", 20, 8), ("normal", 60, 10), ("normal", 65, 6)]],
        } for e in choices],
    }}
