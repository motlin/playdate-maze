"""Rebuild docs/walkthrough.html: python3 tools/walkthrough/build.py (requires Pygments).

Source excerpts are selected by exact boundary text, never copied by hand. Every
excerpted file is also included in full, exceeding the requested 50 percent rule.
The output embeds its styles, scripts, syntax highlighting, and screenshots.
"""
from pathlib import Path
import base64
import hashlib
import html
import re
from pygments import highlight
from pygments.lexers import LuaLexer
from pygments.formatters import HtmlFormatter

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
files = {}
formatter = HtmlFormatter(nowrap=True)


def identity(name):
    return name.replace('/', '-').replace('.', '-')


def source(name):
    if name not in files:
        files[name] = (ROOT / 'source' / name).read_text()
    return files[name]


def listing(name, start=None, stop=None):
    content = source(name)
    begin = content.index(start) if start else 0
    end = content.index(stop, begin + len(start)) if stop else len(content)
    text = content[begin:end].rstrip('\n') + '\n'
    first = content[:begin].count('\n') + 1
    last = first + text.count('\n') - 1
    colored = highlight(text, LuaLexer(), formatter)
    colored = re.sub(r'<span class="(?:n|p|w)">([^<]*)</span>', r'\1', colored)
    rows = colored.rstrip('\n').split('\n')
    numbered = '\n'.join(f'<span class="line" data-line="{i}">{row}</span>' for i, row in enumerate(rows, first))
    label = f'Whole file · {last} lines' if start is None else f'Lines {first}–{last}'
    link = '' if start is None else f'<a href="#file-{identity(name)}">Read whole file ↗</a>'
    return f'<figure class="code"><figcaption><span>source/{name} <small>Lua · {label}</small></span>{link}</figcaption><pre tabindex="0" aria-label="Lua source from {name}"><code class="language-lua">{numbered}</code></pre></figure>'


def excerpt(name, start, stop=None):
    return listing(name, start, stop)


def image(name, alt):
    data = base64.b64encode((ROOT / 'docs/walkthrough-assets' / name).read_bytes()).decode()
    return f'<img width="400" height="240" src="data:image/png;base64,{data}" alt="{html.escape(alt)}">'


chapters = []

def chapter(anchor, title, eyebrow, body):
    chapters.append((anchor, title, f'<section id="{anchor}" class="chapter"><p class="eyebrow">{eyebrow}</p><h2>{title}</h2>{body}</section>'))


def question(prompt, answer):
    return f'<details class="question"><summary>Predict it: {prompt}</summary><p>{answer}</p></details>'


chapter('big-picture', 'One maze. Three ways to see it.', '01 / The big picture', '''
<p class="lead">A maze is a list of walls and spaces. A game adds a player and rules. A renderer turns those numbers into a picture.</p>
<p>That is the secret of this game: the first-person corridors, the rotating platformer, and the throwing slime all begin with the same kind of <strong>two-dimensional grid</strong>. We will start with the pieces you can name, then open them up until we reach the trigonometry that makes a wall look far away.</p>
<div class="screens">'''+ ''.join(f'<figure>{image(name, alt)}<figcaption><strong>{title}</strong><br>{caption}</figcaption></figure>' for name, alt, title, caption in [
('first-person.png','First-person maze with brick walls and a minimap','Explore','Walk inside a picture made from rays.'),
('tumble.png','Tumble maze rotated thirty degrees','Tumble','Turn the maze; gravity stays down the screen.'),
('slime.png','Slime aiming a dotted throw arc up and right','Slime','Aim a throw; predict where you will land.')])+'''
</div><p class="caption">Existing Playdate Simulator captures from this project, embedded so they travel with the document.</p>
<div class="flow"><div><b>INPUT</b>Buttons + crank</div><span>→</span><div><b>RULES</b>State + movement</div><span>→</span><div><b>PICTURE</b>Pixels + sound</div></div>
<p><strong>Read together:</strong> follow the pictures and try the “Predict it” questions. Stop after any chapter. <strong>Dig deeper:</strong> read the Lua excerpts and unfold the full files at the end. You do not need to memorize the code to understand the ideas.</p>
<table><thead><tr><th>Job</th><th>Where to look</th><th>What it owns</th></tr></thead><tbody>
<tr><td>Choose a screen</td><td>main.lua → SceneManager → scenes/</td><td>Title, play, escaped; read the Playdate controls</td></tr>
<tr><td>Describe the world</td><td>Maze, Player, Run</td><td>Walls, position, time, visited cells</td></tr>
<tr><td>Decide what happens</td><td>Game, Tumble, Slime, Puzzle</td><td>Movement, physics, shapes, escape</td></tr>
<tr><td>Draw it</td><td>Raycaster, MazeView, SideView, Minimap</td><td>Visibility, projection, geometry, map</td></tr>
<tr><td>Remember and respond</td><td>SaveGame, Sounds, Music</td><td>Save a run; turn events and proximity into audio</td></tr>
</tbody></table>
<div class="note"><b>A useful distinction</b><p>The maze has width and depth but no stack of floors. The first-person renderer gives its walls height. This is often called <em>2.5D</em>: a convincing 3D view built from a simpler 2D world.</p></div>''')

