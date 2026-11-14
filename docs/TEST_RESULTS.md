# Resultados de pruebas · 12–14 de noviembre de 2026

Resultados del código incluido en esta entrega. Las cuentas y sesiones de ensayo son sintéticas. No son deportistas ni marcas reales.

| Comprobación | Resultado y alcance |
|---|---|
| API sobre SQLite | 9 pruebas aprobadas, `tests-sqlite.xml` |
| API sobre PostgreSQL 16.15 nativo | 9 pruebas aprobadas, `evidence/backend-postgres.xml` |
| Flutter estático | Sin incidencias, `flutter-analyze.txt` |
| Flutter unitario y widgets | 6 pruebas aprobadas; prueba de API separada omitida intencionalmente en esta ejecución, `flutter-tests.txt` |
| Flutter + SQLite + HTTP real + PostgreSQL | 1 prueba aprobada, `evidence/flutter-live-api.txt` |
| HTTP entre dos cuentas | Sesión de 4 ejercicios y 12 series, publicación, reacción, comentario, testigo y ranking: aprobados |
| Reintento tras respuesta perdida | Mismo UUID de operación, una sola sesión y la misma respuesta del servidor |
| Reinicio nativo | Se detuvieron y arrancaron solo los procesos temporales de API y PostgreSQL; se conservaron los datos |
| Restauración | Dump restaurado en base distinta; igualdad de conteos de todas las tablas y comprobación de fotografía/miniatura |
| APK | Compilada el 14 de noviembre, firma verificada y alineación 16 KiB verificada; instalación/apertura Android pendientes |
| Docker en homeserverv2 | No ejecutado: no hay una conexión disponible al servidor desde este entorno |
| Dos teléfonos físicos + dominio público | Pendiente |

El ensayo HTTP principal y el ensayo Dart agregan una sesión cada uno. Por eso la base restaurada contiene 2 sesiones y 24 series, mientras el flujo HTTP inicial demuestra 1 sesión y 12 series. El detalle completo está en `evidence/native-http-restore.json`.

Las pruebas de seguridad comprueban aislamiento de sesiones, prohibición de leer/modificar sesiones ajenas, acceso a publicaciones privadas, aprobación de seguidores, bloqueo, acceso a fotos privadas, acciones de testigo autorizadas, revocación, tokens de renovación y eliminación de cuenta. No equivalen a una auditoría de penetración exhaustiva.

Se observó un aviso de deprecación en Starlette TestClient sobre httpx; no hubo fallos en esas pruebas. PostgreSQL se compiló nativamente y se ejecutó mediante TCP de bucle local, sin Docker; no se utilizó PGlite para los resultados de esta entrega.

## Repetir

```bash
cd backend
python -m pytest -q
cd ../mobile
flutter analyze --no-pub
flutter test --no-pub
cd ..
PG_BIN=/usr/lib/postgresql/16/bin FLUTTER_BIN="$(command -v flutter)" .venv/bin/python scripts/test_native.py
```

En Linux, las pruebas de Drift necesitan la biblioteca nativa SQLite (`libsqlite3-dev` o equivalente). El dispositivo Android utiliza la biblioteca empaquetada por `sqlite3_flutter_libs`.

## Aceptación pendiente en campo

1. Instalar en dos teléfonos físicos; crear A y B e iniciar sesión contra HTTPS real.
2. A registra cuatro ejercicios en modo avión, cierra y reabre. Confirmar sus series.
3. Restablecer la red y comprobar una única sesión en el servidor.
4. A publica. B consulta, reacciona, comenta y confirma un PR.
5. Confirmar que el ranking cambia una sola vez y que B no puede leer notas privadas.
6. Reiniciar únicamente el proyecto Compose LIFTLOG y repetir las consultas.
7. Probar una restauración en un proyecto nuevo, sin conectar ese ensayo al túnel.

No marcar los criterios originales A–H como completados en producción hasta ejecutar estos pasos. Los procesos nativos de ensayo no sustituyen los contenedores del servidor ni los teléfonos físicos.

La evidencia de firma, metadatos y hash de la APK está en `evidence/apk.json`, `apk-signature.txt`, `apk-metadata.txt` y `android-build.txt`. No se afirma que la instalación o la apertura hayan sido comprobadas.

Los scripts Compose de respaldo/restauración pasaron revisión sintáctica, pero no se ejecutaron en Docker. La restauración documentada usa PostgreSQL nativo.
