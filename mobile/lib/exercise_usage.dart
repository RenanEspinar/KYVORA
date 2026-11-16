/// Counts how many *finished workouts* included at least one recorded set
/// for each exercise. A workout contributes at most one use per exercise,
/// regardless of set count or duplicated move instances.
///
/// Calculated locally; it does not expose other athletes' private history.
Map<String, int> countExerciseSessions(Iterable<dynamic> workouts) {
  final counts = <String, int>{};
  for (final workout in workouts) {
    if (workout is! Map) continue;
    final ended = workout['ended_at'];
    if (ended == null || ended.toString().trim().isEmpty) continue;
    final moves = workout['exercises'];
    if (moves is! List) continue;
    final seen = <String>{};
    for (final move in moves) {
      if (move is! Map) continue;
      final id = move['exercise_id'];
      final sets = move['sets'];
      if (id is! String || id.isEmpty || sets is! List || sets.isEmpty) {
        continue;
      }
      seen.add(id);
    }
    for (final id in seen) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}
