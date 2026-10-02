import hashlib
import unittest
from prepare import resolve


class Anchors(unittest.TestCase):
    def setUp(self):
        self.step = {'id': 'example', 'anchor': 'return 1', 'reviewed_sha256': hashlib.sha256(b'return 1').hexdigest()}

    def test_relocation_tracks_lines(self):
        self.assertEqual(resolve('-- inserted\n\nreturn 1\n', self.step), dict(self.step, first=3, last=3))

    def test_missing_and_duplicate_anchors_fail(self):
        for source in ['return 2', 'return 1\nreturn 1']:
            with self.subTest(source=source):
                with self.assertRaises(ValueError) as error:
                    resolve(source, self.step)
                self.assertEqual(str(error.exception), 'Anchor must occur exactly once: example')

    def test_changed_anchor_requires_review(self):
        self.step['anchor'] = 'return 2'
        with self.assertRaises(ValueError) as error:
            resolve('return 2', self.step)
        self.assertEqual(str(error.exception), 'Review changed excerpt: example')
