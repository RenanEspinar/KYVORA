import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('discardDraft deletes only unfinished, local draft and its timer', () async {
    final db = Store(NativeDatabase.memory());
    addTearDown(db.close);
    final w = fresh('Prueba de borrado');
    await db.draft('guest', w);
    await db.put('guest', 'timer', w['id'], '2026-11-15T14:00:00');
    await db.discardDraft('guest', w['id']);
    expect(await db.read('guest', 'workout', w['id']), isNull);
    expect(await db.read('guest', 'timer', w['id']), isNull);
  });

  test('discardDraft refuses finished sessions', () async {
    final db = Store(NativeDatabase.memory());
    addTearDown(db.close);
    final w = fresh('Entrenamiento finalizado');
    await db.finish('guest', w);
    await expectLater(db.discardDraft('guest', w['id']), throwsStateError);
    expect(await db.read('guest', 'workout', w['id']), isNotNull);
  });

  test('delete exercise removes all sets and repairs single-member superset', () {
    final w = fresh('En curso');
    w['state'] = 'draft';
    w['exercises'] = [
      {'id': 'a', 'exercise_id': 'x', 'superset': 'A', 'sets': [1, 2]},
      {'id': 'b', 'exercise_id': 'y', 'superset': 'A', 'sets': [3]},
      {'id': 'c', 'exercise_id': 'z', 'superset': null, 'sets': [4]},
    ];
    removeExerciseFromDraft(w, 'a');
    final exercises = w['exercises'] as List;
    expect(exercises.length, 2);
    expect(exercises.first['id'], 'b');
    expect(exercises.first['superset'], isNull);
    expect(exercises.last['id'], 'c');
  });

  test('finished session cannot lose an exercise', () {
    final w = fresh('Terminada');
    w['state'] = 'synced';
    w['ended_at'] = '2026-11-15T14:00:00Z';
    w['exercises'] = [{'id': 'a', 'superset': null, 'sets': [1]}];
    expect(() => removeExerciseFromDraft(w, 'a'), throwsStateError);
    expect((w['exercises'] as List).length, 1);
  });
}
