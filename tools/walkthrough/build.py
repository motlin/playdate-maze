"""Build docs/walkthrough.html with python3 tools/walkthrough/build.py (Pygments required).

Every panel contains its complete Lua file. Step anchors resolve against unique
source text so edits cannot silently shift the annotations onto unrelated lines.
"""
from pathlib import Path
import html
import re
from pygments import highlight
from pygments.lexers import LuaLexer
from pygments.formatters import HtmlFormatter

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
formatter = HtmlFormatter(nowrap=True)
sections = []
LABS = {
    'Maze.lua': ('maze', 'Watch the stack work', 'Step through carving and backtracking. Cyan marks the current stack; gold marks its last cell.'),
    'Player.lua': ('movement', 'Direction and angle', 'Change the heading. Compare the forward vector with its horizontal and vertical components.'),
    'Raycaster.lua': ('rays', 'Ray traversal', 'Turn the camera and select a ray. Change the field of view, then compare grid crossings and distances. “Face a flat wall” makes the fisheye error easy to see. Cyan marks the camera plane.'),
    'MazeView.lua': ('projection', 'Wall height and distance', 'Double the depth to halve the projected height.'),
    'Shades.lua': ('shading', 'Dither thresholds', 'Change the shade level. Compare the enlarged matrix with the resulting black-and-white pattern.'),
}



def step(anchor, count, title, text):
    return anchor, count, title, text


def section(name, title, steps):
    source = (ROOT / 'source' / name).read_text()
    rows = source.splitlines()
    annotations = []
    section_index = len(sections) + 1
    for index, (anchor, count, heading, text) in enumerate(steps):
        assert source.count(anchor) == 1, (name, anchor)
        first = source[:source.index(anchor)].count('\n') + 1
        last = first + count - 1
        assert last <= len(rows), (name, last)
        annotations.append(f'''<article class="step" id="step-{section_index}-{index}" data-first="{first}" data-last="{last}">
<p class="location">source/{name}<br><a href="#step-{section_index}-{index}">Lines {first}–{last}</a></p>
<h3>{heading}</h3>{text}</article>''')
    colored = highlight(source, LuaLexer(), formatter)
    colored = re.sub(r'<span class="(?:n|p|w)">([^<]*)</span>', r'\1', colored)
    lines = '\n'.join(f'<span class="line" data-line="{index}">{row}</span>' for index, row in enumerate(colored.rstrip('\n').split('\n'), 1))
    folder = 'source/' + (name.rsplit('/', 1)[0] + '/' if '/' in name else '')
    filename = name.rsplit('/', 1)[-1]
    initial_first = source[:source.index(steps[0][0])].count('\n') + 1
    initial_last = initial_first + steps[0][1] - 1
    panel = f'''<div class="code-panel"><header class="file-header"><div class="file-path"><span>{folder}</span><strong>{filename}</strong></div><div class="file-meta"><span>Lua · Complete file · {len(rows)} lines</span><output class="range">Lines {initial_first}–{initial_last}</output></div></header>
<pre tabindex="0" aria-label="Complete source/{name}"><code class="language-lua">{lines}</code></pre>
<footer class="code-footer"><span class="focus-label">Highlighted lines follow the explanation</span><button class="follow" type="button" aria-pressed="true">Follow scroll: on</button></footer></div>'''
    markup = f'''<section class="section" id="section-{section_index}" data-title="{html.escape(title)}" data-file="source/{name}"><div class="explanations"><h2><span>{section_index:02d}</span> {title}</h2>{''.join(annotations)}</div>{panel}</section>'''
    if name in LABS:
        identifier, lab_title, explanation = LABS[name]
        lab = (HERE / (identifier + '.html')).read_text()
        markup += f'<section class="lab-section" id="lab-{identifier}"><div class="lab-intro"><p class="location">source/{name} · Interactive model</p><h2>{lab_title}</h2><p>{explanation}</p></div>{lab}</section>'
    if name == 'MazeView.lua':
        lab = (HERE / 'occlusion.html').read_text()
        markup += f'<section class="lab-section" id="lab-occlusion"><div class="lab-intro"><p class="location">source/MazeView.lua · clipToVisibleColumns</p><h2>Which columns hide the sprite?</h2><p>Move a sprite behind a nearer wall. Compare testing each column with the game’s single clipping rectangle.</p><p>This reduced model has 16 columns. The real game samples 100. The sprite’s screen width is held fixed to isolate visibility.</p></div>{lab}</section>'
    sections.append((name, title, markup))


