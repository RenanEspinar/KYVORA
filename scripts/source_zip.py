"""Rebuild the distributable source archive without developer secrets or caches."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import sys
root=Path(__file__).resolve().parents[1]
out=Path(sys.argv[1]).resolve()
excluded={'.git','.dart_tool','build','.gradle','.kotlin','.idea','__pycache__','.pytest_cache','.venv','backups','.cxx','ephemeral','media','.plugin_symlinks','.coverage'}
with ZipFile(out,'w',ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(root.rglob('*')):
        rel=p.relative_to(root)
        if not p.is_file() or p.is_symlink() or any(part in excluded for part in rel.parts):continue
        if p.name in ['local.properties','key.properties','.env','.flutter-plugins','.flutter-plugins-dependencies','GeneratedPluginRegistrant.java'] or (p.name.startswith('.env.') and p.name!='.env.example') or p.suffix in ['.jks','.keystore','.sqlite','.db','.pyc','.apk','.aab','.iml','.hprof','.log']:continue
        z.write(p,'liftlog/'+str(rel))
print(out.name,out.stat().st_size)
