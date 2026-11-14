import io
import copy
import sqlalchemy as sql
from PIL import Image
from conftest import register, wire, uid
from app.db import engine, workouts, sets, ops, audit, records
from app.training import catalog

def test_catalog(api):
    _, headers = register(api)
    data = api.get("exercises", headers=headers).json()
    assert len({e["id"] for e in data}) == len(data) >= 100
    assert len({e["recording"] for e in data}) == 6
    assert api.get("exercises").status_code == 401
    for e in data:
        assert all(e[key] for key in ("name", "name_en", "technique", "errors", "equipment"))

def test_refresh_replay_logout_and_recovery(api):
    user, headers = register(api)
    body = {"refresh_token": user["refresh_token"]}
    renewed = api.post("auth/refresh", json=body).json()
    current = {"Authorization": "Bearer " + renewed["access_token"]}
    assert api.get("profiles/me", headers=headers).status_code == 401
    assert api.get("profiles/me", headers=current).status_code == 200
    assert api.post("auth/refresh", json=body).status_code == 401
    assert api.get("profiles/me", headers=current).status_code == 401
    recovery = {"username": "atleta_a", "recovery_code": user["recovery_code"],
                "new_password": "renovada-872135"}
    assert api.post("auth/recover", json=recovery).status_code == 200
    assert api.post("auth/recover", json=recovery).status_code == 400
    login = api.post("auth/login", json={"username": "atleta_a", "password": recovery["new_password"]}).json()
    current = {"Authorization": "Bearer " + login["access_token"]}
    assert api.post("auth/logout", headers=current).status_code == 204
    assert api.get("profiles/me", headers=current).status_code == 401

def test_login_rate_limit(api):
    for _ in range(10):
        assert api.post("auth/login", json={"username": "inexistente", "password": "wrong"}).status_code == 401
    assert api.post("auth/login", json={"username": "inexistente", "password": "wrong"}).status_code == 429

def test_four_exercises_replay_conflict_and_ownership(api):
    _, a = register(api)
    _, b = register(api, "atleta_b")
    data = wire(4)
    first = api.post("sync/workouts", headers=a, json=data)
    assert first.status_code == 200, first.text
    assert api.post("sync/workouts", headers=a, json=data).json() == first.json()
    with engine.connect() as conn:
        for table, total in [(workouts, 1), (sets, 12), (ops, 1)]:
            assert conn.scalar(sql.select(sql.func.count()).select_from(table)) == total
    id = data["workout"]["id"]
    assert api.get("workouts/" + id, headers=b).status_code == 404
    assert api.post("sync/workouts", headers=b, json=data).status_code == 404
    modified = copy.deepcopy(data)
    modified["workout"]["name"] = "Cambio"
    assert api.post("sync/workouts", headers=a, json=modified).json()["detail"]["code"] == "operation_reused"
    modified["operation_id"] = uid()
    assert api.post("sync/workouts", headers=a, json=modified).json()["detail"]["server"]["name"] == "Fuerza"

def test_modes_and_atomic_rollback(api):
    _, a = register(api)
    for mode in ("assisted_reps", "bodyweight_reps", "time", "distance_time"):
        data = wire()
        data["workout"]["exercises"][0]["exercise_id"] = next(e["id"] for e in catalog if e["recording"] == mode)
        response = api.post("sync/workouts", headers=a, json=data)
        if mode == "assisted_reps":
            assert response.status_code == 200 and not response.json()["new_records"]
        else:
            assert response.status_code == 422
    result = api.post("sync/workouts", headers=a, json=wire()).json()["new_records"]
    assert any(r["kind"] == "estimated_1rm" and r["value"] == 80 for r in result)
    assert not any(r["load_kg"] == 20 for r in result)
    with engine.connect() as conn:
        assert conn.scalar(sql.select(sql.func.count()).select_from(workouts)) == 2

def test_private_follow_reactions_comments_blocks(api):
    owner, a = register(api)
    follower, b = register(api, "atleta_b")
    _, c = register(api, "atleta_c")
    api.patch("profiles/me", headers=a, json={"private": True, "birth_date": "1993-02-03", "bodyweight_kg": 75})
    post = api.post("posts", headers=a, json={"text": "Entrenamiento", "visibility": "public"}).json()
    id = post["id"]
    assert not api.get("posts", headers=b).json()["items"]
    assert not api.post("follows/" + owner["user_id"], headers=b).json()["approved"]
    assert api.put("follows/" + follower["user_id"] + "/approve", headers=a).status_code == 204
    assert len(api.get("posts", headers=b).json()["items"]) == 1
    for _ in range(2):
        assert api.put(f"posts/{id}/reaction", headers=b).status_code == 204
    assert api.post(f"posts/{id}/comments", headers=b, json={"text": "Bien hecho"}).status_code == 201
    shared = api.get("posts", headers=b).json()["items"][0]
    assert shared["reactions"] == shared["comments"] == 1
    assert "bodyweight_kg" not in shared["author"] and "birth_date" not in shared["author"]
    assert api.get(f"posts/{id}/comments", headers=c).status_code == 404
    assert api.delete(f"posts/{id}", headers=b).status_code == 404
    assert api.post("reports", headers=b, json={"resource_type": "post", "resource_id": id, "reason": "Revisar la descripción"}).status_code == 201
    assert api.put("users/" + follower["user_id"] + "/block", headers=a).status_code == 204
    assert api.get(f"posts/{id}/comments", headers=b).status_code == 404

