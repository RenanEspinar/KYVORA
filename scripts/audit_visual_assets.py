#!/usr/bin/env python3
"""Fail KYVORA CI unless every exercise has valid media in source and APK.

The test checks technical coverage, NOT clinical/biomechanical correctness.
Motion frames are original/attributed source illustrations; other cards are
original pictures or equipment diagrams that may be conceptual.
"""
import argparse
import io
import json
from pathlib import Path, PurePosixPath
import zipfile
import xml.etree.ElementTree as ET
from PIL import Image, UnidentifiedImageError

ASSET_PREFIX = 'assets/'
APK_PREFIX = 'assets/flutter_assets/'

class VisualAuditError(RuntimeError):
    pass


def check_path(path):
    if not isinstance(path, str) or not path.startswith(ASSET_PREFIX):
        raise VisualAuditError(f'Ruta de recurso no válida: {path!r}')
    parts = PurePosixPath(path).parts
    if '..' in parts or '.' in parts or '\\' in path:
        raise VisualAuditError(f'Ruta insegura: {path!r}')
    return path


def check_image(data, path):
    if not data or len(data) < 80:
        raise VisualAuditError(f'Recurso vacío: {path}')
    if path.endswith('.svg'):
        try:
            root = ET.fromstring(data)
            if root.tag.rsplit('}',1)[-1] != 'svg':
                raise ValueError('No SVG root')
        except (ET.ParseError, ValueError) as exc:
            raise VisualAuditError(f'SVG inválido: {path}: {exc}') from exc
    elif path.endswith(('.jpg','.jpeg','.png','.gif','.webp')):
        try:
            with Image.open(io.BytesIO(data)) as im:
                if im.width < 60 or im.height < 60:
                    raise ValueError(f'Imagen demasiado pequeña ({im.size})')
                im.verify()
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise VisualAuditError(f'Imagen dañada: {path}: {exc}') from exc
    else:
        raise VisualAuditError(f'Formato de imagen no permitido: {path}')


def audit(reader):
    """reader(path) returns bytes from the Flutter assets root."""
    def read(path):
        check_path(path)
        try:
            return reader(path)
        except (KeyError, FileNotFoundError, OSError) as exc:
            raise VisualAuditError(f'Archivo referenciado pero ausente: {path}') from exc

    try:
        catalog = json.loads(read('assets/catalog.json'))
        motions = json.loads(read('assets/motion_index.json'))
        guides = json.loads(read('assets/guide_index.json'))
    except (ValueError, TypeError) as exc:
        raise VisualAuditError(f'Índice o catálogo JSON inválido: {exc}') from exc
    if not isinstance(catalog,list) or not catalog:
        raise VisualAuditError('Catálogo vacío o inválido')
    if not isinstance(motions,dict) or not isinstance(guides,dict):
        raise VisualAuditError('Los índices deben ser objetos JSON')
    seen=set(); animated=0; illustrated=0; files=set(); missing=[]
    for ex in catalog:
        eid = ex.get('id') if isinstance(ex,dict) else None
        if not isinstance(eid,str) or not eid.strip() or eid in seen:
            raise VisualAuditError(f'Identificador duplicado o inválido: {eid!r}')
        seen.add(eid)
        motion = motions.get(eid)
        if motion:
            if not isinstance(motion,dict):
                raise VisualAuditError(f'Movimiento inválido para {eid}')
            gif=motion.get('gif')
            frames=motion.get('frames')
            seq=motion.get('sequence')
            if gif is not None:
                if not isinstance(gif,str) or not gif.lower().endswith('.gif'):
                    raise VisualAuditError(f'GIF inválido: {eid}')
                files.add(gif)
            elif isinstance(frames,list) and frames and isinstance(seq,list) and seq:
                if not all(isinstance(frame,str) and frame.endswith('.svg') for frame in frames):
                    raise VisualAuditError(f'Frames no SVG: {eid}')
                if not all(type(n) is int and 0 <= n < len(frames) for n in seq):
                    raise VisualAuditError(f'Secuencia de animación inválida: {eid}')
                files.update(frames)
            else:
                raise VisualAuditError(f'Animación incompleta: {eid}')
            animated+=1
        elif isinstance(guides.get(eid),str):
            path=guides[eid]
            if not path.endswith(('.jpg','.jpeg','.png','.webp')):
                raise VisualAuditError(f'Ficha con formato inválido: {eid}: {path}')
            if not path.endswith(f'{eid}.jpg') and not path.endswith(f'{eid}.png'):
                raise VisualAuditError(f'Ficha asignada al ejercicio incorrecto: {eid}: {path}')
            files.add(path)
            illustrated+=1
        else:
            missing.append({'id':eid,'name':ex.get('name','')})
    if missing:
        raise VisualAuditError(f'Faltan recursos visuales en {len(missing)} ejercicios; ejemplos: {missing[:7]}')
    if set(motions)-seen or set(guides)-seen:
        raise VisualAuditError('Índices contienen IDs que no pertenecen al catálogo')
    if any(e in motions for e in guides):
        raise VisualAuditError('Hay fichas de sustitución para ejercicios ya animados')
    for p in sorted(files):
        check_image(read(p),p)
    return {
        'total':len(catalog),
        'animations':animated,
        'original_static_guides':illustrated,
        'coverage_percent':100.0,
        'files_validated':len(files),
        'missing':0,
        'meaning':'Cobertura técnica, no garantiza corrección biomecánica de ilustraciones'
    }


def audit_source(root):
    root=Path(root)
    return audit(lambda path:(root/'mobile'/path).read_bytes())


def audit_apk(apk):
    with zipfile.ZipFile(apk) as z:
        return audit(lambda path:z.read(APK_PREFIX+path))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',action='store_true',help='Audit source-generated Flutter assets')
    parser.add_argument('--apk',type=Path,help='Audit final built Android APK')
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--report',type=Path,help='Write JSON report (optional)')
    args=parser.parse_args()
    if args.source == bool(args.apk):
        parser.error('Choose one of --source or --apk')
    stats=audit_source(args.root) if args.source else audit_apk(args.apk)
    print('KYVORA visual audit:',json.dumps(stats,ensure_ascii=False))
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(stats,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

if __name__=='__main__':
    main()
