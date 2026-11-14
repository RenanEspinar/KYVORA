"""Inventario de solo lectura. Los argumentos y variables del túnel se procesan en memoria."""
import json
import shutil
import socket
import subprocess
def output(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout
print("Host", socket.gethostname())
print("GiB libres", round(shutil.disk_usage("/").free / 2**30, 1))
print(output("docker", "version", "--format", "{{.Server.Version}}").strip())
print(output("docker", "compose", "version").strip())
print(output("docker", "ps", "--format", "{{.Names}}  {{.Status}}").strip())
row = json.loads(output("docker", "inspect", "cloudflared"))[0]
cfg = row["Config"]
args = [str(x) for x in [*(cfg.get("Entrypoint") or []), *(cfg.get("Cmd") or [])]]
keys = {entry.split("=", 1)[0] for entry in cfg.get("Env", [])}
remote = bool({"TUNNEL_TOKEN", "TUNNEL_TOKEN_FILE"} & keys) or any(
    a.split("=", 1)[0] in ("--token", "--token-file") for a in args
)
local = any(a.split("=", 1)[0] == "--config" for a in args) or any(
    m["Destination"].endswith(("/cloudflared", "config.yml", "config.yaml"))
    for m in row.get("Mounts", [])
)
print("Indicio de administración", "remota" if remote else "local" if local else "por determinar")
print("Redes", ", ".join(row["NetworkSettings"]["Networks"]))
print("Destinos montados", ", ".join(m["Destination"] for m in row.get("Mounts", [])) or "(ninguno)")
