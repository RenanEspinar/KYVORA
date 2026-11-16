part of 'main.dart';

const statuses = {
  'self_declared': 'Autodeclarado',
  'confirmed': 'Confirmado',
  'verified': 'Verificado',
};
const kinds = {
  'max_weight': 'Mayor carga',
  'reps_at_weight': 'Repeticiones con carga',
  'estimated_1rm': '1RM estimado',
  'bodyweight_reps': 'Repeticiones corporales',
};
String recordLabel(LogState a, Map r) {
  final kind = r['kind'], v = numOf(r['value']);
  final mark = ['max_weight', 'estimated_1rm'].contains(kind)
      ? mass(v, a.imperial)
      : kind == 'reps_at_weight'
      ? '$v rep · ${mass(numOf(r['load_kg']), a.imperial)}'
      : '${v.toInt()} rep';
  return '${a.catalog[r['exercise_id']]?['name'] ?? 'Ejercicio'} · $mark';
}

/// Static on-device examples; never written as community posts or given fake likes.
const _communityExamples = <Map<String, String>>[
  {
    'topic': 'Rutina',
    'title': 'Día de pecho · fuerza',
    'caption': 'Press de banca: 3 × 6 · Press inclinado con mancuernas: 3 × 10 · Aperturas en polea: 3 × 12. Adapta las cargas a tu nivel.',
    'icon': 'fitness_center',
  },
  {
    'topic': 'Progreso',
    'title': 'Más repeticiones, misma técnica',
    'caption': 'Ejemplo: pasar de 8 a 10 repeticiones con la misma carga. No todo progreso exige subir kilos.',
    'icon': 'trending_up',
  },
  {
    'topic': 'Recuperación',
    'title': 'Descansa según el esfuerzo',
    'caption': 'En series pesadas, utiliza un descanso suficiente para mantener la ejecución. Regístralo en KYVORA.',
    'icon': 'timer',
  },
];