chapter('lua', 'Enough Lua to read the game', '02 / A small language toolkit', '''
<p>Read code like a recipe: names are ingredients, functions are instructions, and tables keep related things together. Comments beginning with <code>--</code> are notes for people.</p>
<table><thead><tr><th>Lua</th><th>Read it as</th></tr></thead><tbody>
<tr><td><code>local radius = 0.2</code></td><td>Give a nearby piece of code a name for a number.</td></tr>
<tr><td><code>{ x = 1.5, y = 1.5 }</code></td><td>A table with named entries; lists use entries numbered from 1.</td></tr>
<tr><td><code>player:turn(5)</code></td><td>Call a method with the player as its <code>self</code>.</td></tr>
<tr><td><code>#points</code></td><td>The length of a list.</td></tr>
<tr><td><code>points[#points + 1] = point</code></td><td>Add an entry to the end.</td></tr>
<tr><td><code>points[#points] = nil</code></td><td>Remove the last entry. <code>nil</code> means no value.</td></tr>
<tr><td><code>%</code> and <code>//</code></td><td>Remainder (wrap a direction) and floor division (count whole groups).</td></tr>
<tr><td><code>local value &lt;const&gt;</code></td><td>A local name that cannot be reassigned.</td></tr>
<tr><td><code>setmetatable(..., Player)</code></td><td>Let a new table find methods in Player through <code>__index</code>.</td></tr>
</tbody></table>
<p>Only <code>false</code> and <code>nil</code> count as false in Lua. <strong>Zero counts as true.</strong> This matters when distance zero means “we are at the exit.” Multiple return values also matter: <code>maze:blockAt(x, y)</code> returns both grid coordinates.</p>
''' + listing('SceneManager.lua') + '''
<p>This entire file is a tiny switchboard. Switching screens first lets the old scene leave, then lets the new one enter. Every update goes to exactly one current scene. The three dots pass along whatever arguments the new scene needs.</p>''')

chapter('frame', 'A game is a repeating conversation', '03 / One frame at a time', '''
<p>The game requests <strong>30 frames each second</strong>. On each frame the scene reads your controls, the rules update the world, and the view draws the result. At that rate each frame has about <strong>33.3 milliseconds</strong> available. Requesting 30 FPS does not prove the hardware always reaches it.</p>
''' + listing('main.lua') + '''
<p><code>playdate.update()</code> is the front door. The rest of this file imports the pieces, chooses the title screen, and saves a playable run at important lifecycle moments. The Playdate SDK supplies <code>playdate</code>; these modules supply the game.</p>
''' + excerpt('scenes/Play.lua','function PlayScene.update()') + '''
<p>Follow the order: controls → <code>game:update</code> → sounds and music → escape check → head bob → world → HUD. Drawing the HUD last keeps the map and messages on top. The world flip is handled inside MazeView, so the HUD stays upright.</p>
''' + excerpt('Game.lua','function Game:update(input)','Game.SAVE_VERSION') + '''
<p>The long method is a list of decisions. Autopilot, reeling the thread, and normal walking are separate branches. It then measures actual movement, emits sounds, records exploration, checks objects, and tests the exit. <code>Game.WALK_SPEED</code> is 0.08 blocks per frame: at 30 FPS, unobstructed forward movement is 2.4 blocks per second.</p>
<div class="note"><b>Rules and drawing can be tested separately</b><p>The game can update a player and a maze without drawing a single pixel. The host Lua specs exercise those rules. Playdate-facing graphics still need the Simulator or device.</p></div>
''' + question('You hold forward against a wall. Should footsteps keep playing?', 'No. The code adds the distance actually walked, not the requested movement. A blocked push can emit a bump instead.'))

