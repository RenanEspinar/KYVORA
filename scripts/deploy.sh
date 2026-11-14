#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$base"
test -f .env || python3 scripts/init_env.py
./scripts/liftlog config -q
./scripts/liftlog up -d --build --wait --wait-timeout 240 db api gateway
./scripts/liftlog ps
