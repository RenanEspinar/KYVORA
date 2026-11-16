"""Additional original exercise photographs for *exact* movement variants.

Photos show one illustrative phase of a movement, not a form assessment.
Never stretch a generic photo to a different cable angle, stance or machine.
"""
import unicodedata

def _norm(value):
    raw = unicodedata.normalize('NFKD',str(value or '').lower())
    return ' '.join(''.join(ch if ch.isalnum() else ' ' for ch in raw if not unicodedata.combining(ch)).split())

# Only names that match the actual original generated reference photograph.
# All other variants retain their specific Flow animation or neutral equipment card.
EXACT = {
    'press de banca': 'bench_press',
    'barbell bench press': 'bench_press',
    'press inclinado con mancuernas': 'incline_dumbbell_press',
    'incline dumbbell bench press': 'incline_dumbbell_press',
    'aperturas con mancuernas': 'dumbbell_fly',
    'dumbbell fly': 'dumbbell_fly',
    'dumbbell chest fly': 'dumbbell_fly',
    'flexiones': 'push_up',
    'push up': 'push_up',
    'push ups': 'push_up',
    'dominadas pronas': 'pull_up',
    'overhand pull up': 'pull_up',
    'jalon al pecho': 'lat_pulldown',
    'lat pulldown': 'lat_pulldown',
    'remo con barra': 'barbell_row',
    'barbell bent over row': 'barbell_row',
    'remo con mancuerna': 'one_arm_dumbbell_row',
    'one arm dumbbell row': 'one_arm_dumbbell_row',
    'press militar con barra': 'standing_overhead_press',
    'standing barbell overhead press': 'standing_overhead_press',
    'elevaciones laterales': 'dumbbell_lateral_raise',
    'dumbbell lateral raise': 'dumbbell_lateral_raise',
    'curl con barra': 'barbell_curl',
    'barbell curl': 'barbell_curl',
    'fondos lastrados': 'weighted_dips',
    'weighted dips': 'weighted_dips',
    'sentadilla trasera': 'back_squat',
    'barbell back squat': 'back_squat',
    'peso muerto convencional': 'conventional_deadlift',
    'barbell deadlift': 'conventional_deadlift',
    'prensa de piernas': 'leg_press',
    'sled leg press': 'leg_press',
    'plancha frontal': 'forearm_plank',
    'front plank': 'forearm_plank',
    'forearm plank': 'forearm_plank',
}

def visual_type_extra(ex):
    # Be conservative: only match an exact documented Spanish/English name.
    for field in ('name','name_en'):
        match = EXACT.get(_norm(ex.get(field)))
        if match:
            return match
    return None
