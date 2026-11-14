# KYVORA 2.2 — Métodos de entrenamiento

Esta actualización **incluye los archivos acumulados de KYVORA 2.1** y los cambios de 2.2. Los datos de la app conservan el identificador Android anterior para no perder cuentas; no cambia el dominio de la API.

## Interfaz y funcionamiento

- **Serie normal:** calentamiento, normal o al fallo, con explicación emergente de tipos, RPE y RIR.
- **Drop set:** registra etapas de 2 a 5 con carga progresivamente menor, repeticiones y pausas (0 s por defecto).
- **Rest-pause:** secuencia con una serie inicial y esfuerzos cortos; pausas sugeridas de 20 s, ajustables.
- **Myo-reps:** una serie de activación y miniseries; pausa predeterminada de 15 s.
- **Cluster:** miniseries y pausas breves (25 s predeterminados).
- **Pirámide:** series consecutivas con carga progresiva y repeticiones configurables.
- **Superserie:** asigna el mismo grupo (A, B, etc.) a dos ejercicios. **Serie gigante:** tres o más. Si se sigue el orden visual de ejercicios, el aviso de descanso comienza tras registrar el último del grupo.
- Cada método tiene un botón de información con una definición corta y un ejemplo.
- Los métodos avanzados pueden editarse o eliminarse como bloque completo, y conservan las cargas individualizadas según barra/mancuerna/máquina.
- Los bloques se guardan con ID de bloque, método y fase. Cada etapa conserva su carga, repeticiones y pausa.

## Compatibilidad con servidor (OBLIGATORIO ANTES DE SINCRONIZAR ESTOS MÉTODOS)

Esta versión introduce tres columnas en `workout_sets`: `method`, `block_id` y `phase`. Incluye migración Alembic `03c1ec4200ab_training_methods.py`.

**Primero:** publicar el código en GitHub, luego actualizar `homeserverv2`:

```bash
cd ~/LIFTLOG
git pull --ff-only origin main
./scripts/deploy.sh
./scripts/liftlog ps
curl -i http://127.0.0.1:8010/api/v1/ready
```

El despliegue debe completar `alembic upgrade head` antes de comenzar a guardar y sincronizar nuevos bloques. No se exige un cambio de dominio o túnel Cloudflare. **Haz copia de seguridad de PostgreSQL antes de migrar producción.** No sustituir `/deploy` o `.env` locales.

**Luego:** la ejecución verde de GitHub Actions publicará `liftlog-preview-apk` (archivo ZIP). Antes de instalar, confirmar la firma digital. Si difiere, no desinstalar sin verificar sincronización de entrenamientos.

## Modelo y estadísticas

- Los métodos especiales son subseries consecutivas dentro de un bloque, almacenadas como filas independientes.
- No producen récords personales automáticamente para evitar que miniseries/rest-pause inflen comparaciones.
- `superset` en cada ejercicio continúa usando el campo existente del servidor.
- Los entrenamientos previos quedan con `method='straight'`.
- El volumen suma las cargas externas de todas las etapas según el esquema de carga del ejercicio. Es una métrica de trabajo externo aproximada, no una medida de fuerza o intensidad fisiológica.

## Verificación realizada

- Compilación Python: correcta.
- Validación Pydantic con 5 métodos nuevos, fases y reglas: correcta.
- Migración de esquema SQLite de comprobación: correcta.
- Pruebas Flutter/compilación APK: pendientes de ejecutar en GitHub Actions.
- Pruebas completas del backend: pendientes de CI (dependencia `pwdlib` ausente en el entorno local de validación).

## Archivos incluidos

`APLICAR-KYVORA-2.2.ps1` carga los archivos sobre el repositorio del escritorio. No reinicia el servidor ni instala la APK automáticamente.
