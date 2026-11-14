part of 'main.dart';

Future<void> recoveryDialog(BuildContext c, String value) => showDialog<void>(
  context: c,
  barrierDismissible: false,
  builder: (d) => AlertDialog(
    title: const Text('Guarda tu código de recuperación'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Note(
          'Este código de un solo uso permite recuperar tu cuenta sin correo electrónico. Guárdalo en tu gestor de contraseñas.',
        ),
        SelectableText(value),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        child: const Text('Copiar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(d),
        child: const Text('Ya lo guardé'),
      ),
    ],
  ),
);

class Access extends ConsumerStatefulWidget {
  const Access({super.key});
  @override
  ConsumerState<Access> createState() => _Access();
}

class _Access extends ConsumerState<Access> {
  String mode = 'login', username = '', password = '', name = '', code = '';
  bool busy = false;
  String? error;
  Future<void> submit() async {
    final a = ref.read(stateProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (mode == 'recover') {
        final r = await a.api.post('/auth/recover', {
          'username': username.trim().toLowerCase(),
          'recovery_code': code.trim(),
          'new_password': password,
        });
        if (!mounted) return;
        await recoveryDialog(context, r['recovery_code']);
        if (mounted) setState(() => mode = 'login');
      } else {
        final r = await a.login(
          username.trim().toLowerCase(),
          password,
          mode == 'register' ? name.trim() : null,
        );
        if (!mounted) return;
        if (r['recovery_code'] != null) {
          await recoveryDialog(context, r['recovery_code']);
        }
        if (mounted) context.go('/perfil');
      }
    } catch (e) {
      if (mounted) setState(() => error = a.api.explain(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Cuenta KYVORA')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TitleBlock(
          'Acceso seguro',
          mode == 'login'
              ? 'Bienvenido'
              : mode == 'register'
              ? 'Crea tu cuenta'
              : 'Recupera tu cuenta',
        ),
        TextField(
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (v) => username = v,
          decoration: const InputDecoration(
            labelText: 'Usuario',
            helperText: '3–24 letras minúsculas, dígitos o guion bajo',
          ),
        ),
        if (mode == 'register')
          TextField(
            onChanged: (v) => name = v,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nombre visible'),
          ),
        if (mode == 'recover')
          TextField(
            onChanged: (v) => code = v,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Código de recuperación',
            ),
          ),
        TextField(
          obscureText: true,
          onChanged: (v) => password = v,
          decoration: InputDecoration(
            labelText: mode == 'recover' ? 'Nueva contraseña' : 'Contraseña',
            helperText: mode == 'login' ? null : 'Al menos 12 caracteres',
          ),
        ),
        if (error != null) Note(error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Conectando…'
                : mode == 'login'
                ? 'Entrar'
                : mode == 'register'
                ? 'Crear cuenta'
                : 'Cambiar contraseña',
          ),
        ),
        if (mode != 'register')
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    mode = 'register';
                    error = null;
                  }),
            child: const Text('Crear una cuenta'),
          ),
        if (mode != 'login')
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    mode = 'login';
                    error = null;
                  }),
            child: const Text('Ya tengo una cuenta'),
          ),
        if (mode == 'login')
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    mode = 'recover';
                    error = null;
                  }),
            child: const Text('Recuperar acceso'),
          ),
      ],
    ),
  );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final a = ref.watch(stateProvider), p = a.profile;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        TitleBlock(
          'Identidad',
          p['display_name'] ?? (a.onlineAccount ? 'Mi perfil' : 'Perfil local'),
        ),
        if (!a.onlineAccount)
          FilledButton(
            onPressed: () => c.push('/cuenta'),
            child: const Text('Iniciar sesión o crear cuenta'),
          ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Usar libras'),
                subtitle: Text(
                  a.imperial ? 'Sistema imperial' : 'Sistema métrico',
                ),
                value: a.imperial,
                onChanged: (v) => attempt(
                  c,
                  a,
                  () => a.updateProfile({'units': v ? 'imperial' : 'metric'}),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Activar avisos de descanso'),
                subtitle: const Text('Permite notificaciones y, opcionalmente, alarmas puntuales.'),
                onTap: () async {
                  final permitted = await restAlerts.requestNotifications();
                  if (!c.mounted) return;
                  if (permitted) {
                    final precise = await restAlerts.requestPreciseAlarms();
                    if (c.mounted) snack(c, precise
                        ? 'Avisos puntuales habilitados.'
                        : 'Avisos habilitados; Android podría retrasarlos.');
                  } else {
                    snack(c, 'Permite las notificaciones desde los ajustes de Android.');
                  }
                },
              ),
              ListTile(
                title: const Text('Peso corporal privado'),
                subtitle: Text(
                  p['bodyweight_kg'] == null
                      ? 'Sin registrar'
                      : mass(numOf(p['bodyweight_kg']), a.imperial),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final v = await ask(
                    c,
                    'Peso corporal (${a.imperial ? 'lb' : 'kg'})',
                  );
                  final d = double.tryParse(v?.replaceAll(',', '.') ?? '');
                  if (d == null || !c.mounted) return;
                  final kg = normalizedMass(d, a.imperial);
                  if (kg < 25 || kg > 450) {
                    snack(c, 'El peso debe estar entre 25 y 450 kg.');
                    return;
                  }
                  await attempt(
                    c,
                    a,
                    () => a.updateProfile({'bodyweight_kg': kg}),
                  );
                },
              ),
              if (a.onlineAccount) ...[
                ListTile(
                  title: const Text('Biografía'),
                  subtitle: Text(p['bio'] ?? ''),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final v = await ask(
                      c,
                      'Biografía',
                      initial: p['bio'] ?? '',
                      limit: 300,
                    );
                    if (v != null && c.mounted) {
                      await attempt(c, a, () => a.updateProfile({'bio': v}));
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Cuenta privada'),
                  subtitle: const Text(
                    'Aprueba las solicitudes de seguimiento.',
                  ),
                  value: p['private'] ?? true,
                  onChanged: (v) =>
                      attempt(c, a, () => a.updateProfile({'private': v})),
                ),
                SwitchListTile(
                  title: const Text('Participar en rankings'),
                  subtitle: const Text(
                    'Publica la carga y su relación con tu peso. Otros podrán deducir tu peso corporal.',
                  ),
                  value: p['rankings_opt_in'] ?? false,
                  onChanged: (v) => attempt(
                    c,
                    a,
                    () => a.updateProfile({'rankings_opt_in': v}),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (a.onlineAccount) ...[
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('Testigos y notificaciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const Inbox()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sincronizar ahora'),
            subtitle: Text(
              a.syncInfo ?? 'Se reintenta con la aplicación abierta.',
            ),
            onTap: () => a.sync(force: true),
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('Importar sesiones del perfil local'),
            onTap: () async {
              if (!await confirm(
                    c,
                    '¿Copiar tus sesiones locales finalizadas a esta cuenta?',
                  ) ||
                  !c.mounted) {
                return;
              }
              await attempt(c, a, () async {
                final n = await a.db.importGuest(a.owner);
                await a.reload();
                await a.sync(force: true);
                if (c.mounted) snack(c, '$n sesiones importadas.');
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar mis datos'),
            onTap: () async {
              await attempt(c, a, () async {
                final d = await a.api.get('/profiles/me/export');
                final tmp = await getTemporaryDirectory();
                final f = File('${tmp.path}/liftlog-${ids.v4()}.json');
                try {
                  await f.writeAsString(
                    const JsonEncoder.withIndent('  ').convert({
                      'servidor': d,
                      'sesiones_locales': a.workouts,
                      'rutinas_locales': a.routines,
                    }),
                  );
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(f.path)],
                      title: 'Mis datos de KYVORA',
                    ),
                  );
                } finally {
                  if (await f.exists()) await f.delete();
                }
              });
            },
          ),
        ],
        const SizedBox(height: 16),
        Text('Récords personales', style: Theme.of(c).textTheme.titleLarge),
        if (a.records.isEmpty)
          const Note('Aparecerán al finalizar sesiones con series válidas.'),
        for (final r in a.records)
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.workspace_premium_outlined,
                color: lime,
              ),
              title: Text(recordLabel(a, r)),
              subtitle: Text(
                '${kinds[r['kind']] ?? r['kind']} · ${r['local'] == true ? 'Guardado en el teléfono' : statuses[r['status']] ?? ''}',
              ),
              trailing: a.onlineAccount && r['local'] != true
                  ? IconButton(
                      tooltip: 'Solicitar testigo',
                      icon: const Icon(Icons.person_add_alt_1),
                      onPressed: () async {
                        final who = await ask(
                          c,
                          'Usuario que presenció la marca',
                        );
                        if (who == null || !c.mounted) return;
                        await attempt(c, a, () async {
                          await a.api.post('/verifications', {
                            'record_id': r['id'],
                            'witness_username': who.toLowerCase(),
                          });
                          if (c.mounted) snack(c, 'Solicitud enviada.');
                        });
                      },
                    )
                  : null,
            ),
          ),
        if (a.onlineAccount) ...[
          TextButton(
            onPressed: () => attempt(c, a, () => a.logout()),
            child: const Text('Cerrar sesión'),
          ),
          TextButton(
            onPressed: () async {
              if (!await confirm(
                    c,
                    '¿Eliminar la cuenta y sus datos de forma permanente?',
                  ) ||
                  !c.mounted) {
                return;
              }
              final pw = await ask(
                c,
                'Confirma tu contraseña',
                limit: 128,
                secret: true,
              );
              if (pw == null || !c.mounted) return;
              await attempt(c, a, () async {
                await a.flight;
                final owner = a.owner;
                await a.api.http.delete(
                  '/profiles/me',
                  data: {'username': p['username'], 'password': pw},
                );
                await a.api.forget();
                await a.db.erase(owner);
                await a.reload();
              });
            },
            child: const Text(
              'Eliminar cuenta',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ],
    );
  }
}

