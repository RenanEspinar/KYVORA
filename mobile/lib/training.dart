part of 'main.dart';

class WorkoutTile extends StatelessWidget {
  final Json w;
  const WorkoutTile(this.w, {super.key});
  @override
  Widget build(BuildContext c) => Card(
    child: ListTile(
      leading: const Icon(Icons.fitness_center, color: lime),
      title: Text(w['name']),
      subtitle: Text(
        "${day(w['started_at'])} · ${{'draft': 'En curso', 'local': 'Local', 'synced': 'Sincronizado', 'pending': 'Pendiente', 'conflict': 'Conflicto'}[w['state']] ?? ''}",
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => c.push('/sesion/${w['id']}'),
    ),
  );
}

class Training extends ConsumerWidget {
  const Training({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final a = ref.watch(stateProvider);
    Future<void> open([Json? t]) async {
      final w = await attempt(c, a, () => a.start(template: t));
      if (c.mounted && w != null) c.push('/sesion/${w['id']}');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const TitleBlock('Registro local', 'Entrenar'),
        FilledButton.icon(
          onPressed: () => open(),
          icon: const Icon(Icons.play_arrow),
          label: Text(
            a.active == null ? 'Entrenamiento libre' : 'Reanudar sesión',
          ),
        ),
        const SizedBox(height: 22),
        Text('Mis rutinas', style: Theme.of(c).textTheme.titleLarge),
        if (a.routines.isEmpty)
          const Note(
            'Abre una sesión y elige Guardar rutina en su menú. Puedes asignarle un día de la semana.',
          ),
        ...a.routines.map(
          (t) => Card(
            child: ListTile(
              onTap: () => open(t),
              leading: const Icon(Icons.calendar_month, color: lime),
              title: Text(t['name']),
              subtitle: Text(
                '${(t['exercises'] as List).length} ejercicios · ${t['weekday'] == null ? 'Sin día fijo' : ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][t['weekday']]}',
              ),
              trailing: IconButton(
                tooltip: 'Duplicar rutina',
                icon: const Icon(Icons.copy),
                onPressed: () =>
                    a.routine(t, '${t['name']} (copia)', t['weekday']),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Mis sesiones', style: Theme.of(c).textTheme.titleLarge),
        ...a.workouts.map(WorkoutTile.new),
        if (a.workouts.isEmpty) const Note('Aún no tienes sesiones.'),
        const SizedBox(height: 20),
      ],
    );
  }
}

String setLabel(Json st, Json ex, bool imperial) {
  final mode = ex['recording'];
  if (mode == 'time') return "${st['seconds']} s";
  if (mode == 'distance_time') {
    return "${st['distance_m']} m · ${st['seconds']} s";
  }
  if (mode == 'bodyweight_reps') return "${st['reps']} rep · corporal";
  return "${mass(numOf(st['load_kg']), imperial)} × ${st['reps']}${mode == 'assisted_reps'
      ? ' · asistencia'
      : mode == 'weighted_reps'
      ? ' · lastre'
      : ''}";
}

// Las animaciones se cargan de assets generados durante la compilación.
// Un ejercicio sin frames verificados conserva su ilustración estática.
class ExerciseMotion extends StatefulWidget {
  final Json exercise;
  final double width;
  final double height;
  const ExerciseMotion(this.exercise, {super.key, this.width = 100, this.height = 72});
  @override
  State<ExerciseMotion> createState() => _ExerciseMotionState();
}

class _ExerciseMotionState extends State<ExerciseMotion> {
  Timer? _ticker;
  int _frame = 0;
  @override
  void initState() { super.initState(); _start(); }
  void _start() {
    _ticker?.cancel();
    final motion = exerciseMotions[widget.exercise['id']?.toString()];
    if (motion == null) return;
    final seq = motion['sequence'] as List<dynamic>? ?? [];
    if (seq.isEmpty) return;
    _ticker = Timer.periodic(Duration(milliseconds: (motion['duration_ms'] as int?) ?? 250), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % seq.length);
    });
  }
  @override
  void didUpdateWidget(covariant ExerciseMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise['id'] != widget.exercise['id']) { _frame = 0; _start(); }
  }
  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final motion = exerciseMotions[widget.exercise['id']?.toString()];
    final frames = motion?['frames'] as List<dynamic>?;
    final sequence = motion?['sequence'] as List<dynamic>?;
    Widget visual;
    if (motion?['gif'] is String) {
      visual = Image.asset(motion!['gif'] as String,
        width: widget.width, height: widget.height, fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: 'Demostración animada: ${widget.exercise['name']}');
    } else if (frames != null && sequence != null && frames.isNotEmpty && sequence.isNotEmpty) {
      final index = sequence[_frame % sequence.length] as int;
      visual = SvgPicture.asset(frames[index] as String,
        width: widget.width, height: widget.height, fit: BoxFit.contain,
        semanticsLabel: 'Secuencia ilustrativa: ${widget.exercise['name']}');
    } else {
      // Keep the original stylized mannequin visual language for movements
      // without a licensed, exercise-specific GIF or Flow SVG animation.
      // An anatomical silhouette is not a demonstration of the movement.
      final suppliedMap = widget.exercise['image']?.toString();
      const acceptedMaps = {
        'assets/maps/arms.svg', 'assets/maps/calf.svg',
        'assets/maps/cardio.svg', 'assets/maps/hinge.svg',
        'assets/maps/plank.svg', 'assets/maps/press.svg',
        'assets/maps/pull.svg', 'assets/maps/row.svg',
        'assets/maps/squat.svg',
      };
      final map = suppliedMap != null && acceptedMaps.contains(suppliedMap)
          ? suppliedMap : 'assets/maps/arms.svg';
      visual = SvgPicture.asset(map,
        width: widget.width, height: widget.height, fit: BoxFit.contain,
        semanticsLabel: 'Esquema muscular ilustrativo, no técnica de ejecución: ${widget.exercise['name']}');
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: visual);
  }
}

