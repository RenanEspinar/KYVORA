import json
import unittest
from pathlib import Path
from enrich_exercise_catalog import enrich, normalize, VARIANTS

class TestCatalogEnrichment(unittest.TestCase):
    def setUp(self):
        self.base=[{'id':'base1','name':'Pec deck','name_en':'Pec deck fly','muscle':'pecho','equipment':'máquina'}]

    def test_variants_unique_and_idempotent(self):
        data=[dict(e) for e in self.base]
        a=enrich(data)
        self.assertGreaterEqual(a['added'],35)
        self.assertEqual(len({e['id'] for e in data}),len(data))
        b=enrich(data)
        self.assertEqual(b['added'],0)
        self.assertEqual(len({e['id'] for e in data}),len(data))

    def test_aliases_include_english_and_typo(self):
        data=[dict(e) for e in self.base]
        enrich(data)
        pec=data[0]
        self.assertIn('peck deck',[normalize(v) for v in pec['search_aliases']])
        self.assertTrue(any('cable' in ' '.join(x['search_aliases']).lower() for x in data))

    def test_reference_urls_https_and_no_embedded_third_party_media(self):
        data=[dict(e) for e in self.base]
        enrich(data)
        refs=[e['visual_reference_url'] for e in data if e.get('visual_reference_url')]
        self.assertGreaterEqual(len(refs),3)
        self.assertTrue(all(u.startswith('https://') for u in refs))
        self.assertTrue(all(not e.get('gif_url') for e in data))

    def test_unique_variant_english_names(self):
        variants=json.loads(Path(VARIANTS).read_text(encoding='utf-8'))
        names=[normalize(x['name_en']) for x in variants]
        self.assertEqual(len(names),len(set(names)))

if __name__=='__main__':unittest.main()