chapter('grid', 'Build a world from squares', '04 / Coordinates and maze generation', '''
<p>Imagine graph paper. In this game <strong>x grows right</strong> and <strong>y grows down</strong>. A block is one unit wide. World positions can be fractions; Lua grid indices are whole numbers starting at 1.</p>
<div class="equation">gridX = floor(x) + 1 &nbsp; · &nbsp; gridY = floor(y) + 1</div>
<p>World position (1.5, 1.5) is the center of grid block (2, 2). Block (2, 2) covers x from 1 up to, but not including, 2, and the same for y. A <em>cell</em> is a room in the maze; blocks are the smaller squares used to build its floor and walls.</p>
''' + excerpt('Maze.lua','function Maze.new','-- random(n)') + '''
<p>With corridor width 1, cell (column, row) sits at grid (2 × column, 2 × row). A 3-by-2-cell maze needs a 7-by-5-block grid. Slime uses corridor width 3: the pitch becomes 4, leaving wider spaces to fly through. The constructor makes isolated rooms first.</p>
<h3>Carve, explore, backtrack</h3>
<p>Picture walking through unexplored rooms with a stack of sticky notes. Choose an unvisited neighbor, knock down the wall, and put the new room on the stack. If you get stuck, peel off the top note and return to the previous room.</p>
''' + excerpt('Maze.lua','function Maze.generate','-- The blocks of the wall') + '''
<ol><li><code>visited</code> remembers rooms already reached.</li><li><code>stack[#stack]</code> is the room we are exploring now.</li><li>Choose randomly from neighbors that are inside and unvisited.</li><li>Carve one passage and push that neighbor.</li><li>At a dead end, pop. Finish when the stack is empty.</li></ol>
<p>This is <strong>depth-first search with backtracking</strong>. Each new room gets exactly one connection to the already visited maze. No step connects two visited rooms, so no loops form. All rooms are reached: a <em>perfect maze</em> has exactly one route between any two cells. For N cells there are N − 1 internal carved connections.</p>
<div class="lab"><h3>Watch the stack work</h3><p>A tiny 4 × 3 teaching maze. Cyan is the current stack; gold is its tip. Step through carving and backtracking.</p><canvas id="maze-demo" width="720" height="310" role="img" aria-label="Step-by-step depth-first maze generation"></canvas><div class="controls"><button id="maze-step">Next step</button><button id="maze-reset">Start over</button><output id="maze-status" aria-live="polite"></output></div></div>
<p>The diagram is a small JavaScript teaching model of the algorithm, not the running Lua game. The source above is the real implementation.</p>
''' + question('Why can’t we carve into a room we already visited?', 'Doing so could join two existing paths into a loop. Skipping visited rooms is what gives this generator one route between each pair of rooms.'))

