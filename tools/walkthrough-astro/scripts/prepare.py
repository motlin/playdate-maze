"""Resolve source anchors and tokenize full files; Astro owns page rendering."""
import hashlib
import json
from pathlib import Path
import re
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import LuaLexer

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]


def resolve(source, step):
    anchor = step['anchor']
    if not anchor or source.count(anchor) != 1:
        raise ValueError(f'Anchor must occur exactly once: {step["id"]}')
    first = source[:source.index(anchor)].count('\n') + 1
    last = first + anchor.count('\n')
    digest = hashlib.sha256(anchor.encode()).hexdigest()
    if digest != step['reviewed_sha256']:
        raise ValueError(f'Review changed excerpt: {step["id"]}')
    return dict(step, first=first, last=last)


def prepare():
    spec = json.loads((PROJECT / 'walkthrough.json').read_text())
    formatter = HtmlFormatter(nowrap=True, style='native')
    identifiers = set()
    for section in spec['sections']:
        source = (ROOT / section['file']).read_text()
        section['steps'] = [resolve(source, step) for step in section['steps']]
        for step in section['steps']:
            if step['id'] in identifiers:
                raise ValueError(f'Duplicate step ID: {step["id"]}')
            identifiers.add(step['id'])
        colored = highlight(source, LuaLexer(stripnl=False), formatter).removesuffix('\n')
        section['lines'] = colored.split('\n')
        section['source_sha256'] = hashlib.sha256(source.encode()).hexdigest()
        for experiment in section['experiments']:
            experiment['markup'] = (ROOT / experiment['file']).read_text()
    template = (ROOT / 'tools/walkthrough/template.html').read_text()
    spec['references'] = re.search(r'<footer class="references">(.*?)</footer>', template, re.S)[1].split('<p>Complete Lua')[0]
    destination = PROJECT / 'generated'
    destination.mkdir(exist_ok=True)
    (destination / 'walkthrough.json').write_text(json.dumps(spec, ensure_ascii=False) + '\n')
    (destination / 'syntax.css').write_text(formatter.get_style_defs('.source') + '\n')
    print(f'Resolved {len(identifiers)} explanations against complete source files.')


if __name__ == '__main__':
    prepare()
