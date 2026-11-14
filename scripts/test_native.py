"""Repeatable native PostgreSQL + HTTP + restore test, using temporary data only.

Usage: PG_BIN=/path/to/postgres/bin python scripts/test_native.py
Optionally set FLUTTER_BIN=/path/to/flutter to test SQLite→real API with Dart.
No existing database or server is touched. All identities are synthetic.
"""
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
from datetime import datetime, timezone
from uuid import uuid4

import httpx
from PIL import Image
import psycopg

ROOT = Path(__file__).resolve().parents[1]
PG = Path(os.environ.get("PG_BIN", "/usr/lib/postgresql/16/bin"))
EVIDENCE = ROOT / "docs" / "evidence"
EVIDENCE.mkdir(parents=True, exist_ok=True)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)


def main():
    assert (PG / "initdb").is_file(), "Set PG_BIN to a native PostgreSQL installation."
    with tempfile.TemporaryDirectory(prefix="llqa-") as raw:
        work = Path(raw)
        pgport, apiport = free_port(), free_port()
        pglog = work / "postgres.log"
        result = {"executed_at": datetime.now(timezone.utc).isoformat(),
                  "engine": run([PG / "postgres", "--version"], capture_output=True,
                                text=True).stdout.strip(),
                  "scope": "Disposable native processes on development host; not Docker or homeserverv2"}
        run([PG / "initdb", "-D", work / "pg", "--auth=trust", "--encoding=UTF8",
             "--locale=C", "--no-instructions"], stdout=subprocess.DEVNULL)
        pg_args = [PG / "pg_ctl", "-D", work / "pg", "-l", pglog, "-w"]
        pg_opts = (f"-h 127.0.0.1 -p {pgport} -c unix_socket_directories='' "
                   "-c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap")
        try:
            run([*pg_args, "-o", pg_opts, "start"], stdout=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            print(pglog.read_text(), file=sys.stderr)
            raise
        process = None
        api_log = (work / "api.log").open("w")
        try:
            connargs = {"host": "127.0.0.1", "port": pgport, "dbname": "postgres"}
            with psycopg.connect(**connargs, autocommit=True) as conn:
                for db in ("liftlog_tests", "liftlog_http", "liftlog_restore"):
                    conn.execute(f"CREATE DATABASE {db}")
            env = {**os.environ, "DATABASE_URL": f"postgresql+psycopg://127.0.0.1:{pgport}/liftlog_tests",
                   "ALLOW_DISPOSABLE_TEST_DB": "1", "MEDIA_DIR": str(work / "media")}
            with (EVIDENCE / "backend-postgres.txt").open("w") as log:
                run([sys.executable, "-m", "pytest", "-q",
                     f"--junitxml={EVIDENCE / 'backend-postgres.xml'}"],
                    cwd=ROOT / "backend", env=env, stdout=log, stderr=subprocess.STDOUT)
            result["backend_tests"] = "passed"
            env["DATABASE_URL"] = f"postgresql+psycopg://127.0.0.1:{pgport}/liftlog_http"
            run([sys.executable, "-m", "alembic", "upgrade", "head"], cwd=ROOT / "backend",
                env=env, stdout=api_log, stderr=subprocess.STDOUT)

            def start_api():
                proc = subprocess.Popen([sys.executable, "-m", "uvicorn", "app.main:app",
                    "--host", "127.0.0.1", "--port", str(apiport), "--no-access-log"],
                    cwd=ROOT / "backend", env=env, stdout=api_log, stderr=subprocess.STDOUT)
                for _ in range(100):
                    if proc.poll() is not None:
                        raise RuntimeError("API failed to start")
                    try:
                        if httpx.get(f"http://127.0.0.1:{apiport}/api/v1/ready", timeout=1, trust_env=False).status_code == 200:
                            return proc
                    except httpx.TransportError:
                        pass
                    time.sleep(.1)
                raise RuntimeError("API readiness timeout")

            process = start_api()
            base = f"http://127.0.0.1:{apiport}/api/v1/"
            with httpx.Client(base_url=base, timeout=15, trust_env=False) as a, httpx.Client(base_url=base, timeout=15, trust_env=False) as b:
                for client, username in ((a, "ensayo_a"), (b, "ensayo_b")):
                    reg = client.post("auth/register", json={"username": username,
                        "display_name": username, "password": "ensayo-local-934812"})
                    reg.raise_for_status()
                    client.headers["Authorization"] = "Bearer " + reg.json()["access_token"]
                a.patch("profiles/me", json={"private": False, "rankings_opt_in": True}).raise_for_status()
                catalog = a.get("exercises").json()
                choices = sorted((e for e in catalog if e["recording"] == "weight_reps"),
                                 key=lambda e: e["name"] != "Press de banca")[:4]
                uid = lambda: str(uuid4())
                now = datetime.now(timezone.utc).isoformat()
                workout = {"id": uid(), "name": "HTTP QA", "started_at": now, "ended_at": now,
                    "bodyweight_kg": 75, "notes": "PRIVATE-QA-NOTE", "exercises": [
                        {"id": uid(), "exercise_id": e["id"], "sets": [
                            {"id": uid(), "kind": "normal", "load_kg": 60, "reps": 10,
                             "rest_seconds": 90} for _ in range(3)]} for e in choices]}
                wire = {"operation_id": uid(), "workout": workout}
                first = a.post("sync/workouts", json=wire)
                first.raise_for_status()
                assert a.post("sync/workouts", json=wire).json() == first.json()
                assert len(a.get("workouts").json()["items"]) == 1
                assert b.get("workouts/" + workout["id"]).status_code == 404
                image = io.BytesIO()
                Image.new("RGB", (64, 48), (40, 90, 45)).save(image, "PNG")
                photo = a.post("media", files={"file": ("synthetic.png", image.getvalue(), "image/png")})
                photo.raise_for_status()
                photo_id = photo.json()["id"]
                assert b.get("media/" + photo_id).status_code == 404
                post = a.post("posts", json={"text": "Synthetic QA", "visibility": "public",
                            "workout_id": workout["id"], "media_id": photo_id})
                post.raise_for_status()
                post_id = post.json()["id"]
                for _ in range(2):
                    b.put(f"posts/{post_id}/reaction").raise_for_status()
                b.post(f"posts/{post_id}/comments", json={"text": "QA recibido"}).raise_for_status()
                record = next(r for r in first.json()["new_records"]
                              if r["kind"] == "max_weight" and r["exercise_id"] == choices[0]["id"])
                witness = a.post("verifications", json={"record_id": record["id"], "witness_username": "ensayo_b"})
                witness.raise_for_status()
                decision = b.post(f"verifications/{witness.json()['id']}/decision",
                                  json={"decision": "approved", "reason": "Atestación sintética de QA."})
                assert decision.json()["record"]["status"] == "confirmed"
                board = b.get("rankings", params={"exercise_id": record["exercise_id"], "status": "confirmed"})
                assert len(board.json()["items"]) == 1
                assert b.get("media/" + photo_id, params={"thumbnail": True}).content[:2] == b"\xff\xd8"
                feed = b.get("posts").json()["items"]
                assert feed[0]["reactions"] == feed[0]["comments"] == 1
                assert "PRIVATE-QA-NOTE" not in json.dumps(feed)
                result["http_two_accounts"] = {"workouts": 1, "exercises": 4, "sets": 12,
                    "posts": 1, "comments": 1, "reactions": 1, "confirmed_ranking_rows": 1,
                    "private_data_hidden": True, "retry_duplicated_workout": False}

                flutter = os.environ.get("FLUTTER_BIN")
                if flutter:
                    with (EVIDENCE / "flutter-live-api.txt").open("w") as log:
                        run([flutter, "test", "test/sync_live_test.dart", "--no-pub", "--reporter", "expanded",
                             "--dart-define=LIVE_API_TEST=true", "--dart-define=APP_ENV=development",
                             f"--dart-define=API_BASE_URL={base.rstrip('/')}"],
                            cwd=ROOT / "mobile", stdout=log, stderr=subprocess.STDOUT)
                    result["flutter_sqlite_to_real_api"] = "passed"
                else:
                    result["flutter_sqlite_to_real_api"] = "not run; FLUTTER_BIN not set"

                # Restart only our temporary API and database, keeping their files.
                process.terminate(); process.wait(timeout=20); process = None
                run([*pg_args, "-m", "fast", "stop"], stdout=subprocess.DEVNULL)
                run([*pg_args, "-o", pg_opts, "start"], stdout=subprocess.DEVNULL)
                process = start_api()
                restored_feed = b.get("posts").json()["items"]
                shared = next(p for p in restored_feed if p["id"] == post_id)
                assert shared["reactions"] == shared["comments"] == 1
                assert len(b.get("rankings", params={"exercise_id": record["exercise_id"],
                            "status": "confirmed"}).json()["items"]) == 1
                result["native_api_and_database_restart"] = "passed"
                process.terminate(); process.wait(timeout=20); process = None
                pg_common = ["-h", "127.0.0.1", "-p", str(pgport)]
                run([PG / "pg_dump", *pg_common, "-d", "liftlog_http", "--format=custom",
                     "--compress=0", "--no-owner", "--file", work / "database.dump"])
                with tarfile.open(work / "media.tar.gz", "w:gz") as archive:
                    for path in sorted((work / "media").glob("*")):
                        archive.add(path, arcname=path.name)
                run([PG / "pg_restore", *pg_common, "-d", "liftlog_restore", "--no-owner",
                     "--exit-on-error", "--single-transaction", work / "database.dump"])
                with psycopg.connect(**{**connargs, "dbname": "liftlog_http"}) as original, \
                     psycopg.connect(**{**connargs, "dbname": "liftlog_restore"}) as restored:
                    from psycopg import sql
                    tables = original.execute("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename").fetchall()
                    counts = {}
                    for (table,) in tables:
                        query = sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(table))
                        count = original.execute(query).fetchone()[0]
                        assert restored.execute(query).fetchone()[0] == count
                        counts[table] = count
                    media = restored.execute("SELECT id,bytes FROM media").fetchall()
                    run([sys.executable, ROOT / "scripts/check_media_backup.py", work / "media.tar.gz"],
                        input="".join(f"{id}|{size}\n" for id, size in media), text=True,
                        stdout=subprocess.DEVNULL)
                    result["backup_restore"] = {"passed": True, "tables_compared": counts,
                                                "photos_and_thumbnails_checked": len(media)}
            (EVIDENCE / "native-http-restore.json").write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps(result, indent=2))
        except Exception:
            api_log.flush()
            print((work / "api.log").read_text()[-8000:], file=sys.stderr)
            raise
        finally:
            if process and process.poll() is None:
                process.terminate(); process.wait(timeout=20)
            api_log.close()
            subprocess.run([str(x) for x in [*pg_args, "-m", "fast", "stop"]],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