chapter('movement', 'Move a body, not a dot', '05 / Collision and sliding', '''
<p>The player’s position is the center of a square. Its radius is 0.2 blocks, so the body is 0.4 blocks wide. A proposed position is blocked if one of its four corners lands in a wall or closed door.</p>
''' + listing('Player.lua') + '''
<h3>Why move x, then y?</h3><p>Suppose you push diagonally into a vertical wall. The x movement hits the wall, but the y movement may still be safe. Testing the axes separately lets you <strong>slide along it</strong>. Rejecting the entire diagonal move would make you stick.</p>
<p><code>slide</code> first tries the destination. If it is blocked, it finds the relevant wall edge and places the body just short of it. The tiny <code>GAP</code> avoids rounding the resting body into the wall. The second axis uses the new x position.</p>
<div class="note"><b>A limit of this collision method</b><p>This checks positions, not every point along a very long motion. The game uses small steps; Tumble and Slime cap speed at 0.35 blocks per frame. Teleporting a body several blocks with this method could skip a wall.</p></div>
<h3>The first bit of trigonometry</h3>
<p>A direction is an arrow with two numbers. At angle θ, <strong>cos(θ)</strong> tells us its horizontal part and <strong>sin(θ)</strong> its vertical part. Lua’s trig functions take radians, so <code>math.rad</code> converts degrees first. Here, 90° points down because y grows down.</p>
<div class="equation">forward = (cos θ, sin θ)<br>right = (−sin θ, cos θ)<br>movement = forward × walking + right × strafing</div>
<div class="lab"><h3>Turn the direction arrow</h3><label for="angle">Heading <output id="angle-label">35°</output></label><input id="angle" type="range" min="0" max="360" value="35"><canvas id="trig-demo" width="720" height="300" role="img" aria-label="Direction vector with cosine and sine components"></canvas><p id="trig-values" class="readout"></p></div>
<table><thead><tr><th>Angle</th><th>Forward vector</th><th>Direction</th></tr></thead><tbody><tr><td>0°</td><td>(1, 0)</td><td>East / right</td></tr><tr><td>90°</td><td>(0, 1)</td><td>South / down</td></tr><tr><td>180°</td><td>(−1, 0)</td><td>West / left</td></tr><tr><td>270°</td><td>(0, −1)</td><td>North / up</td></tr></tbody></table>
''' + question('At 90°, what happens when you strafe right?', 'You move west: right = (−1, 0). “Right” is relative to the player, not always the right edge of the map.'))

chapter('algorithms', 'Three different ways to find your way', '06 / Search, navigation, and memory', '''
<h3>1. Breadth-first search: send a ripple from the exit</h3>
<p>A room may look close to the exit through a wall but require a long walk. <code>ExitDistance</code> measures corridor distance. Start with zero at the exit’s cell, put its neighbors at one, their unvisited neighbors at two, and keep going.</p>
''' + listing('ExitDistance.lua') + '''
<p>The <strong>queue</strong> processes the oldest waiting room first. This explores distance layers, unlike the stack used to generate the maze. Moving <code>head</code> avoids shifting the entire list. Because every cell-to-cell passage costs one step, the first assigned distance is the shortest.</p>
<p>The key <code>(row − 1) * columns + column</code> gives each room one list position. A 4-column maze’s second row has keys 5, 6, 7, 8. The exit’s distance is zero, which is truthy in Lua, so it stays marked as visited. Music uses the resulting proximity to respond to progress through corridors.</p>
<h3>2. Autopilot: keep your left hand on the wall</h3>
''' + listing('Autopilot.lua') + '''
<p>At a cell center, try left, ahead, right, then back. Turn toward the chosen direction before walking to the next center. This wall-following rule is suited to the game’s tree-shaped maze; it is not a general shortest-path planner.</p>
<p>The turning expression wraps differences into [−180°, 180°). From 350° to 10°, it asks for +20°, not a long −340° spin. At an exact half-turn it chooses −180°.</p>
<h3>3. Thread: keep a trail you can unwind</h3>
''' + listing('Thread.lua') + '''
<p>The thread samples a point roughly every quarter block. If you move closer to the previous point, it removes the newer end of the trail. Reeling consumes whole segments until only part of the next one is needed, then uses a fraction to stop between its ends.</p>
<div class="equation">new position = current + (target − current) × share</div>
<p><code>share = distance / stretch</code>. If you reel 0.1 blocks along a 0.25-block segment, share is 0.4. <code>math.atan(y, x)</code> recovers the segment’s angle, and <code>math.deg</code> converts radians back to degrees. The 800-point cap means very old trail points are eventually forgotten.</p>
''' + question('Would the left-hand autopilot always choose the shortest route?', 'No. It follows a local preference and may visit dead ends. Breadth-first search is the method here that computes shortest corridor distances.'))