section('main.lua', 'Game structure', [
    step('playdate.update = SceneManager.update', 1, 'One update per frame', '<p>Playdate calls <code>playdate.update()</code> every frame.</p><p>What happens each frame depends on where we are: the title screen, the first-person maze, Tumble, or Slime. We call each of these a <em>scene</em>. We created <code>SceneManager</code> to keep track of the current scene and call its update function.</p><p>This assignment registers <code>SceneManager.update</code> as Playdate’s update callback. Without parentheses, it assigns the function rather than calling it.</p><p>SceneManager is imported before registration. Switching scenes changes the current scene used by that function, so the same callback keeps dispatching to the active scene.</p>'),
    step('playdate.gameWillPause =', 1, 'Delegate pause to the scene manager', '<p>Register <code>SceneManager.pause</code> as the Playdate pause callback. It saves the active scene before calling that scene’s optional pause hook. Audio shutdown belongs to the scenes that play it.</p><p>Sleep, lock, and termination callbacks below continue to use <code>SceneManager.save</code>.</p>'),
    step('SceneManager.onSwitch =', 2, 'Start at the title screen', '<p>The first line stores <code>SystemMenu.refresh</code> as the callback to run after each scene switch. Without parentheses, it passes the function rather than calling it.</p><p>The second line calls <code>SceneManager.switch(TitleScene)</code>: select the title scene, call its <code>enter()</code> function, then refresh the system menu through that callback.</p><p>Next, where does <code>TitleScene</code> come from?</p>'),
    step('import "scenes/TitleScene"', 1, 'Load the title-screen file', '<p>Earlier in <code>source/main.lua</code>, this import loads the title scene before the startup calls run.</p><p>Playdate’s <code>import</code> runs <code>source/scenes/TitleScene.lua</code> once. Later imports of the same file do nothing.</p><p>Lua lets a call omit parentheses around a single string argument: <code>import "scenes/TitleScene"</code> is equivalent to <code>import("scenes/TitleScene")</code>.</p><p>Standard Lua uses <code>require</code>; <code>import</code> is supplied by Playdate. This game uses it to load files that define shared globals.</p><p>Next, in <code>source/scenes/TitleScene.lua</code>, we’ll see the assignment that creates <code>TitleScene</code>.</p><p><a href="https://sdk.play.date/Inside%20Playdate.html#_structuring_your_project">SDK reference: imports</a></p>'),
])
section('scenes/TitleScene.lua', 'The imported scene', [
    step('TitleScene = { selection = 1', 1, 'Create the shared scene table', '<p>This assignment creates the global <code>TitleScene</code> because there is no <code>local</code>. After the import runs, <code>source/main.lua</code> can pass this table to <code>SceneManager.switch</code>.</p><p>The assignment creates the name, not the filename. The table initially holds the selected row, maze-size index, and menu rows.</p>'),
    step('local controls = PlayInput.new()', 1, 'Keep a private input reader', '<p>Each scene owns a local <code>PlayInput</code> reader. Hardware polling stays in that shared module; the reader is private to this scene.</p>'),
    step('    local input = controls:read()', 6, 'Read once, interpret the menu', '<p><code>controls:read()</code> captures one hardware snapshot for this frame. <code>input.crankChange</code> feeds <code>CrankSteps</code>, while <code>input:isPressed</code> checks button edges from the same snapshot.</p><p>The scene still interprets menu actions: D-pad presses override crank movement and reset partial turns. After navigation clamps the highlight to a valid row, the scene resolves that row for left, right, and confirmation actions. A simultaneous turn and A therefore confirms the newly highlighted entry.</p>'),
])
section('SceneManager.lua', 'Scene changes', [
    step('function SceneManager.switch(scene, ...)', 6, 'Exit, replace, enter', '<p>Let the old scene clean up, replace <code>currentScene</code>, then initialize the new scene. The <code>...</code> passes its arguments through.</p>'),
    step('function SceneManager.update()', 1, 'Call the current scene', '<p>Only one scene receives updates. In first-person play, this calls <code>FirstPersonScene.update()</code> in <code>source/scenes/FirstPersonScene.lua</code>.</p>'),
    step('function SceneManager.save()', 3, 'Save through the scene', '<p>If the current scene provides <code>save()</code>, call it. Before a scene is selected, or in a scene without a save hook, do nothing.</p><p><code>FirstPersonScene.save()</code> decides whether to store a run through <code>SaveGame</code>; <code>EditorScene.save()</code> keeps editor persistence separate. SceneManager does not choose a disk format or persistence policy.</p>'),
    step('function SceneManager.pause()', 4, 'Save, then pause the active scene', '<p>Reuse the save dispatch first, then call the current scene’s optional <code>pause()</code> hook. No scene, or no hook, is safe. The current scene remains selected; SceneManager knows nothing about audio.</p>'),
])
section('scenes/FirstPersonScene.lua', 'First-person scene', [
    step('    SUBMODES =', 1, 'Three first-person submodes', '<p>Explore, Daily, and Screensaver share this scene and its 3D maze rules. Daily fixes the maze seed and size; Screensaver starts on autopilot without the puzzle. Tumble and Slime use separate scenes.</p>'),
    step('local controls = PlayInput.new()', 2, 'Create the input reader and action mapper', '<p><code>PlayInput</code> reads hardware. <code>WalkingActions.new(controls)</code> connects a mapper to that reader. The mapper translates its snapshot into movement and item actions and owns the button history.</p>'),
    step('    walkingActions = WalkingActions.new(controls)', 3, 'Reset transient state on entry', '<p>Fresh and resumed runs get a new walking mapper, dock timer, and head bob. The mapper keeps the existing controls reader but forgets button history from the previous visit, including B released in another scene.</p>'),
    step('    local input = controls:read()', 6, 'Read, map, update', '<p>Read one hardware snapshot. <code>dockTimer:update</code> returns a handover action; <code>FirstPersonScene.applyDockAction</code> applies it to the scene’s game. Then map the snapshot into walking actions.</p><p><code>takingOver</code> tells the mapper to consume item actions from the takeover press. The game receives only the resulting action table.</p>'),
    step('function FirstPersonScene.restart()', 9, 'Discard the run when restarting', '<p>A resumed custom run has no original drawing to restart. Switch to My mazes first so the outgoing exit hook finishes saving, then delete that save. The title will no longer offer Continue. Ordinary exits and pauses still save the run.</p><p>Other puzzle restarts delete the old save before generating the next maze; the screensaver leaves saves alone.</p>'),
    step('function FirstPersonScene.pause()', 4, 'Stop held audio for the system menu', '<p>Stop the shape hums and music so held notes cannot drone behind the system menu. Leaving the scene saves the run and reuses this pause hook. Tumble and Slime stop their music in their own pause and exit hooks; they do not play shape hums.</p><p>Returning from the system menu keeps the same run. The existing per-frame sound and music updates resume playback without a new restart callback.</p>'),
    step('    Sounds.play(game.events)', 18, 'Draw the result', '<p>Play sounds, check for escape, then draw the world and HUD. Drawing the HUD last keeps it above the 3D image.</p><p><code>distanceWalked</code> drives head bob from actual travel.</p>'),
])
section('PlayInput.lua', 'Shared hardware input', [
    step('function PlayInput:read()', 7, 'Capture one frame', '<p>The three play modes use this reader. It records held, pressed, and released buttons, crank movement, crank angle, and whether the crank is docked.</p><p>These are hardware readings; their meaning depends on the game mode.</p>'),
    step('function PlayInput:isDown(button)', 1, 'Test a button bit', '<p>Each button has its own bit in the mask. <code>&amp;</code> keeps the bits shared by the mask and the requested button. A nonzero result means that button is down.</p>'),
    step('function PlayInput:axis(', 3, 'Combine opposite directions', '<p>Subtract the negative button from the positive button. Left alone gives −1, right alone gives +1, and both or neither gives 0.</p>'),
])
section('WalkingActions.lua', 'Walking actions', [
    step('function WalkingActions.new(controls)', 3, 'Own the button history', '<p>The constructor stores the supplied <code>controls</code> reader. Each mapper owns its <code>TapOrReel</code> tracker. Reads return fresh actions unless the scene explicitly supplies its reusable output table. The tracker distinguishes tapping B from holding B while reeling.</p>'),
    step('    actions.forward =', 12, 'Map hardware to actions', '<p>Up/down moves forward/back. The crank turns the view unless B is held. Left/right turns when docked and strafes when undocked.</p><p><code>crank</code> preserves actual crank movement for the gate; D-pad turning does not operate it.</p>'),
    step('    if suppressItemActions then', 4, 'Consume the takeover press', '<p>Suppress pickup, drop, and reel for this frame. Tell the B tracker to ignore the rest of this press too, so releasing it later cannot drop an item.</p>'),
])
section('TumbleActions.lua', 'Tumble actions', [
    step('    actions.turn =', 3, 'Map the same controls for Tumble', '<p>Crank movement rotates the maze. Left/right moves the player. A, B, or up starts a jump on a fresh press.</p>'),
])
section('SlimeActions.lua', 'Slime actions', [
    step('    actions.aim =', 4, 'Map the same controls for Slime', '<p>Crank angle sets aim, holding A keeps aiming, and a fresh B press cancels. Left/right moves along a surface.</p>'),
])
section('Game.lua', 'First-person rules', [
    step('function Game.new(options)', 9, 'Create the world', '<p>Generate a maze, place the player in its first cell, and combine them in a <code>Run</code>. Face an open passage at the start.</p><p>A Lua table holds state; <code>setmetatable</code> lets it find the module’s methods.</p>'),
    step('    if self.autopilot then\n        self.autopilot:update()', 15, 'Choose one movement mode', '<p>Autopilot, thread reeling, and manual movement are exclusive branches. Manual movement scales input by <code>Game.WALK_SPEED</code>: 0.08 blocks per frame.</p><p><code>player:move(...)</code> passes the player as <code>self</code>. The colon marks a method call.</p>'),
    step('    local walkedX, walkedY', 12, 'Measure what moved', '<p>Subtract the old position and use √(dx² + dy²) for distance. Footsteps follow actual travel; a blocked push can produce a bump.</p>'),
    step('    self:visit()\n    if self.flippers', 11, 'Check interactions', '<p>Record the visited cell, handle flippers and shapes, then check whether the player entered the exit block.</p><p>The drawing code reads this state after the update.</p>'),
])
section('scenes/EditorScene.lua', 'Editor screen', [
    step('function EditorScene.play()', 5, 'Ask the editor whether the drawing can play', '<p><code>designToPlay()</code> returns a playable drawing or records the reason play is blocked. The scene handles navigation without writing the editor’s message or save state.</p>'),
    step('function EditorScene.randomMaze()', 1, 'Request a complete editing transition', '<p>The scene requests a new maze. MapEditor owns replacing the drawing, resetting the cursor and tool, and recording the change.</p>'),
])
section('MapEditor.lua', 'Editing state belongs together', [
    step('function MapEditor:generateMaze(random)', 6, 'Replace the drawing and reset the tools', '<p>Generate a maze at the current size and convert it to a drawing. Use the same cursor initialization as a newly opened drawing: select the cells tool and snap to the cell nearest the entrance without moving the design’s start. Record the message and unsaved change in the same operation.</p>'),
    step('function MapEditor:designToPlay()', 8, 'Explain a blocked play attempt', '<p>Validation can update the action message without marking the drawing dirty. A valid drawing is returned for play; only saving clears the dirty flag.</p>'),
])
section('Maze.lua', 'Grid and maze generation', [
    step('function Maze.fromDesign(design)', 12, 'Build a playable grid inside its owner', '<p>Maze copies the design’s open blocks and installs a closed exit gate. Game no longer constructs the grid through nested field writes. The copy lets play open the gate without changing the editor drawing.</p>'),
    step('function Maze:blockAt(x, y)', 3, 'World positions to grid indices', '<p>World x grows right; y grows down. Positions can be fractional. Grid indices start at 1.</p><p><code>(1.5, 1.5)</code> becomes block <code>(2, 2)</code>: floor each coordinate, then add one.</p>'),
    step('    local pitch = corridorWidth + 1', 10, 'Rooms separated by walls', '<p><code>pitch</code> is corridor width plus one wall block. The remainder operator <code>%</code> places wall rows and columns.</p><p>With width 1, a 3 × 2-cell maze occupies 7 × 5 blocks. Tumble uses two-block corridors for jumping; Slime uses three-block corridors for throwing.</p>'),
    step('    local visited = { [1] = true }', 13, 'Find unvisited neighbors', '<p>Start at cell (1, 1). The last entry of <code>stack</code> is the current cell; <code>#stack</code> is the list length.</p><p>The loop gathers neighboring cells that are inside the maze and have not been visited.</p>'),
    step('        if #unvisited == 0 then', 10, 'Carve or backtrack', '<p>Choose a random unvisited neighbor, carve the wall, and push that cell. If none remain, remove the stack’s last entry by assigning <code>nil</code>.</p><p>This is depth-first search. Connecting only new cells prevents loops: N cells get N − 1 internal passages.</p>'),
])
section('Player.lua', 'Movement and collision', [
    step('function Player:walkTowards', 12, 'Follow a navigation target', '<p>Player owns the speed-limited move and exact arrival at a clear cell center. Autopilot chooses the route and asks for a step; it does not assign coordinates.</p>'),
    step('function Player:rewindAlong', 10, 'Rewind position and heading together', '<p>The thread checks its swept path. Player applies the resulting position and turns toward the backward heading at the allowed speed. If no clear movement remains, position and heading stay unchanged.</p>'),
    step('local function isBlocked', 6, 'Check the body’s four corners', '<p>The player is a square, 0.4 blocks wide. Test all four corners at the proposed position. Walls and closed doors block movement.</p>'),
    step('local function slide', 13, 'Stop at the wall edge', '<p>Try the target first. If blocked, calculate a position just short of the wall. <code>GAP</code> avoids rounding a touching body into it.</p><p>This checks destinations, not the entire path. The game must use small movement steps.</p>'),
    step('function Player:moveBy', 7, 'Slide along walls', '<p>Move x first, then y using the updated x. A wall can block one axis while allowing movement along the other.</p>'),
    step('function Player:move(maze', 5, 'Rotate forward and sideways motion', '<p><code>cos(angle)</code> gives the horizontal part of forward; <code>sin(angle)</code> gives its vertical part. Lua takes radians, so convert degrees first.</p><p>Forward = (cos θ, sin θ). Right = (−sin θ, cos θ). At 90°, forward is down and right is left on the map.</p>'),
])
section('ExitDistance.lua', 'Shortest corridor distances', [
    step('    local queue, head = { { exitColumn, exitRow } }, 1', 6, 'Start a queue at the exit', '<p>The exit cell has distance zero. Process the oldest queued cell first by advancing <code>head</code>.</p><p>This is breadth-first search: visit distance 0, then 1, then 2, and so on.</p>'),
    step('            if isInside and not distances.byCell', 5, 'Visit each reachable neighbor once', '<p>Follow passages, assign the neighbor’s distance, and enqueue it. Every passage costs one step, so the first assigned distance is shortest.</p><p>Zero is true in Lua. The exit’s zero distance therefore still marks it as visited.</p>'),
    step('local function blockDistances', 5, 'Follow custom maps block by block', '<p>Hand-made maps can connect between cell centers. Their breadth-first search starts at the gate, even while closed, and follows every open block. Walls and disconnected blocks have zero proximity.</p>'),
    step('function ExitDistance:proximity', 9, 'Convert distance to proximity', '<p>Generated mazes measure cells; custom maps measure blocks, with proximity 1 at the gate. Proximity is 0 at the farthest reachable position. Music follows this corridor distance rather than straight-line distance through walls.</p>'),
])
section('Autopilot.lua', 'Wall-following navigation', [
    step('local PREFERENCE', 9, 'Try left, ahead, right, back', '<p>The numbers are quarter-turn offsets from the current heading. Choose the first open passage.</p><p>This works for the game’s tree-shaped maze, but does not choose the shortest route.</p>'),
    step('    if player:walkTowards', 1, 'Let Player perform the move', '<p>If a target step was needed, finish this frame. Once at the target, choose the next passage and turn before advancing.</p>'),
    step('    local turn = (ANGLES', 5, 'Turn by the shorter angle', '<p>Wrap the turn into [−180°, 180°). From 350° to 10°, the result is +20°.</p><p>Limit turning to six degrees per frame before moving toward the next cell center.</p>'),
])
section('Thread.lua', 'Recording and reversing a path', [
    step('function Thread:record', 22, 'Keep collision-safe path segments', '<p>Record a point every 0.25 blocks, with extra points where a shortcut would cross a wall. Check clearance for the player’s whole body before removing a retraced point.</p><p>The scene’s game records both axes of movement. The list is capped at 800 points.</p>'),
    step('        local share = stretch > 0', 8, 'Check the segment before rewinding', '<p><code>share = distance / stretch</code>, capped at 1, gives the fraction to rewind. Reeling 0.1 blocks along 0.25 blocks moves 40% of the segment.</p><p>Check the entire segment for body clearance before moving. Stop at blocked segments, including unsafe paths from older saves.</p>'),
])
section('Spikes.lua', 'Platforming hazards', [
    step('function Spikes.place', 22, 'Leave safe takeoff and landing space', '<p>Place short spike patches on solid floors, leaving the starting cell, its first landing below any open shaft, collectible cells, and exit cell clear. Slime cannot steer while falling, so the first landing remains safe on both entry and respawn. Each run owns its hazards. The triangles rotate with the maze in Tumble.</p>'),
    step('function Spikes.touches', 10, 'Contact sends you back to the start', '<p>Check the player body against each patch. Tumble and Slime reset movement on contact but retain collected shapes, the open exit, and elapsed time. Slime trajectory previews stop at spikes as well as walls.</p>'),
])
section('Tumble.lua', 'Rotating gravity', [
    step('    self.angle = (self.angle', 9, 'Convert screen directions to maze directions', '<p>The view rotates clockwise by <code>angle</code>. Gravity must still point down the screen.</p><p>In maze coordinates, down = (sin θ, cos θ). At 90°, gravity points east. Right = (cos θ, −sin θ).</p><p>Tumble requests a turn through Player’s existing method to align its heading with gravity.</p>'),
    step('    local along = velocityX', 10, 'Change the sideways velocity', '<p>The dot product measures velocity along the screen’s right direction: multiply corresponding components and add.</p><p>Walking changes that component toward the desired speed. With no input, friction reduces it.</p>'),
    step('    if input.jump and self.isGrounded then', 10, 'Jump, then cap speed', '<p>Replace the downward velocity with an upward jump speed. Limit total speed to 0.35 blocks per frame before collision checks.</p>'),
])
section('SideView.lua', '2D drawing coordinates', [
    step('function SideView.toScreen', 4, 'Translate, rotate, scale', '<p>Subtract the player position, rotate the offset, multiply by pixels per block, then add screen center (200, 120).</p><p>The player stays centered while the maze rotates around them.</p>'),
    step('local function fillWorldRect', 7, 'A rotated rectangle becomes a polygon', '<p>Transform all four corners with the same function. Draw the resulting polygon to show a corridor.</p>'),
])
section('Slime.lua', 'Throwing and trajectory prediction', [
    step('local function throwVelocity', 4, 'Convert the crank angle to velocity', '<p>Slime uses 0° up, unlike the first-person camera’s 0° east. Its launch direction is (sin θ, −cos θ).</p><p>Multiply by <code>THROW_SPEED</code> to get blocks per frame.</p>'),
    step('local function fly', 17, 'Simulate one frame', '<p>Add gravity, cap speed, then call the shared collision method. A downward hit is a floor; other blocked directions identify walls or the ceiling.</p>'),
    step('function Slime:arc(result)', 14, 'Preview with the same simulation', '<p>A spare player, <code>scout</code>, resets its own pose through <code>copyFrom</code> and repeats <code>fly</code> until collision or 240 frames. The real player stays unchanged, and the spare body is reused. The returned points are fresh unless the view supplies its own output buffer.</p><p>The real flight uses this same function. The preview therefore includes the same gravity, speed cap, and collisions.</p>'),
])
section('Puzzle.lua', 'Shape states', [
    step('function Puzzle:pickUp', 7, 'Ground → carried', '<p>Find an item within reach, change its state, and remember it in <code>self.carried</code>. Only one item can be carried.</p>'),
    step('    local pedestal = self:pedestalInReach', 8, 'Carried → placed', '<p>A matching empty pedestal within reach receives the item. Mark both as filled or placed, then empty the player’s hands.</p>'),
    step('function Puzzle:isSolved()', 6, 'Check all shapes', '<p>Any shape not placed means the puzzle is unfinished. In first-person play, solving it unlocks the gate; the player must still crank it open.</p>'),
])
section('Raycaster.lua', 'Rays and perspective', [
    step('function Raycaster.scan', 3, 'Own each scan result', '<p>Without an output buffer, every call returns independent runs and depths. MazeView supplies its private buffer each frame to reuse those tables. Only another scan into that same buffer invalidates its contents. The buffer keeps a pool of run tables even when fewer faces are visible; its runs list contains only the active faces.</p>'),
    step('    local width, columnWidth = screen.width', 5, 'Build the camera directions', '<p>Forward = (cos θ, sin θ). The camera plane is perpendicular to forward and has half-width <code>tan(FOV / 2)</code>.</p><p>For 70° FOV, tan(35°) ≈ 0.700. Tangent is opposite ÷ adjacent: plane half-width divided by one unit forward.</p>'),
    step('    local function castAt', 4, 'Aim one ray through the screen', '<p><code>cameraX</code> maps screen x to −1 at the left edge, 0 at center, and +1 at the right edge.</p><p>Add that share of the camera plane to forward. The resulting ray direction is deliberately not normalized.</p>'),
    step('    local gridX, gridY = math.floor(x)', 3, 'Calculate grid-crossing intervals', '<p>Write a ray as position + t × direction. Crossing one block in x takes <code>abs(1 / directionX)</code> units of t.</p><p>A zero component gets infinity: an exactly horizontal ray never crosses a horizontal grid line.</p>'),
    step('    if directionX < 0 then', 10, 'Find the first boundaries', '<p>Choose −1 or +1 for each grid direction. Multiply the distance to the first boundary by that axis’s interval.</p><p>From x = 1.5 pointing east with directionX = 1, the first x boundary is reached at t = 0.5.</p>'),
    step('        if sideDistanceX < sideDistanceY then', 9, 'Visit the next crossed block', '<p>Advance whichever boundary comes first, then schedule its next crossing. This is DDA: digital differential analysis.</p><p>It jumps from boundary to boundary instead of taking tiny steps through empty space.</p>'),
    step('        local block = blocks[gridY][gridX]', 5, 'Stop at the first nonempty block', '<p>Return the hit and t. Subtract the delta because the next boundary time was already advanced.</p><p>EXIT also stops a ray, although the player can enter it. The renderer draws it as white light.</p>'),
    step('        local cameraX = 2 * screenX', 2, 'Equal screen spacing, unequal angles', '<p>Pixels are evenly spaced on a flat camera plane. The angle of a ray is <code>atan(cameraX × tan(FOV / 2))</code> relative to forward.</p><p>At 70° FOV, halfway from center to edge is about 19.3°, not 17.5°. Incrementing the angle by a fixed amount would not match this projection.</p>'),
    step('        return cast(maze, x, y, forwardX', 1, 'Why t is the correct depth', '<p>Forward has length 1; the plane is perpendicular to it. Thus dot(forward, ray) = 1, and a hit at t × ray has forward depth t.</p><p>A flat wall ahead keeps the same depth across the screen. Using diagonal travel distance would shrink its edges: the fisheye error.</p>'),
    step('        if column <= columnCount then depths[column]', 7, 'Group samples by wall face', '<p>Save each column’s depth. Consecutive hits on the same block face form a run, drawn later as one trapezoid.</p><p>At 400 pixels with 4-pixel columns, there are 100 depth samples plus edge and refinement rays.</p>'),
    step('            for _ = 1, screen.refinements do', 13, 'Refine the edge by bisection', '<p>Cast halfway between the two samples. Replace one endpoint, then repeat. Two refinements reduce the search interval to a quarter.</p><p>A thin third face can be folded into the boundary; this is sampled visibility.</p>'),
    step('    local offsetX, offsetY = worldX - x', 6, 'Project an object onto the screen', '<p>Subtract camera position. Dot products measure forward depth and sideways offset. Reject points behind the camera.</p><p>For an object 2 blocks ahead and 0.5 right: screen x = 200 × (1 + 0.5 / (2 × 0.700)) ≈ 271.4.</p>'),
])
section('MazeView.lua', 'Drawing the 3D image', [
    step('local PROJECTION <const>', 3, 'Set the perspective scale', '<p><code>PROJECTION = 200 / tan(35°)</code> ≈ 285.63 pixels for a one-block wall one block ahead.</p><p>Clamp very near depths to 0.1 so screen coordinates remain manageable.</p>'),
    step('local function drawRun', 7, 'Divide by depth', '<p>Wall height = 285.63 ÷ depth. At depth 2, it is 142.81 pixels; at depth 4, 71.41 pixels.</p><p>Center both ends around the horizon. Their top and bottom edges form a trapezoid.</p>'),
    step('        local distance = (run.startDistance', 6, 'Shade and fill each face', '<p>Darken with distance and make x-facing walls slightly darker. <code>fillPolygon</code> draws the four projected corners.</p>'),
    step('local function drawBricks', 17, 'Draw brickwork in world coordinates', '<p>Horizontal courses divide the wall’s height. Vertical joints are placed along the block face, then projected onto the screen.</p><p>Bitmap textures instead use the fractional hit position to choose an image column. This game draws lines; it does not sample a wall texture. Distant walls omit small brick details.</p>'),
    step('local function drawBackground()', 14, 'The floor is a cached gradient', '<p>These horizontal bands suggest a floor and ceiling without locating a world point for every pixel.</p><p>A textured floor needs another projection: intersect viewing rays with the floor plane and sample its texture. This renderer only projects individual floor marks.</p>'),
    step('    local firstColumn = math.max', 12, 'Hide sprites behind walls', '<p>Compare the sprite’s depth with each wall-column depth. Clip drawing between the first and last visible columns.</p><p>This single rectangle can include a hidden middle strip. It is approximate occlusion, not a per-pixel depth buffer.</p>'),
    step('    local scan = Raycaster.scan', 7, 'Draw walls, marks, then sprites', '<p>Scan from the player’s position into the view’s reusable buffer and draw the wall runs. Add floor and ceiling marks, then sprites sorted farthest first.</p><p>Nearby sprites paint over farther ones. The scene draws the HUD afterward.</p>'),
])
section('Shades.lua', 'Black-and-white shading', [
    step('local BAYER <const>', 6, 'Use a repeating threshold pattern', '<p>Playdate pixels are black or white. The Bayer matrix orders which pixels turn white to imitate gray.</p><p>At level 8, eight of the sixteen pixels are white. At level 16, all are white.</p>'),
    step('for level = 0, Shades.WHITE do', 13, 'Build the drawing patterns once', '<p>Repeat the matrix over an 8 × 8 tile. A pixel is white when its matrix value is below the shade level.</p><p><code>byte * 2</code> shifts the row’s bits left; adding 0 or 1 appends a pixel. Store the eight rows for <code>playdate.graphics.setPattern</code>.</p>'),
])