Future<void> technique(BuildContext c, Json e) => showModalBottomSheet(
  context: c,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (d) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .8,
    builder: (d, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: ExerciseMotion(e, width: 280, height: 180)),
        const SizedBox(height: 5),
        Text(exerciseMotions.containsKey(e['id']?.toString())
            ? 'Animación ilustrativa · consulta la técnica específica'
            : 'Muñeco esquemático · indica la región muscular, no el movimiento exacto',
            style: const TextStyle(color: muted, fontSize: 11)),
        Text(e['name'], style: Theme.of(d).textTheme.headlineMedium),
        Note('${e['name_en']} · ${e['muscle']} · ${e['equipment']}'),
        Text(e['description']),
        const SizedBox(height: 14),
        const Text('Técnica', style: TextStyle(color: lime)),
        Text(e['technique']),
        const SizedBox(height: 14),
        const Text('Errores frecuentes', style: TextStyle(color: lime)),
        Text(e['errors']),
        Note(
          loadHelp(e),
        ),
        if (e['visual_reference_url'] is String) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ver demostración de referencia'),
            onPressed: () async {
              final uri = Uri.tryParse(e['visual_reference_url'] as String);
              if (uri == null || uri.scheme != 'https') return;
              try {
                final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!ok && c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('No se pudo abrir la referencia.')),
                  );
                }
              } catch (_) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('No se pudo abrir el enlace.')),
                  );
                }
              }
            },
          ),
          const Note('Referencia externa: puede utilizar imágenes con derechos reservados. No se copia su material a KYVORA.'),
        ],
      ],
    ),
  ),
);

class Picker extends StatefulWidget {
  final List<Json> exercises;
  final Store? store;
  final String? owner;
  /// Real usage: one count per completed workout containing a logged set.
  final Map<String, int> usageCounts;
  const Picker(this.exercises, {
    super.key,
    this.store,
    this.owner,
    this.usageCounts = const {},
  });
  @override
  State<Picker> createState() => _Picker();
}

