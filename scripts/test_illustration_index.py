import json
import tempfile
import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_illustration_index as illustrations

class IllustrationAssetsTest(unittest.TestCase):
    def test_exact_bindings_are_unique_and_valid(self):
        index=illustrations.build()
        catalog=json.loads(illustrations.CATALOG.read_text(encoding='utf-8'))
        ids={str(e['id']) for e in catalog}
        self.assertTrue(index)
        self.assertTrue(set(index).issubset(ids))
        self.assertGreaterEqual(len(index), 35)
        for img in index.values():
            self.assertTrue((illustrations.ROOT/'mobile'/img).is_file())

    def test_bad_fuzzy_names_cannot_be_assigned(self):
        index=illustrations.build()
        rules=json.loads(illustrations.RULES.read_text(encoding='utf-8'))
        expected=set(rules.values())
        self.assertTrue(set(index.values()).issubset(expected))
        self.assertEqual(len(set(index)),len(index))

if __name__=='__main__': unittest.main()
