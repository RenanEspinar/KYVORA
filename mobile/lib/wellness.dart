part of 'main.dart';

/// Short, conservative warm-up suggestions. These are general examples,
/// not medical advice or a substitute for adjusting training to ability.
const _warmupGuides = <Map<String, Object>>[
  {
    'title': 'Tren superior',
    'subtitle': 'Antes de pecho, espalda y hombros',
    'icon': Icons.fitness_center,
    'image': 'assets/guides/warmup_upper.png',
    'steps': <String>[
      '3–5 min de movimiento cómodo para elevar gradualmente la frecuencia cardiaca.',
      'Movilidad activa de hombros y escápulas, sin buscar dolor ni rangos forzados.',
      'Realiza 2–3 series de aproximación con menos carga antes del primer ejercicio pesado.',
    ],
  },
  {
    'title': 'Tren inferior',
    'subtitle': 'Antes de sentadillas, zancadas y peso muerto',
    'icon': Icons.directions_run,
    'image': 'assets/guides/warmup_lower.png',
    'steps': <String>[
      '3–5 min de caminata o bicicleta a intensidad cómoda.',
      'Practica bisagra de cadera y sentadilla sin carga, dentro de tu rango cómodo.',
      'Aumenta la carga progresivamente con 2–4 series de aproximación.',
    ],
  },
  {
    'title': 'Sesión de cardio',
    'subtitle': 'Antes de correr, remar o pedalear',
    'icon': Icons.favorite_outline,
    'image': 'assets/guides/warmup_cardio.png',
    'steps': <String>[
      'Empieza con 5 min a intensidad baja.',
      'Aumenta gradualmente la intensidad según cómo te sientas.',
      'Para intervalos intensos, añade un breve tramo intermedio antes del primer esfuerzo.',
    ],
  },
];

const _trainingTips = <String>[
  'Registra las repeticiones realmente realizadas. La consistencia importa más que redondear cifras.',
  'Descansos más largos suelen ayudar a mantener el rendimiento en series exigentes de fuerza.',
  'No todas las series deben terminar al fallo. Ajusta el esfuerzo al objetivo de cada ejercicio.',
  'Aumenta la carga solo cuando mantienes una técnica controlada.',
  'El calentamiento prepara el movimiento; no tiene que dejarte fatigado.',
  'Un cambio de peso aislado no permite concluir que ganaste músculo o perdiste grasa.',
  'El progreso puede evaluarse por repeticiones, carga, ejecución y continuidad.',
];

class WarmupAndTips extends StatelessWidget {
  const WarmupAndTips({super.key});

  @override
  Widget build(BuildContext context) {
    final tip = _trainingTips[(DateTime.now().difference(DateTime(2026)).inDays) % _trainingTips.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prepara tu sesión', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ..._warmupGuides.map((guide) => Card(
              child: ListTile(
                leading: Icon(guide['icon'] as IconData, color: lime),
                title: Text(guide['title'] as String),
                subtitle: Text(guide['subtitle'] as String),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (c) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(guide['image'] as String,
                            width: double.infinity, height: 160, fit: BoxFit.cover,
                            cacheWidth: 900),
                        ),
                        const SizedBox(height: 12),
                        Text(guide['title'] as String,
                            style: Theme.of(c).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        for (final (index, step) in (guide['steps'] as List<String>).indexed)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: lime.withValues(alpha: .15),
                              child: Text('${index + 1}', style: const TextStyle(color: lime)),
                            ),
                            title: Text(step),
                          ),
                        const Note('Detén el movimiento ante dolor, mareo u otros síntomas inusuales.'),
                      ],
                    ),
                  ),
                ),
              ),
            )),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: lime),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Consejo de entrenamiento',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(tip),
                  ],
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.monitor_weight_outlined),
          label: const Text('Seguimiento de recomposición corporal'),
          onPressed: () => context.go('/recomposicion'),
        ),
      ],
    );
  }
}

/// Private, opt-in tracking. Not a public appearance-based leaderboard.
/// The client stores these records under the logged-in owner's ID.
class RecompPage extends ConsumerStatefulWidget {
  const RecompPage({super.key});
  @override
  ConsumerState<RecompPage> createState() => _RecompPageState();
}

