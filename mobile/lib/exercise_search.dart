/// KYVORA bilingual exercise search and filters.
/// Pure Dart so it can be tested without rendering Flutter widgets.
String normExercise(Object? value) {
  var s = (value ?? '').toString().toLowerCase().trim();
  const folding = <String, String>{
    'á':'a','à':'a','ä':'a','â':'a','ã':'a',
    'é':'e','è':'e','ë':'e','ê':'e',
    'í':'i','ì':'i','ï':'i','î':'i',
    'ó':'o','ò':'o','ö':'o','ô':'o',
    'ú':'u','ù':'u','ü':'u','û':'u','ñ':'n',
  };
  folding.forEach((a,b) => s=s.replaceAll(a,b));
  return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
}

String muscleGroupOf(Map<String,dynamic> e) {
  final s=normExercise(e['muscle'] ?? e['category'] ?? '');
  if (s.contains('pecho') || s.contains('chest') || s.contains('pector')) return 'Pecho';
  if (s.contains('espalda') || s.contains('back') || s.contains('dorsal') || s=='lats') return 'Espalda';
  if (s.contains('hombro') || s.contains('shoulder') || s.contains('deltoid')) return 'Hombros';
  if (s.contains('biceps')) return 'Bíceps';
  if (s.contains('triceps')) return 'Tríceps';
  if (s.contains('antebrazo') || s.contains('forearm')) return 'Brazos';
  if (s.contains('glute') || s.contains('hip') || s=='cadera') return 'Glúteos';
  if (s.contains('abdomen') || s.contains('core') || s=='waist' || s=='abs') return 'Core';
  if (s.contains('cardio') || s.contains('aerob')) return 'Cardio';
  if (s.contains('pierna') || s.contains('quadricep') || s.contains('cuadricep') || s.contains('isquiotibial') || s.contains('hamstring') || s.contains('cadena posterior') || s.contains('pantorrilla') || s.contains('calf') || s.contains('aductor')) return 'Piernas';
  if (s.contains('brazo') || s.contains('arm')) return 'Brazos';
  return 'Otros';
}

String equipmentGroupOf(Map<String,dynamic> e) {
  final s=normExercise(e['equipment']);
  final mode=normExercise(e['recording']);
  if(mode=='bodyweight reps' || mode=='weighted reps' || mode=='assisted reps' || s=='barra fija' || s=='paralelas') return 'Corporal';
  if (s.contains('mancuerna') || s.contains('dumbbell')) return 'Mancuernas';
  if (s.contains('polea') || s.contains('cable') || s.contains('pulley')) return 'Poleas';
  if (s.contains('maquina') || s.contains('machine') || s.contains('smith') || s.contains('sled')) return 'Máquinas';
  if (s.contains('barra') || s.contains('barbell') || s.contains('ez bar')) return 'Barras';
  if (s.contains('corporal') || s.contains('bodyweight') || s.contains('body weight') || s=='ninguno' || s=='barra fija' || s=='paralelas') return 'Corporal';
  if (s.contains('kettlebell')) return 'Kettlebell';
  if (s.contains('banda') || s.contains('band')) return 'Bandas';
  return 'Otros';
}

String lateralityOf(Map<String,dynamic> e) {
  final explicit=normExercise(e['laterality']);
  if (explicit=='unilateral' || explicit=='bilateral' || explicit=='alternado') return explicit;
  final n=normExercise('${e['name'] ?? ''} ${e['name_en'] ?? ''}');
  if (RegExp(r'\b(unilateral|single arm|one arm|single leg|one leg|una mano|un brazo|una pierna)\b').hasMatch(n)) return 'unilateral';
  if (n.contains('alternad') || n.contains('alternat')) return 'alternado';
  return 'bilateral';
}

String exerciseTypeOf(Map<String,dynamic> e) {
  final s=normExercise(e['exercise_type']);
  if (s=='aislamiento' || s=='isolation') return 'aislamiento';
  if (s=='compuesto' || s=='compound') return 'compuesto';
  return 'otro';
}

