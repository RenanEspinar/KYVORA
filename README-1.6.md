# LIFTLOG 1.6 — jerarquía de animaciones y pendientes

**Prioridades**: (1) GIF específico suministrado por el titular o con licencia suficiente; (2) secuencia SVG de Flow Exercise Dataset; (3) ilustración estática y entrada en la cola de producción original.

La base de datos de **Exercises Dataset** puede usarse para cotejar nombres/IDs, pero sus GIFs proceden de **Gym visual**. La licencia MIT del proyecto **no** permite reutilizar automáticamente esos GIFs. Esta actualización no descarga ni republica tales medios. Obtener permiso antes de usar el material en una APK que vaya a distribuirse, incluso si se compila mediante GitHub Actions.

## Uso

1. En el proyecto LIFTLOG, incluir el script `scripts/complete_gif_coverage.py` y reemplazar el workflow indicado en este parche.
2. Agregar GIFs cuya utilización esté autorizada a `media/exercise_gifs/<id-del-catalogo>.gif` o `<source_id>.gif` (NO subir credenciales ni material no autorizado al repositorio).
3. Durante GitHub Actions, el script de Flow genera el catálogo y medios SVG; luego este nuevo script da prioridad a los GIFs aportados. Para cotejar contra el JSON de `Exercises Dataset`, se puede ejecutar `python scripts/complete_gif_coverage.py --exercises-dataset-json data/exercises.json` después de preparar Flow, proporcionando el JSON local.
4. En Artifacts: `liftlog-motion-audit` muestra los GIFs enlazados, ejercicios con SVG y cola exacta de ejercicios sin animación. No necesita modificar PostgreSQL si el catálogo ya fue importado.

**Limitación:** esta versión ordena e integra correctamente fuentes, pero no inventa ni aporta los GIFs protegidos que no estén autorizados. Tampoco cambia la firma Android; una firma estable sigue siendo necesaria para actualizar sin desinstalar.
