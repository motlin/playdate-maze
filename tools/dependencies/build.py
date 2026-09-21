"""Build docs/dependencies.html: reviewed ownership findings and reference context.

Run with python3 tools/dependencies/build.py. Requires Pygments and Graphviz.
This is a named-reference graph, not a runtime call graph.
"""
from pathlib import Path
import json
import re
import subprocess
import textwrap

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
    declarations = re.findall(r'\blocal[ \t]+(?:function[ \t]+)?([A-Za-z_]\w*(?:[ \t]*,[ \t]*[A-Za-z_]\w*)*)', stripped)
    locals_ = {name.strip() for declaration in declarations for name in declaration.split(',')}
    assert not names & locals_, (path, names & locals_, 'shadowed local')
    for name in names:
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



def evidence(module, anchor):
    source = sources[owners[module]]
    assert source.count(anchor) == 1, (module, anchor)
    number = source[:source.index(anchor)].count('\n') + 1
    return {'module': module, 'number': number, 'text': source.splitlines()[number - 1]}


# Reviewed findings, not inferred from names. Anchors fail when evidence changes.
findings = [
    {'from': 'EditorScene', 'to': 'MapEditor', 'kind': 'operation',
     'label': 'requests editor transitions',
     'explanation': 'MapEditor owns regeneration, cursor and tool reset, the action message, and the dirty flag. The scene asks for a playable design or a new maze rather than assigning those fields.',
     'lines': [evidence('EditorScene', 'EditorScene.editor:designToPlay()'),
               evidence('EditorScene', 'EditorScene.editor:generateMaze(math.random)'),
               evidence('MapEditor', 'function MapEditor:generateMaze(random)'),
               evidence('MapEditor', 'function MapEditor:designToPlay()')]},
    {'from': 'Autopilot', 'to': 'Player', 'kind': 'operation',
     'label': 'requests target following',
     'explanation': 'Autopilot chooses clear cell centers. Player owns the bounded movement and exact arrival, preserving the previous navigation behavior.',
     'lines': [evidence('Autopilot', 'player:walkTowards('), evidence('Player', 'function Player:walkTowards(')]},
    {'from': 'Game', 'to': 'Player', 'kind': 'operation',
     'label': 'requests thread rewind',
     'explanation': 'Player asks the thread for a collision-checked rewind and applies position and limited heading together. Game handles messages and sound events.',
     'lines': [evidence('Game', 'player:rewindAlong('), evidence('Player', 'function Player:rewindAlong(')]},
    {'from': 'Tumble', 'to': 'Player', 'kind': 'operation',
     'label': 'requests heading turn',
     'explanation': 'Tumble computes gravity direction and uses the existing Player turn operation instead of assigning its angle.',
     'lines': [evidence('Tumble', 'self.player:turn('), evidence('Player', 'function Player:turn(')]},
    {'from': 'Slime', 'to': 'Player', 'kind': 'operation',
     'label': 'resets simulation pose',
     'explanation': 'The reusable prediction body copies the live pose through Player behavior. The caller owns the returned arc points; the live body is never advanced by the preview.',
     'lines': [evidence('Slime', 'scout:copyFrom('), evidence('Player', 'function Player:copyFrom(')]},
    {'from': 'Game', 'to': 'Maze', 'kind': 'operation',
     'label': 'requests drawing conversion',
     'explanation': 'Maze owns copying the design into its block representation and placing the closed gate. Game no longer writes Maze blocks or exit coordinates.',
     'lines': [evidence('Game', 'local maze = Maze.fromDesign(design)'), evidence('Maze', 'function Maze.fromDesign(design)')]},
    {'from': 'MazeView', 'to': 'Raycaster', 'kind': 'operation',
     'label': 'fills view-owned scan buffer',
     'explanation': 'Raycaster.scan returns independent nested data by default. MazeView explicitly supplies its private output buffer to avoid per-frame table allocation; only reusing that buffer overwrites it.',
     'lines': [evidence('MazeView', 'local scan = Raycaster.scan('),
               evidence('Raycaster', 'result = result or { runs = {}, depths = {} }'),
               evidence('Raycaster', 'return result')]},
    {'from': 'Sounds', 'to': 'Hum', 'kind': 'operation',
     'label': 'fills sound-owned level buffer',
     'explanation': 'Hum.levels returns independent level tables by default. Sounds supplies its own reusable buffer and consumes it before updating the same buffer next frame.',
     'lines': [evidence('Sounds', 'for index, level in ipairs(Hum.levels('),
               evidence('Hum', 'levels = levels or {}'), evidence('Hum', 'return levels')]},
    {'from': 'Hud', 'to': 'Compass', 'kind': 'operation',
     'label': 'fills HUD-owned mark buffer',
     'explanation': 'Compass.marks returns independent marks by default. Hud supplies its private output buffer, which is overwritten only when explicitly reused.',
     'lines': [evidence('Hud', 'for _, mark in ipairs(Compass.marks('),
               evidence('Compass', 'marks = marks or {}'), evidence('Compass', 'return marks')]},
]
ownership = {(finding['from'], finding['to']): finding for finding in findings}


