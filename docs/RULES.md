# Reglas LL-2026.1

## Récords

Se excluyen calentamientos. Carga máxima: mayor carga externa registrada en una serie válida de repeticiones. No exige que la serie tenga una sola repetición. Repeticiones por carga: máximo de repeticiones para la misma carga normalizada. Peso corporal: máximo de repeticiones sin carga externa. Se conserva cada nuevo máximo recibido.

Epley: `e1RM = kg × (1 + rep/30)` para 2–10 repeticiones. Con una repetición se muestra la propia carga; con más de diez no se calcula. Solo se aplica a `weight_reps`; no a asistencia, tiempo, distancia ni variantes lastradas. Es una estimación del modelo con incertidumbre individual y de ejercicio, no un 1RM realmente levantado ni una carga recomendada.

Volumen: suma de carga externa en kg por repeticiones, sin calentamientos; modalidades `weight_reps` y `weighted_reps`. Para lastre mide solo el volumen del lastre. No suma peso corporal ni trata la asistencia como volumen externo positivo. No es trabajo mecánico en joules.

## Niveles propios de LIFTLOG

Las categorías siguientes son umbrales internos de producto. **No son percentiles poblacionales, normas de la IPF, equivalencias médicas ni estándares universales de fuerza.** No se usa altura como multiplicador. La variable es carga máxima registrada/peso corporal de la sesión, adimensional.

| Ejercicio | Bronce | Plata | Oro | Platino | Diamante | Élite |
|---|---:|---:|---:|---:|---:|---:|
| Press de banca | 0 | 0,50 | 0,80 | 1,10 | 1,40 | 1,70 |
| Sentadilla trasera | 0 | 0,75 | 1,10 | 1,50 | 1,90 | 2,30 |
| Peso muerto convencional | 0 | 1,00 | 1,40 | 1,80 | 2,20 | 2,60 |

El archivo versionado es `backend/app/data/levels.json` y su copia local está en `mobile/assets/levels.json`. Un usuario aporta una sola mejor marca por ejercicio y filtro. La tabla comunitaria no suma ejercicios diferentes. No existen niveles por pago.

## Confirmación

Autodeclarado: registrado por la persona. Confirmado: al menos `REQUIRED_CONFIRMERS` testigos identificados aprueban la solicitud. Valor configurable de 1 a 5. Una revocación o eliminación de un testigo recalcula el estado.

Verificado: reservado para un procedimiento futuro de evidencia y arbitraje. Esta versión no lo concede. La API devuelve vacío para rankings `verified`. Una relación recíproca genera una señal de auditoría; no invalida automáticamente una marca ni identifica por sí sola fraude.

El reglamento técnico de la International Powerlifting Federation puede servir como referencia para un futuro módulo oficial de sentadilla/banca/peso muerto: https://www.powerlifting.sport/rules/codes/info/technical-rules. Esta implementación no afirma aplicar ese reglamento.

## Recursos visuales

Los nueve SVG en `mobile/assets/maps/` y el icono vectorial de LIFTLOG fueron creados para este proyecto. Son esquemas originales y no copian fotografías o marcas de otras aplicaciones. Flutter y cada dependencia conservan su licencia original. La aplicación incluye las licencias de dependencias mediante el registro de licencias de Flutter; los paquetes fuente pueden consultarse en pub.dev y PyPI.