class Inbox extends ConsumerStatefulWidget {
  const Inbox({super.key});
  @override
  ConsumerState<Inbox> createState() => _Inbox();
}

class _Inbox extends ConsumerState<Inbox> {
  late Future<List<dynamic>> inbox;
  Future<List<dynamic>> fetch() {
    final api = ref.read(stateProvider).api;
    return Future.wait([
      api.get('/verifications'),
      api.get('/follows/requests'),
      api.get('/notifications'),
    ]);
  }

  @override
  void initState() {
    super.initState();
    inbox = fetch();
  }

  void refresh() {
    if (mounted) setState(() => inbox = fetch());
  }

  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    const state = {
      'pending': 'Pendiente',
      'approved': 'Confirmada',
      'rejected': 'Rechazada',
      'revoked': 'Revocada',
    };
    const types = {
      'comment': 'comentó tu publicación',
      'reaction': 'reaccionó a tu publicación',
      'verification_request': 'solicitó un testigo',
      'verification_decision': 'respondió a tu solicitud',
      'follow': 'te sigue',
      'follow_request': 'quiere seguirte',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de entrada'),
        actions: [
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder(
        future: inbox,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Note(a.api.explain(s.error!)),
            );
          }
          final data = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Marcas presenciadas',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              if ((data[0] as List).isEmpty) const Note('Sin solicitudes.'),
              for (final v in data[0])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recordLabel(a, v['record'])),
                        Note(
                          '@${v['requester']['username']} → @${v['witness']['username']} · ${state[v['state']]}',
                        ),
                        if (v['reason'] != null) Text(v['reason']),
                        if (v['witness_id'] == a.owner)
                          Wrap(
                            children: [
                              for (final k
                                  in (v['state'] == 'pending'
                                      ? ['approved', 'rejected']
                                      : v['state'] == 'approved'
                                      ? ['revoked']
                                      : <String>[]))
                                TextButton(
                                  onPressed: () async {
                                    final reason = await ask(
                                      c,
                                      'Describe lo que presenciaste',
                                      limit: 500,
                                    );
                                    if (reason == null || !c.mounted) return;
                                    await attempt(c, a, () async {
                                      await a.api.post(
                                        '/verifications/${v['id']}/decision',
                                        {'decision': k, 'reason': reason},
                                      );
                                      await a.sync(force: true);
                                      refresh();
                                    });
                                  },
                                  child: Text(
                                    {
                                      'approved': 'Confirmar',
                                      'rejected': 'Rechazar',
                                      'revoked': 'Revocar',
                                    }[k]!,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              const Divider(),
              Text('Seguimiento', style: Theme.of(c).textTheme.titleLarge),
              if ((data[1] as List).isEmpty)
                const Note('Sin solicitudes pendientes.'),
              for (final u in data[1])
                ListTile(
                  title: Text('@${u['username']}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await attempt(
                        c,
                        a,
                        () => a.api.http.put('/follows/${u['id']}/approve'),
                      );
                      refresh();
                    },
                    child: const Text('Aprobar'),
                  ),
                ),
              const Divider(),
              Text(
                'Actividad reciente',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              if ((data[2] as List).isEmpty) const Note('Sin notificaciones.'),
              for (final n in data[2])
                ListTile(
                  title: Text(
                    '@${n['actor']['username']} ${types[n['kind']] ?? n['kind']}',
                  ),
                  subtitle: Text(day(n['created_at'])),
                ),
            ],
          );
        },
      ),
    );
  }
}
