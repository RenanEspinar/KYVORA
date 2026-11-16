# KYVORA 2.4 · Login social, guías visuales y comunidad

## Entregado en código

**Cuenta**: nuevo backend que valida ID tokens de Google (firma RSA, issuer, aud, expiración) y tokens clásicos de Facebook (Graph `/debug_token`, identificación de usuario y aplicación). Identidad vinculada por `(proveedor, subject)` en tabla `auth_identities`, **nunca se enlazan cuentas automáticamente por correo ni por coincidencia de nombre**. Acceso por correo sin contraseña mediante OTP de ocho dígitos y SMTP con STARTTLS, TTL 10 min, máximo 5 intentos por código, throttling IP+destinatario. Inicio convencional continúa funcionando.

**Frontend**: botones Google y Facebook con `google_sign_in` y `flutter_facebook_auth`; acceso por correo si SMTP configurado. Los botones se desactivan si faltan IDs o si `/auth/providers` responde que el proveedor no está activo. No se envían tokens de acceso de terceros como tokens para la API de KYVORA.

**Guías**: 16 fotos ilustrativas originales generadas para familias específicas de ejercicios y tres imágenes de calentamiento. Script `scripts/build_guide_cards.py` produce una ficha visual única de cada ejercicio sin animación identificada en el catálogo; muestra nombre, grupo muscular, equipo y un extracto de la técnica. Cuando no hay una foto fiel al movimiento, la ficha muestra un **esquema del equipo**, no una postura de otro ejercicio. El material es ilustrativo y no demuestra ejecución verificada. Cada compilación regenera las fichas tras el catálogo y las animaciones.

**Comunidad**: tarjetas visuales de inspiración marcadas **EJEMPLO** (no son publicaciones ni usuarios ficticios), mayor altura para imágenes, avatar, acciones existentes de me gusta/comentar, y composición real con foto/entrenamiento. Mejoras de rendimiento: imágenes limitadas a ancho de decodificación y búsqueda de ejercicios con debounce de 130 ms; el listado de ejercicios ya usa `SliverList` perezoso.

## Requisitos para activar Google

1. Configurar una firma Android **estable** para todas las APK posteriores y obtener SHA-1 del certificado.
2. En Google Cloud crear una identidad OAuth Android con paquete `website.chuma.liftlog` y su SHA-1; obtener también un **OAuth Web Client ID** para verificar los ID tokens desde el backend.
3. Guardar el ID web como variable pública GitHub Actions `KYVORA_GOOGLE_WEB_CLIENT_ID` y en el `.env` del despliegue como `GOOGLE_WEB_CLIENT_ID` (mismo valor).

## Requisitos para activar Facebook

1. Crear aplicación en Meta Developers, agregar plataforma Android y registrar el hash de firma de Android.
2. En Variables de GitHub Actions configurar **valores públicos**: `KYVORA_FACEBOOK_APP_ID` y `KYVORA_FACEBOOK_CLIENT_TOKEN`. El script `configure_mobile_auth.py` los inserta en los recursos Android. **Nunca poner App Secret en el APK ni Git.**
3. En el `.env` del servidor definir `FACEBOOK_APP_ID` y `FACEBOOK_APP_SECRET` (este último es privado). Registrar usuarios de prueba en Meta o completar configuración de app Live.
4. La verificación implementada es para el token de Facebook **clásico de Android**, no Login Limitado de iOS.

## Requisitos para activar correo

Configurar solo en el `.env` privado del backend: `SMTP_HOST`, `SMTP_PORT=587`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` y `AUTH_CODE_PEPPER` (valor secreto aleatorio de al menos 32 caracteres). La función requiere conexión SMTP con STARTTLS. No se incluyen claves ni credenciales.

## Despliegue y verificación

- El ZIP es **código**, no una APK ya compilada. Ejecuta `APLICAR-KYVORA-2.4.ps1` desde Descargas en Windows con el repositorio local limpio; el script publica en la rama `main` y dispara GitHub Actions.
- Las pruebas de GitHub comprueban backend y Android, generan guías después de las animaciones y crean el artefacto `liftlog-preview-apk`.
- Para que funcione el inicio social, debes actualizar **también** el contenedor backend del servidor (`liftlog-api-1`) con los nuevos archivos y la migración Alembic. La ruta del Compose actual se obtiene sin adivinar con `docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' liftlog-api-1`. Ejecuta el procedimiento de despliegue **después** de validar tests y config. El `Dockerfile` ejecuta `alembic upgrade head` al arrancar la API. No usar `docker compose down -v` ni limpiar otros contenedores.
- Activar cuentas externas por primera vez requiere IDs reales de Google/Meta o SMTP: sin esas configuraciones los botones de OAuth quedan correctamente deshabilitados.
- La firma de APK **no** se ha estabilizado: no desinstalar versiones anteriores con datos locales sin sincronizar.

## Límites transparentes

- Apple Sign-In y passkeys **no se han implementado**. Passkeys requiere backend WebAuthn/RP ID, asociación Android con dominio HTTPS y manejo de credenciales; Apple requiere flujo de plataforma específico. No se simula acceso ni se envían contraseñas a un proveedor incorrecto.
- No se implementó vincular varias identidades externas a una cuenta antigua ni reautenticación de cuenta social para el borrado del perfil. No presentar esto como preparado para lanzamiento público hasta completar el ciclo de cuenta.
- No se ejecutó `flutter analyze`, `flutter test` ni compilación Android en este entorno (Flutter no está instalado aquí). Sí se validaron XML, Python y los 13 tests unitarios de vocabulario y carga existentes; la compilación y las pruebas completas deben pasar en GitHub Actions.
- Las fichas de ejercicios son ayudas visuales y **no sustituyen una demostración biomecánica exacta**. Las fotos son originales, no copias extraídas de MuscleWiki ni de otras webs.