section('SaveData.lua', 'Independent save snapshots', [
    step('function SaveData.copy(value)', 8, 'Detach nested save data', '<p>Game, Maze, Puzzle, and MapDesign copy mutable nested data when exporting a save. Later gameplay and edits to the exported tables cannot change each other. This helper only copies acyclic plain save data; constructors and SDK objects keep their own ownership rules.</p>'),
])
section('Hum.lua', 'Owning proximity levels', [
    step('function Hum.levels', 8, 'Keep or reuse the result', '<p>Omitting the output buffer creates independent levels, including each left/right pair. Sounds supplies its private buffer every frame, consuming the values before explicitly overwriting them next frame.</p>'),
])
section('Compass.lua', 'Owning compass marks', [
    step('function Compass.marks', 8, 'Reuse only the caller’s marks', '<p>Each ordinary call returns independent marks. Hud supplies its own reusable list. Only writing into that same buffer changes its nested marks, so separate callers cannot invalidate each other.</p>'),
])
section('SoundBook.lua', 'Borrowing immutable notes', [
    step('function SoundBook.notes', 1, 'Read shared sheet music', '<p>The note book is immutable by contract. Sounds reads it without modifying it, and later calls never rewrite it. Each scheduled note reserves a synth until its release finishes, so long and overlapping effects keep every note. Finite effects continue on the sound clock across scene switches and paused game updates; stopping held hums does not cancel them. Copying these constants would add allocation without fixing an observed ownership violation.</p>'),
])

options = ''.join(f'<option value="section-{index}">{index:02d} {html.escape(title)} — source/{name}</option>' for index, (name, title, _) in enumerate(sections, 1))
page = (HERE / 'template.html').read_text().replace('<!-- OPTIONS -->', options).replace('<!-- SECTIONS -->', ''.join(markup for _, _, markup in sections)).replace('<!-- INTERACTIONS -->', (HERE / 'interactions.js').read_text())
(ROOT / 'docs/walkthrough.html').write_text(page)
print(f'Built {len(sections)} complete files; {len(page.encode()):,} bytes')
