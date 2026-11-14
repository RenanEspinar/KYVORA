# Alcance entregado y pendientes

Esta es una versión vertical de pruebas de LIFTLOG. La matriz no convierte código escrito en una prueba de producción. Los resultados ejecutados se separan en `TEST_RESULTS.md`.

| Área | Estado de implementación |
|---|---|
| Android | Cinco secciones, Material 3 oscuro, registro rápido, persistencia local, modo invitado |
| Entrenamiento | Biblioteca de 114 ejercicios, rutinas locales, división por día, series, calentamiento, fallo, RPE/RIR, superseries, descanso y reanudación |
| Sincronización | Sesiones finalizadas, cola persistente, UUID idempotente, recuperación de sesiones del servidor y conflictos explícitos |
| Identidad | Cuenta real, Argon2, sesiones, refresh rotatorio, revocación y recuperación por código |
| Comunidad | Feed cronológico, fotografías, sesión/PR compartido, reacciones, comentarios, seguimiento, aprobación de privados, bloqueos y denuncias |
| PR | Carga máxima, repeticiones por carga, Epley limitado a 1–10 rep, repeticiones corporales, historial |
| Confirmación | Solicitud a testigo, aprobación/rechazo/revocación, auditoría y señal de reciprocidad |
| Rankings | Aceptación voluntaria, tres ejercicios, seis niveles internos, filtros del backend por categoría, temporada, gimnasio, ciudad y país |
| Estadísticas | Historial, volumen externo, frecuencia y evolución por ejercicio; ver definiciones en RULES.md |
| Operación | Compose aislado, volúmenes, límites de recursos/logs, health/readiness, respaldo y restauración a proyecto nuevo |

## No implementado o incompleto

- Verificación oficial de PR mediante video, reglamento de arbitraje y revisores acreditados. Ninguna acumulación de confirmaciones concede el estado `verified`.
- Desafíos con inscripción, temporadas administradas y resultados; clasificación por categoría de edad/peso y niveles por disciplina/global.
- Creación de ejercicios personalizados, sincronización de rutinas/preferencias y borradores entre teléfonos. Las tablas preparadas no implican que esos flujos existan.
- Foto de avatar, perfiles públicos completos y listas de seguidores/seguidos; lectura de notificaciones y desbloqueo no tienen un flujo completo de administración.
- Moderación con revisión de denuncias, resolución y acciones administrativas. Las denuncias se conservan, pero no hay panel.
- Detección robusta de cuentas falsas o fraude coordinado. La señal de reciprocidad sirve para auditoría, no demuestra fraude.
- Traducción íntegra al inglés. Están habilitados los delegates de localización, pero los textos del producto permanecen en español.
- Gráfica completa de peso corporal, cumplimiento de rutinas y fuerza relativa histórica. No se prometen por incluir `fl_chart`.
- Exportación integral del almacenamiento local e importación de ese archivo, cifrado adicional de SQLite y respaldo externo automático.
- Prueba de carga de producción, auditoría de penetración independiente, compatibilidad con toda la gama de Android y accesibilidad completa.

## Límites conocidos

Las fotografías sin publicación pueden consumir cuota hasta eliminar la cuenta. Un cierre abrupto durante una escritura multimedia puede dejar archivos huérfanos; el comprobador del respaldo los detecta, pero no hay recolector automático.

La lista de PR devuelve los 500 más recientes. Las notificaciones y solicitudes devuelven las 100 más recientes. No hay paginación completa para esos recursos.

Un PR del servidor se compara contra los máximos ya recibidos. Si se sincronizan sesiones antiguas después de nuevas, no se reconstruye retrospectivamente cada hito histórico; los máximos y registros ya existentes no se sobrescriben.

Los rankings usan la categoría y ubicación actuales del perfil; no son un registro congelado de participación oficial por temporada. Los ejercicios de máquina y asistencia no se comparan como levantamientos libres.

La firma de la APK de pruebas no es una clave de producción administrada por el usuario. No usar esta build para publicar en Google Play. Antes de distribuir ampliamente, establece una clave propia y un procedimiento de actualización que preserve los datos.

## Pendiente de infraestructura

No se dispone de una sesión SSH a homeserverv2 ni de la configuración real de su túnel. No se ha modificado ningún contenedor existente ni se ha publicado el dominio. La API pública y el uso con dos teléfonos reales requieren completar ese despliegue y la prueba de aceptación en campo.