List<String> searchTermsFor(Map<String,dynamic> e) {
  final aliases=(e['search_aliases'] is List)
    ? (e['search_aliases'] as List).map((v)=>v.toString())
    : <String>[];
  return [
    '${e['name'] ?? ''}', '${e['name_en'] ?? ''}', '${e['name_es'] ?? ''}',
    ...aliases,
    '${e['muscle'] ?? ''}', '${e['category'] ?? ''}', '${e['equipment'] ?? ''}',
    '${e['target'] ?? ''}', '${e['angle'] ?? ''}',
  ].map(normExercise).where((s)=>s.isNotEmpty).toList();
}

int _editDistanceCapped(String a,String b,int cap) {
  if ((a.length-b.length).abs()>cap) return cap+1;
  var prev=List<int>.generate(b.length+1,(i)=>i);
  for(var i=1;i<=a.length;i++) {
    final cur=List<int>.filled(b.length+1,0);
    cur[0]=i;
    for(var j=1;j<=b.length;j++) {
      final cost=a.codeUnitAt(i-1)==b.codeUnitAt(j-1)?0:1;
      var minimum=cur[j-1]+1;
      if(prev[j]+1<minimum) minimum=prev[j]+1;
      if(prev[j-1]+cost<minimum) minimum=prev[j-1]+cost;
      cur[j]=minimum;
    }
    if(cur.reduce((a,b)=>a<b?a:b)>cap) return cap+1;
    prev=cur;
  }
  return prev.last;
}

/// -1 = no match. Exact Spanish/English names and known aliases rank first.
int exerciseSearchRank(Map<String,dynamic> e,String rawQuery) {
  final query=normExercise(rawQuery);
  if(query.isEmpty) return 0;
  final name=normExercise(e['name']);
  final english=normExercise(e['name_en']);
  final aliases=(e['search_aliases'] is List)
      ? (e['search_aliases'] as List).map(normExercise).toList() : <String>[];
  if(query==name || query==english) return 1000;
  if(aliases.contains(query)) return 950;
  if(name.startsWith(query) || english.startsWith(query)) return 850;
  if(aliases.any((s)=>s.startsWith(query))) return 820;
  final fields=searchTermsFor(e);
  final words=fields.expand((s)=>s.split(' ')).toSet().toList();
  var score=0;
  for(final token in query.split(' ')) {
    var best=0;
    if(words.contains(token)) {best=55;}
    else if(words.any((w)=>w.startsWith(token))) {best=42;}
    else if(words.any((w)=>w.contains(token) && token.length>=3)) {best=27;}
    else if(token.length>=3) {
      final cap=token.length>=8?2:1;
      if(words.any((w)=> (w.length-token.length).abs()<=cap && _editDistanceCapped(token,w,cap)<=cap)) best=15;
    }
    if(best==0) return -1;
    score+=best;
  }
  if(name.contains(query)) score+=110;
  if(english.contains(query)) score+=90;
  if(aliases.any((s)=>s.contains(query))) score+=70;
  return score;
}

bool exerciseMatchesFilters(Map<String,dynamic> e,{
  String? muscle, String? equipment, String? laterality,
  String? exerciseType, bool includeSecondary=false, bool animatedOnly=false,
  Map<String, Map<String,dynamic>>? motions,
}) {
  if(muscle!=null && muscleGroupOf(e)!=muscle) {
    final secondary=e['secondary'];
    if(!includeSecondary || secondary is! List ||
       !secondary.any((g)=>muscleGroupOf({'muscle':g})==muscle)) {
      return false;
    }
  }
  if(equipment!=null && equipmentGroupOf(e)!=equipment) return false;
  if(laterality!=null && lateralityOf(e)!=laterality) return false;
  if(exerciseType!=null && exerciseTypeOf(e)!=exerciseType) return false;
  if(animatedOnly && !(motions?.containsKey(e['id']?.toString()) ?? false)) return false;
  return true;
}
