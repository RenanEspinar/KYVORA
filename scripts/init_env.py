"""Crea un archivo privado sin sobrescribir configuraciones existentes."""
import argparse
import os
import secrets
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument("--dev", action="store_true")
opts = parser.parse_args()
root = Path(__file__).resolve().parents[1]
path = root / (".env.dev" if opts.dev else ".env")
text = (root / ".env.example").read_text().replace(
    "POSTGRES_PASSWORD=\n", "POSTGRES_PASSWORD=" + secrets.token_hex(32) + "\n"
)
if opts.dev:
    text = text.replace("LIFTLOG_EDGE_NETWORK=liftlog_edge", "LIFTLOG_EDGE_NETWORK=liftlog_dev_edge")
with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as stream:
    stream.write(text)
print("Configuración privada creada en", path.name)
