# Manual breve

## Entrenar ahora

Abre **Entrenar → Entrenamiento libre → Añadir ejercicio**.

Busca el nombre. El botón de información muestra técnica, errores y modalidad. La biblioteca incluida tiene 114 ejercicios. Los dibujos son esquemas de regiones de trabajo, no demostraciones biomecánicas de cada movimiento.

Añade una serie. Ajusta carga, repeticiones, RPE/RIR y descanso según corresponda. El registro distingue asistencia, lastre, peso corporal, duración y distancia. La carga asistida no se trata como peso levantado.

**Cada serie se guarda en SQLite.** Repetir la serie anterior conserva los valores sin proponer aumentos de carga. El temporizador usa una hora de finalización persistente; reabrir la aplicación permite recuperar el descanso restante.

Finaliza la sesión cuando termines. Con cuenta, queda pendiente hasta que el servidor confirme la operación. Sin cuenta, queda como sesión local.

## Rutinas e historial

En el menú de una sesión, usa **Guardar rutina** y asigna opcionalmente un día (1 a 7). Puedes duplicar una rutina. Las rutinas de esta versión permanecen en el teléfono; no se sincronizan con otros dispositivos.

Si cierras la aplicación durante una sesión, vuelve a **Entrenar → Reanudar sesión**. No borres los datos de Android ni desinstales mientras tengas sesiones pendientes: eso elimina el almacenamiento local.

## Cuenta

En **Perfil**, crea una cuenta con nombre de usuario único y contraseña de al menos 12 caracteres. Guarda el código de recuperación en un lugar privado. No existe recuperación por correo en esta versión.

Las cuentas son privadas por defecto. Las sesiones locales pueden importarse voluntariamente a una cuenta; repetir la importación en esa cuenta no crea duplicados.

Una sesión finalizada es inmutable en el servidor. Ante un conflicto, la aplicación permite conservar ambas copias o usar la del servidor. Conservar ambas representa una decisión explícita de crear dos sesiones distintas.

## Comunidad

Una publicación puede contener texto, una fotografía, una sesión o un PR. Selecciona visibilidad privada, seguidores o pública. En una cuenta privada, una publicación marcada pública continúa restringida a seguidores aprobados.

Busca otra cuenta por su nombre de usuario exacto. Sigue la cuenta, espera aprobación si es privada y publica. La otra persona puede reaccionar y comentar. Bloquear elimina la relación de seguimiento e impide las consultas mutuas cubiertas por la API.

## PR y rankings

Los PR locales aparecen antes de sincronizar. La API conserva el historial de nuevos máximos. Una persona identificada puede confirmar que presenció la serie, rechazar la solicitud o revocar una confirmación.

**Confirmado no significa verificado oficialmente.** Esta versión no emite verificación oficial. La pestaña correspondiente no inventa resultados.

Para aparecer en rankings debes aceptar la participación en Perfil. El ranking utiliza la carga realmente registrada dividida entre el peso corporal registrado para esa sesión, en tres ejercicios. El cociente y la carga publicados permiten deducir el peso usado en la clasificación.

## Tus datos

Perfil permite exportar datos y eliminar la cuenta confirmando credenciales. La exportación del servidor no contiene rutinas ni borradores que solo existan en el teléfono. Consulta `docs/SCOPE.md` antes de depender de la exportación como respaldo completo del dispositivo.

Las estadísticas son descriptivas. El 1RM estimado es un cálculo, no una marca levantada ni una recomendación automática de carga.
