import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;
const ids = Uuid();
String stamp() => DateTime.now().toUtc().toIso8601String();
Json clone(Json v) => jsonDecode(jsonEncode(v)) as Json;
double numOf(dynamic v) => (v as num?)?.toDouble() ?? 0;
double displayMass(double kg, bool imperial) =>
    imperial ? kg * 2.20462262185 : kg;
double normalizedMass(double value, bool imperial) =>
    imperial ? value / 2.20462262185 : value;
String mass(double kg, bool imperial) =>
    "${displayMass(kg, imperial).toStringAsFixed(1)} ${imperial ? 'lb' : 'kg'}";
double? epley(double load, int reps) => load <= 0 || reps < 1 || reps > 10
    ? null
    : reps == 1
    ? load
    : load * (1 + reps / 30);
Json fresh(String name, {double? bodyweight}) => {
  'id': ids.v4(),
  'name': name,
  'started_at': stamp(),
  'ended_at': null,
  'notes': '',
  'bodyweight_kg': bodyweight,
  'exercises': <dynamic>[],
};
Json duplicate(Json w, {bool retainSets = false, bool retainTime = false}) {
  final copy = clone(w)..['id'] = ids.v4();
  copy.remove('state');
  copy.remove('version');
  copy.remove('updated_at');
  copy.remove('created_at');
  if (!retainTime) {
    copy['started_at'] = stamp();
    copy['ended_at'] = null;
  }
  for (final m in copy['exercises'] as List) {
    m['id'] = ids.v4();
    if (retainSets) {
      for (final st in m['sets'] as List) {
        st['id'] = ids.v4();
      }
    } else {
      m['sets'] = <dynamic>[];
    }
  }
  return copy;
}

double volume(Json w, Map<String, Json> catalog) {
  double sum = 0;
  for (final m in w['exercises'] as List) {
    if (![
      'weighted_reps',
      'weight_reps',
    ].contains(catalog[m['exercise_id']]?['recording'])) {
      continue;
    }
    for (final st in m['sets'] as List) {
      if (st['kind'] != 'warmup') {
        sum += numOf(st['load_kg']) * numOf(st['reps']);
      }
    }
  }
  return sum;
}

Json? previousSet(List<Json> history, String ex, {String? except}) {
  final sessions =
      history.where((w) => w['ended_at'] != null && w['id'] != except).toList()
        ..sort(
          (a, b) =>
              (b['ended_at'] as String).compareTo(a['ended_at'] as String),
        );
  for (final w in sessions) {
    for (final m in w['exercises'] as List) {
      if (m['exercise_id'] != ex) continue;
      for (final st in (m['sets'] as List).reversed) {
        if (st['kind'] != 'warmup') return Json.from(st as Map);
      }
    }
  }
  return null;
}

List<Json> localRecords(List<Json> history, Map<String, Json> catalog) {
  final best = <String, double>{};
  final result = <Json>[];
  final sessions = history.where((w) => w['ended_at'] != null).toList()
    ..sort(
      (a, b) => (a['ended_at'] as String).compareTo(b['ended_at'] as String),
    );
  for (final w in sessions) {
    for (final m in w['exercises'] as List) {
      final ex = m['exercise_id'] as String;
      final mode = catalog[ex]?['recording'];
      for (final st in m['sets'] as List) {
        final n = st['reps'] as int?;
        if (st['kind'] == 'warmup' || n == null) continue;
        final kg = numOf(st['load_kg']);
        final values = <String, double>{};
        if (mode == 'bodyweight_reps') values['bodyweight_reps'] = n.toDouble();
        if (['weight_reps', 'weighted_reps'].contains(mode) && kg > 0) {
          values['max_weight'] = kg;
          values['reps_at_weight'] = n.toDouble();
          final estimate = epley(kg, n);
          if (mode == 'weight_reps' && estimate != null) {
            values['estimated_1rm'] = estimate;
          }
        }
        for (final pair in values.entries) {
          final key =
              '$ex/${pair.key}/${pair.key == 'reps_at_weight' ? kg : 0}';
          if (pair.value <= (best[key] ?? -1)) continue;
          best[key] = pair.value;
          if (w['state'] != 'synced') {
            result.add({
              'id': ids.v5(Namespace.url.value, '${st['id']}/${pair.key}'),
              'exercise_id': ex,
              'kind': pair.key,
              'value': pair.value,
              'load_kg': kg,
              'reps': n,
              'status': 'self_declared',
              'local': true,
              'achieved_at': w['ended_at'],
            });
          }
        }
      }
    }
  }
  return result.reversed.toList();
}