chapter('physics', 'Turn the maze. Throw the slime.', '07 / 2D physics and reusable math', '''
<h3>Tumble: keep gravity down the screen</h3>
<p>Tumble stores positions and velocities in maze coordinates. The camera rotates that maze for drawing. So “down the screen” must be converted back into the maze’s coordinates before adding gravity.</p>
''' + excerpt('Tumble.lua','function Tumble:update(input)') + '''
<p>At maze angle 0°, down = (0, 1). At 90°, down = (1, 0): screen gravity now pulls east through the maze. The right vector is (cos θ, −sin θ). This is the <strong>inverse rotation</strong> of the view.</p>
<p>The dot product <code>velocityX * rightX + velocityY * rightY</code> measures how much velocity points right. Walking adjusts only that component. Jumping replaces the downward component with an upward jump speed. Gravity adds 0.012 blocks per frame to downward velocity.</p>
''' + excerpt('SideView.lua','function SideView.toScreen','local toScreen') + '''
<p>Drawing goes the other way: subtract the player’s position, rotate the offset, scale blocks into pixels, and add screen center (200, 120). The player stays centered while the maze moves around them.</p>
<h3>Slime: predict a throw by rehearsing it</h3>
<p>Slime’s crank angle uses a different zero: <strong>0° aims up</strong>, 90° right. That gives a launch vector of (sin θ, −cos θ) times throw speed. Every flight step adds gravity to vertical velocity, limits speed, and reuses Player’s collision.</p>
''' + excerpt('Slime.lua','local function throwVelocity','local function stick') + '''
<p><code>arc()</code> moves a spare Player called <code>scout</code> using the <em>same</em> <code>fly</code> function as the real slime. It keeps a dot every three frames and stops at a collision, or after 240 simulated frames. The preview and actual flight therefore agree when they start from the same position and angle in the same maze. The grip clock keeps running while aiming, so the launch position can still change.</p>
<p>The speed is <code>sqrt(2 * gravity * 4)</code>, about 0.310 blocks per frame. The continuous-motion formula h = v²/(2g) suggests a four-block rise. This implementation adds gravity before moving in discrete frames, so an unobstructed straight-up throw peaks a little lower, about 3.85 blocks.</p>
<div class="flow"><div><b>RESTING</b>Safe on a floor</div><span>↔</span><div><b>FLYING</b>No mid-air throw</div><span>↔</span><div><b>CLINGING</b>30 frames of grip</div></div>
<p>A wall grip runs out into <strong>SLIDING</strong>; a ceiling grip runs out into falling. These named states keep the movement rules explicit. The full Slime file includes the transitions and input handling.</p>
''' + question('Why not draw the aiming arc with an unrelated parabola formula?', 'A separate formula could disagree with the game’s per-frame gravity, speed cap, and wall collisions. Reusing fly makes the preview obey the same rules.'))

chapter('puzzle', 'Objects have states, too', '08 / Shapes, fog, and the gate', '''
<p>The shape puzzle is a small state machine: a shape is on the <strong>GROUND</strong>, <strong>CARRIED</strong>, or <strong>PLACED</strong>. A successful pickup changes its state and remembers which shape is in your hands.</p>
''' + excerpt('Puzzle.lua','function Puzzle:pickUp','local function isOccupied') + excerpt('Puzzle.lua','function Puzzle:drop','-- What is needed to build') + '''
<p>Dropping first checks for the carried shape’s matching empty pedestal within reach. Otherwise it tries the player’s current block. Finishing the last pedestal <em>unlocks</em> the first-person gate; it still needs two full forward crank turns to raise. Tumble and Slime collect shapes on contact and open the exit when all three are collected.</p>
''' + excerpt('Run.lua','function Run:visit()','function Run:say') + '''
<p>Fog of war is another memory table: entering a cell marks its key. The minimap’s background can be reused until exploration or the exit changes. Its position conversion is a scale and an offset:</p>
''' + excerpt('Minimap.lua','local function toMap','local function isRevealed') + '''
<p>Compare this with SideView’s rotated coordinates. Both turn world positions into screen positions, but the minimap keeps north at the top. The first-person view needs one extra operation: dividing by depth.</p>''')

