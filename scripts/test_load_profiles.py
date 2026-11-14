"""Regression checks for KYVORA's resistance-entry classification."""
import unittest
import json
from pathlib import Path
from assign_load_profiles import classify, VALID, MOBILE


class LoadProfiles(unittest.TestCase):
    def test_full_local_catalog_has_profiles(self):
        catalog = json.loads(MOBILE.read_text(encoding='utf-8'))
        self.assertGreaterEqual(len(catalog), 114)
        self.assertEqual(len(catalog), len({x['id'] for x in catalog}))
        for ex in catalog:
            self.assertIn(ex['load_profile']['kind'], VALID)

    def test_standard_bar_with_two_side_plates(self):
        p = classify(dict(name='Press de banca', equipment='barra', recording='weight_reps'))
        self.assertEqual(p['kind'], 'barbell')
        self.assertEqual(p['default_bar_kg'], 20)
        # 20 kg bar + (15 kg + 15 kg) = 50 kg total; Dart UI uses this exact expression.
        self.assertEqual(20+2*15,50)

    def test_two_dumbbells(self):
        p = classify(dict(name='Press con mancuernas', equipment='mancuernas', recording='weight_reps'))
        self.assertEqual(p['kind'], 'dumbbell_pair')

    def test_single_dumbbell(self):
        p = classify(dict(name='Remo con mancuerna', equipment='mancuerna', recording='weight_reps'))
        self.assertEqual(p['kind'], 'dumbbell_single')

    def test_alternating_dumbbell_pair(self):
        p = classify(dict(name='Curl alternado', equipment='mancuernas', recording='weight_reps'))
        self.assertEqual(p['kind'], 'dumbbell_pair')
        self.assertTrue(p['alternating'])

    def test_bodyweight_vs_added_vs_assisted(self):
        eq = 'barra fija'
        self.assertEqual(classify(dict(name='Dominadas', equipment=eq, recording='bodyweight_reps'))['kind'], 'bodyweight')
        self.assertEqual(classify(dict(name='Dominadas lastradas', equipment='lastre', recording='weighted_reps'))['kind'], 'added')
        self.assertEqual(classify(dict(name='Dominadas asistidas', equipment='máquina', recording='assisted_reps'))['kind'], 'assisted')

    def test_machine(self):
        self.assertEqual(classify(dict(name='Prensa de piernas', equipment='máquina', recording='weight_reps'))['kind'],'plate_machine')
        self.assertEqual(classify(dict(name='Press pecho', equipment='máquina', recording='weight_reps'))['kind'],'machine')

    def test_two_cable_stacks(self):
        self.assertEqual(classify(dict(name='Aperturas en poleas', equipment='poleas', recording='weight_reps'))['kind'],'cable_pair')

    def test_unknown_needs_review(self):
        p=classify(dict(name='Movimiento especial',equipment='artilugio',recording='weight_reps'))
        self.assertEqual(p['confidence'],'needs_review')
        self.assertEqual(p['kind'],'single')


if __name__=='__main__':
    unittest.main()