class Store extends GeneratedDatabase {
  Store(super.executor);
  static Future<Store> open() async {
    final d = await getApplicationSupportDirectory();
    return Store(
      NativeDatabase.createInBackground(File('${d.path}/liftlog.sqlite')),
    );
  }

  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE docs(owner TEXT NOT NULL,kind TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,modified TEXT NOT NULL,PRIMARY KEY(owner,kind,id))',
      );
      await customStatement(
        'CREATE TABLE queue(id TEXT PRIMARY KEY,owner TEXT NOT NULL,workout TEXT NOT NULL,payload TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,retry_at INTEGER NOT NULL DEFAULT 0,error TEXT,UNIQUE(owner,workout))',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA journal_mode=WAL');
      await customStatement('PRAGMA synchronous=FULL');
    },
  );
  Future<void> put(
    String owner,
    String kind,
    String id,
    dynamic data,
  ) => customStatement(
    'INSERT INTO docs VALUES(?,?,?,?,?) ON CONFLICT(owner,kind,id) DO UPDATE SET payload=excluded.payload,modified=excluded.modified',
    [owner, kind, id, jsonEncode(data), stamp()],
  );
  Future<dynamic> read(String owner, String kind, String id) async {
    final r = await customSelect(
      'SELECT payload FROM docs WHERE owner=? AND kind=? AND id=?',
      variables: [Variable(owner), Variable(kind), Variable(id)],
    ).getSingleOrNull();
    return r == null ? null : jsonDecode(r.read<String>('payload'));
  }

  Future<List<Json>> list(
    String owner,
    String kind,
  ) async => (await customSelect(
    'SELECT payload FROM docs WHERE owner=? AND kind=? ORDER BY modified DESC',
    variables: [Variable(owner), Variable(kind)],
  ).get()).map((r) => jsonDecode(r.read<String>('payload')) as Json).toList();
  Future<void> draft(String owner, Json w) => transaction(() async {
    final old = await read(owner, 'workout', w['id']);
    if (old != null && old['state'] != 'draft') {
      throw StateError('Sesión finalizada');
    }
    await put(owner, 'workout', w['id'], {...w, 'state': 'draft'});
  });
  Future<void> finish(String owner, Json input) => transaction(() async {
    final w = clone(input);
    final old = await read(owner, 'workout', w['id']);
    if (old != null && old['state'] != 'draft') return;
    w['ended_at'] ??= stamp();
    w['state'] = owner == 'guest' ? 'local' : 'pending';
    await put(owner, 'workout', w['id'], w);
    if (owner != 'guest') {
      final op = ids.v4();
      final wire = {
        for (final key in [
          'id',
          'name',
          'started_at',
          'ended_at',
          'notes',
          'bodyweight_kg',
          'exercises',
        ])
          key: w[key],
        'base_version': 0,
      };
      await customStatement(
        'INSERT INTO queue(id,owner,workout,payload) VALUES(?,?,?,?)',
        [
          op,
          owner,
          w['id'],
          jsonEncode({'operation_id': op, 'workout': wire}),
        ],
      );
    }
  });
  Future<List<Json>> pending(String owner, {bool force = false}) async {
    final bound = force
        ? 9000000000000000
        : DateTime.now().millisecondsSinceEpoch;
    return (await customSelect(
          'SELECT * FROM queue WHERE owner=? AND retry_at<=? ORDER BY rowid',
          variables: [Variable(owner), Variable(bound)],
        ).get())
        .map(
          (r) => {
            'id': r.read<String>('id'),
            'workout': r.read<String>('workout'),
            'body': jsonDecode(r.read<String>('payload')),
            'attempts': r.read<int>('attempts'),
          },
        )
        .toList();
  }

  Future<void> ack(String owner, String op, Json w) => transaction(() async {
    await put(owner, 'workout', w['id'], {...w, 'state': 'synced'});
    await customStatement('DELETE FROM queue WHERE owner=? AND id=?', [
      owner,
      op,
    ]);
  });
  Future<void> fail(String owner, Json op, String reason) async {
    final n = op['attempts'] as int;
    final delay = (5 * (1 << n.clamp(0, 8))).clamp(5, 900);
    await customStatement(
      'UPDATE queue SET attempts=attempts+1,retry_at=?,error=? WHERE id=? AND owner=?',
      [
        DateTime.now().millisecondsSinceEpoch + 1000 * delay,
        reason,
        op['id'],
        owner,
      ],
    );
  }

  Future<void> conflict(
    String owner,
    Json op,
    Json server,
  ) => transaction(() async {
    final local = Json.from(await read(owner, 'workout', op['workout']) as Map);
    await put(owner, 'workout', local['id'], {...local, 'state': 'conflict'});
    await put(owner, 'conflict', local['id'], server);
    await customStatement(
      'UPDATE queue SET retry_at=9223372036854775807 WHERE owner=? AND id=?',
      [owner, op['id']],
    );
  });
  Future<void> resolve(
    String owner,
    Json local,
    bool keepBoth,
  ) => transaction(() async {
    final server = Json.from(await read(owner, 'conflict', local['id']) as Map);
    await put(owner, 'workout', local['id'], {...server, 'state': 'synced'});
    await customStatement('DELETE FROM queue WHERE owner=? AND workout=?', [
      owner,
      local['id'],
    ]);
    await customStatement(
      "DELETE FROM docs WHERE owner=? AND kind='conflict' AND id=?",
      [owner, local['id']],
    );
    if (keepBoth) {
      final copy = duplicate(local, retainSets: true, retainTime: true);
      await finish(owner, copy);
    }
  });
  Future<void> pull(String owner, Json w) async {
    final old = await read(owner, 'workout', w['id']);
    if (old == null ||
        (old['state'] == 'synced' && (old['version'] ?? 0) < w['version'])) {
      await put(owner, 'workout', w['id'], {...w, 'state': 'synced'});
    }
  }

  Future<int> importGuest(String owner) => transaction(() async {
    if (owner == 'guest') return 0;
    int n = 0;
    for (final w in await list('guest', 'workout')) {
      if (w['ended_at'] == null ||
          await read(owner, 'import', w['id']) != null) {
        continue;
      }
      await finish(owner, duplicate(w, retainSets: true, retainTime: true));
      await put(owner, 'import', w['id'], true);
      n++;
    }
    return n;
  });
  Future<void> erase(String owner) => transaction(() async {
    await customStatement('DELETE FROM docs WHERE owner=?', [owner]);
    await customStatement('DELETE FROM queue WHERE owner=?', [owner]);
  });
}