Widget communityInspiration() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Padding(
      padding: EdgeInsets.only(top: 12, bottom: 5),
      child: Text('IDEAS PARA COMPARTIR', style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.2)),
    ),
    SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _communityExamples.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (c, index) {
          final example = _communityExamples[index];
          final icons = [Icons.fitness_center, Icons.trending_up, Icons.timer_outlined];
          return SizedBox(
            width: 250,
            child: Card(
              color: const Color(0xFF152E53),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icons[index], color: lime),
                      const Spacer(),
                      const Text('EJEMPLO',style: TextStyle(color: muted,fontSize: 10)),
                    ]),
                    const SizedBox(height: 9),
                    Text(example['topic']!, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                    Text(example['title']!, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 7),
                    Expanded(child: Text(example['caption']!, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ],
);

class Feed extends ConsumerStatefulWidget {
  const Feed({super.key});
  @override
  ConsumerState<Feed> createState() => _Feed();
}

class _Feed extends ConsumerState<Feed> {
  List<Json> items = [];
  String? next, error;
  bool busy = false;
  String? loaded;
  Future<void> load({bool more = false}) async {
    final a = ref.read(stateProvider);
    if (busy || !a.onlineAccount) return;
    final owner = a.owner;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await a.api.get('/posts', {
        if (more && next != null) 'before': next,
      });
      if (mounted && a.owner == owner) {
        setState(() {
          items = [if (more) ...items, ...(page['items'] as List).cast<Json>()];
          next = page['next_cursor'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = a.api.explain(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    if (!a.onlineAccount) {
      loaded = null;
      items = [];
      return const NeedAccount('Comunidad');
    }
    if (loaded != a.owner) {
      loaded = a.owner;
      items = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        children: [
          TitleBlock(
            'Comunidad',
            'Tu comunidad',
            action: IconButton(
              tooltip: 'Buscar atleta',
              icon: const Icon(Icons.person_search_outlined),
              onPressed: () async {
                final s = await ask(c, 'Nombre de usuario exacto');
                if (s == null || s.isEmpty || !c.mounted) return;
                final v = await attempt(
                  c,
                  a,
                  () async =>
                      (await a.api.get('/users/search', {
                            'username': s.toLowerCase(),
                          })
                          as List),
                );
                if (v == null || !c.mounted) return;
                if (v.isEmpty) {
                  snack(c, 'No se encontró ese atleta.');
                  return;
                }
                await athlete(c, a, Json.from(v.first));
                await load();
              },
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              final sent = await Navigator.push<bool>(
                c,
                MaterialPageRoute(builder: (_) => const ComposePost()),
              );
              if (sent == true && mounted) await load();
            },
            icon: const Icon(Icons.add),
            label: const Text('Nueva publicación'),
          ),
          communityInspiration(),
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            ListTile(
              title: Text(error!),
              trailing: IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (!busy && error == null && items.isEmpty)
            const Note(
              'Todavía no hay publicaciones reales. Comparte una sesión o empieza siguiendo a un atleta.',
            ),
          for (final p in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: lime.withValues(alpha: .14),
                          child: Text(
                            (p['author']['display_name'] as String).isNotEmpty
                                ? (p['author']['display_name'] as String).substring(0, 1).toUpperCase()
                                : 'K',
                            style: const TextStyle(color: lime, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => athlete(c, a, Json.from(p['author'])),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['author']['display_name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '@${p['author']['username']} · ${day(p['created_at'])}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (k) async {
                            if (k == 'delete') {
                              final yes = await confirm(
                                c,
                                '¿Eliminar esta publicación?',
                              );
                              if (yes && c.mounted) {
                                await attempt(
                                  c,
                                  a,
                                  () => a.api.http.delete('/posts/${p['id']}'),
                                );
                              }
                            }
                            if (k == 'report' && c.mounted) {
                              final why = await ask(
                                c,
                                'Motivo de la denuncia',
                                limit: 500,
                              );
                              if (why != null && c.mounted) {
                                await attempt(
                                  c,
                                  a,
                                  () => a.api.post('/reports', {
                                    'resource_type': 'post',
                                    'resource_id': p['id'],
                                    'reason': why,
                                  }),
                                );
                              }
                            }
                            await load();
                          },
                          itemBuilder: (_) => [
                            if (p['author']['id'] == a.owner)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'report',
                                child: Text('Denunciar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if ((p['text'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(p['text']),
                      ),
                    if (p['workout'] != null)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(p['workout']['name']),
                        leading: const Icon(Icons.fitness_center),
                        children: [
                          for (final m in p['workout']['exercises'])
                            ListTile(
                              title: Text(m['name']),
                              subtitle: Text(
                                (m['sets'] as List)
                                    .map(
                                      (s) => s['reps'] != null
                                          ? '${s['reps']} rep · ${mass(numOf(s['load_kg']), a.imperial)}'
                                          : '${s['seconds']} s${s['distance_m'] != null ? ' · ${s['distance_m']} m' : ''}',
                                    )
                                    .join('   /   '),
                              ),
                            ),
                        ],
                      ),
                    if (p['record'] != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.workspace_premium,
                          color: lime,
                        ),
                        title: Text(recordLabel(a, p['record'])),
                        subtitle: Text(kinds[p['record']['kind']] ?? ''),
                      ),
                    if (p['media_id'] != null)
                      SecurePhoto(
                        key: ValueKey(p['media_id']),
                        id: p['media_id'],
                        api: a.api,
                      ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await attempt(
                              c,
                              a,
                              () => p['reacted'] == true
                                  ? a.api.http.delete(
                                      '/posts/${p['id']}/reaction',
                                    )
                                  : a.api.http.put(
                                      '/posts/${p['id']}/reaction',
                                    ),
                            );
                            await load();
                          },
                          icon: Icon(
                            p['reacted'] == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          label: Text('${p['reactions']}'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              c,
                              MaterialPageRoute(
                                builder: (_) => CommentsPage(post: p),
                              ),
                            );
                            await load();
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text('${p['comments']}'),
                        ),
                        if (p['visibility'] == 'public')
                          IconButton(
                            tooltip: 'Compartir texto público',
                            onPressed: () async {
                              await SharePlus.instance.share(
                                ShareParams(text:
                                  '${p['author']['display_name']} en KYVORA:\n${p['text']}'),
                              );
                            },
                            icon: const Icon(Icons.ios_share_outlined),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (next != null)
            OutlinedButton(
              onPressed: busy ? null : () => load(more: true),
              child: const Text('Cargar más'),
            ),
        ],
      ),
    );
  }
}

Future<bool> confirm(BuildContext c, String title) async =>
    await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ) ??
    false;
Future<void> athlete(BuildContext c, LogState a, Json user) async {
  final action = await showDialog<String>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(user['display_name']),
      content: Text('@${user['username']}\n${user['bio'] ?? ''}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cerrar'),
        ),
        if (user['id'] != a.owner) ...[
          TextButton(
            onPressed: () => Navigator.pop(d, 'block'),
            child: const Text('Bloquear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, 'unfollow'),
            child: const Text('Dejar de seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, 'follow'),
            child: const Text('Seguir'),
          ),
        ],
      ],
    ),
  );
  if (action == null || !c.mounted) return;
  await attempt(c, a, () async {
    String msg;
    if (action == 'follow') {
      final r = await a.api.post('/follows/${user['id']}');
      msg = r['approved'] == true
          ? 'Ahora sigues a este atleta.'
          : 'Solicitud de seguimiento enviada.';
    } else if (action == 'block') {
      if (!await confirm(c, '¿Bloquear a este atleta?')) return;
      await a.api.http.put('/users/${user['id']}/block');
      msg = 'Atleta bloqueado.';
    } else {
      await a.api.http.delete('/follows/${user['id']}');
      msg = 'Seguimiento retirado.';
    }
    if (c.mounted) snack(c, msg);
  });
}

class SecurePhoto extends StatefulWidget {
  final String id;
  final Api api;
  const SecurePhoto({super.key, required this.id, required this.api});
  @override
  State<SecurePhoto> createState() => _SecurePhoto();
}

class _SecurePhoto extends State<SecurePhoto> {
  late final Future<List<int>> bytes;
  @override
  void initState() {
    super.initState();
    bytes = widget.api.http
        .get<List<int>>(
          '/media/${widget.id}',
          queryParameters: {'thumbnail': true},
          options: Options(responseType: ResponseType.bytes),
        )
        .then((r) => r.data!);
  }

  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: bytes,
    builder: (_, snap) => snap.hasData
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              Uint8List.fromList(snap.data!),
              height: 340,
              width: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: 900,
            ),
          )
        : Note(snap.hasError ? 'Foto no disponible' : 'Cargando foto…'),
  );
}

class ComposePost extends ConsumerStatefulWidget {
  const ComposePost({super.key});
  @override
  ConsumerState<ComposePost> createState() => _ComposePost();
}

class _ComposePost extends ConsumerState<ComposePost> {
  String text = '', visibility = 'followers';
  String? workout, record, media;
  XFile? file;
  bool busy = false;
  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            maxLength: 2000,
            maxLines: 4,
            onChanged: (v) => text = v,
            decoration: const InputDecoration(
              labelText: 'Comparte tu progreso',
            ),
          ),
          DropdownButtonFormField(
            initialValue: visibility,
            decoration: const InputDecoration(labelText: 'Visibilidad'),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('Solo yo')),
              DropdownMenuItem(value: 'followers', child: Text('Seguidores')),
              DropdownMenuItem(value: 'public', child: Text('Pública')),
            ],
            onChanged: (v) => setState(() => visibility = v!),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Adjuntar entrenamiento',
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Ninguno')),
              for (final w in a.workouts.where((w) => w['state'] == 'synced'))
                DropdownMenuItem(
                  value: w['id'] as String,
                  child: Text(
                    '${w['name']} · ${day(w['ended_at'])}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => workout = v == '' ? null : v,
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Adjuntar récord'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Ninguno')),
              for (final r in a.records.where((r) => r['local'] != true))
                DropdownMenuItem(
                  value: r['id'] as String,
                  child: Text(
                    recordLabel(a, r),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => record = v == '' ? null : v,
          ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      maxHeight: 1600,
                      imageQuality: 82,
                    );
                    if (f != null && mounted) {
                      setState(() {
                        file = f;
                        media = null;
                      });
                    }
                  },
            icon: const Icon(Icons.photo_outlined),
            label: Text(file?.name ?? 'Añadir foto'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await attempt(c, a, () async {
                      if (file != null && media == null) {
                        final upload = await a.api.post(
                          '/media',
                          FormData.fromMap({
                            'file': await MultipartFile.fromFile(
                              file!.path,
                              filename: file!.name,
                            ),
                          }),
                        );
                        media = upload['id'];
                      }
                      await a.api.post('/posts', {
                        'text': text.trim(),
                        'visibility': visibility,
                        'workout_id': workout,
                        'record_id': record,
                        'media_id': media,
                      });
                      if (c.mounted) Navigator.pop(c, true);
                    });
                    if (mounted) setState(() => busy = false);
                  },
            child: Text(busy ? 'Enviando…' : 'Publicar'),
          ),
        ],
      ),
    );
  }
}

