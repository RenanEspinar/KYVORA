#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
dir=$(cd -- "${1:?Indica la carpeta del respaldo}" && pwd)
dc="$root/scripts/liftlog"
(cd "$dir" && sha256sum -c SHA256SUMS)
scratch_db=liftlog_check_$(date +%s)_$$
"$dc" exec -T db createdb -U liftlog "$scratch_db"
trap '"$dc" exec -T db dropdb --if-exists -U liftlog "$scratch_db"' EXIT
"$dc" exec -T db pg_restore --exit-on-error --single-transaction -U liftlog --no-owner -d "$scratch_db" < "$dir/database.dump"
"$dc" exec -T db psql -XAt -v ON_ERROR_STOP=1 -U liftlog -d "$scratch_db" -c 'SELECT version_num FROM alembic_version; SELECT count(*) FROM workout_sessions;'
"$dc" exec -T db psql -XAt -v ON_ERROR_STOP=1 -U liftlog -d "$scratch_db" -c 'SELECT id,bytes FROM media' | python3 "$root/scripts/check_media_backup.py" "$dir/media.tar.gz"