class _RecompPageState extends ConsumerState<RecompPage> {
  List<Json> entries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final a = ref.read(stateProvider);
    final data = await a.db.list(a.owner, 'recomp');
    data.sort((x, y) => (x['date'] as String).compareTo(y['date'] as String));
    if (mounted) setState(() { entries = data; loading = false; });
  }

  Future<void> addEntry() async {
    final weight = TextEditingController();
    final waist = TextEditingController();
    final fat = TextEditingController();
    final strength = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final data = await showDialog<Json>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Registrar progreso'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Note('Los valores son opcionales, pero registra al menos uno. Utiliza el mismo método de medición en todas las fechas.'),
              _metricField('Peso corporal (kg)', weight, min: 25, max: 450),
              _metricField('Cintura (cm)', waist, min: 30, max: 250),
              _metricField('Grasa estimada (%)', fat, min: 3, max: 70),
              _metricField('Carga de referencia (kg)', strength, min: 0, max: 1000),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              double? parse(TextEditingController x) =>
                  double.tryParse(x.text.trim().replaceAll(',', '.'));
              final values = [weight, waist, fat, strength].map(parse).toList();
              if (values.every((n) => n == null)) {
                ScaffoldMessenger.of(d).showSnackBar(
                    const SnackBar(content: Text('Ingresa al menos una medida.')));
                return;
              }
              Navigator.pop(d, {
                'id': ids.v4(),
                'date': stamp(),
                'weight_kg': values[0],
                'waist_cm': values[1],
                'body_fat_pct': values[2],
                'strength_kg': values[3],
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    weight.dispose(); waist.dispose(); fat.dispose(); strength.dispose();
    if (data == null || !mounted) return;
    final a = ref.read(stateProvider);
    await a.db.put(a.owner, 'recomp', data['id'] as String, data);
    await load();
  }

  Widget _metricField(String title, TextEditingController controller,
      {required double min, required double max}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: title),
      validator: (v) {
        if ((v ?? '').trim().isEmpty) return null;
        final n = double.tryParse(v!.replaceAll(',', '.'));
        return n != null && n >= min && n <= max
            ? null : 'Ingresa un valor entre $min y $max';
      },
    ),
  );

  String delta(String field, String unit) {
    final values = entries.where((e) => e[field] is num).toList();
    if (values.length < 2) return 'Sin tendencia';
    final d = (values.last[field] as num).toDouble() -
        (values.first[field] as num).toDouble();
    return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} $unit';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Body Recomp')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addEntry,
      icon: const Icon(Icons.add),
      label: const Text('Registrar'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 96), children: [
            TitleBlock('Desafío personal · 8–12 semanas', 'Recomposición corporal'),
            const Note('Pensado también para mujeres que buscan reducir grasa y desarrollar fuerza o masa muscular. No requiere pesarse ni publicar fotografías.'),
            const Note('Los datos se almacenan solo en este teléfono. Los porcentajes de grasa son estimaciones y no equivalen a una medición directa de masa muscular.'),
            Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cambios registrados',style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Peso: ${delta('weight_kg', 'kg')}'),
                Text('Cintura: ${delta('waist_cm', 'cm')}'),
                Text('Grasa estimada: ${delta('body_fat_pct', 'puntos porcentuales')}'),
                Text('Carga de referencia: ${delta('strength_kg', 'kg')}'),
              ]),
            )),
            const SizedBox(height: 14),
            Text('Historial privado',style: Theme.of(context).textTheme.titleLarge),
            if (entries.isEmpty) const Note('Aún no tienes registros. Elige «Registrar» para comenzar.'),
            for (final e in entries.reversed)
              Card(child: ListTile(
                title: Text(day(e['date'])),
                subtitle: Text([
                  if (e['weight_kg'] != null) 'Peso ${e['weight_kg']} kg',
                  if (e['waist_cm'] != null) 'Cintura ${e['waist_cm']} cm',
                  if (e['body_fat_pct'] != null) 'Grasa est. ${e['body_fat_pct']} %',
                  if (e['strength_kg'] != null) 'Fuerza ${e['strength_kg']} kg',
                ].join(' · ')),
                leading: const Icon(Icons.insights, color: lime),
              )),
          ]),
  );
}
