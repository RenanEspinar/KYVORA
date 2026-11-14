part of 'main.dart';

// The exercise grouping (superset/giant set) is independent from the set method
// (drop set, rest-pause, myo-reps or cluster). Both survive synchronization.
const trainingMethods = <String, (String, String, String)>{
  'drop_set': (
    'Drop set',
    'Al terminar una serie, reduce la carga y continúa con el mismo ejercicio sin descanso significativo.',
    'Ejemplo: 40 kg × 10 → 32 kg × 8 → 24 kg × 8. Se registran las tres etapas.',
  ),
  'rest_pause': (
    'Rest-pause',
    'Divide una serie en esfuerzos cortos, separados por pausas breves de 10–25 segundos.',
    'Ejemplo: 50 kg × 10 → pausa 20 s → 3 rep → pausa 20 s → 3 rep.',
  ),
  'myo_reps': (
    'Myo-reps',
    'Realiza una serie inicial de activación y luego miniseries con la misma carga y pausas cortas.',
    'Ejemplo: 35 kg × 15 → 15 s → 4 rep → 15 s → 4 rep.',
  ),
  'pyramid': (
    'Pirámide',
    'Aumenta o disminuye la carga entre series, ajustando las repeticiones. Entre etapas puedes descansar normalmente.',
    'Ejemplo ascendente: 40 kg × 12 → 45 kg × 10 → 50 kg × 8.',
  ),
  'cluster': (
    'Cluster',
    'Fracciona una serie en bloques de pocas repeticiones con pausas cortas dentro de la serie.',
    'Ejemplo: 70 kg × 3 → 25 s → 3 rep → 25 s → 3 rep.',
  ),
};

String techniqueName(String? method) =>
    trainingMethods[method]?.$1 ?? 'Serie normal';

Future<void> showMethodHelp(BuildContext context, String method) async {
  final t = trainingMethods[method];
  if (t == null) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.$1),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.$2),
        const SizedBox(height: 12),
        Text(t.$3, style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        const Text('Elige las cargas y repeticiones según tu capacidad. Evita entrenar al fallo en todas las series.'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
    ),
  );
}

Future<void> explainSetKinds(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text('Tipos de serie'),
    content: const Text('Normal: serie de trabajo convencional.\n\n'
        'Calentamiento: serie de aproximación, normalmente con menor carga. No genera récords.\n\n'
        'Al fallo: termina cuando ya no puedes completar otra repetición con técnica adecuada. '
        'No es necesario llegar al fallo en todas las series.\n\n'
        'RIR: repeticiones que crees poder completar antes del fallo. RPE: percepción del esfuerzo (1–10).'),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar'))],
  ),
);

Future<String?> pickMethod(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheet) => SingleChildScrollView(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Métodos avanzados', style: Theme.of(sheet).textTheme.titleLarge),
      const Note('Cada etapa se guarda con su carga, repeticiones y pausa. No modifica los ejercicios anteriores.'),
      for (final t in trainingMethods.entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.value.$1),
          subtitle: Text(t.value.$2, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Qué es ${t.value.$1}',
            onPressed: () => showMethodHelp(sheet, t.key),
          ),
          onTap: () => Navigator.pop(sheet, t.key),
        ),
    ]),
  )),
);

Future<void> explainExerciseGroups(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text('Superseries y series gigantes'),
    content: const Text(
      'Superserie: enlaza dos ejercicios y alterna sus series con poca o ninguna pausa entre ellos.\n\n'
      'Serie gigante: enlaza tres o más ejercicios en la misma ronda.\n\n'
      'Asigna la misma letra a los ejercicios del grupo (por ejemplo, A) y realiza las series en el orden mostrado. El descanso empieza tras el último ejercicio del grupo. '
      'No se modifican las cargas ni se suman los pesos de ejercicios diferentes.'
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
  ),
);

