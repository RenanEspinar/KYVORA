# LIFTLOG 1.1 - cambios de entrada de series

- Repeticiones con selector de rueda de 1 a 1000, por defecto 10 o último valor registrado.
- Carga editable inmediatamente: si es cero, el campo inicia vacío (sin `0.00`); la carga vacía se interpreta como cero.
- Versionado a 1.1.0+2.

## Animaciones

No se incorporaron GIFs: el generador de imágenes falló. Las imágenes SVG originales permanecen disponibles. Se necesitan animaciones correctas de cada ejercicio antes de incorporarlas a la aplicación.

## APK

La APK no pudo compilarse en este entorno porque no hay SDK Flutter/Android. El proyecto incluye `.github/workflows/ci.yml` que compila una APK al publicar estos cambios en GitHub. Ver Actions > LIFTLOG checks > android > artifact `liftlog-preview-apk`.

**Firma:** el flujo usa firma de depuración para el APK de release. Si la firma no coincide con la APK instalada, Android no permitirá instalarla sobre la anterior. No desinstalar sin respaldar primero los entrenamientos locales; considerar firma persistente para distribuciones futuras.
