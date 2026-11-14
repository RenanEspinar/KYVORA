#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
dc="$root/scripts/liftlog"
dest=${LIFTLOG_BACKUP_DIR:-"$root/backups"}
mkdir -p "$dest"
exec 9>"$dest/.backup.lock"
flock -n 9 || { echo "Hay otro respaldo en curso" >&2; exit 1; }
stamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp=$(mktemp -d "$dest/.pending.XXXXXXXX")
original=$("$dc" ps --status running --services)
resume=()
for service in api gateway; do
  if printf '%s\n' "$original" | grep -qx "$service"; then resume+=("$service"); fi
done
cleanup() {
  rc=$?
  trap - EXIT
  if (( ${#resume[@]} )); then "$dc" start "${resume[@]}" >&2 || rc=1; fi
  if [[ -d "$tmp" ]]; then rm -r -- "$tmp"; fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if (( ${#resume[@]} )); then "$dc" stop "${resume[@]}" >&2; fi
"$dc" exec -T db pg_dump -U liftlog -d liftlog --format=custom --no-owner > "$tmp/database.dump"
"$dc" run --rm --no-deps -T --entrypoint tar api -C /data/media -czf - . > "$tmp/media.tar.gz"
"$dc" exec -T db pg_restore --list < "$tmp/database.dump" > "$tmp/toc.txt"
tar -tzf "$tmp/media.tar.gz" > /dev/null
(cd "$tmp" && sha256sum database.dump media.tar.gz toc.txt > SHA256SUMS)
[[ ! -e "$dest/$stamp" ]]
mv "$tmp" "$dest/$stamp"
echo "$dest/$stamp"