Future<String?> chooseExerciseGroup(BuildContext context, Json workout, Json move) {
  final all = (workout['exercises'] as List).whereType<Map>();
  final counts = <String, int>{};
  for (final m in all) {
    final group = m['superset'];
    if (group is String && group.isNotEmpty) counts[group] = (counts[group] ?? 0) + 1;
  }
  String newName = 'A';
  for (final letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
    if (!counts.containsKey(letter)) { newName = letter; break; }
  }
  return showModalBottomSheet<String>(
    context: context, useSafeArea: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Agrupar ejercicios', style: Theme.of(c).textTheme.titleLarge)),
          IconButton(icon: const Icon(Icons.info_outline), tooltip: 'Explicación',
              onPressed: () => explainExerciseGroups(c)),
        ]),
        const Note('Elige la misma letra en los ejercicios que quieras enlazar.'),
        ListTile(
          leading: const Icon(Icons.link_off), title: const Text('Sin grupo'),
          onTap: () => Navigator.pop(c, ''),
        ),
        for (final entry in counts.entries)
          ListTile(
            leading: CircleAvatar(child: Text(entry.key)),
            title: Text('Grupo ${entry.key}'),
            subtitle: Text(entry.value >= 3 ? 'Serie gigante · ${entry.value} ejercicios' :
              entry.value == 2 ? 'Superserie · 2 ejercicios' : '1 ejercicio · añade otro para enlazar'),
            trailing: move['superset'] == entry.key ? const Icon(Icons.check, color: lime) : null,
            onTap: () => Navigator.pop(c, entry.key),
          ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline, color: lime),
          title: Text('Crear grupo $newName'),
          onTap: () => Navigator.pop(c, newName),
        ),
      ]),
    ),
  );
}

class _TechniqueStage {
  final TextEditingController load;
  int reps;
  int pause;
  _TechniqueStage(double value, this.reps, this.pause)
      : load = TextEditingController(text: value == 0 ? '' : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), ''));
  void dispose() => load.dispose();
}

class TechniqueSequenceForm extends StatefulWidget {
  final Json exercise;
  final Json base;
  final String method;
  final bool imperial;
  final List<Json>? existing;
  final String? initialLoadMethod;
  const TechniqueSequenceForm({super.key, required this.exercise,
    required this.base, required this.method, required this.imperial,
    this.existing, this.initialLoadMethod});
  @override
  State<TechniqueSequenceForm> createState() => _TechniqueSequenceFormState();
}

class _TechniqueSequenceFormState extends State<TechniqueSequenceForm> {
  final stages = <_TechniqueStage>[];
  bool get weighted => ['weight_reps','weighted_reps','assisted_reps']
      .contains(widget.exercise['recording']);
  String get unit => widget.imperial ? 'lb' : 'kg';
  String get loadCaption => widget.exercise['recording'] == 'weighted_reps'
      ? 'Lastre añadido ($unit)'
      : widget.exercise['recording'] == 'assisted_reps'
      ? 'Asistencia indicada ($unit)'
      : divisor == 2 ? 'Por unidad ($unit)' : 'Carga ($unit)';
  late final String inputMethod;
  double get divisor => widget.exercise['recording'] == 'weight_reps' && loadIsPair(inputMethod) ? 2 : 1;
  double toDisplay(double kg) => displayMass(kg, widget.imperial) / divisor;
  double toKg(double display) => normalizedMass(display * divisor, widget.imperial);

  @override
  void initState() {
    super.initState();
    inputMethod = widget.initialLoadMethod ?? widget.base['_load_entry_method']?.toString() ?? loadEntryKind(widget.exercise);
    if (widget.existing != null && widget.existing!.isNotEmpty) {
      for (final row in widget.existing!) {
        stages.add(_TechniqueStage(toDisplay(numOf(row['load_kg'])),
          (row['reps'] as num?)?.toInt() ?? 1, (row['rest_seconds'] as num?)?.toInt() ?? 0));
      }
      return;
    }
    final load = toDisplay(numOf(widget.base['load_kg']));
    final reps = (widget.base['reps'] as num?)?.toInt() ?? 10;
    final count = widget.method == 'myo_reps' ? 4 : 3;
    for (var i = 0; i < count; i++) {
      final factor = widget.method == 'drop_set' ? (i == 0 ? 1 : i == 1 ? .8 : .65) : widget.method == 'pyramid' ? 1.0 + .1 * i : 1.0;
      final targetReps = i == 0 ? reps : widget.method == 'myo_reps' ? 4 : widget.method == 'rest_pause' ? 3 : widget.method == 'cluster' ? 3 : widget.method == 'pyramid' ? (reps-2*i).clamp(1,1000).toInt() : reps;
      final pause = i == count - 1 ? (widget.base['rest_seconds'] as num?)?.toInt() ?? 90 :
          widget.method == 'drop_set' ? 0 : widget.method == 'pyramid' ? 90 : widget.method == 'myo_reps' ? 15 : widget.method == 'rest_pause' ? 20 : 25;
      stages.add(_TechniqueStage(load * factor, targetReps, pause));
    }
  }

  @override
  void dispose() {
    for (final row in stages) { row.dispose(); }
    super.dispose();
  }

  void appendStage() {
    if (stages.length >= 5) return;
    final prev = stages.last;
    setState(() {
      stages.add(_TechniqueStage(double.tryParse(prev.load.text.replaceAll(',','.')) ?? 0,
        widget.method == 'myo_reps' ? 4 : prev.reps, prev.pause));
    });
  }

