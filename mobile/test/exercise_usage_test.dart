import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/exercise_usage.dart';

void main() {
  test('counts finished sessions, not number of sets', () {
    final counts = countExerciseSessions([
      {
        'ended_at': '2026-11-14T12:30:00Z',
        'exercises': [
          {'exercise_id': 'bench', 'sets': [{}, {}, {}]},
          {'exercise_id': 'fly', 'sets': [{}]},
          {'exercise_id': 'bench', 'sets': [{}]},
        ],
      },
      {
        'ended_at': '2026-11-15T12:30:00Z',
        'exercises': [
          {'exercise_id': 'bench', 'sets': [{}]},
          {'exercise_id': 'squat', 'sets': []},
        ],
      },
    ]);
    expect(counts, {'bench': 2, 'fly': 1});
  });

  test('does not count unfinished or empty workout exercises', () {
    final counts = countExerciseSessions([
      {'ended_at': null, 'exercises': [{'exercise_id': 'x', 'sets': [{}]}]},
      {'ended_at': '', 'exercises': [{'exercise_id': 'x', 'sets': [{}]}]},
      {'ended_at': '2026-11-15', 'exercises': [{'exercise_id': 'x', 'sets': []}]},
      {'ended_at': '2026-11-15', 'exercises': [{'exercise_id': '', 'sets': [{}]}]},
      {'ended_at': '2026-11-15', 'exercises': 'bad'},
      null,
    ]);
    expect(counts, isEmpty);
  });
}