def diagram(pairs, nodes, findings_view=False):
    dot = ['digraph G { rankdir=LR; bgcolor="transparent"; graph [pad="0.2", nodesep="0.28", ranksep="0.55"];',
           'node [shape=box, style="rounded,filled", fillcolor="#19222e", color="#47576a", fontcolor="#e9eff6", fontname="Arial", fontsize=13, margin="0.14,0.1"];',
           'edge [color="#7994ac", arrowsize=0.65];']
    for name in sorted(nodes):
        dot.append(f'{json.dumps(name)} [URL={json.dumps("#" + name)}, tooltip={json.dumps(owners.get(name, "Playdate SDK"))}];')
    for a, b in sorted(pairs):
        style = ''
        if findings_view:
            finding = ownership[a, b]
            color = {'write': '#ffae80', 'borrow': '#c8adff', 'operation': '#88d7b0'}[finding['kind']]
            label = "\n".join(textwrap.wrap(finding["label"], width=18))
            style = f' [color="{color}", fontcolor="{color}", fontname="Arial", fontsize=11, label={json.dumps(label)}]'
        dot.append(f'{json.dumps(a)} -> {json.dumps(b)}{style};')
    dot.append('}')
    svg = subprocess.run(['dot', '-Tsvg'], input='\n'.join(dot), capture_output=True, text=True, check=True).stdout
    label = 'Reviewed ownership relationships; arrows point from caller to state owner' if findings_view else 'Named references only; not an ownership assessment'
    return svg[svg.index('<svg'):].replace('<svg ', f'<svg role="img" aria-label="{label}" ', 1)


data = {'nodes': {}, 'edges': [], 'findings': findings}
formatter = HtmlFormatter(nowrap=True)
for name, path in owners.items():
    colored = highlight(sources[path], LuaLexer(), formatter).splitlines()
    listing = '\n'.join(f'<span class="line" id="line-{i}"><span class="number">{i}</span>{row}</span>' for i, row in enumerate(colored, 1))
    neighbors = {pair for pair in edges if name in pair}
    concerns = {pair for pair in ownership if name in pair}
    data['nodes'][name] = {'path': path, 'code': listing,
                           'graph': diagram(neighbors, {name} | {n for pair in neighbors for n in pair}),
                           'ownershipGraph': diagram(concerns, {name} | {n for pair in concerns for n in pair}, True) if concerns else ''}
data['nodes']['playdate'] = {'path': 'Playdate SDK (external)', 'code': '', 'graph': diagram({pair for pair in edges if 'playdate' in pair}, {'playdate'} | {a for a, b in edges if b == 'playdate'})}
for (a, b), lines in sorted(edges.items()):
    data['edges'].append({'from': a, 'to': b, 'imported': (a, b) in imports,
                          'lines': [{'module': a, 'number': n, 'text': sources[owners[a]].splitlines()[n - 1]} for n in sorted(lines)]})
project_edges = {pair for pair in edges if pair[1] != 'playdate'}
template = Path(__file__).with_name('template.html').read_text()
page = template.replace('__DATA__', json.dumps(data).replace('<', '\\u003c'))
page = page.replace('__OWNERSHIP__', diagram(ownership, {n for pair in ownership for n in pair}, True))
page = page.replace('__FULL__', diagram(project_edges, names))
page = page.replace('__CSS__', formatter.get_style_defs('.source'))
page = page.replace('__COUNTS__', f'{sum(f["kind"] == "write" for f in findings)} outstanding outside-write relationships · {sum(f["kind"] == "operation" for f in findings)} resolved relationships · {sum(f["kind"] == "borrow" for f in findings)} shared-result relationships')
(ROOT / 'docs/dependencies.html').write_text(page)
print(f'Wrote docs/dependencies.html with {len(findings)} reviewed ownership relationships.')
print(f'{len(edges)} named edges; {len(imports)} import edges; {len(project_edges - imports)} project references without a direct import.')
