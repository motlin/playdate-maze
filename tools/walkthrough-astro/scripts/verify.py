"""Build twice and verify exact source listings, baseline hashes, and output bytes."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import subprocess
import shutil

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]
OUTPUT = ROOT / 'docs/walkthrough-comparison'


class Listings(HTMLParser):
    def __init__(self):
        super().__init__()
        self.files = {}
        self.path = None
        self.in_listing = False
        self.in_number = False

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == 'section' and attributes.get('class') == 'section':
            self.path = attributes['data-file']
            self.files[self.path] = []
        if tag == 'pre' and attributes.get('class') == 'source':
            self.in_listing = True
        if self.in_listing and attributes.get('class') == 'line':
            self.files[self.path].append('')
        if self.in_listing and attributes.get('class') == 'number':
            self.in_number = True

    def handle_endtag(self, tag):
        if tag == 'pre':
            self.in_listing = False
        if tag == 'span':
            self.in_number = False

    def handle_data(self, value):
        if self.in_listing and not self.in_number:
            self.files[self.path][-1] += value


def hashes(directory):
    return {str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(directory.rglob('*')) if path.is_file()}


def main():
    expected = json.loads((PROJECT / 'baselines.json').read_text())
    assert hashes(ROOT / 'docs/walkthrough-baselines') == expected, 'A preserved baseline changed'
    if (PROJECT / '.astro').exists():
        shutil.rmtree(PROJECT / '.astro')
    subprocess.run(['npm', 'run', 'build'], cwd=PROJECT, check=True)
    first = hashes(OUTPUT)
    if (PROJECT / '.astro').exists():
        shutil.rmtree(PROJECT / '.astro')
    subprocess.run(['npm', 'run', 'build'], cwd=PROJECT, check=True)
    assert hashes(OUTPUT) == first, 'Repeated Astro builds differ'
    listings = Listings()
    listings.feed((OUTPUT / 'maze/index.html').read_text())
    spec = json.loads((PROJECT / 'walkthrough.json').read_text())
    sources = {section['file']: (ROOT / section['file']).read_text().splitlines() for section in spec['sections']}
    assert listings.files == sources, 'Rendered complete listings differ from source'
    print(f'Identical Astro output across two builds; {len(sources)} complete listings match; both baselines unchanged.')


if __name__ == '__main__':
    main()
