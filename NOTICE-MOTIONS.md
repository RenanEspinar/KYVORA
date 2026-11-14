# LIFTLOG 1.4 — biblioteca completa y animaciones

Fuente: https://github.com/ozansozuozgit/flow-exercise-dataset

La base externa contiene 1.324 registros, 1.257 secuencias SVG y 67 ejercicios sin animación. Se conservan todos los registros originales de LIFTLOG y se añaden los externos sin sustituir IDs existentes. Las coincidencias exactas pueden compartir ilustración.

Los SVG externos son declarados CC0 por sus mantenedores **solo hasta donde poseen derechos**. La documentación advierte sobre procedencia incompleta y que las ilustraciones NO están validadas por profesionales. Verifica licencias y técnica antes de distribuir comercialmente.

`python scripts/build_complete_library.py --with-media` genera los dos catálogos, el índice de animaciones y las imágenes para APK. No necesita librerías Python adicionales. No descarga GIFs de terceros ni mezcla movimientos aleatorios.

Para desplegar el catálogo en servidor, ejecuta tras actualizar el repositorio: `python3 scripts/build_complete_library.py --catalog-only`, y después reconstruye el backend mediante el script habitual de despliegue. El servidor necesita los nuevos UUID antes de sincronizar entrenamientos que los referencien.

No ejecutar la herramienta en un backend público sin antes revisar los cambios generados. La aplicación conserva el catálogo local para uso sin conexión.