chapter('rays', 'Send out rays to find the walls', '09 / From a flat map to a 3D view', '''
<p>Imagine sending a thin measuring beam through each narrow strip of the screen. For every beam, ask: <strong>which wall does it hit first, and how far ahead is that wall?</strong> Nearby walls become tall strips; far walls become short ones.</p>
<h3>First build a camera</h3>
<div class="equation">forward = (cos θ, sin θ)<br>plane = (−sin θ, cos θ) × tan(FOV / 2)<br>cameraX = 2 × screenX / width − 1<br>ray = forward + plane × cameraX</div>
<p><code>cameraX</code> runs from −1 at the left edge through 0 at the center to +1 at the right edge. The camera plane is perpendicular to forward. For a 70° field of view, its half-width at one unit forward is tan(35°) ≈ 0.700.</p>
''' + excerpt('Raycaster.lua','function Raycaster.scan','    local runCount') + '''
<h3>DDA: skip straight to the next grid boundary</h3>
<p>A slow ray marcher might take hundreds of tiny steps. This game uses <strong>digital differential analysis (DDA)</strong>: work out when the ray next crosses a vertical or horizontal grid line, then choose whichever crossing comes first.</p>
''' + excerpt('Raycaster.lua','function Raycaster.cast','-- Reused between frames') + '''
<p>Write the ray as position + t × direction. <code>deltaX = abs(1 / directionX)</code> is the increase in t between successive vertical boundaries. <code>deltaY</code> does the same for horizontal boundaries. A zero component gets infinity: a horizontal ray never crosses a horizontal grid line.</p>
<ol><li>Calculate the first boundary times.</li><li>Pick the smaller time and enter that neighboring block.</li><li>Add that axis’s delta to schedule its next boundary.</li><li>If the block is nonzero, return the hit.</li></ol>
<p>Notice the subtraction at the end: the boundary time was already advanced, so the hit time is <code>sideDistance − delta</code>. The renderer stops at every non-OPEN value, including EXIT. Collision allows EXIT; drawing paints it as white light. These are different questions about the same block.</p>
<div class="lab"><h3>A map and its first-person picture</h3><p>Turn in a small teaching room. Gold is the selected ray; cyan rays explain the rest of the view. Each selected ray visits whole grid cells.</p><label for="view-angle">Camera heading <output id="view-angle-label">0°</output></label><input id="view-angle" type="range" min="0" max="359" value="0"><label for="ray-column">Selected screen column <output id="ray-column-label">200</output></label><input id="ray-column" type="range" min="0" max="400" value="200"><canvas id="ray-demo" width="800" height="320" role="img" aria-label="Top-down ray traversal beside a matching first-person wall projection"></canvas><p id="ray-values" class="readout"></p><p class="caption">JavaScript teaching model: fixed map, colored columns, no bricks or sprites. The Lua renderer groups columns into wall faces, as the next chapter explains.</p></div>
<h3>Why the walls do not bulge: perpendicular depth</h3>
<p>The ray above is intentionally <strong>not normalized</strong>. Forward has length 1, and the plane is perpendicular to it. Therefore the dot product of forward with the ray is 1. At a hit, offset = t × ray, so forward depth = dot(offset, forward) = t. DDA’s returned parameter is already the depth the projection needs.</p>
<p>For a flat wall straight ahead, every ray has the same forward depth, even though the edge rays travel farther diagonally. Using diagonal travel distance would shrink the wall at the edges: the “fisheye” error.</p>
''' + question('A ray points exactly east. What is deltaY?', 'Infinity. Its y component is zero, so it never crosses a horizontal grid boundary. Only the x crossings advance.'))

