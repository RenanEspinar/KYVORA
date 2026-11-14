part of 'main.dart';

// User-facing resistance-entry methods. They normalize into the existing
// backend-compatible `load_kg` field without altering the server schema.
const loadEntryNames = <String, String>{
  'barbell': 'Barra: total o discos por lado',
  'dumbbell_pair': 'Dos mancuernas (peso de cada una)',
  'dumbbell_single': 'Una mancuerna (peso por mano)',
  'cable_pair': 'Dos poleas (peso de cada torre)',
  'cable_single': 'Una polea (peso indicado)',
  'machine': 'Máquina (peso indicado)',
  'plate_machine': 'Máquina con discos por lado',
  'single': 'Implemento / carga externa',
};

String loadEntryKind(Json exercise) {
  final profile = exercise['load_profile'];
  if (profile is Map && profile['kind'] is String) {
    return profile['kind'] as String;
  }
  // Backward-compatible fallback for a catalog returned by an older server.
  final mode = exercise['recording'];
  if (mode == 'bodyweight_reps') return 'bodyweight';
  if (mode == 'weighted_reps') return 'added';
  if (mode == 'assisted_reps') return 'assisted';
  if (mode == 'time' || mode == 'distance_time') return 'none';
  final equipment = (exercise['equipment'] ?? '').toString().toLowerCase();
  if (equipment.contains('mancuernas')) return 'dumbbell_pair';
  if (equipment.contains('mancuerna') || equipment.contains('dumbbell')) {
    return 'dumbbell_single';
  }
  if (equipment.contains('máquina') || equipment.contains('machine')) {
    return 'machine';
  }
  if (equipment.contains('poleas')) return 'cable_pair';
  if (equipment.contains('polea') || equipment.contains('cable')) {
    return 'cable_single';
  }
  if (equipment.contains('barra') || equipment.contains('barbell')) {
    return 'barbell';
  }
  return 'single';
}

bool loadIsPair(String method) =>
    method == 'dumbbell_pair' || method == 'cable_pair';

String loadEntryHint(String method, {bool unilateral = false}) {
  if (method == 'barbell') {
    return 'Peso externo total = barra + todos los discos. No registres solo los discos.';
  }
  if (method == 'dumbbell_pair') {
    return 'Escribe el peso de UNA mancuerna. KYVORA calcula el total de las dos.';
  }
  if (method == 'dumbbell_single') {
    return 'Peso de una mancuerna, por mano. No duplicamos automáticamente el volumen: registra cada lado como serie si quieres contabilizarlos por separado.';
  }
  if (method == 'cable_pair') {
    return 'Escribe lo que marca UNA torre; KYVORA suma las dos. No es fuerza real medida.';
  }
  if (method == 'cable_single') {
    return 'Escribe el valor indicado en la torre. Las relaciones de poleas pueden variar.';
  }
  if (method == 'plate_machine') {
    return 'Registra discos por lado y solo suma el peso del carro si conoces su valor real. Si tiene selector de placas, cambia a Máquina.';
  }
  if (method == 'machine') {
    return 'Escribe la carga seleccionada que muestra la máquina. No equivale necesariamente a la fuerza ejercida.';
  }
  if (method == 'added') {
    return 'Solo el lastre adicional: nunca sumes automáticamente tu peso corporal.';
  }
  if (method == 'assisted') {
    return 'Indica la asistencia seleccionada; más asistencia no significa más carga levantada.';
  }
  if (method == 'bodyweight') return 'Registra repeticiones. El peso corporal no se agrega como carga externa.';
  if (method == 'none') return 'Este ejercicio se registra por tiempo o distancia.';
  return unilateral
      ? 'Registra el peso del implemento utilizado en un lado.'
      : 'Registra la masa externa que empleas en la serie.';
}

String loadHelp(Json exercise) {
  final profile = exercise['load_profile'];
  final unilateral = profile is Map && profile['unilateral'] == true;
  return loadEntryHint(loadEntryKind(exercise), unilateral: unilateral);
}
