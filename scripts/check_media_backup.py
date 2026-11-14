"""Comprueba que cada imagen y miniatura del respaldo coincidan con la base restaurada."""
import sys
import tarfile
files = {}
with tarfile.open(sys.argv[1], "r:gz") as archive:
    for entry in archive:
        name = entry.name.removeprefix("./")
        if entry.isdir() and name in ("", "."):
            continue
        if not entry.isfile() or "/" in name or name in files:
            raise SystemExit("Entrada multimedia inesperada")
        files[name] = entry.size
for row in sys.stdin:
    if not row.strip():
        continue
    id, size = row.strip().split("|")
    try:
        total = files.pop(id + ".jpg") + files.pop(id + "-thumb.jpg")
    except KeyError:
        raise SystemExit("Falta una imagen de la base restaurada")
    if total != int(size):
        raise SystemExit("Tamaño de imagen incorrecto")
if files:
    raise SystemExit("Medios huérfanos en la copia; investigar antes de restaurar")
print("Medios y base restaurada coinciden")