chapter('projection', 'Distance becomes height', '10 / Perspective and trigonometry', '''
<p>Hold your hand near your face, then move it away. The hand stays the same size, but it covers less of your view. A renderer needs to recreate that relationship.</p>
<div class="equation">projection = (screen width / 2) / tan(FOV / 2)<br>wall height in pixels = projection / depth<br>top = horizon − height / 2 &nbsp; · &nbsp; bottom = horizon + height / 2</div>
<p>For this game: width = 400, FOV = 70°, and projection ≈ 285.63 pixels per block at depth 1. A one-block wall at depth 2 is about 142.81 pixels tall; at depth 4 it is about 71.41. Twice as far means half as tall.</p>
<div class="lab"><h3>Move a wall away</h3><label for="depth">Wall depth in blocks <output id="depth-label">2.0</output></label><input id="depth" type="range" min="1" max="10" step="0.1" value="2"><canvas id="projection-demo" width="720" height="290" role="img" aria-label="A wall shrinking with distance around the horizon"></canvas><p id="projection-values" class="readout"></p></div>
<h3>Project a shape into the same picture</h3>
''' + excerpt('Raycaster.lua','function Raycaster.project') + '''
<p>First subtract the camera position. Two dot products measure <strong>depth</strong> along forward and <strong>sideways</strong> along right. Reject a point with depth ≤ 0; it is behind the camera or exactly on the camera plane. Divide sideways by depth to get its apparent direction, then map that to screen pixels.</p>
<p>Example: camera (1.5, 1.5), facing east; object (3.5, 2.0). Offset is (2, 0.5), depth is 2, sideways is 0.5. Its screen x is 200 × (1 + 0.5 / (2 × 0.7002)) ≈ <strong>271.4</strong>. It appears to the right of center, exactly as the map suggests.</p>
<div class="note"><b>Where tangent comes from</b><p>In a right triangle, tan(angle) = opposite / adjacent. At half the field of view, the opposite side is half the camera plane’s width and the adjacent side is one unit forward. That is why tan(FOV / 2) sets the plane scale. Sine and cosine aim the camera; tangent controls its spread.</p></div>
''' + question('If you double both an object’s sideways offset and its depth, does its screen x change?', 'No. The ratio sideways / depth stays the same. It lies along the same viewing direction, although its drawn size becomes smaller.'))

chapter('pixels', 'Make the picture affordable', '11 / Runs, dithering, and hidden objects', '''
<h3>Group rays that see the same wall face</h3>
<p>The screen is 400 pixels wide, and the sampling column is 4 pixels wide: <strong>100 depth samples</strong>. The scan also casts at the left and right edges and adds two refinement casts at each detected face change. It is more than 100 ray casts in total.</p>
''' + excerpt('Raycaster.lua','    local runCount','-- Where a point in the world') + '''
<p>A <em>run</em> groups consecutive samples that hit the same face of the same block. The face key includes block x, block y, and whether the crossed boundary was vertical or horizontal. When a key changes, bisection halves the gap twice to better locate the edge.</p>
<p>The two ends tell the renderer the wall’s top and bottom at each side. Straight edges in the world project to straight edges, so one trapezoid can fill the face. The tables for runs and depths are reused across frames, reducing garbage-collection work. This is still sampled visibility: a very thin third face can be folded into a run boundary, as the code’s comment explains.</p>
''' + excerpt('MazeView.lua','local function drawRun','-- The game\'s frame count') + '''
<h3>Gray made from black and white</h3>
<p>Playdate’s screen is 1-bit: a pixel is black or white. The walls look gray because of <strong>ordered dithering</strong>. The 4 × 4 Bayer matrix decides which pixels turn white at each brightness level. Level 8 lights half the pixels; level 16 lights all of them.</p>
''' + listing('Shades.lua') + '''
<div class="lab"><h3>Mix black and white pixels</h3><label for="shade">Dither level <output id="shade-label">8 / 16</output></label><input id="shade" type="range" min="0" max="16" value="8"><canvas id="shade-demo" width="720" height="190" role="img" aria-label="Enlarged Bayer pixels and a small repeated dither swatch"></canvas><p id="shade-values" class="readout"></p></div>
<p><code>drawRun</code> darkens distant walls and makes x-facing walls a little darker to clarify corners. Brick courses disappear below 40 pixels of wall height; the vertical joints disappear below 80. The background floor and ceiling are cached bands, not full per-pixel textured floor casting.</p>
<h3>Hide shapes behind walls</h3>
''' + excerpt('MazeView.lua','local function clipToVisibleColumns','local function drawSprite') + '''
<p>The scan’s depth array acts like a ruler behind each 4-pixel strip. An object is visible where its depth is less than the wall’s. Sprites are sorted farthest first so nearer ones paint over farther ones.</p>
<div class="note"><b>Read what the code does, not just its intention</b><p>This clipping function finds the first and last visible columns and uses one rectangular clip between them. It does not make separate clips for separated visible islands. If a nearer wall hides a middle strip but both sides are visible, the rectangle can include that hidden strip. It is an approximation, not a full per-pixel depth buffer.</p></div>
''' + excerpt('MazeView.lua','local function drawScene','-- Where the scene is drawn') + '''
<p>The final order is background → wall runs → floor/ceiling marks → sorted sprites. MazeView can draw the result into an image and flip it vertically. The scene then draws the HUD separately.</p>''')