class CommentsPage extends ConsumerStatefulWidget {
  final Json post;
  const CommentsPage({super.key, required this.post});
  @override
  ConsumerState<CommentsPage> createState() => _Comments();
}

class _Comments extends ConsumerState<CommentsPage> {
  List<Json> all = [];
  String? next, error;
  bool busy = false;
  final field = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final a = ref.read(stateProvider);
    try {
      final r = await a.api.get('/posts/${widget.post['id']}/comments', {
        if (more && next != null) 'before': next,
      });
      if (mounted) {
        setState(() {
          all = [if (more) ...all, ...(r['items'] as List).cast<Json>()];
          next = r['next_cursor'];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = a.api.explain(e));
    }
  }

  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Conversación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: field,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Comentario'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (field.text.trim().isEmpty) return;
                    setState(() => busy = true);
                    await attempt(c, a, () async {
                      await a.api.post('/posts/${widget.post['id']}/comments', {
                        'text': field.text.trim(),
                      });
                      field.clear();
                      await load();
                    });
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('Comentar'),
          ),
          if (error != null) Note(error!),
          for (final r in all)
            ListTile(
              title: Text(r['text']),
              subtitle: Text(
                '@${r['author']['username']} · ${day(r['created_at'])}',
              ),
              trailing:
                  r['author']['id'] == a.owner ||
                      widget.post['author']['id'] == a.owner
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await attempt(
                          c,
                          a,
                          () => a.api.http.delete('/comments/${r['id']}'),
                        );
                        await load();
                      },
                    )
                  : null,
            ),
          if (next != null)
            TextButton(
              onPressed: () => load(more: true),
              child: const Text('Cargar más'),
            ),
        ],
      ),
    );
  }
}

