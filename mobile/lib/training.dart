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
        SizedBox(height: 110, child: SvgPicture.asset(e['image'])),
        Text(e['name'], style: Theme.of(d).textTheme.headlineMedium),
        Note('${e['name_en']} · ${e['muscle']} · ${e['equipment']}'),
        Text(e['description']),
        const SizedBox(height: 14),
        const Text('Técnica', style: TextStyle(color: lime)),
        Text(e['technique']),
        const SizedBox(height: 14),
        const Text('Errores frecuentes', style: TextStyle(color: lime)),
        Text(e['errors']),
        const Note(
          'El esquema indica la región de trabajo. Con mancuernas simultáneas se registra la carga externa total. Para variantes unilaterales registra carga y repeticiones por lado.',
        ),
      ],
    ),
  ),
);

class Picker extends StatefulWidget {
  final List<Json> exercises;
  const Picker(this.exercises, {super.key});
  @override
  State<Picker> createState() => _Picker();
}

class _Picker extends State<Picker> {
  String filter = '';
  @override
  Widget build(BuildContext c) {
    final items = widget.exercises
        .where(
          (e) => "${e['name']} ${e['name_en']} ${e['muscle']} ${e['equipment']}"
              .toLowerCase()
              .contains(filter.toLowerCase()),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(c).height * .85,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Biblioteca · ${widget.exercises.length}',
              style: Theme.of(c).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Ejercicio, músculo o equipo',
              ),
              onChanged: (v) => setState(() => filter = v),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (d, i) {
                  final e = items[i];
                  return ListTile(
                    leading: SizedBox(
                      width: 34,
                      child: SvgPicture.asset(e['image']),
                    ),
                    title: Text(e['name']),
                    subtitle: Text("${e['muscle']} · ${e['equipment']}"),
                    trailing: IconButton(
                      tooltip: 'Técnica',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => technique(c, e),
                    ),
                    onTap: () => Navigator.pop(c, e),
                  );
                },
              ),
            ),
          ],
        ),
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

  Future<void> add(Json m, {Json? edit, bool repeat = false}) async {
    final a = ref.read(stateProvider), ex = a.catalog[m['exercise_id']]!;
    final list = m['sets'] as List;
    final source =
        edit ??
        (list.isNotEmpty
            ? Json.from(list.last as Map)
            : previousSet(a.workouts, ex['id'], except: widget.id));
    final value = repeat && source != null
        ? clone(source)
        : await showModalBottomSheet<Json>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (c) => SetForm(ex: ex, old: source, imperial: a.imperial),
          );
    if (value == null || !mounted) return;
    await change(() async {
      value['id'] = edit?['id'] ?? ids.v4();
      if (edit == null) {
        list.add(value);
      } else {
        list[list.indexWhere((s) => s['id'] == edit['id'])] = value;
      }
      await a.save(w);
      rest = DateTime.now().add(Duration(seconds: value['rest_seconds']));
      await a.db.put(a.owner, 'timer', widget.id, rest!.toIso8601String());
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
                        ],
                      ),
                      Text(
                        "${ex['muscle']} · ${ex['equipment']}",
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      if (last != null)
                        Note(
                          'Última sesión · ${setLabel(last, ex, a.imperial)}',
                        ),
                      if (m['superset'] != null)
                        Note("Superserie ${m['superset']}"),
                      ...(m['sets'] as List).asMap().entries.map((entry) {
                        final st = entry.value as Json;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Text('${entry.key + 1}'),
                          title: Text(setLabel(st, ex, a.imperial)),
                          subtitle: Text(
                            "${{'normal': 'Normal', 'warmup': 'Calentamiento', 'failure': 'Al fallo'}[st['kind']]} · RPE ${st['rpe'] ?? '—'} · RIR ${st['rir'] ?? '—'}",
                          ),
                          onTap: finished || busy
                              ? null
                              : () => add(m, edit: st),
                          trailing: finished
                              ? null
                              : IconButton(
                                  tooltip: 'Quitar serie',
                                  icon: const Icon(Icons.close, size: 17),
                                  onPressed: busy
                                      ? null
                                      : () => change(() async {
                                          (m['sets'] as List).removeAt(
                                            entry.key,
                                          );
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
                            IconButton(
                              tooltip: 'Grupo de superserie',
                              icon: const Icon(Icons.link),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final v = await ask(
                                        c,
                                        'Grupo de superserie',
                                        initial: m['superset'] ?? '',
                                        limit: 24,
                                      );
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
                          builder: (_) => Picker(a.catalog.values.toList()),
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
                        if (c.mounted) c.pop();
                      }),
                icon: const Icon(Icons.check),
                label: const Text('Finalizar entrenamiento'),
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
  const SetForm({
    super.key,
    required this.ex,
    this.old,
    required this.imperial,
  });
  @override
  State<SetForm> createState() => _SetForm();
}

class _SetForm extends State<SetForm> {
  final form = GlobalKey<FormState>();
  late Map<String, String> values;
  late String kind;
  @override
  void initState() {
    super.initState();
    final old = widget.old ?? {};
    kind = old['kind'] ?? 'normal';
    values = {
      'load_kg': displayMass(
        numOf(old['load_kg']),
        widget.imperial,
      ).toStringAsFixed(2),
      'reps': '${old['reps'] ?? 10}',
      'seconds': '${old['seconds'] ?? 60}',
      'distance_m': '${old['distance_m'] ?? 1000}',
      'rpe': '${old['rpe'] ?? ''}',
      'rir': '${old['rir'] ?? ''}',
      'rest_seconds': '${old['rest_seconds'] ?? 90}',
    };
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
      initialValue: values[k],
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => values[k] = v.replaceAll(',', '.'),
      validator: (_) {
        final v = values[k] ?? '';
        if (optional && v.isEmpty) return null;
        final n = double.tryParse(v);
        return n == null ||
                !n.isFinite ||
                n < min ||
                n > max ||
                (integer && n != n.roundToDouble())
            ? 'Revisa el valor ($min–$max)'
            : null;
      },
    ),
  );
  @override
  Widget build(BuildContext c) {
    final mode = widget.ex['recording'];
    final timed = ['time', 'distance_time'].contains(mode),
        weighted = [
          'weight_reps',
          'weighted_reps',
          'assisted_reps',
        ].contains(mode);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        MediaQuery.viewInsetsOf(c).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.ex['name'], style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 14),
              if (weighted)
                field(
                  'load_kg',
                  "${mode == 'assisted_reps'
                      ? 'Asistencia'
                      : mode == 'weighted_reps'
                      ? 'Lastre'
                      : 'Carga'} (${widget.imperial ? 'lb' : 'kg'})",
                  0,
                  displayMass(1000, widget.imperial),
                ),
              if (!timed) field('reps', 'Repeticiones', 1, 1000, integer: true),
              if (timed) field('seconds', 'Duración (s)', 1, 86400),
              if (mode == 'distance_time')
                field('distance_m', 'Distancia (m)', 1, 1000000),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Tipo de serie'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(
                    value: 'warmup',
                    child: Text('Calentamiento'),
                  ),
                  DropdownMenuItem(value: 'failure', child: Text('Al fallo')),
                ],
                onChanged: (v) => kind = v!,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: field(
                      'rpe',
                      'RPE (opcional)',
                      1,
                      10,
                      optional: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: field(
                      'rir',
                      'RIR (opcional)',
                      0,
                      20,
                      integer: true,
                      optional: true,
                    ),
                  ),
                ],
              ),
              field('rest_seconds', 'Descanso (s)', 0, 3600, integer: true),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    double? val(String k) => double.tryParse(values[k] ?? '');
                    Navigator.pop(c, {
                      'id': ids.v4(),
                      'kind': kind,
                      'load_kg': weighted
                          ? normalizedMass(val('load_kg')!, widget.imperial)
                          : 0.0,
                      'reps': timed ? null : val('reps')!.toInt(),
                      'seconds': timed ? val('seconds') : null,
                      'distance_m': mode == 'distance_time'
                          ? val('distance_m')
                          : null,
                      'rpe': val('rpe'),
                      'rir': val('rir')?.toInt(),
                      'rest_seconds': val('rest_seconds')!.toInt(),
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