def test_witness_audit_revoke_unique_rank(api):
    _, a = register(api)
    _, b = register(api, "atleta_b")
    _, c = register(api, "atleta_c")
    data = wire()
    result = api.post("sync/workouts", headers=a, json=data).json()
    record = next(r for r in result["new_records"] if r["kind"] == "max_weight" and r["value"] == 65)
    params = {"exercise_id": record["exercise_id"]}
    assert not api.get("rankings", headers=b, params=params).json()["items"]
    api.patch("profiles/me", headers=a, json={"rankings_opt_in": True})
    assert len(api.get("rankings", headers=b, params=params).json()["items"]) == 1
    def request(who):
        return api.post("verifications", headers=a, json={"record_id": record["id"], "witness_username": who})
    assert request("atleta_a").status_code == 422
    req = request("atleta_b").json()
    assert request("atleta_b").json()["id"] == req["id"]
    decision = "verifications/" + req["id"] + "/decision"
    evidence = {"decision": "approved", "reason": "Presencié personalmente la serie."}
    assert api.post(decision, headers=c, json=evidence).status_code == 404
    assert api.post(decision, headers=b, json=evidence).json()["record"]["status"] == "confirmed"
    assert api.post(decision, headers=b, json=evidence).status_code == 200
    board = api.get("rankings", headers=b, params={**params, "status": "confirmed"}).json()["items"]
    assert len(board) == 1 and board[0]["level"] == "Oro" and board[0]["ratio"] == .867
    assert not api.get("rankings", headers=b, params={**params, "status": "verified"}).json()["items"]
    assert api.post(decision, headers=b, json={**evidence, "decision": "revoked"}).json()["record"]["status"] == "self_declared"
    with engine.connect() as conn:
        assert conn.scalar(sql.select(sql.func.count()).select_from(audit)) == 3

def test_photos_content_and_private_access(api):
    _, a = register(api)
    _, b = register(api, "atleta_b")
    assert api.post("media", headers=a, files={"file": ("fake.jpg", b"not-image", "image/jpeg")}).status_code == 415
    raw = io.BytesIO()
    Image.new("RGB", (40, 30), (61, 112, 17)).save(raw, "PNG")
    image = api.post("media", headers=a, files={"file": ("test.png", raw.getvalue(), "image/png")})
    assert image.status_code == 201, image.text
    id = image.json()["id"]
    assert api.get("media/" + id, headers=b).status_code == 404
    assert api.get("media/" + id, headers=a).content.startswith(b"\xff\xd8")
    api.patch("profiles/me", headers=a, json={"private": False})
    api.post("posts", headers=a, json={"media_id": id, "visibility": "public"})
    assert api.get("media/" + id, headers=b, params={"thumbnail": True}).headers["content-type"] == "image/jpeg"

def test_pagination_export_delete_and_wrong_credentials(api):
    _, a = register(api)
    _, b = register(api, "atleta_b")
    for _ in range(3):
        assert api.post("sync/workouts", headers=a, json=wire()).status_code == 200
    first = api.get("workouts", headers=a, params={"limit": 2}).json()
    second = api.get("workouts", headers=a, params={"limit": 2, "after": first["next_cursor"]}).json()
    assert len({w["id"] for w in first["items"] + second["items"]}) == 3
    assert second["next_cursor"] is None
    exported = api.get("profiles/me/export", headers=a).json()
    assert len(exported["workouts"]) == 3 and "password_hash" not in str(exported)
    body = {"username": "atleta_a", "password": "local-ensayo-8374"}
    assert api.request("DELETE", "profiles/me", headers=b, json=body).status_code == 401
    assert api.request("DELETE", "profiles/me", headers=a, json={**body, "password": "incorrecta"}).status_code == 401
    assert api.request("DELETE", "profiles/me", headers=a, json=body).status_code == 204
    assert api.get("profiles/me", headers=a).status_code == 401
