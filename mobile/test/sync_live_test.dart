import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/core.dart';

class _LiveBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

// Run only against a disposable API; never targets production implicitly.
void main() {
  const enabled = bool.fromEnvironment('LIVE_API_TEST', defaultValue: false);
  if (enabled) {
    _LiveBinding();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
  test(
    'SQLite offline → API real → reintento → segunda cuenta',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('liftlog-live-');
      final file = File('${directory.path}/session.sqlite');
      final apiA = Api();
      final apiB = Api();
      final suffix = ids.v4().replaceAll('-', '').substring(0, 10);
      final a = Json.from(
        await apiA.post('/auth/register', {
          'username': 'a_$suffix',
          'display_name': 'Ensayo A',
          'password': 'local-live-test-92475',
        }),
      );
      final b = Json.from(
        await apiB.post('/auth/register', {
          'username': 'b_$suffix',
          'display_name': 'Ensayo B',
          'password': 'local-live-test-92475',
        }),
      );
      await apiA.remember(a);
      await apiB.remember(b);
      await apiA.http.patch('/profiles/me', data: {'private': false});
      final catalog = (await apiA.get('/exercises') as List).cast<Json>();
      final exercises = catalog
          .where((e) => e['recording'] == 'weight_reps')
          .take(4);
      final w = fresh('Ensayo sin red', bodyweight: 75);
      w['exercises'] = exercises
          .map(
            (e) => {
              'id': ids.v4(),
              'exercise_id': e['id'],
              'superset': null,
              'sets': List.generate(
                3,
                (_) => {
                  'id': ids.v4(),
                  'kind': 'normal',
                  'load_kg': 60.0,
                  'reps': 10,
                  'rpe': 8.0,
                  'rir': 2,
                  'rest_seconds': 90,
                },
              ),
            },
          )
          .toList();
      var db = Store(NativeDatabase(file));
      // Actual connection failure, then process-style database close/reopen.
      final target = apiA.http.options.baseUrl;
      apiA.http.options.baseUrl = 'http://127.0.0.1:1/api/v1';
      await db.finish(apiA.owner, w);
      final original = (await db.pending(apiA.owner)).single;
      await expectLater(
        apiA.post('/sync/workouts', original['body']),
        throwsA(anything),
      );
      await db.close();
      db = Store(NativeDatabase(file));
      final op = (await db.pending(apiA.owner)).single;
      expect(op['id'], original['id']);
      apiA.http.options.baseUrl = target;
      final first = await apiA.post('/sync/workouts', op['body']);
      // Server accepted but client did not acknowledge: model a lost response.
      await db.close();
      db = Store(NativeDatabase(file));
      final retry = (await db.pending(apiA.owner)).single;
      final second = await apiA.post('/sync/workouts', retry['body']);
      expect(second, first);
      await db.ack(apiA.owner, retry['id'], Json.from(second['workout']));
      expect(await db.pending(apiA.owner), isEmpty);
      final remote = await apiA.get('/workouts');
      expect((remote['items'] as List).length, 1);
      expect(
        (remote['items'][0]['exercises'] as List)
            .expand((e) => e['sets'] as List)
            .length,
        12,
      );
      final post = await apiA.post('/posts', {
        'text': 'Sesión de ensayo',
        'visibility': 'public',
        'workout_id': w['id'],
      });
      await apiB.http.put('/posts/${post['id']}/reaction');
      await apiB.post('/posts/${post['id']}/comments', {
        'text': 'Confirmo recepción',
      });
      final feed = await apiB.get('/posts');
      final shared = (feed['items'] as List).firstWhere(
        (p) => p['id'] == post['id'],
      );
      expect(shared['reactions'], 1);
      expect(shared['comments'], 1);
      final pr = (first['new_records'] as List).firstWhere(
        (p) => p['kind'] == 'max_weight',
      );
      final request = await apiA.post('/verifications', {
        'record_id': pr['id'],
        'witness_username': 'b_$suffix',
      });
      final decision = await apiB.post(
        '/verifications/${request['id']}/decision',
        {
          'decision': 'approved',
          'reason': 'Atestación sintética de prueba técnica.',
        },
      );
      expect(decision['record']['status'], 'confirmed');
      expect(apiB.owner, b['user_id']);
      await db.close();
      apiA.http.close();
      apiB.http.close();
      await directory.delete(recursive: true);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