class Api {
  static const endpoint = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.chuma.website/api/v1',
  );
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );
  final FlutterSecureStorage secure;
  final Dio http;
  Json? session;
  Future<bool>? refreshing;
  Api({this.secure = const FlutterSecureStorage()})
    : http = Dio(
        BaseOptions(
          baseUrl: endpoint,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      ) {
    if (environment == 'production' && Uri.parse(endpoint).scheme != 'https') {
      throw StateError('HTTPS requerido');
    }
    http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (session != null) {
            o.headers['Authorization'] = 'Bearer ${session!['access_token']}';
          }
          h.next(o);
        },
        onError: (e, h) async {
          if (e.response?.statusCode == 401 &&
              session != null &&
              !e.requestOptions.path.startsWith('/auth/') &&
              e.requestOptions.extra['retried'] != true) {
            final f = refreshing ??= refresh();
            final ok = await f;
            if (identical(f, refreshing)) refreshing = null;
            if (ok) {
              final o = e.requestOptions..extra['retried'] = true;
              try {
                return h.resolve(await http.fetch(o));
              } on DioException catch (err) {
                return h.next(err);
              }
            }
          }
          h.next(e);
        },
      ),
    );
  }
  String get owner => session?['user_id'] as String? ?? 'guest';
  Future<void> restore() async {
    final text = await secure.read(key: 'liftlog-auth');
    if (text != null) session = jsonDecode(text) as Json;
  }

  Future<void> remember(Json v) async {
    final data = {
      for (final k in ['access_token', 'refresh_token', 'user_id']) k: v[k],
    };
    await secure.write(key: 'liftlog-auth', value: jsonEncode(data));
    session = data;
  }

  Future<void> forget() async {
    await secure.delete(key: 'liftlog-auth');
    session = null;
  }

  Future<bool> refresh() async {
    try {
      final v = await post('/auth/refresh', {
        'refresh_token': session!['refresh_token'],
      });
      await remember(Json.from(v as Map));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String path, [Json? params]) async =>
      (await http.get(path, queryParameters: params)).data;
  Future<dynamic> post(String path, [dynamic data]) async =>
      (await http.post(path, data: data)).data;
  String explain(Object err) {
    if (err is DioException) {
      final body = err.response?.data;
      final detail = body is Map ? body['detail'] : null;
      if (detail is String) return detail;
      if (err.response == null) {
        return 'Servidor sin conexión. Tus entrenamientos siguen guardados.';
      }
      if (err.response?.statusCode == 422) {
        return 'Revisa los valores e inténtalo otra vez.';
      }
      return 'El servidor respondió HTTP ${err.response?.statusCode}.';
    }
    return err.toString();
  }
}

final stateProvider = ChangeNotifierProvider<LogState>(
  (_) => throw StateError('Inicializa LIFTLOG'),
);

