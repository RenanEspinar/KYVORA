# LIFTLOG 1.0 · entrega de pruebas

Aplicación Android en Flutter y API FastAPI para registrar sesiones sin conexión, sincronizarlas y compartirlas entre cuentas. **Esta entrega no equivale a un lanzamiento de producción ni completa todo el prompt maestro.**

## Empezar

1. Instala la APK de pruebas. Consulta [Android](docs/ANDROID.md).
2. Puedes entrenar inmediatamente en modo local, sin crear cuenta.
3. Para registro de cuentas y comunidad, despliega la API y configura el túnel: [Servidor](docs/DEPLOY.md).
4. Consulta [lo implementado y los pendientes](docs/SCOPE.md), [manual](docs/USER_GUIDE.md) y [resultados de prueba](docs/TEST_RESULTS.md).

La dirección de producción es `https://api.chuma.website/api/v1`. Es una configuración de compilación, definida una sola vez en `mobile/lib/core.dart`. **No hay evidencia de despliegue en homeserverv2 en esta entrega.**

## Componentes

| Directorio | Contenido |
|---|---|
| `mobile/` | Flutter, Riverpod, GoRouter, Drift/SQLite, Dio, Secure Storage, gráficas |
| `backend/` | FastAPI, SQLAlchemy, modelos, autorización y migración Alembic |
| `deploy/` | PostgreSQL 16, API, Nginx, redes propias, temporizador de respaldo |
| `scripts/` | Instalación, inspección, respaldos, restauración y pruebas nativas |
| `docs/` | Operación, reglas, arquitectura, límites y evidencia reproducible |
| `.github/workflows/` | Pruebas automáticas y compilación de una APK de pruebas |

El monolito no necesita Redis, Kubernetes, servicios de pago ni proveedores de correo. La recuperación usa un código de un solo uso entregado al registrar la cuenta.

## Desarrollo de la API

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.lock
cd backend
python -m pytest -q
```

Para desarrollo integrado con Docker, desde la raíz:

```bash
python3 scripts/init_env.py --dev
docker compose --env-file .env.dev -p liftlog_dev -f deploy/compose.yml -f deploy/compose.dev.yml up -d --build --wait
```

Solo el gateway de desarrollo se publica en `127.0.0.1:8180`. PostgreSQL no publica puertos. No uses `scripts/liftlog` para actuar sobre desarrollo: ese wrapper selecciona únicamente el proyecto `liftlog`.

## Pruebas nativas reproducibles

Con PostgreSQL 16 y Flutter instalados:

```bash
PG_BIN=/usr/lib/postgresql/16/bin FLUTTER_BIN="$(command -v flutter)" .venv/bin/python scripts/test_native.py
```

El script crea un clúster temporal, dos bases independientes y cuentas sintéticas. Ejecuta la API por HTTP, prueba reintentos y permisos, reinicia sus propios procesos y restaura un respaldo en otra base. Nunca recibe la URL de una base real. Los resultados se guardan en `docs/evidence/`.

Consulta la configuración real de versiones en `mobile/pubspec.lock` y `backend/requirements.lock`. Los datos, secretos, certificados privados y cachés están excluidos del ZIP y de Git.