  Future<void> chooseReps(int i) async {
    final current = stages[i].reps;
    var selected = current;
    final next = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(child: SizedBox(height: 260, child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Repeticiones')),
          TextButton(onPressed: () => Navigator.pop(c, selected), child: const Text('Listo')),
        ]),
        Expanded(child: ListWheelScrollView.useDelegate(
          controller: FixedExtentScrollController(initialItem: current.clamp(1, 1000).toInt() - 1),
          itemExtent: 43, physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (n) => selected = n + 1,
          childDelegate: ListWheelChildBuilderDelegate(childCount: 1000,
            builder: (_, n) => Center(child: Text('${n + 1}', style: const TextStyle(fontSize: 22)))),
        )),
      ]))),
    );
    if (next != null && mounted) setState(() => stages[i].reps = next);
  }

  void save() {
    if (stages.length < 2) { snack(context, 'Se requieren al menos dos etapas'); return; }
    final loads = <double>[];
    for (final s in stages) {
      final v = double.tryParse(s.load.text.trim().replaceAll(',', '.'));
      if (weighted && (v == null || !v.isFinite || v < 0 || toKg(v) > 1000)) {
        snack(context, 'Revisa las cargas de cada etapa'); return;
      }
      loads.add(weighted ? toKg(v ?? 0) : 0);
      if (s.reps < 1 || s.reps > 1000 || s.pause < 0 || s.pause > 3600) {
        snack(context, 'Revisa repeticiones y pausas'); return;
      }
    }
    if (widget.method == 'drop_set' && weighted) {
      for (var i = 1; i < loads.length; i++) {
        if (loads[i] >= loads[i-1]) {
          snack(context, 'En un drop set cada etapa debe reducir la carga'); return;
        }
      }
    }
    final block = widget.existing?.first['block_id']?.toString() ?? ids.v4();
    final result = <Json>[];
    for (var i = 0; i < stages.length; i++) {
      result.add({
        ...widget.base,
        'id': widget.existing != null && i < widget.existing!.length ? widget.existing![i]['id'] : ids.v4(),
        'load_kg': loads[i],
        'reps': stages[i].reps,
        'rpe': i == 0 ? widget.base['rpe'] : null,
        'rir': i == 0 ? widget.base['rir'] : null,
        'rest_seconds': stages[i].pause,
        'method': widget.method,
        'block_id': block,
        'phase': i,
      }..remove('_load_entry_method'));
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final name = techniqueName(widget.method);
    return SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 12),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * .72,
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(name, style: Theme.of(context).textTheme.titleLarge)),
            IconButton(icon: const Icon(Icons.info_outline), tooltip: 'Cómo funciona',
                onPressed: () => showMethodHelp(context, widget.method)),
          ]),
          Text('Cada etapa se registra por separado. Pausa = tiempo hasta la siguiente etapa; la última es el descanso final.',
              style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(child: ListView(children: [
            for (var i = 0; i < stages.length; i++)
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(i == 0 && widget.method == 'myo_reps'
                        ? 'Activación' : 'Etapa ${i+1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (i >= 2) IconButton(
                      tooltip: 'Quitar etapa', icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() => stages.removeAt(i).dispose()),
                    ),
                  ]),
                  Row(children: [
                    if (weighted) Expanded(child: TextFormField(
                      controller: stages[i].load,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: loadCaption, isDense: true),
                    )),
                    if (weighted) const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(
                      onPressed: () => chooseReps(i),
                      child: Text('${stages[i].reps} rep', maxLines: 1),
                    )),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(i == stages.length-1 ? 'Descanso final:' : 'Pausa siguiente:'),
                    IconButton(icon: const Icon(Icons.remove), tooltip: 'Reducir pausa',
                      onPressed: stages[i].pause <= 0 ? null : () => setState(() => stages[i].pause = (stages[i].pause-5).clamp(0,3600).toInt())),
                    Text('${stages[i].pause} s'),
                    IconButton(icon: const Icon(Icons.add), tooltip: 'Aumentar pausa',
                      onPressed: () => setState(() => stages[i].pause = (stages[i].pause+5).clamp(0,3600).toInt())),
                  ]),
                ],
              ))),
            if (stages.length < 5)
              TextButton.icon(onPressed: appendStage, icon: const Icon(Icons.add), label: const Text('Añadir etapa (máximo 5)')),
          ])),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: const Text('Guardar bloque completo'))),
        ]),
      ),
    ));
  }
}
