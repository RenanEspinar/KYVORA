import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/exercise_search.dart';

void main() {
  final pec=<String,dynamic>{
    'id':'pec','name':'Pec deck','name_en':'Pec deck fly',
    'search_aliases':['peck deck','contractora','butterfly machine'],
    'muscle':'pecho','equipment':'máquina',
    'laterality':'bilateral','exercise_type':'aislamiento',
  };
  final cable=<String,dynamic>{
    'id':'cable','name':'Apertura unilateral en polea de pie',
    'name_en':'Standing single-arm cable chest fly',
    'search_aliases':['one arm cable fly','aperturas unilateral polea'],
    'muscle':'pecho','equipment':'polea','laterality':'unilateral',
    'exercise_type':'aislamiento',
  };
  test('bilingual aliases and common typos', () {
    expect(exerciseSearchRank(pec,'pec deck'),greaterThan(0));
    expect(exerciseSearchRank(pec,'peck deck'),greaterThan(0));
    expect(exerciseSearchRank(pec,'contractora'),greaterThan(0));
    expect(exerciseSearchRank(cable,'single arm cable fly'),greaterThan(0));
    expect(exerciseSearchRank(cable,'aperturas unilateral polea'),greaterThan(0));
    expect(exerciseSearchRank(pec,'peck deck'),greaterThan(exerciseSearchRank(cable,'peck deck')));
  });
  test('spelling and accents normalization', () {
    expect(normExercise('Extensión DE TRÍCEPS'), 'extension de triceps');
    expect(exerciseSearchRank(pec,'peck dek'),greaterThan(0));
  });
  test('filters mix muscle, cable and unilateral', () {
    expect(exerciseMatchesFilters(cable,muscle:'Pecho',equipment:'Poleas',laterality:'unilateral'),isTrue);
    expect(exerciseMatchesFilters(pec,muscle:'Pecho',equipment:'Poleas'),isFalse);
    expect(exerciseMatchesFilters(cable,animatedOnly:true,motions:{}),isFalse);
    expect(exerciseMatchesFilters(cable,animatedOnly:true,motions:{'cable':{}}),isTrue);
  });
  test('broad muscle categories and secondary group', () {
    expect(muscleGroupOf({'muscle':'isquiotibiales'}),'Piernas');
    expect(muscleGroupOf({'muscle':'glúteos'}),'Glúteos');
    final e=<String,dynamic>{...cable,'secondary':['tríceps']};
    expect(exerciseMatchesFilters(e,muscle:'Tríceps',includeSecondary:true),isTrue);
    expect(exerciseMatchesFilters(e,muscle:'Tríceps',includeSecondary:false),isFalse);
  });
}