class _Picker extends State<Picker> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String query = '';
  String? muscleFilter;
  String? equipmentFilter;
  String? lateralityFilter;
  String? typeFilter;
  bool animatedOnly = false;
  bool secondaryMuscles = false;
  bool filtersOpen = false;
  bool advancedOpen = false;
  String sortMode = 'used';
  Json? savedPreset;

  @override
  void initState() {
    super.initState();
    _loadPreset();
  }

  Future<void> _loadPreset() async {
    if(widget.store==null || widget.owner==null) return;
    try {
      final data=await widget.store!.read(widget.owner!,'settings','exercise_filter_preset');
      if(mounted && data is Map) setState(()=>savedPreset=Json.from(data));
    } catch (_) { /* Non-critical: catalog search remains usable. */ }
  }

  Future<void> _savePreset() async {
    if(widget.store==null || widget.owner==null) return;
    final preset=<String,dynamic>{
      'muscle':muscleFilter,'equipment':equipmentFilter,
      'laterality':lateralityFilter,'type':typeFilter,
      'animated':animatedOnly,'secondary':secondaryMuscles,
    };
    try {
      await widget.store!.put(widget.owner!,'settings','exercise_filter_preset',preset);
      if(!mounted) return;
      setState(()=>savedPreset=preset);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Filtros favoritos guardados en este dispositivo.')),
      );
    } catch (_) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('No se pudieron guardar los filtros.')),
      );
    }
  }

  void _restorePreset() {
    final v=savedPreset;
    if(v==null) return;
    setState(() {
      muscleFilter=v['muscle'] as String?;
      equipmentFilter=v['equipment'] as String?;
      lateralityFilter=v['laterality'] as String?;
      typeFilter=v['type'] as String?;
      animatedOnly=v['animated']==true;
      secondaryMuscles=v['secondary']==true;
    });
  }

  static const groups = <String>[
    'Pecho', 'Espalda', 'Hombros', 'Bíceps', 'Tríceps',
    'Piernas', 'Glúteos', 'Core', 'Cardio', 'Brazos', 'Otros',
  ];
  static const gears = <String>[
    'Mancuernas', 'Poleas', 'Máquinas', 'Barras',
    'Corporal', 'Kettlebell', 'Bandas', 'Otros',
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void reset() => setState(() {
    query=''; _search.clear();
    muscleFilter=null; equipmentFilter=null; lateralityFilter=null;
    typeFilter=null; animatedOnly=false; secondaryMuscles=false;
  });

  bool _accept(Json e,{String? muscleOverride, String? equipmentOverride}) {
    return exerciseMatchesFilters(e,
      muscle:muscleOverride ?? muscleFilter,
      equipment:equipmentOverride ?? equipmentFilter,
      laterality:lateralityFilter, exerciseType:typeFilter,
      includeSecondary:secondaryMuscles, animatedOnly:animatedOnly,
      motions:exerciseMotions);
  }

  @override
  Widget build(BuildContext c) {
    final ranked = <(int,Json)>[];
    final scores=<String,int>{};
    for (final e in widget.exercises) {
      final score=exerciseSearchRank(e,query);
      scores[e['id']?.toString()??'']=score;
      if(_accept(e) && score>=0) ranked.add((score,e));
    }
    ranked.sort((a,b) {
      // A typed query always prioritizes an exact/relevant match.
      if (query.trim().isNotEmpty) {
        final match = b.$1.compareTo(a.$1);
        if (match != 0) return match;
      }
      if (sortMode == 'used') {
        final left = widget.usageCounts[a.$2['id']?.toString()] ?? 0;
        final right = widget.usageCounts[b.$2['id']?.toString()] ?? 0;
        final frequency = right.compareTo(left);
        if (frequency != 0) return frequency;
      }
      return (a.$2['name'] ?? '').toString()
          .compareTo((b.$2['name'] ?? '').toString());
    });

    // Counts update with the search. Selecting a group never requires scrolling
    // a horizontal carousel: the complete group grid remains visible.
    final muscleCounts=<String,int>{};
    final equipmentCounts=<String,int>{};
    for(final e in widget.exercises) {
      if((scores[e['id']?.toString()??'']??-1)<0) continue;
      if(exerciseMatchesFilters(e, equipment:equipmentFilter,
          laterality:lateralityFilter, exerciseType:typeFilter,
          animatedOnly:animatedOnly, motions:exerciseMotions)) {
        final g=muscleGroupOf(e);
        muscleCounts[g]=(muscleCounts[g]??0)+1;
        if(secondaryMuscles && e['secondary'] is List) {
          for(final s in (e['secondary'] as List)) {
            final g2=muscleGroupOf({'muscle':s});
            if(g2!=g) muscleCounts[g2]=(muscleCounts[g2]??0)+1;
          }
        }
      }
      if(exerciseMatchesFilters(e, muscle:muscleFilter,
          includeSecondary:secondaryMuscles,
          laterality:lateralityFilter, exerciseType:typeFilter,
          animatedOnly:animatedOnly, motions:exerciseMotions)) {
        final eq=equipmentGroupOf(e);
        equipmentCounts[eq]=(equipmentCounts[eq]??0)+1;
      }
    }

    Widget groupChip(String g) => Padding(
      padding:const EdgeInsets.only(right:6,bottom:6),
      child: FilterChip(
        materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,
        label:Text('$g · ${muscleCounts[g]??0}'),
        selected:muscleFilter==g,
        onSelected:(_)=>setState(()=>muscleFilter=muscleFilter==g?null:g),
      ),
    );
    Widget equipmentChip(String g) => Padding(
      padding:const EdgeInsets.only(right:6,bottom:6),
      child: FilterChip(
        materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,
        label:Text('$g · ${equipmentCounts[g]??0}'),
        selected:equipmentFilter==g,
        onSelected:(_)=>setState(()=>equipmentFilter=equipmentFilter==g?null:g),
      ),
    );
    final visibleGroups=groups.where((g)=>(muscleCounts[g]??0)>0 || muscleFilter==g).toList();
    final visibleGears=gears.where((g)=>(equipmentCounts[g]??0)>0 || equipmentFilter==g).toList();
    final activeFilters=[muscleFilter,equipmentFilter,lateralityFilter,typeFilter].whereType<String>().length+
      (animatedOnly?1:0)+(secondaryMuscles?1:0);

    return SizedBox(
      height:MediaQuery.sizeOf(c).height*.88,
      child:Padding(
        padding:const EdgeInsets.fromLTRB(16,12,16,6),
        child:Column(children:[
          Row(children:[
            Expanded(child:Text('Biblioteca de ejercicios',style:Theme.of(c).textTheme.titleLarge)),
            IconButton(tooltip:'Cerrar',icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(c)),
          ]),
          const SizedBox(height:6),
          TextField(
            controller:_search, autofocus:true, textInputAction:TextInputAction.search,
            decoration:InputDecoration(
              prefixIcon:const Icon(Icons.search),
              hintText:'Pec deck, contractora, single arm fly…',
              suffixIcon:query.isEmpty?null:IconButton(
                tooltip:'Borrar búsqueda',icon:const Icon(Icons.clear),
                onPressed:()=>setState(() {query='';_search.clear();}),
              ),
            ),
            onChanged:(value) {
              _searchDebounce?.cancel();
              _searchDebounce=Timer(const Duration(milliseconds: 130), () {
                if (mounted) { setState(() => query=value); }
              });
            },
          ),
          const SizedBox(height:6),
          Expanded(child:CustomScrollView(slivers:[
            SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Expanded(child:Text('${ranked.length} resultados · ${widget.exercises.length} ejercicios',
                  style:const TextStyle(color:muted,fontSize:12))),
                TextButton.icon(
                  icon:Icon(filtersOpen ? Icons.expand_less : Icons.expand_more, size:18),
                  label:Text('Filtros${activeFilters>0?' ($activeFilters)':''}'),
                  onPressed:()=>setState(()=>filtersOpen=!filtersOpen),
                ),
                if(activeFilters>0) IconButton(
                  tooltip:'Limpiar filtros',
                  icon:const Icon(Icons.filter_alt_off_outlined,size:20),
                  onPressed:reset,
                ),
              ]),
              if(!filtersOpen && activeFilters>0) ...[
                Text(
                  'Activos: ${[
                    if (muscleFilter!=null) muscleFilter!,
                    if (equipmentFilter!=null) equipmentFilter!,
                    if (lateralityFilter!=null) lateralityFilter!,
                    if (typeFilter!=null) typeFilter!,
                    if (animatedOnly) 'Con animación',
                    if (secondaryMuscles) 'Músculos secundarios',
                  ].join(' · ')}',
                  style:const TextStyle(color:muted,fontSize:12),
                  maxLines:2,overflow:TextOverflow.ellipsis,
                ),
              ],
              if(filtersOpen) ...[
                const SizedBox(height:8),
                const Text('GRUPO MUSCULAR',style:TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.bold)),
                const SizedBox(height:6),
                Wrap(children:visibleGroups.map(groupChip).toList()),
                const SizedBox(height:4),
                const Text('EQUIPAMIENTO',style:TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.bold)),
                const SizedBox(height:6),
                Wrap(children:visibleGears.map(equipmentChip).toList()),
                Align(
                  alignment:Alignment.centerLeft,
                  child:TextButton.icon(
                    icon:Icon(advancedOpen ? Icons.expand_less : Icons.tune,size:18),
                    label:Text(advancedOpen?'Menos opciones':'Más opciones'),
                    onPressed:()=>setState(()=>advancedOpen=!advancedOpen),
                  ),
                ),
                if(advancedOpen) ...[
                  const Divider(),
                  Wrap(spacing:6,runSpacing:5,children:[
                    OutlinedButton.icon(
                      icon:const Icon(Icons.bookmark_add_outlined,size:18),
                      label:const Text('Guardar filtros'),
                      onPressed:widget.store==null?null:_savePreset,
                    ),
                    OutlinedButton.icon(
                      icon:const Icon(Icons.bookmarks_outlined,size:18),
                      label:const Text('Mis filtros'),
                      onPressed:savedPreset==null?null:_restorePreset,
                    ),
                  ]),
                  const Text('VARIANTE',style:TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.bold)),
                  Wrap(spacing:6,children:[
                    for(final t in <String>['unilateral','bilateral','alternado'])
                      FilterChip(label:Text(t=='unilateral'?'Unilateral':t=='bilateral'?'Bilateral':'Alternado'),
                        selected:lateralityFilter==t,
                        onSelected:(_)=>setState(()=>lateralityFilter=lateralityFilter==t?null:t)),
                  ]),
                  const Text('TIPO',style:TextStyle(color:muted,fontSize:11,fontWeight:FontWeight.bold)),
                  Wrap(spacing:6,children:[
                    for(final t in <String>['aislamiento','compuesto'])
                      FilterChip(label:Text(t=='aislamiento'?'Aislamiento':'Compuesto'),
                        selected:typeFilter==t,
                        onSelected:(_)=>setState(()=>typeFilter=typeFilter==t?null:t)),
                  ]),
                  SwitchListTile.adaptive(
                    title:const Text('Solo con animación'),
                    value:animatedOnly,onChanged:(v)=>setState(()=>animatedOnly=v),
                    contentPadding:EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    title:const Text('Incluir músculos secundarios'),
                    value:secondaryMuscles,onChanged:(v)=>setState(()=>secondaryMuscles=v),
                    contentPadding:EdgeInsets.zero,
                  ),
                ],
              ],
              const SizedBox(height:4),
              Row(children:[
                const Icon(Icons.sort,size:18,color:muted),
                const SizedBox(width:8),
                const Text('Ordenar:',style:TextStyle(color:muted,fontSize:12)),
                const SizedBox(width:12),
                Expanded(child:DropdownButtonHideUnderline(child:DropdownButton<String>(
                  isExpanded:true,
                  value:sortMode,
                  items:const [
                    DropdownMenuItem(value:'used',child:Text('Más usados por ti')),
                    DropdownMenuItem(value:'alpha',child:Text('Nombre (A–Z)')),
                  ],
                  onChanged:(value){
                    if (value!=null) setState(()=>sortMode=value);
                  },
                ))),
              ]),
              if(sortMode=='used' &&
                  !widget.usageCounts.values.any((count)=>count>0))
                const Text(
                  'Sin sesiones finalizadas: el ranking aparecerá cuando registres entrenamientos.',
                  style:TextStyle(color:muted,fontSize:11),
                ),
              if(sortMode=='used' && widget.usageCounts.values.any((count)=>count>0))
                const Text(
                  'Posición por sesiones completadas, no por peso levantado ni series. Datos privados.',
                  style:TextStyle(color:muted,fontSize:11),
                ),
              if(query.trim().isNotEmpty && ranked.isNotEmpty) ...[
                const SizedBox(height:4),
                Text('Coincidencias sugeridas',style:Theme.of(c).textTheme.labelMedium),
                Wrap(spacing:6,children:[
                  for(final e in ranked.take(3).map((r)=>r.$2))
                    ActionChip(label:Text('${e['name']}',maxLines:1,overflow:TextOverflow.ellipsis),
                      onPressed:()=>setState(() {
                        query=(e['name']??'').toString();
                        _search.text=query;
                        _search.selection=TextSelection.collapsed(offset:query.length);
                      })),
                ]),
              ],
              const Divider(height:22),
            ])),
            if(ranked.isEmpty) const SliverToBoxAdapter(child:Padding(
              padding:EdgeInsets.all(18),
              child:Note('Sin resultados. Prueba otro nombre, cambia el equipo o limpia los filtros.'),
            )),
            SliverList(delegate:SliverChildBuilderDelegate((context,i) {
              final e=ranked[i].$2;
              final variant=lateralityOf(e);
              final count = widget.usageCounts[e['id']?.toString()] ?? 0;
              final isRanking = sortMode=='used' && query.trim().isEmpty && count>0;
              final subtitle='${muscleGroupOf(e)} · ${equipmentGroupOf(e)}${variant=='unilateral'?' · Unilateral':''}${count>0?' · $count ${count==1?'sesión':'sesiones'}':''}';
              return ListTile(
                contentPadding:const EdgeInsets.symmetric(horizontal:3,vertical:3),
                leading:SizedBox(width:isRanking?96:68,child:Row(children:[
                  if(isRanking) ...[
                    SizedBox(width:26,child:Text('${i+1}.',
                      style:const TextStyle(color:lime,fontWeight:FontWeight.bold))),
                    const SizedBox(width:2),
                  ],
                  ExerciseMotion(e,width:64,height:58),
                ])),
                title:Text('${e['name']}',maxLines:2,overflow:TextOverflow.ellipsis),
                subtitle:Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis),
                trailing:IconButton(
                  tooltip:'Ver técnica y referencias',icon:const Icon(Icons.info_outline),
                  onPressed:()=>technique(c,e),
                ),
                onTap:()=>Navigator.pop(c,e),
              );
            },childCount:ranked.length)),
            const SliverToBoxAdapter(child:SizedBox(height:22)),
          ])),
        ]),
      ),
    );
  }
}