chapter('experiments', 'Be the game designer', '12 / Try it, explain it, change it', '''
<p>Before editing, make a prediction. Change one thing, run the game, and compare what happened with what you expected. These are experiments to try later; the walkthrough does not change the game’s rules.</p>
<table><thead><tr><th>Experiment</th><th>Where</th><th>Prediction to discuss</th></tr></thead><tbody>
<tr><td>Change walking speed from 0.08 to 0.04</td><td>Game.WALK_SPEED</td><td>How long should the same straight walk take?</td></tr>
<tr><td>Try a field of view of 50° or 90°</td><td>MazeView.SCREEN</td><td>Does the same wall look larger or smaller?</td></tr>
<tr><td>Change columnWidth from 4 to 2</td><td>MazeView.SCREEN</td><td>Twice as many base depth samples. What happens near narrow edges?</td></tr>
<tr><td>Prefer right before left</td><td>Autopilot.PREFERENCE</td><td>Does the route change? Does it become shortest?</td></tr>
<tr><td>Change gravity</td><td>Slime.GRAVITY</td><td>THROW_SPEED also depends on gravity. Which aspects of the jump remain similar?</td></tr>
</tbody></table>
<h3>How this project checks its ideas</h3>
<p><code>spec/Maze_spec.lua</code> exercises maze structure; <code>spec/Player_spec.lua</code> checks movement and collisions; <code>spec/Raycaster_spec.lua</code> checks casting and projection; <code>spec/Slime_spec.lua</code> checks flight and preview behavior. Host specs test numbers and rules. The screenshot harness runs the Playdate drawing and scene code in the Simulator.</p>
<p>The local recipes are <code>just test</code> for host specs, <code>just lint</code> for Lua checks, and <code>just build</code> for the Playdate compiler. <code>just smoke</code> drives Simulator scenarios. None of those substitutes for measuring performance and controls on the handheld.</p>
<div class="note"><b>Trace one step all the way through</b><p>You press up. PlayScene sets <code>input.forward</code>. Game scales it into blocks per frame. Player rotates it with sine and cosine, then checks the walls. Raycaster sees the world from the new position. MazeView divides by depth and paints the next picture. One button press has become geometry.</p></div>
<h3>A pocket glossary</h3><dl><dt>State</dt><dd>The facts the game remembers right now.</dd><dt>Vector</dt><dd>An arrow described by components, such as (x, y).</dd><dt>Dot product</dt><dd>Multiply matching components and add; with a unit direction, it measures the amount along that direction.</dd><dt>Projection</dt><dd>Turning a world position into a screen position.</dd><dt>Stack / queue</dt><dd>Newest-first / oldest-first ways to process waiting work.</dd><dt>Depth</dt><dd>How far forward something lies in camera coordinates.</dd><dt>Occlusion</dt><dd>A nearer thing hiding a farther thing.</dd></dl>''')

appendix = '<p>Every file quoted in the chapters is included below in full, even when the excerpt is less than half. No omitted middle sections. The snippets are exact slices of these source files; line numbers match this snapshot.</p><div class="source-index">'
for name in files:
    appendix += f'<a href="#file-{identity(name)}">{name}</a>'
appendix += '</div>'
for name, content in list(files.items()):
    digest = hashlib.sha256(content.encode()).hexdigest()[:12]
    appendix += f'<details class="full-source" id="file-{identity(name)}"><summary>{name} <small>{len(content.splitlines())} lines · SHA-256 {digest}</small></summary>{listing(name)}</details>'
chapter('source', 'The complete source shelf', '13 / All the way down', appendix)

navigation = ''.join(f'<a href="#{anchor}"><span>{i:02d}</span>{title}</a>' for i, (anchor, title, _) in enumerate(chapters, 1))
body = ''.join(content for _, _, content in chapters)
page = (HERE / 'template.html').read_text().replace('<!-- NAVIGATION -->', navigation).replace('<!-- CHAPTERS -->', body)
(ROOT / 'docs/walkthrough.html').write_text(page)
print(f'Built docs/walkthrough.html: {len(files)} complete Lua files, {len(page.encode()):,} bytes')
