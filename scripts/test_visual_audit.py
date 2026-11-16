"""Fast, offline tests for every-media-present build gate."""
import json
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile
from PIL import Image

from audit_visual_assets import audit_apk, audit_source, VisualAuditError
from kyvora_visual_types_extra import visual_type_extra


class VisualAuditTests(unittest.TestCase):
    def setUp(self):
        self.dir=tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.root=Path(self.dir.name)
        self.assets=self.root/'mobile/assets'
        self.assets.mkdir(parents=True)
        (self.assets/'guides').mkdir()
        (self.assets/'flow_frames').mkdir()
        catalog=[{'id':'a','name':'Bench press'}, {'id':'b','name':'Romanian deadlift'}]
        motions={'a':{'frames':['assets/flow_frames/a-0.svg','assets/flow_frames/a-1.svg'],'sequence':[0,1,0]}}
        guides={'b':'assets/guides/guide_b.jpg'}
        for name,obj in [('catalog.json',catalog),('motion_index.json',motions),('guide_index.json',guides)]:
            (self.assets/name).write_text(json.dumps(obj),encoding='utf-8')
        svg=b'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="60" height="80"/></svg>'
        for n in ['a-0.svg','a-1.svg']:
            (self.assets/'flow_frames'/n).write_bytes(svg)
        Image.new('RGB',(100,80),'blue').save(self.assets/'guides/guide_b.jpg','JPEG')

    def test_source_is_complete(self):
        result=audit_source(self.root)
        self.assertEqual(result['total'],2)
        self.assertEqual(result['missing'],0)
        self.assertEqual(result['animations'],1)
        self.assertEqual(result['original_static_guides'],1)

    def test_missing_image_fails(self):
        (self.assets/'guides/guide_b.jpg').unlink()
        with self.assertRaisesRegex(VisualAuditError,'ausente'):
            audit_source(self.root)

    def test_corrupt_jpg_fails(self):
        (self.assets/'guides/guide_b.jpg').write_bytes(b'x'*100)
        with self.assertRaisesRegex(VisualAuditError,'dañada'):
            audit_source(self.root)

    def test_unknown_motion_index_fails(self):
        p=self.assets/'motion_index.json'
        d=json.loads(p.read_text());d['unknown']=d['a']
        p.write_text(json.dumps(d))
        with self.assertRaisesRegex(VisualAuditError,'IDs'):
            audit_source(self.root)

    def test_apk_must_bundle_every_image(self):
        pkg=self.root/'example.apk'
        with ZipFile(pkg,'w') as z:
            for f in self.assets.rglob('*'):
                if f.is_file():
                    z.write(f,'assets/flutter_assets/assets/'+f.relative_to(self.assets).as_posix())
        self.assertEqual(audit_apk(pkg)['total'],2)
        with ZipFile(pkg,'w') as z:
            for f in self.assets.rglob('*'):
                if f.is_file() and f.name!='guide_b.jpg':
                    z.write(f,'assets/flutter_assets/assets/'+f.relative_to(self.assets).as_posix())
        with self.assertRaises(VisualAuditError):
            audit_apk(pkg)

    def test_photo_names_do_not_match_other_variants(self):
        self.assertEqual(visual_type_extra({'name':'Press de banca'}),'bench_press')
        self.assertEqual(visual_type_extra({'name':'Prensa de piernas'}),'leg_press')
        self.assertIsNone(visual_type_extra({'name':'Press de banca inclinado en Smith'}))
        self.assertIsNone(visual_type_extra({'name':'Pec deck unilateral'}))

if __name__=='__main__': unittest.main()
