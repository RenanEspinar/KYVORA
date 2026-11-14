# Desplegar en homeserverv2

**Estado:** instrucciones preparadas; no ejecutadas en ese servidor. No hay acceso SSH configurado desde este entorno. El dominio previsto no prueba que el servicio esté publicado.

## 1. Inspeccionar sin cambiar servicios

Copia y extrae el ZIP en una carpeta temporal del servidor. Desde la raíz `liftlog/`:

```bash
python3 scripts/inspect_host.py
```

El script muestra Docker, contenedores activos, redes de `cloudflared` e indicios de configuración remota/local. No imprime argumentos, variables ni tokens del túnel. No pegues la salida completa de `docker inspect cloudflared`, porque puede contener su token.

Antes de instalar, comprueba que `/opt/liftlog` y los nombres `liftlog`, `liftlog_edge`, `liftlog_pgdata` y `liftlog_media` no correspondan a otra instalación. Si existe una instalación, sigue la sección de actualización; no sobrescribas `.env`.

## 2. Preparar el proyecto

Ejemplo de instalación nueva, después de verificar que no existe el destino:

```bash
sudo install -d -m 750 -o "$USER" -g "$(id -gn)" /opt/liftlog
cp -a liftlog/. /opt/liftlog/
cd /opt/liftlog
chmod +x scripts/liftlog scripts/*.sh
python3 scripts/init_env.py
./scripts/deploy.sh
```

`init_env.py` genera la contraseña PostgreSQL localmente, con permiso 0600, y rechaza sobrescribir un archivo existente. Usa una cuenta con acceso ya autorizado a Docker. No es necesario reiniciar Docker ni los otros contenedores.

El comando despliega exclusivamente `db`, `api` y `gateway` bajo el proyecto Compose `liftlog`. Las redes y volúmenes son propios. Los puertos de producción no se publican en el host.

Comprueba disponibilidad dentro de Docker:

```bash
./scripts/liftlog ps
./scripts/liftlog exec -T api python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/api/v1/ready').read().decode())"
```

## 3. Integrar el túnel existente

Primero revisa el resultado del inventario y confirma qué túnel y configuración están realmente activos.

Para que el contenedor `cloudflared` existente llegue al gateway, conéctalo a la red específica **sin reiniciarlo**:

```bash
docker network connect liftlog_edge cloudflared
```

Ejecuta ese comando solo si `cloudflared` aún no pertenece a la red. Esta conexión se conserva tras un reinicio, pero se pierde si otro sistema elimina y vuelve a crear el contenedor. Documenta entonces la red externa en la configuración que realmente administra ese contenedor, conservando todos sus servicios, después de revisar y respaldar esa configuración.

**Túnel administrado en Cloudflare:** añade una única ruta de aplicación publicada para `api.chuma.website`, servicio HTTP `liftlog-gateway:8080`, en el túnel que corresponde al contenedor. No cambies rutas existentes. Si el DNS del hostname ya existe para otro servicio, no lo sobrescribas sin resolver la colisión.

**Túnel con configuración local:** localiza el archivo montado mediante el inventario, copia su contenido a un respaldo con permiso privado e inserta el fragmento `deploy/cloudflare-ingress.example.yml` antes de la regla final. Mantén intactas las demás entradas. Valida el archivo con la versión instalada de cloudflared antes de aplicar la recarga mínima que admita esa configuración. Si exige reiniciar el túnel, programa esa operación porque afectaría temporalmente a todos sus servicios. Esta entrega no automatiza ese reinicio.

No añadas `admin.chuma.website`. No publiques PostgreSQL, `/internal/metrics` ni interfaces administrativas.

## 4. Comprobar desde fuera

```bash
curl --fail --show-error https://api.chuma.website/api/v1/health
curl --fail --show-error https://api.chuma.website/api/v1/ready
```

Ambos deben devolver JSON de LIFTLOG y HTTPS válido. No desactives la validación de certificados. Instala la APK en dos teléfonos, crea cuentas independientes y ejecuta los flujos del archivo `TEST_RESULTS.md`. Los usuarios del ensayo automático son sintéticos y no se transfieren a producción.

## 5. Respaldo y restauración

Respaldo manual y restauración de comprobación:

```bash
cd /opt/liftlog
backup=$(./scripts/backup.sh)
./scripts/restore-check.sh "$backup"
```

La copia contiene `database.dump`, `media.tar.gz`, listado del dump y SHA256SUMS. La comprobación restaura en una base temporal y compara los archivos multimedia con los registros restaurados. El script no comprueba solo que exista un archivo: lee el dump mediante PostgreSQL.

Para un ensayo aislado sin tocar los volúmenes activos:

```bash
./scripts/restore-new.sh /opt/liftlog/backups/FECHA liftlog_restore_ensayo1
```

Rechaza reutilizar volúmenes existentes. No conecta el proyecto de restauración al túnel. Tras verificarlo, su limpieza debe limitarse explícitamente a ese proyecto; no uses `docker system prune`, `docker volume prune` ni comandos globales.

Programación diaria opcional en el propio servidor:

```bash
sudo cp deploy/systemd/liftlog-backup.service deploy/systemd/liftlog-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now liftlog-backup.timer
systemctl list-timers liftlog-backup.timer
```

El horario es 03:20 **de la zona horaria configurada en homeserverv2**, con hasta 10 minutos de dispersión. La copia detiene brevemente solo la API/gateway de LIFTLOG. Guarda una copia adicional fuera del disco del servidor. No se incluye `.env`: conserva ese archivo privado por separado. No hay borrado automático de copias en esta versión; supervisa su crecimiento.

## 6. Operación y actualización

```bash
./scripts/liftlog logs --tail 100 api
./scripts/liftlog exec -T api python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/internal/metrics').read().decode())"
docker stats --no-stream $(./scripts/liftlog ps -q)
df -h /opt/liftlog
du -sh /opt/liftlog/backups
```

Métricas: usuarios, bytes registrados en medios, solicitudes y errores 5xx del último minuto, latencia media. La ventana de métricas es en memoria y se reinicia con la API. Los logs rotan a 3 archivos de 8 MiB por servicio.

Antes de actualizar: crea y verifica un respaldo. Conserva `.env` y los volúmenes. Copia la nueva versión del código; revisa migraciones y cambios de contrato; ejecuta `./scripts/liftlog up -d --build --wait db api gateway`. Alembic aplica las migraciones al arrancar la API. Verifica health, readiness y una sesión de prueba. No uses `down -v` en producción.

Un retroceso de versión que cambie el esquema requiere restauración ensayada en un proyecto nuevo; no se promete reversión automática de datos.