class LogState extends ChangeNotifier {
  final Store db;
  final Api api;
  LogState(this.db, this.api);
  Map<String, Json> catalog = {};
  Json rules = {}, profile = {};
  List<Json> workouts = [], routines = [], records = [];
  String get owner => api.owner;
  bool get onlineAccount => owner != 'guest';
  bool get imperial => profile['units'] == 'imperial';
  Json? get active => workouts.where((w) => w['ended_at'] == null).firstOrNull;
  Timer? ticker;
  Future<void>? flight;
  String? syncInfo;
  bool get syncing => flight != null;
  Future<void> init() async {
    final items =
        (jsonDecode(await rootBundle.loadString('assets/catalog.json')) as List)
            .cast<Json>();
    catalog = {for (final x in items) x['id'] as String: x};
    if (await db.read('catalog', 'meta', 'version') != 1) {
      await db.transaction(() async {
        for (final e in items) {
          await db.put('catalog', 'exercise', e['id'], e);
        }
        await db.put('catalog', 'meta', 'version', 1);
      });
    }
    rules =
        jsonDecode(await rootBundle.loadString('assets/levels.json')) as Json;
    await api.restore();
    await reload();
    ticker = Timer.periodic(const Duration(seconds: 30), (_) => sync());
    unawaited(sync());
  }

  Future<void> reload() async {
    final u = owner;
    workouts = await db.list(u, 'workout');
    routines = await db.list(u, 'routine');
    profile = Json.from(await db.read(u, 'settings', 'profile') as Map? ?? {});
    final cloud = (await db.read(u, 'settings', 'records') as List? ?? [])
        .cast<Json>();
    records = [...localRecords(workouts, catalog), ...cloud];
    notifyListeners();
  }

  Future<void> updateProfile(Json changes) async {
    profile = onlineAccount
        ? Json.from(
            (await api.http.patch('/profiles/me', data: changes)).data as Map,
          )
        : {...profile, ...changes};
    await db.put(owner, 'settings', 'profile', profile);
    notifyListeners();
  }

  Future<Json> login(String username, String password, String? name) async {
    await flight;
    final data = Json.from(
      await api.post(name == null ? '/auth/login' : '/auth/register', {
            'username': username,
            'password': password,
            if (name != null) 'display_name': name,
          })
          as Map,
    );
    await api.remember(data);
    await reload();
    unawaited(sync(force: true));
    return data;
  }

  Future<void> logout() async {
    await flight;
    await api.post('/auth/logout');
    await api.forget();
    await reload();
  }

  Future<Json> start({Json? template}) async {
    if (active != null) return clone(active!);
    final w = template == null
        ? fresh('Entrenamiento libre')
        : duplicate(template);
    w['bodyweight_kg'] = profile['bodyweight_kg'];
    await save(w);
    return w;
  }

  Future<void> save(Json w) async {
    await db.draft(owner, w);
    await reload();
  }

  Future<void> finish(Json w) async {
    await db.finish(owner, w);
    await reload();
    unawaited(sync(force: true));
  }

  Future<void> routine(Json w, String name, int? weekday) async {
    final id = ids.v4();
    await db.put(owner, 'routine', id, {
      ...clone(w),
      'id': id,
      'name': name,
      'weekday': weekday,
    });
    await reload();
  }

  Future<void> sync({bool force = false}) async {
    if (!onlineAccount) return;
    if (flight != null) return flight!;
    final job = _sync(owner, force);
    flight = job;
    notifyListeners();
    try {
      await job;
    } finally {
      flight = null;
      notifyListeners();
    }
  }

  Future<void> _sync(String u, bool force) async {
    try {
      for (final op in await db.pending(u, force: force)) {
        try {
          final data = await api.post('/sync/workouts', op['body']);
          await db.ack(u, op['id'], Json.from(data['workout'] as Map));
        } on DioException catch (e) {
          final r = e.response?.data;
          final d = r is Map ? r['detail'] : null;
          if (e.response?.statusCode == 409 && d is Map && d['server'] is Map) {
            await db.conflict(u, op, Json.from(d['server'] as Map));
            continue;
          }
          await db.fail(u, op, api.explain(e));
          rethrow;
        }
      }
      String? cursor;
      do {
        final page = await api.get('/workouts', {
          if (cursor != null) 'after': cursor,
          'limit': 100,
        });
        for (final w in page['items'] as List) {
          await db.pull(u, Json.from(w as Map));
        }
        cursor = page['next_cursor'] as String?;
      } while (cursor != null);
      await db.put(u, 'settings', 'profile', await api.get('/profiles/me'));
      await db.put(u, 'settings', 'records', await api.get('/records'));
      syncInfo = 'Sincronización completada';
    } catch (e) {
      syncInfo = api.explain(e);
    } finally {
      await reload();
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }
}
