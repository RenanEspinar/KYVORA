# Arquitectura y contratos

## Dispositivo

`Store` utiliza Drift sobre SQLite con WAL y `synchronous=FULL`. Las tablas `docs` y `queue` separan los documentos por propietario. Los identificadores de sesión, ejercicio de sesión, serie y operación son UUID. Las unidades internas son kg, m y s; la conversión de masa a lb ocurre en la interfaz.

La transacción de finalización escribe sesión y operación pendiente juntas. La cola conserva su `operation_id` y contenido al reintentar. Los fallos aplican espera exponencial de 5 a 900 s. Se intenta sincronizar cada 30 s mientras la aplicación está activa, al volver al primer plano y manualmente. No hay un servicio Android permanente en segundo plano.

La cola se confirma únicamente después de recibir respuesta de la API. Si la respuesta se pierde, el mismo identificador recupera la respuesta previamente confirmada en PostgreSQL. Las sesiones del servidor son inmutables y tienen versión 1. Un conflicto conserva las dos versiones hasta una decisión explícita.

Tokens en Android Keystore a través de Secure Storage. La base SQLite permanece dentro del sandbox de la aplicación; no incorpora SQLCipher. El manifiesto desactiva Android Auto Backup. No hay captura de contraseñas en logs.

## Servidor

FastAPI usa SQLAlchemy Core 2 y Alembic. PostgreSQL 16 mantiene sesiones, series, PR, relaciones sociales, publicaciones, medios, notificaciones, auditoría y operaciones idempotentes. Se incluyen claves foráneas, restricciones e índices. `docs/postgresql-schema.sql` contiene el esquema de referencia; la fuente operativa es la migración Alembic.

Una transacción persiste la sesión, series, nuevos PR y respuesta idempotente. El bloqueo por propietario serializa sincronizaciones concurrentes en PostgreSQL. El hash SHA-256 del contenido impide reutilizar un identificador de operación con otro cuerpo.

La API restringe lectura y modificación por propietario. El acceso al feed y a fotografías evalúa privacidad, seguimiento aprobado y bloqueo. El resumen publicado excluye notas privadas y peso corporal de la sesión. Rankings requieren aceptación explícita y exponen la información necesaria para su métrica.

Contraseñas con Argon2. Tokens opacos aleatorios, solo sus hashes en la base. Acceso de 15 min; sesión de 30 días; renovación rotatoria; reutilizar un refresh anterior revoca la sesión. Cerrar sesión revoca todas las sesiones de esa cuenta. El código de recuperación rota al utilizarse.

## API

Prefijo `/api/v1`. OpenAPI en `/api/v1/openapi.json`; documentación interactiva en `/api/v1/docs`. El ZIP incluye el contrato generado en `docs/openapi.json`.

| Grupo | Operaciones disponibles |
|---|---|
| auth | Registro, login, refresh, logout, recuperación |
| profiles | Leer/modificar propio perfil, exportar, eliminar |
| exercises | Catálogo autenticado |
| sync/workouts | Subir una sesión finalizada de forma idempotente |
| workouts | Lista paginada y detalle propio |
| posts/comments | Crear, consultar, reaccionar, eliminar con permisos |
| follows/users | Búsqueda exacta, seguir, aprobar, dejar de seguir, bloquear |
| records/verifications | PR, solicitud de testigo, decisión, revocación |
| rankings | Reglas internas y tabla por ejercicio, estado y filtros |
| notifications/reports | Notificaciones dentro de la aplicación y denuncias |
| media | Subir foto, leer original comprimido o miniatura con autorización |

HTTP 401: autenticación; 404: inexistente o no accesible; 409: conflicto; 413: tamaño/cuota; 415: imagen inválida; 422: validación; 429: límite de peticiones; 503: base sin migrar. El feed usa cursor de fecha e ID; las sesiones usan cursor por ID para descarga determinista.

## Multimedia y operación

PNG/JPEG/WebP estáticos, entrada máxima 5 MiB y 20 megapíxeles. Se recodifican a JPEG (lado máximo 1600 px) y miniatura de 320 px; orientación corregida y metadatos originales descartados. Cuotas iniciales: 50 MiB/cuenta y 5 GiB totales.

Nginx expone solo `/api/v1/`; `/internal/metrics` queda dentro de Docker. No se publica PostgreSQL. Límites por cuenta y servicio en API y gateway. No se confían cabeceras externas de IP. Por ello los límites por IP detrás del gateway son compartidos: con la configuración inicial, el registro queda limitado a 30 cuentas/hora por gateway.

El respaldo detiene brevemente solo API y gateway de LIFTLOG, mantiene PostgreSQL y copia medios en estado consistente. Los scripts usan `trap` para intentar reanudar esos servicios aun si falla el respaldo. No ofrecen respaldo remoto frente a pérdida física del disco.
