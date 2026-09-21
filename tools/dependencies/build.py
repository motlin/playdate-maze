"""Build docs/dependencies.html: lexical global references, imports, and cycles.

Run with python3 tools/dependencies/build.py. Requires Pygments and Graphviz.
This is a named-reference graph, not a runtime call graph.
"""
from pathlib import Path
import json
import re
import subprocess

from pygments import lex, highlight
from pygments.lexers import LuaLexer
from pygments.formatters import HtmlFormatter
from pygments.token import Comment, String, Name

ROOT = Path(__file__).resolve().parents[2]
sources = {str(p.relative_to(ROOT)): p.read_text() for p in sorted((ROOT / 'source').rglob('*.lua'))}
owners = {}
for path, source in sources.items():
    declarations = re.findall(r'^([A-Z]\w*)\s*=', source, re.M)
    assert len(declarations) == (0 if path == 'source/main.lua' else 1), path
    owners[declarations[0] if declarations else 'main'] = path
names = set(owners)
edges = {}
imports = set()
for owner, path in owners.items():
    source = sources[path]
    # Fail if local declarations/parameters shadow a module: this scanner does not resolve scopes.
    stripped = ''.join(''.join('\n' if c == '\n' else ' ' for c in value)
                       if token in Comment or token in String else value
                       for token, value in lex(source, LuaLexer()))
    for name in names:
        assert not re.search(r'\blocal\s+[^\n=]*\b' + name + r'\b', stripped), (path, name, 'shadowed local')
        assert not re.search(r'\bfunction\b[^\n(]*\([^)]*\b' + name + r'\b', stripped), (path, name, 'shadowed parameter')
    line = 1
    previous = ''
    for token, value in lex(source, LuaLexer()):
        if token not in Comment and token not in String:
            if token in Name and value in names | {'playdate'} and value != owner and not previous.endswith(('.', ':')):
                edges.setdefault((owner, value), set()).add(line)
            if value.strip():
                previous = value.strip()
        line += value.count('\n')
    for imported in re.findall(r'^import\s+"([^"]+)"', source, re.M):
        target_path = 'source/' + imported + '.lua'
        target = next((name for name, p in owners.items() if p == target_path), None)
        if target:
            imports.add((owner, target))


def components(pairs):
    """Strongly connected components via mutual reachability; small, fixed graph."""
    adjacency = {name: {b for a, b in pairs if a == name} for name in names}
    reach = {}
    for name in names:
        seen, pending = set(), list(adjacency[name])
        while pending:
            target = pending.pop()
            if target not in seen:
                seen.add(target)
                pending.extend(adjacency.get(target, ()))
        reach[name] = seen
    groups, assigned = [], set()
    for name in sorted(names):
        if name not in assigned:
            group = sorted(other for other in names if other == name or (other in reach[name] and name in reach[other]))
            assigned.update(group)
            if len(group) > 1:
                groups.append(group)
    return groups


cycles = components(edges)
import_cycles = components(imports)
cycle_pairs = {(a, b) for group in cycles for a, b in edges if a in group and b in group}


def diagram(pairs, nodes):
    dot = ['digraph G { rankdir=LR; bgcolor="transparent"; graph [pad="0.2", nodesep="0.28", ranksep="0.55"];',
           'node [shape=box, style="rounded,filled", fillcolor="#19222e", color="#47576a", fontcolor="#e9eff6", fontname="Arial", fontsize=13, margin="0.14,0.1"];',
           'edge [color="#7994ac", arrowsize=0.65];']
    for name in sorted(nodes):
        dot.append(f'{json.dumps(name)} [URL={json.dumps("#" + name)}, tooltip={json.dumps(owners.get(name, "Playdate SDK"))}];')
    for a, b in sorted(pairs):
        style = ' [color="#ffae80", penwidth=1.8]' if (a, b) in cycle_pairs else ''
        dot.append(f'{json.dumps(a)} -> {json.dumps(b)}{style};')
    dot.append('}')
    svg = subprocess.run(['dot', '-Tsvg'], input='\n'.join(dot), capture_output=True, text=True, check=True).stdout
    return svg[svg.index('<svg'):].replace('<svg ', '<svg role="img" aria-label="Dependency graph; arrows point from user to dependency" ', 1)


data = {'nodes': {}, 'edges': [], 'cycles': cycles, 'importCycles': import_cycles}
formatter = HtmlFormatter(nowrap=True)
for name, path in owners.items():
    colored = highlight(sources[path], LuaLexer(), formatter).splitlines()
    listing = '\n'.join(f'<span class="line" id="line-{i}"><span class="number">{i}</span>{row}</span>' for i, row in enumerate(colored, 1))
    neighbors = {pair for pair in edges if name in pair}
    data['nodes'][name] = {'path': path, 'code': listing, 'graph': diagram(neighbors, {name} | {n for pair in neighbors for n in pair})}
data['nodes']['playdate'] = {'path': 'Playdate SDK (external)', 'code': '', 'graph': diagram({pair for pair in edges if 'playdate' in pair}, {'playdate'} | {a for a, b in edges if b == 'playdate'})}
for (a, b), lines in sorted(edges.items()):
    data['edges'].append({'from': a, 'to': b, 'imported': (a, b) in imports, 'cycle': (a, b) in cycle_pairs,
                          'lines': [{'number': n, 'text': sources[owners[a]].splitlines()[n - 1]} for n in sorted(lines)]})
project_edges = {pair for pair in edges if pair[1] != 'playdate'}
template = Path(__file__).with_name('template.html').read_text()
page = template.replace('__DATA__', json.dumps(data).replace('<', '\\u003c'))
page = page.replace('__CYCLES__', diagram(cycle_pairs, {n for group in cycles for n in group}) if cycles else '<p>No named-reference cycles found.</p>')
page = page.replace('__FULL__', diagram(project_edges, names))
page = page.replace('__CSS__', formatter.get_style_defs('.source'))
page = page.replace('__COUNTS__', f'{len(owners) - 1} project globals · {len(project_edges)} named dependencies · {len(cycles)} cyclic group(s) · {len(import_cycles)} import cycles')
(ROOT / 'docs/dependencies.html').write_text(page)
print(f'Wrote docs/dependencies.html. Cyclic groups: {cycles}; import cycles: {import_cycles}')
print(f'{len(edges)} named edges; {len(imports)} import edges; {len(project_edges - imports)} project references without a direct import.')