const medals = [
  Color(0xFFCE8A5B),
  Color(0xFFB6C5D0),
  Color(0xFFF2BE51),
  Color(0xFF91C5B9),
  Color(0xFF62CDE6),
  Color(0xFFB89BFF),
];

class Medal extends StatelessWidget {
  final int level;
  const Medal(this.level, {super.key});
  @override
  Widget build(BuildContext c) {
    final color = medals[level];
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, color, .25)!,
            color,
            Color.lerp(Colors.black, color, .35)!,
          ],
        ),
      ),
      child: Icon(
        [
          Icons.chevron_right,
          Icons.double_arrow,
          Icons.star,
          Icons.shield,
          Icons.diamond,
          Icons.workspace_premium,
        ][level],
        color: canvas,
        size: 23,
      ),
    );
  }
}

class Rankings extends ConsumerStatefulWidget {
  const Rankings({super.key});
  @override
  ConsumerState<Rankings> createState() => _Rankings();
}

class _Rankings extends ConsumerState<Rankings> {
  String group = 'pecho';
  String status = 'self_declared';
  String? owner;
  Future<dynamic>? job;

  static const groups = <String, String>{
    'pecho': 'Pecho',
    'espalda': 'Espalda',
    'cuádriceps': 'Cuádriceps',
    'cadena posterior': 'Cadena posterior',
    'hombros': 'Hombros',
    'bíceps': 'Bíceps',
    'tríceps': 'Tríceps',
    'abdomen': 'Abdomen',
    'glúteos': 'Glúteos',
  };

  void update(LogState a) {
    job = a.api.get('/rankings/groups', {'group': group, 'status': status});
  }

  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    if (!a.onlineAccount) return const NeedAccount('Competencias');
    if (owner != a.owner || job == null) {
      owner = a.owner;
      update(a);
    }
    return ListView(padding: const EdgeInsets.all(18), children: [
      TitleBlock('KYVORA  /  comunidad', 'Competencias',
        action: IconButton(icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => update(a)))),
      Card(child: ListTile(
        leading: const Icon(Icons.monitor_weight_outlined, color: lime),
        title: const Text('Body Recomp'),
        subtitle: const Text('Seguimiento privado de grasa estimada, cintura y fuerza; pensado también para mujeres.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => c.go('/recomposicion'),
      )),
      const SizedBox(height: 14),
      Text('Clasificación por grupo muscular', style: Theme.of(c).textTheme.titleLarge),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: group,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Grupo muscular'),
        items: groups.entries.map((e) => DropdownMenuItem(
          value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {group = v; update(a);});
        },
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Validación'),
        items: statuses.entries.map((e) => DropdownMenuItem(
          value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {status = v; update(a);});
        },
      ),
      const Note('Se comparan marcas de fuerza relativas al peso corporal y normalizadas frente a una prueba de referencia por movimiento. Solo participan atletas que aceptaron entrar en rankings.'),
      FutureBuilder<dynamic>(
        future: job,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snap.hasError) {
            return const Note('La clasificación por grupos necesita KYVORA API 2.0 en el servidor. Las sesiones de entrenamiento siguen disponibles.');
          }
          final response = snap.data as Map;
          final tests = (response['tests'] as List?) ?? [];
          final rows = (response['items'] as List?) ?? [];
          if (tests.isEmpty) {
            return const Note('Este grupo todavía no tiene una prueba de fuerza estandarizada. No se asignarán puntos arbitrarios.');
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Note('Prueba(s) comparable(s): ${tests.join(', ')}'),
            if (rows.isEmpty) const Note('Aún no hay marcas registradas para esta categoría.'),
            for (final r in rows) Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: lime.withValues(alpha: .12),
                child: Text('${r['rank']}',style: const TextStyle(color: lime))),
              title: Text(r['athlete']['display_name'] as String),
              subtitle: Text(recordLabel(a, r['record'] as Map)),
              trailing: Text('${r['score']} pt'),
            )),
          ]);
        },
      ),
    ]);
  }
}
