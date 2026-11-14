#!/usr/bin/env bash
# Solo restaura en un proyecto nuevo con nombre liftlog_restore_identificador.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
dir=$(cd -- "${1:?Indica la carpeta del respaldo}" && pwd)
project=${2:?Indica liftlog_restore_identificador}
[[ "$project" =~ ^liftlog_restore_[a-z0-9]{1,18}$ ]] || { echo "Nombre inválido" >&2; exit 1; }
(cd "$dir" && sha256sum -c SHA256SUMS)
for vol in pgdata media; do
  if docker volume inspect "${project}_$vol" >/dev/null 2>&1; then echo "Volumen existente; cancelado" >&2; exit 1; fi
done
export LIFTLOG_EDGE_NETWORK="${project}_edge"
dc=(docker compose --env-file "$root/.env" -p "$project" -f "$root/deploy/compose.yml")
"${dc[@]}" up -d --wait db
"${dc[@]}" exec -T db pg_restore --exit-on-error --single-transaction -U liftlog -d liftlog --no-owner < "$dir/database.dump"
"${dc[@]}" exec -T db psql -XAt -v ON_ERROR_STOP=1 -U liftlog -d liftlog -c 'SELECT id,bytes FROM media' | python3 "$root/scripts/check_media_backup.py" "$dir/media.tar.gz"
"${dc[@]}" build api
"${dc[@]}" run --rm --no-deps -T --entrypoint tar api -C /data/media --no-same-owner -xzf - < "$dir/media.tar.gz"
"${dc[@]}" up -d --wait api gateway
"${dc[@]}" ps