class SessionPage extends ConsumerStatefulWidget {
  final String id;
  const SessionPage({super.key, required this.id});
  @override
  ConsumerState<SessionPage> createState() => _Session();
}

class _Session extends ConsumerState<SessionPage> {
  late Json w;
  bool busy = false;
  DateTime? rest;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    final a = ref.read(stateProvider);
    w = clone(a.workouts.where((e) => e['id'] == widget.id).firstOrNull ?? {});
    a.db.read(a.owner, 'timer', widget.id).then((v) {
      if (mounted && v is String) setState(() => rest = DateTime.tryParse(v));
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && rest != null) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> change(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    final a = ref.read(stateProvider);
    try {
      await action();
    } catch (e) {
      if (mounted) snack(context, a.api.explain(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int restForGroup(Json move, int requested) {
    final group = move['superset'];
    if (group == null) return requested;
    final linked = (w['exercises'] as List).where((item) => item['superset'] == group).toList();
    // Follow the exercise order shown on screen. Only the last member starts
    // the inter-round rest timer; earlier members flow directly to the next.
    if (linked.length < 2 || linked.last['id'] == move['id']) return requested;
    return 0;
  }

  Future<void> add(Json m, {Json? edit, bool repeat = false}) async {
    final a = ref.read(stateProvider), ex = a.catalog[m['exercise_id']]!;
    final list = m['sets'] as List;
    final source =
        edit ??
        (list.isNotEmpty
            ? Json.from(list.last as Map)
            : previousSet(a.workouts, ex['id'], except: widget.id));
    final storedMethod = await a.db.read(a.owner, 'load_profile', ex['id']);
    if (!mounted) return;
    final value = repeat && source != null
        ? clone(source)
        : await showModalBottomSheet<Json>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (c) => SetForm(
              ex: ex,
              old: source,
              imperial: a.imperial,
              initialLoadMethod: storedMethod is String ? storedMethod : null,
            ),
          );
    if (value == null || !mounted) return;
    // Entry preferences stay on the device. The public API only accepts
    // normalized load_kg; sending a new field would break synchronization.
    final chosenMethod = value.remove('_load_entry_method');
    // Repeating a single stage must never duplicate an advanced block ID.
    value.remove('method');
    value.remove('block_id');
    value.remove('phase');
    await change(() async {
      if (chosenMethod is String) {
        await a.db.put(a.owner, 'load_profile', ex['id'], chosenMethod);
      }
      value['id'] = edit?['id'] ?? ids.v4();
      if (edit == null) {
        list.add(value);
      } else {
        list[list.indexWhere((s) => s['id'] == edit['id'])] = value;
      }
      await a.save(w);
      final restSeconds = restForGroup(m, (value['rest_seconds'] as num?)?.toInt() ?? 0);
      rest = restSeconds > 0
          ? DateTime.now().add(Duration(seconds: restSeconds))
          : null;
      await a.db.put(a.owner, 'timer', widget.id, rest?.toIso8601String());
      // Native scheduled notification also works when the screen is locked.
      await restAlerts.schedule(widget.id, restSeconds);
    });
  }

  Future<void> addAdvanced(Json m) async {
    final a = ref.read(stateProvider), ex = a.catalog[m['exercise_id']]!;
    final recording = ex['recording'];
    if (recording == 'time' || recording == 'distance_time') {
      if (mounted) snack(context, 'Estos métodos registran repeticiones, no intervalos de cardio.');
      return;
    }
    final method = await pickMethod(context);
    if (method == null || !mounted) return;
    if (method == 'drop_set' && (recording == 'bodyweight_reps' || recording == 'assisted_reps')) {
      snack(context, 'Usa un ejercicio con carga ajustable para el drop set. La asistencia de máquina no equivale a carga externa.');
      return;
    }
    final list = m['sets'] as List;
    final source = list.isNotEmpty
        ? Json.from(list.last as Map)
        : previousSet(a.workouts, ex['id'], except: widget.id);
    final preferred = await a.db.read(a.owner, 'load_profile', ex['id']);
    if (!mounted) return;
    final base = await showModalBottomSheet<Json>(
      context: context, useSafeArea: true, isScrollControlled: true,
      builder: (_) => SetForm(ex: ex, old: source, imperial: a.imperial,
        initialLoadMethod: preferred is String ? preferred : null),
    );
    if (base == null || !mounted) return;
    final rows = await showModalBottomSheet<List<Json>>(
      context: context, useSafeArea: true, isScrollControlled: true,
      builder: (_) => TechniqueSequenceForm(
        exercise: ex, base: base, method: method, imperial: a.imperial),
    );
    if (rows == null || !mounted) return;
    final preference = base['_load_entry_method'];
    await change(() async {
      if (preference is String) await a.db.put(a.owner, 'load_profile', ex['id'], preference);
      list.addAll(rows);
      await a.save(w);
      final seconds = restForGroup(m, (rows.last['rest_seconds'] as num?)?.toInt() ?? 0);
      rest = seconds > 0 ? DateTime.now().add(Duration(seconds: seconds)) : null;
      await a.db.put(a.owner, 'timer', widget.id, rest?.toIso8601String());
      await restAlerts.schedule(widget.id, seconds);
    });
  }

  Future<void> editAdvanced(Json m, Json st) async {
    final a = ref.read(stateProvider), ex = a.catalog[m['exercise_id']]!;
    final block = st['block_id'];
    if (block == null) return;
    final list = m['sets'] as List;
    final group = list.where((v) => v['block_id'] == block)
        .map((v) => Json.from(v as Map)).toList()
      ..sort((a, b) => (a['phase'] as num).compareTo(b['phase'] as num));
    if (group.isEmpty) return;
    final storedMethod = await a.db.read(a.owner, 'load_profile', ex['id']);
    if (!mounted) return;
    final rows = await showModalBottomSheet<List<Json>>(
      context: context, useSafeArea: true, isScrollControlled: true,
      builder: (_) => TechniqueSequenceForm(
        exercise: ex, base: group.first,
        initialLoadMethod: storedMethod is String ? storedMethod : null,
        method: group.first['method']?.toString() ?? 'drop_set',
        imperial: a.imperial, existing: group),
    );
    if (rows == null || !mounted) return;
    await change(() async {
      final index = list.indexWhere((v) => v['block_id'] == block);
      list.removeWhere((v) => v['block_id'] == block);
      list.insertAll(index, rows);
      await a.save(w);
    });
  }

  Future<void> deleteAdvanced(Json m, Json st) async {
    final block = st['block_id'];
    if (block == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Eliminar bloque completo'),
      content: const Text('Esta acción eliminará todas las etapas del método avanzado.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
      ],
    ));
    if (confirm != true || !mounted) return;
    final a = ref.read(stateProvider);
    await change(() async {
      (m['sets'] as List).removeWhere((v) => v['block_id'] == block);
      await a.save(w);
    });
  }

  Future<void> removeExercise(Json move) async {
    if (busy || w['ended_at'] != null) return;
    final a = ref.read(stateProvider);
    final exercise = a.catalog[move['exercise_id']];
    final title = exercise?['name']?.toString() ?? 'este ejercicio';
    final count = (move['sets'] as List).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('¿Quitar ejercicio?'),
        content: Text('Se quitará "$title" y sus $count serie(s) de este entrenamiento. Los otros ejercicios se conservarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Conservar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Quitar ejercicio')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await change(() async {
      removeExerciseFromDraft(w, move['id'].toString());
      await a.save(w);
      if (!(w['exercises'] as List).any((e) => (e['sets'] as List).isNotEmpty)) {
        rest = null;
        await a.db.put(a.owner, 'timer', widget.id, null);
        await restAlerts.cancel(widget.id);
      }
    });
  }

  Future<void> discardWorkout() async {
    if (busy || w['ended_at'] != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('¿Descartar entrenamiento?'),
        content: const Text(
          'Se eliminará esta sesión en curso, incluidos todos sus ejercicios y series. No se guardará en tu historial. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Seguir entrenando')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Descartar entrenamiento')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final a = ref.read(stateProvider);
    await change(() async {
      await a.discardDraft(widget.id);
      await restAlerts.cancel(widget.id);
      if (mounted) context.go('/entrenar');
    });
  }

  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    if (w.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Note('Sesión no encontrada'),
      );
    }
    final finished = w['ended_at'] != null;
    final remaining = (rest?.difference(DateTime.now()).inSeconds ?? 0).clamp(
      0,
      3600,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(w['name']),
        actions: [
          if (!finished)
            IconButton(
              tooltip: 'Descartar entrenamiento',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: busy ? null : discardWorkout,
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'routine') {
                final name = await ask(
                  c,
                  'Nombre de la rutina',
                  initial: w['name'],
                );
                if (name == null || name.isEmpty || !c.mounted) return;
                final raw = await ask(
                  c,
                  'Día de la semana (1–7 o vacío)',
                  limit: 1,
                );
                if (raw == null) return;
                final day = int.tryParse(raw);
                await a.routine(
                  w,
                  name,
                  day != null && day >= 1 && day <= 7 ? day - 1 : null,
                );
                if (c.mounted) snack(c, 'Rutina guardada');
                return;
              }
              final value = await ask(
                c,
                v == 'name' ? 'Nombre de la sesión' : 'Notas privadas',
                initial: w[v],
                limit: v == 'name' ? 100 : 2000,
              );
              if (value != null && mounted) {
                await change(() async {
                  w[v] = value;
                  await a.save(w);
                });
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'routine',
                child: Text('Guardar rutina'),
              ),
              if (!finished) ...[
                const PopupMenuItem(
                  value: 'name',
                  child: Text('Cambiar nombre'),
                ),
                const PopupMenuItem(
                  value: 'notes',
                  child: Text('Notas privadas'),
                ),
              ],
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Note(
              "${day(w['started_at'])} · ${finished ? 'Finalizada' : 'Cada serie se guarda en el teléfono'}",
            ),
            if (w['notes'] != '') Note(w['notes']),
            if (w['state'] == 'conflict')
              Card(
                child: Column(
                  children: [
                    const Note(
                      'La copia del servidor y la local son distintas.',
                    ),
                    for (final keep in [true, false])
                      TextButton(
                        onPressed: () async {
                          await a.db.resolve(a.owner, w, keep);
                          await a.reload();
                          if (c.mounted) c.pop();
                        },
                        child: Text(
                          keep
                              ? 'Conservar las dos copias'
                              : 'Usar la copia del servidor',
                        ),
                      ),
                  ],
                ),
              ),
            if (remaining > 0 && !finished)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined, color: lime),
                  title: Text(
                    'Descanso · ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Terminar descanso',
                    onPressed: () {
                      setState(() => rest = null);
                      restAlerts.cancel(widget.id);
                      a.db.put(a.owner, 'timer', widget.id, null);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ...(w['exercises'] as List).map((item) {
              final m = item as Json;
              final ex = a.catalog[m['exercise_id']];
              if (ex == null) return const SizedBox.shrink();
              final last = previousSet(a.workouts, ex['id'], except: widget.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ex['name'],
                              style: Theme.of(c).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ver técnica',
                            onPressed: () => technique(c, ex),
                            icon: const Icon(Icons.info_outline),
                          ),
                          if (!finished)
                            IconButton(
                              tooltip: 'Quitar ejercicio completo',
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: busy ? null : () => removeExercise(m),
                            ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => technique(c, ex),
                          child: ExerciseMotion(ex, width: 140, height: 94),
                        ),
                      ),
                      Text(
                        "${ex['muscle']} · ${ex['equipment']}",
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      if (loadEntryNames.containsKey(loadEntryKind(ex)))
                        Text(
                          'Registro de carga: ${loadEntryNames[loadEntryKind(ex)]}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      if (last != null)
                        Note(
                          'Última sesión · ${setLabel(last, ex, a.imperial)}',
                        ),
                      if (m['superset'] != null)
                        Note(() {
                          final members = (w['exercises'] as List)
                              .where((v) => v['superset'] == m['superset']).length;
                          final title = members >= 3 ? 'Serie gigante' :
                              members == 2 ? 'Superserie' : 'Grupo pendiente';
                          return '$title ${m['superset']} · $members ejercicio(s)';
                        }()),
                      ...(m['sets'] as List).asMap().entries.map((entry) {
                        final st = entry.value as Json;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Text('${entry.key + 1}'),
                          title: Text(setLabel(st, ex, a.imperial)),
                          subtitle: Text(
                            '${st['block_id'] != null ? '${techniqueName(st['method']?.toString())} · etapa ${((st['phase'] as num?)?.toInt() ?? 0) + 1} · ' : ''}'
                            "${{'normal': 'Normal', 'warmup': 'Calentamiento', 'failure': 'Al fallo'}[st['kind']]} · pausa ${st['rest_seconds'] ?? 0} s · RPE ${st['rpe'] ?? '—'} · RIR ${st['rir'] ?? '—'}",
                          ),
                          onTap: finished || busy ? null : () => st['block_id'] != null
                              ? editAdvanced(m, st) : add(m, edit: st),
                          trailing: finished || busy ? null : st['block_id'] != null && st['phase'] != 0
                              ? const SizedBox(width: 1)
                              : IconButton(
                                  tooltip: st['block_id'] != null ? 'Quitar bloque' : 'Quitar serie',
                                  icon: const Icon(Icons.close, size: 17),
                                  onPressed: () => st['block_id'] != null
                                      ? deleteAdvanced(m, st)
                                      : change(() async {
                                          (m['sets'] as List).removeAt(entry.key);
                                          await a.save(w);
                                        }),
                                ),
                        );
                      }),
                      if (!finished)
                        Wrap(
                          spacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: busy ? null : () => add(m),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Serie'),
                            ),
                            if ((m['sets'] as List).isNotEmpty || last != null)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => add(m, repeat: true),
                                child: const Text('Repetir valores'),
                              ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.layers_outlined, size: 18),
                              label: const Text('Método'),
                              onPressed: busy ? null : () => addAdvanced(m),
                            ),
                            IconButton(
                              tooltip: 'Superserie / serie gigante',
                              icon: const Icon(Icons.link),
                              onPressed: busy ? null : () async {
                                final v = await chooseExerciseGroup(c, w, m);
                                if (v != null) {
                                  await change(() async {
                                    m['superset'] = v.isEmpty ? null : v;
                                    await a.save(w);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (!finished) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final e = await showModalBottomSheet<Json>(
                          context: c,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => Picker(
                            a.catalog.values.toList(),
                            store:a.db,
                            owner:a.owner,
                            usageCounts: countExerciseSessions(a.workouts),
                          ),
                        );
                        if (e != null) {
                          await change(() async {
                            (w['exercises'] as List).add({
                              'id': ids.v4(),
                              'exercise_id': e['id'],
                              'superset': null,
                              'sets': <dynamic>[],
                            });
                            await a.save(w);
                          });
                        }
                      },
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => change(() async {
                        if (!(w['exercises'] as List).any(
                          (e) => (e['sets'] as List).isNotEmpty,
                        )) {
                          snack(c, 'Registra al menos una serie.');
                          return;
                        }
                        await a.finish(w);
                        await restAlerts.cancel(widget.id);
                        if (c.mounted) c.pop();
                      }),
                icon: const Icon(Icons.check),
                label: const Text('Finalizar entrenamiento'),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: busy ? null : discardWorkout,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('Descartar entrenamiento',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class SetForm extends StatefulWidget {
  final Json ex;
  final Json? old;
  final bool imperial;
  final String? initialLoadMethod;
  const SetForm({
    super.key,
    required this.ex,
    this.old,
    required this.imperial,
    this.initialLoadMethod,
  });
  @override
  State<SetForm> createState() => _SetForm();
}

class _SetForm extends State<SetForm> {
  final form = GlobalKey<FormState>();
  late Map<String, String> values;
  late String kind;
  late String entryMethod;
  bool platesBySide = false;

  String get unit => widget.imperial ? 'lb' : 'kg';

  double parsed(String key) => double.tryParse(values[key] ?? '') ?? 0;

  double get displayedLoad {
    if ((entryMethod == 'barbell' || entryMethod == 'plate_machine') && platesBySide) {
      return parsed('bar_kg') + 2 * parsed('plates_side');
    }
    final single = parsed('load_kg');
    return loadIsPair(entryMethod) ? 2 * single : single;
  }

  double get standardizedLoadKg => normalizedMass(displayedLoad, widget.imperial);

  @override
  void initState() {
    super.initState();
    final old = widget.old ?? <String, dynamic>{};
    kind = old['kind'] ?? 'normal';
    final suggested = loadEntryKind(widget.ex);
    entryMethod = loadEntryNames.containsKey(widget.initialLoadMethod)
        ? widget.initialLoadMethod!
        : suggested;
    platesBySide = entryMethod == 'plate_machine';
    final oldLoad = displayMass(numOf(old['load_kg']), widget.imperial);
    final barKg = numOf((widget.ex['load_profile'] is Map)
        ? widget.ex['load_profile']['default_bar_kg']
        : 20);
    values = {
      'load_kg': oldLoad == 0 ? '' : _formatLoad(oldLoad / (loadIsPair(entryMethod) ? 2 : 1)),
      'bar_kg': entryMethod == 'plate_machine' ? '0' : _formatLoad(displayMass(barKg, widget.imperial)),
      'plates_side': entryMethod == 'plate_machine' ? _formatLoad(oldLoad / 2) : '',
      'reps': '${old['reps'] ?? 10}',
      'seconds': '${old['seconds'] ?? 60}',
      'distance_m': '${old['distance_m'] ?? 1000}',
      'rpe': '${old['rpe'] ?? ''}',
      'rir': '${old['rir'] ?? ''}',
      'rest_seconds': '${old['rest_seconds'] ?? 90}',
    };
  }

  String _formatLoad(double x) {
    if (x == 0) return '';
    final value = x.toStringAsFixed(2);
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void changeEntryMethod(String next) {
    final oldTotal = displayedLoad;
    setState(() {
      entryMethod = next;
      platesBySide = next == 'plate_machine';
      if (platesBySide) {
        values['bar_kg'] = '0';
        values['plates_side'] = _formatLoad(oldTotal / 2);
      }
      values['load_kg'] = _formatLoad(oldTotal / (loadIsPair(next) ? 2 : 1));
    });
  }

  Widget repetitionsWheel() {
    final initial = (int.tryParse(values['reps'] ?? '') ?? 10).clamp(1, 1000);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.ex['load_profile'] is Map &&
                    widget.ex['load_profile']['unilateral'] == true
                ? 'Repeticiones (por lado)'
                : 'Repeticiones',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 142,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: lime.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lime.withValues(alpha: .5)),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: FixedExtentScrollController(initialItem: initial - 1),
                  physics: const FixedExtentScrollPhysics(),
                  itemExtent: 46,
                  onSelectedItemChanged: (index) => values['reps'] = '${index + 1}',
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 1000,
                    builder: (context, index) => Center(
                      child: Text('${index + 1}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget field(
    String k,
    String label,
    double min,
    double max, {
    bool optional = false,
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      // Reset only when switching the entry scheme, not when typing numbers.
      key: ValueKey('$k/$entryMethod/$platesBySide'),
      initialValue: values[k],
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(
        labelText: label,
        hintText: k == 'load_kg' || k == 'plates_side' ? '0' : null,
      ),
      onChanged: (v) {
        values[k] = v.replaceAll(',', '.');
        if (['load_kg', 'bar_kg', 'plates_side'].contains(k)) setState(() {});
      },
      validator: (_) {
        final v = values[k] ?? '';
        if ((optional || ['load_kg', 'plates_side'].contains(k)) && v.isEmpty) return null;
        final n = double.tryParse(v);
        return n == null || !n.isFinite || n < min || n > max ||
                (integer && n != n.roundToDouble())
            ? 'Revisa el valor ($min–$max)'
            : null;
      },
    ),
  );

  Widget loadInputs() {
    final profile = widget.ex['load_profile'];
    final unilateral = profile is Map && profile['unilateral'] == true;
    final mode = widget.ex['recording'];
    if (mode == 'weighted_reps' || mode == 'assisted_reps') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field('load_kg', '${mode == 'weighted_reps' ? 'Lastre añadido' : 'Asistencia indicada'} ($unit)', 0, displayMass(1000, widget.imperial)),
          Note(loadEntryHint(mode == 'weighted_reps' ? 'added' : 'assisted')),
        ],
      );
    }
    final captions = <String, String>{
      'barbell': 'Peso TOTAL de barra y discos ($unit)',
      'dumbbell_pair': 'Peso de CADA mancuerna ($unit)',
      'dumbbell_single': 'Peso de UNA mancuerna ($unit)',
      'cable_pair': 'Peso indicado en CADA torre ($unit)',
      'cable_single': 'Peso indicado en la polea ($unit)',
      'machine': 'Peso indicado en la máquina ($unit)',
      'plate_machine': 'Carga total externa ($unit)',
      'single': 'Carga del implemento ($unit)',
    };
    final profileReview = profile is Map && profile['confidence'] == 'needs_review';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('load-method/$entryMethod'),
          initialValue: entryMethod,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Cómo registrar la carga'),
          items: loadEntryNames.entries.map((e) => DropdownMenuItem<String>(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) { if (value != null) changeEntryMethod(value); },
        ),
        const SizedBox(height: 10),
        if (profileReview) const Note('Método sugerido automáticamente. Verifica si coincide con tu equipo; puedes cambiarlo aquí y KYVORA lo recordará para este ejercicio.'),
        if (entryMethod == 'barbell' || entryMethod == 'plate_machine') ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(entryMethod == 'plate_machine' ? 'Sumar discos por lado' : 'Calcular con discos por lado'),
            subtitle: Text(entryMethod == 'plate_machine' ? 'Carro/base (si se conoce) + discos de ambos lados' : 'Barra + discos izquierdos + discos derechos'),
            value: platesBySide,
            onChanged: (value) {
              final total = displayedLoad;
              setState(() {
                platesBySide = value;
                if (value) {
                  values['plates_side'] = _formatLoad(
                    ((total - parsed('bar_kg')) / 2).clamp(0.0, 1000.0).toDouble(),
                  );
                } else {
                  values['load_kg'] = _formatLoad(total);
                }
              });
            },
          ),
          if (platesBySide) ...[
            field('bar_kg', entryMethod == 'plate_machine' ? 'Peso del carro/base conocido ($unit)' : 'Peso real de la barra ($unit)', 0, displayMass(1000, widget.imperial)),
            field('plates_side', 'Discos por CADA lado ($unit)', 0, displayMass(500, widget.imperial)),
          ] else field('load_kg', captions[entryMethod]!, 0, displayMass(1000, widget.imperial)),
        ] else field('load_kg', captions[entryMethod]!, 0,
            displayMass(loadIsPair(entryMethod) ? 500 : 1000, widget.imperial)),
        Note(loadEntryHint(entryMethod, unilateral: unilateral)),
        if (displayedLoad > 0) ...[
          const SizedBox(height: 4),
          Text('Carga registrada: ${_formatLoad(displayedLoad)} $unit${loadIsPair(entryMethod) || (entryMethod == 'barbell' || entryMethod == 'plate_machine') ? ' en total' : ''}',
              style: const TextStyle(color: lime, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext c) {
    final mode = widget.ex['recording'];
    final timed = ['time', 'distance_time'].contains(mode);
    final weighted = ['weight_reps', 'weighted_reps', 'assisted_reps'].contains(mode);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(c).bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.ex['name'], style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (weighted) loadInputs(),
              if (!weighted && !timed) Note(loadEntryHint('bodyweight')),
              if (!timed) repetitionsWheel(),
              if (timed) field('seconds', 'Duración (s)', 1, 86400),
              if (mode == 'distance_time') field('distance_m', 'Distancia (m)', 1, 1000000),
              Row(children: [
                const Expanded(child: Text('Tipo de serie')),
                IconButton(icon: const Icon(Icons.info_outline),
                    tooltip: 'Qué significan los tipos de serie',
                    onPressed: () => explainSetKinds(c)),
              ]),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'warmup', child: Text('Calentamiento')),
                  DropdownMenuItem(value: 'failure', child: Text('Al fallo')),
                ],
                onChanged: (v) => kind = v!,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: field('rpe', 'RPE (opcional)', 1, 10, optional: true)),
                  const SizedBox(width: 8),
                  Expanded(child: field('rir', 'RIR (opcional)', 0, 20, integer: true, optional: true)),
                ],
              ),
              field('rest_seconds', 'Descanso (s)', 0, 3600, integer: true),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    if (weighted && (standardizedLoadKg < 0 || standardizedLoadKg > 1000)) {
                      snack(c, 'La carga total debe estar entre 0 y 1000 kg');
                      return;
                    }
                    double? val(String k) => double.tryParse(values[k] ?? '');
                    Navigator.pop(c, {
                      'id': ids.v4(),
                      'kind': kind,
                      'load_kg': weighted ? standardizedLoadKg : 0.0,
                      'reps': timed ? null : val('reps')!.toInt(),
                      'seconds': timed ? val('seconds') : null,
                      'distance_m': mode == 'distance_time' ? val('distance_m') : null,
                      'rpe': val('rpe'),
                      'rir': val('rir')?.toInt(),
                      'rest_seconds': val('rest_seconds')!.toInt(),
                      if (mode == 'weight_reps') '_load_entry_method': entryMethod,
                    });
                  },
                  child: const Text('Guardar serie'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
