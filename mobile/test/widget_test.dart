import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/core.dart';
import 'package:liftlog/main.dart';

Json session() {
  final w = fresh('Sesión de prueba', bodyweight: 75);
  w['exercises'] = List.generate(
    4,
    (i) => {
      'id': ids.v4(),
      'exercise_id': 'ejercicio-$i',
      'superset': null,
      'sets': List.generate(
        3,
        (_) => {
          'id': ids.v4(),
          'kind': 'normal',
          'reps': 10,
          'load_kg': 60.0,
          'rest_seconds': 90,
        },
      ),
    },
  );
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Reapertura de SQLite, doce series y cola idempotente', () async {
    final directory = await Directory.systemTemp.createTemp('liftlog-qa');
    final file = File('${directory.path}/local.db');
    final w = session();
    var db = Store(NativeDatabase(file));
    await db.draft('a', w);
    await db.close();
    db = Store(NativeDatabase(file));
    final draft = Json.from(await db.read('a', 'workout', w['id']));
    expect(draft['state'], 'draft');
    await db.finish('a', draft);
    final pending = (await db.pending('a')).single;
    await db.close();
    db = Store(NativeDatabase(file));
    final op = (await db.pending('a')).single;
    expect(op['id'], pending['id']);
    final exercises = op['body']['workout']['exercises'] as List;
    expect(exercises.expand((m) => m['sets'] as List).length, 12);
    await db.finish('a', draft);
    expect((await db.pending('a')).length, 1);
    await db.ack('a', op['id'], {...op['body']['workout'], 'version': 1});
    expect(await db.pending('a'), isEmpty);
    expect((await db.list('a', 'workout')).single['state'], 'synced');
    await db.close();
    await directory.delete(recursive: true);
  });
  test('Resolver conflicto conserva servidor y copia local', () async {
    final db = Store(NativeDatabase.memory());
    final w = session();
    await db.finish('a', w);
    final op = (await db.pending('a')).single;
    final remote = <String, dynamic>{
      ...op['body']['workout'],
      'name': 'Servidor',
      'version': 1,
    };
    await db.conflict('a', op, remote);
    expect(await db.pending('a', force: true), isEmpty);
    final local = (await db.list('a', 'workout')).single;
    expect(local['state'], 'conflict');
    await db.resolve('a', local, true);
    final all = await db.list('a', 'workout');
    expect(all.length, 2);
    expect(
      all.any((w) => w['name'] == 'Servidor' && w['state'] == 'synced'),
      true,
    );
    expect((await db.pending('a')).single['workout'], isNot(w['id']));
    await db.close();
  });
  test('Importación voluntaria por cuenta evita duplicaciones', () async {
    final db = Store(NativeDatabase.memory());
    await db.finish('guest', session());
    expect(await db.pending('guest'), isEmpty);
    expect(await db.list('a', 'workout'), isEmpty);
    expect(await db.importGuest('a'), 1);
    expect(await db.importGuest('a'), 0);
    expect(await db.pending('b'), isEmpty);
    expect((await db.list('guest', 'workout')).length, 1);
    await db.close();
  });
  test('Pull nunca sobrescribe un borrador pendiente', () async {
    final db = Store(NativeDatabase.memory());
    final w = session();
    await db.draft('a', w);
    await db.pull('a', {...w, 'name': 'Remoto', 'version': 99});
    expect((await db.read('a', 'workout', w['id']))['name'], w['name']);
    await db.close();
  });
  test('Epley, unidades y modalidades de asistencia', () {
    expect(normalizedMass(displayMass(60, true), true), closeTo(60, 1e-8));
    expect(epley(60, 10), 80);
    expect(epley(60, 11), null);
    expect(epley(60, 1), 60);
    final w = session()
      ..['ended_at'] = stamp()
      ..['state'] = 'pending';
    final catalog = <String, Json>{
      for (int i = 0; i < 4; i++)
        'ejercicio-$i': {'recording': i == 0 ? 'weight_reps' : 'assisted_reps'},
    };
    w['exercises'][0]['sets'][0]['kind'] = 'warmup';
    expect(volume(w, catalog), 1200);
    expect(localRecords([w], catalog).length, 3);
  });
  testWidgets('Navegación y apertura de sesión sin conexión', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final db = Store(NativeDatabase.memory());
    final state = LogState(db, Api());
    await tester.runAsync(state.init);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stateProvider.overrideWith((ref) => state)],
        child: const Liftlog(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tu espacio'), findsOneWidget);
    expect(state.catalog.length, greaterThanOrEqualTo(100));
    await tester.tap(find.text('Entrenar').last);
    await tester.pumpAndSettle();
    expect(find.text('Mis rutinas'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Entrenamiento libre').first);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    });
    await tester.pumpAndSettle();
    expect(find.text('Añadir ejercicio'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
