# KYVORA 2.5 · paquete integrado para comprobar en Android

## Qué incluye

Este paquete **incluye las mejoras inéditas de KYVORA 2.4** (inicio de sesión Google y Facebook preparado, email OTP, guías visuales generadas, comunidad estilo red social) **y KYVORA 2.5** (filtros realmente desplegables y listado por ejercicios más usados personalmente).

- **Filtros plegados por defecto**: pulsa «Filtros» para desplegar grupos musculares y equipos; «Más opciones» despliega variantes, tipo, animaciones, músculos secundarios y favoritos; cuando se pliegan permanecen aplicados y se indican los activos.
- **Orden «Más usados por ti»**, calculado de las sesiones **finalizadas** guardadas en el teléfono. Se cuenta **una vez cada ejercicio por sesión**, no una vez por serie; el ranking cambia con los filtros y muestra N sesiones. Cuando todavía no hay historial, presenta la biblioteca en orden alfabético y explica por qué no hay ranking.
- **Orden alternativo A–Z** y búsqueda ES/EN por alias, con la relevancia de texto prioritaria si se escribe una consulta.
- **Sin ranking global simulado**: todavía no hay datos comunitarios publicados, ni se extrae el historial privado de otros usuarios para fabricarlos.
- Nueva prueba `mobile/test/exercise_usage_test.dart` para conteo de sesiones.
- GitHub Actions produce artefacto `kyvora-preview-apk`.

## Publicación

1. Descarga `KYVORA-2.5-integrada-filtros-ranking.zip` en Descargas.
2. Extrae y ejecuta `APLICAR-KYVORA-2.5.ps1` desde Windows PowerShell. El script detecta y valida el repositorio KYVORA; si no existe localmente, lo clona en el Escritorio.
3. Revisa **GitHub Actions** en `https://github.com/RenanEspinar/KYVORA/actions`. El APK **solo existe** cuando Flutter analyze, tests y build terminan en verde.
4. Descarga `kyvora-preview-apk` del último run satisfactorio. Para actualizar sin borrar datos, primero configura una **firma Android estable**; con firma incompatible, NO desinstales sin sincronizar.
5. **OAuth** requiere datos de Google Cloud / Meta y actualización del backend. Los botones deshabilitados sin credenciales no son errores de interfaz ni significan autenticación operativa.

## Pruebas rápidas en Pixel

- Abre Entrenar → Añadir ejercicio. Filtros están plegados; ábrelos, selecciona Pecho → Poleas → Más opciones → Unilateral y vuelve a plegarlos: los filtros deben mantenerse y limitar la lista.
- Escribe «pec deck», «peck deck», «contractora», «single arm cable fly». Deben aparecer coincidencias del catálogo.
- Cambia «Ordenar» entre «Más usados por ti» y «Nombre (A–Z)».
- Finaliza una sesión con press de banca y otra con press de banca y aperturas; al volver a añadir ejercicio, el press debe aparecer con «2 sesiones» y ocupar el primer lugar en «Más usados por ti» (si no había historial previo).
- Comprueba descanso, método de carga, superseries, guía técnica y comunidad. Verifica accesos externos únicamente tras configurar los proveedores y desplegar el backend actualizado.

## Seguridad y límites

No hay borrado de usuarios, restablecimiento de base de datos ni migración de identificador Android en este paquete. El código de 2.4 no se había publicado en GitHub cuando se construyó este archivo. Flutter no está instalado en el entorno de preparación; por tanto **no se afirma que el APK haya sido compilado ni probado en teléfono**. Si CI falla, revisar logs y corregir antes de instalar.
