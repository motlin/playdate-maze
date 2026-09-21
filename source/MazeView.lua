-- The first-person view of a Game. Walls come from Raycaster.scan as runs, each drawn as one
-- shaded trapezoid with a black edge. Shapes and pedestals are drawn over the walls, far to near,
-- clipped to the screen columns where nothing nearer hides them.

import "Bob"
import "Landmarks"
import "Puzzle"
import "Raycaster"
import "Shades"
import "ShapeArt"

MazeView = {}

MazeView.SCREEN = { width = 400, height = 240, columnWidth = 4, fieldOfView = 70, refinements = 2 }

local HORIZON_AT_REST <const> = MazeView.SCREEN.height / 2
-- Where the horizon is on the frame being drawn: it rises and falls a little with each stride
local horizon = HORIZON_AT_REST
-- The floor and ceiling are painted this much taller than the screen, so a bob never shows an edge
local BOB_ROOM <const> = Bob.HEAD_PIXELS + 1
-- Pixels per block for something one block away
local PROJECTION <const> = MazeView.SCREEN.width / 2 / math.tan(math.rad(MazeView.SCREEN.fieldOfView / 2))
-- Anything nearer than this is drawn as if it were this far away, to keep coordinates sane
local NEAREST <const> = 0.1

local BRIGHTEST_WALL <const> = 15
local DARKEST_WALL <const> = 3
local SHADE_PER_BLOCK <const> = 1.7
-- Walls facing east or west are a touch darker, so corners read clearly
local SIDE_X_DARKENING <const> = 2
-- The locked exit is a portcullis: upright bars with two crossbars, dark behind
local GATE_SHADE <const> = 4
local GATE_BARS <const> = 5
local GATE_CROSSBARS <const> = { 0.25, 0.75 }

-- Bricks: courses are the horizontal rows, joints the vertical gaps, staggered row by row.
-- Far walls are too small on screen for the detail to read, so it drops away with distance.
local COURSES <const> = 4
local SHORTEST_WALL_WITH_COURSES <const> = 40
local SHORTEST_WALL_WITH_JOINTS <const> = 80
local JOINTS <const> = { 0.25, 0.5, 0.75 }
local JOINTS_IN_COURSE <const> = { { 2 }, { 1, 3 }, { 2 }, { 1, 3 } }

-- Sizes in blocks. Walls are one block tall with the eye half-way up. Shapes hover just below
-- eye level so they stay on screen close up, where the floor beneath them has dropped out of view.
local ITEM_SIZE <const> = 0.3
local ITEM_HOVER_BELOW_EYE <const> = 0.1
local PEDESTAL_WIDTH <const> = 0.34
local PEDESTAL_HEIGHT <const> = 0.4
local PEDESTAL_ICON_SIZE <const> = 0.16
-- The thing that turns the world over hangs at eye level and spins this fast, in radians a frame
local FLIPPER_SIZE <const> = 0.36
local FLIPPER_SPIN <const> = 0.12

local BLOCK_DOOR <const> = 2
local BLOCK_EXIT <const> = 3

local background

local function drawBackground()
    local image = playdate.graphics.image.new(
        MazeView.SCREEN.width,
        MazeView.SCREEN.height + 2 * BOB_ROOM,
        playdate.graphics.kColorBlack
    )
    playdate.graphics.pushContext(image)
    local bandHeight <const> = 8
    local middle = HORIZON_AT_REST + BOB_ROOM
    for band = 0, middle // bandHeight do
        -- The floor brightens towards the viewer; the ceiling stays nearly black
        playdate.graphics.setPattern(Shades.pattern(2 + band // 2))
        playdate.graphics.fillRect(0, middle + band * bandHeight, MazeView.SCREEN.width, bandHeight)
        playdate.graphics.setPattern(Shades.pattern(band // 5))
        playdate.graphics.fillRect(0, middle - (band + 1) * bandHeight, MazeView.SCREEN.width, bandHeight)
    end
    playdate.graphics.popContext()
    return image
end

-- The view for the frame being drawn, set by MazeView.draw
local viewX, viewY, forwardX, forwardY
local PLANE_SCALE <const> = math.tan(math.rad(MazeView.SCREEN.fieldOfView / 2))

-- Returns the screen x of a point in the world and how tall a wall is there, or nil if the
-- point is too close or behind
local function projectWallPoint(worldX, worldY)
    local offsetX, offsetY = worldX - viewX, worldY - viewY
    local depth = offsetX * forwardX + offsetY * forwardY
    if depth < NEAREST then return nil end
    local sideways = -offsetX * forwardY + offsetY * forwardX
    return MazeView.SCREEN.width / 2 * (1 + sideways / (depth * PLANE_SCALE)), PROJECTION / depth
end

-- The point a fraction of the way along the face of the block that a run is looking at, which
-- is the face on the viewer's side. Returns the same as projectWallPoint.
local function projectAlongFace(run, along)
    if run.side == Raycaster.SIDES.X then
        local faceX = viewX < run.gridX - 1 and run.gridX - 1 or run.gridX
        return projectWallPoint(faceX, run.gridY - 1 + along)
    end
    local faceY = viewY < run.gridY - 1 and run.gridY - 1 or run.gridY
    return projectWallPoint(run.gridX - 1 + along, faceY)
end

-- How far the gate has been cranked up, from 0 to 1, for the frame being drawn
local gateLift = 0

-- The gate rises into the ceiling as one piece, leaving the light from outside beneath it
local function drawGate(run, startTop, startHeight, endTop, endHeight)
    local startX, endX = run.startX, run.endX
    local shown = 1 - gateLift
    local startFoot, endFoot = startTop + startHeight * shown, endTop + endHeight * shown
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.fillPolygon(
        startX,
        startFoot,
        endX,
        endFoot,
        endX,
        endTop + endHeight,
        startX,
        startTop + startHeight
    )

    for _, fraction in ipairs(GATE_CROSSBARS) do
        local height = fraction - gateLift
        if height > 0 then
            playdate.graphics.setLineWidth(math.max(2, (startHeight + endHeight) // 60))
            playdate.graphics.drawLine(startX, startTop + startHeight * height, endX, endTop + endHeight * height)
        end
    end
    for bar = 1, GATE_BARS do
        local x, height = projectAlongFace(run, bar / (GATE_BARS + 1))
        -- Only the part of the face inside the run is in view
        if x and x > startX and x < endX then
            playdate.graphics.setLineWidth(math.max(2, height // 30))
            playdate.graphics.drawLine(x, horizon - height / 2, x, horizon - height / 2 + height * shown)
        end
    end
    playdate.graphics.setLineWidth(1)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.drawLine(startX, startFoot, endX, endFoot)
end

-- Landmarks. A picture hangs across the middle half of its wall face, between these heights
-- measured down from the top of the wall; walls shorter than this on screen show no picture.
local PICTURE_FROM <const> = 0.25
local PICTURE_TO <const> = 0.75
local PICTURE_TOP <const> = 0.28
local PICTURE_BOTTOM <const> = 0.72
local SHORTEST_WALL_WITH_PICTURE <const> = 36
-- Each motif is a list of strokes; each stroke is a list of x, y pairs across the picture, from
-- 0, 0 at its top left to 1, 1 at its bottom right
local MOTIFS <const> = {
    -- A sun
    {
        { 0.5, 0.25, 0.75, 0.5, 0.5, 0.75, 0.25, 0.5, 0.5, 0.25 },
        { 0.5, 0.08, 0.5, 0.18 },
        { 0.5, 0.82, 0.5, 0.92 },
        { 0.08, 0.5, 0.18, 0.5 },
        { 0.82, 0.5, 0.92, 0.5 },
    },
    -- A tree
    { { 0.5, 0.1, 0.85, 0.65, 0.15, 0.65, 0.5, 0.1 }, { 0.5, 0.65, 0.5, 0.9 } },
    -- Waves
    { { 0.1, 0.35, 0.3, 0.2, 0.5, 0.35, 0.7, 0.2, 0.9, 0.35 }, { 0.1, 0.7, 0.3, 0.55, 0.5, 0.7, 0.7, 0.55, 0.9, 0.7 } },
    -- A star
    { { 0.5, 0.1, 0.72, 0.88, 0.1, 0.38, 0.9, 0.38, 0.28, 0.88, 0.5, 0.1 } },
    -- An eye
    {
        { 0.1, 0.5, 0.5, 0.2, 0.9, 0.5, 0.5, 0.8, 0.1, 0.5 },
        { 0.42, 0.42, 0.58, 0.42, 0.58, 0.58, 0.42, 0.58, 0.42, 0.42 },
    },
    -- A house
    {
        { 0.2, 0.9, 0.2, 0.45, 0.5, 0.15, 0.8, 0.45, 0.8, 0.9, 0.2, 0.9 },
        { 0.45, 0.9, 0.45, 0.65, 0.6, 0.65, 0.6, 0.9 },
    },
    -- A cross
    { { 0.15, 0.15, 0.85, 0.85 }, { 0.85, 0.15, 0.15, 0.85 } },
    -- A spiral of squares
    { { 0.15, 0.15, 0.85, 0.15, 0.85, 0.85, 0.15, 0.85, 0.15, 0.35, 0.65, 0.35, 0.65, 0.65, 0.35, 0.65, 0.35, 0.5 } },
}
-- Marks on floors and ceilings are squares or diamonds this far across, in blocks
local MARK_HALF_SIZE <const> = 0.22

local landmarks

-- Which face of a run's block the viewer is looking at
local function faceOf(run)
    if run.side == Raycaster.SIDES.X then
        return viewX < run.gridX - 1 and Landmarks.FACES.WEST or Landmarks.FACES.EAST
    end
    return viewY < run.gridY - 1 and Landmarks.FACES.NORTH or Landmarks.FACES.SOUTH
end

-- Draws the picture hanging on a run's wall face, if there is one. Wall heights vary evenly
-- across the screen, so a point part of the way across the picture is found by blending its ends.
local function drawPicture(run)
    local motif = landmarks:pictureOn(run.gridX, run.gridY, faceOf(run))
    if not motif then return end
    local fromX, fromHeight = projectAlongFace(run, PICTURE_FROM)
    local toX, toHeight = projectAlongFace(run, PICTURE_TO)
    if not fromX or not toX then return end
    -- Each visible projection returns its position and height together.
    ---@cast fromHeight number
    ---@cast toHeight number
    if math.max(fromHeight, toHeight) < SHORTEST_WALL_WITH_PICTURE then return end
    -- Along some faces the far end comes first on screen
    if fromX > toX then
        fromX, fromHeight, toX, toHeight = toX, toHeight, fromX, fromHeight
    end

    local function place(across, down)
        local height = fromHeight + (toHeight - fromHeight) * across
        local fraction = PICTURE_TOP + (PICTURE_BOTTOM - PICTURE_TOP) * down
        return fromX + (toX - fromX) * across, horizon - height / 2 + height * fraction
    end

    -- Only the part of the face inside the run is in view
    playdate.graphics.setClipRect(run.startX, 0, run.endX - run.startX, MazeView.SCREEN.height)
    local x1, y1 = place(0, 0)
    local x2, y2 = place(1, 0)
    local x3, y3 = place(1, 1)
    local x4, y4 = place(0, 1)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.fillPolygon(x1, y1, x2, y2, x3, y3, x4, y4)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.setLineWidth(2)
    playdate.graphics.drawPolygon(x1, y1, x2, y2, x3, y3, x4, y4)
    playdate.graphics.setLineWidth(1)
    for _, stroke in ipairs(MOTIFS[motif]) do
        local previousX, previousY = place(stroke[1], stroke[2])
        for index = 3, #stroke, 2 do
            local x, y = place(stroke[index], stroke[index + 1])
            playdate.graphics.drawLine(previousX, previousY, x, y)
            previousX, previousY = x, y
        end
    end
    playdate.graphics.clearClipRect()
end

local jointX, jointHeight = {}, {}

local function drawBricks(run, startTop, startHeight, endTop, endHeight)
    local tallest = math.max(startHeight, endHeight)
    if tallest < SHORTEST_WALL_WITH_COURSES then return end
    local startX, endX = run.startX, run.endX
    for course = 1, COURSES - 1 do
        local fraction = course / COURSES
        playdate.graphics.drawLine(startX, startTop + startHeight * fraction, endX, endTop + endHeight * fraction)
    end
    if tallest < SHORTEST_WALL_WITH_JOINTS then return end

    for index, along in ipairs(JOINTS) do
        jointX[index], jointHeight[index] = projectAlongFace(run, along)
    end
    for course, joints in ipairs(JOINTS_IN_COURSE) do
        for _, index in ipairs(joints) do
            local x, height = jointX[index], jointHeight[index]
            -- Only the part of the face inside the run is in view
            if x and x > startX and x < endX then
                local top = horizon - height / 2
                playdate.graphics.drawLine(x, top + height * (course - 1) / COURSES, x, top + height * course / COURSES)
            end
        end
    end
end

local function drawRun(run)
    local startHeight = PROJECTION / math.max(run.startDistance, NEAREST)
    local endHeight = PROJECTION / math.max(run.endDistance, NEAREST)
    local startX, endX = run.startX, run.endX
    local startTop, startBottom = horizon - startHeight / 2, horizon + startHeight / 2
    local endTop, endBottom = horizon - endHeight / 2, horizon + endHeight / 2

    if run.block == BLOCK_EXIT then
        playdate.graphics.setColor(playdate.graphics.kColorWhite)
        playdate.graphics.fillPolygon(startX, startTop, endX, endTop, endX, endBottom, startX, startBottom)
        return
    end

    if run.block == BLOCK_DOOR then
        playdate.graphics.setPattern(Shades.pattern(GATE_SHADE))
    else
        local distance = (run.startDistance + run.endDistance) / 2
        local level = BRIGHTEST_WALL - math.floor(distance * SHADE_PER_BLOCK)
        if run.side == Raycaster.SIDES.X then level = level - SIDE_X_DARKENING end
        playdate.graphics.setPattern(Shades.pattern(math.max(DARKEST_WALL, level)))
    end
    playdate.graphics.fillPolygon(startX, startTop, endX, endTop, endX, endBottom, startX, startBottom)

    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.drawLine(startX, startTop, endX, endTop)
    playdate.graphics.drawLine(startX, startBottom, endX, endBottom)
    playdate.graphics.drawLine(startX, startTop, startX, startBottom)
    if run.block == BLOCK_DOOR then
        drawGate(run, startTop, startHeight, endTop, endHeight)
    else
        drawBricks(run, startTop, startHeight, endTop, endHeight)
        drawPicture(run)
    end
end

-- The game's frame count on the frame being drawn, which keeps the shapes' hovering in time
local frame = 0

-- Reused between frames
local sprites = {}
local function byDepthFarthestFirst(a, b) return a.depth > b.depth end

local function collectSprites(game)
    local count = 0
    local player = game.player
    local function add(thing, kind, index)
        local worldX, worldY = game.maze:blockCenter(thing.gridX, thing.gridY)
        local screenX, depth = Raycaster.project(player.x, player.y, player.angle, MazeView.SCREEN, worldX, worldY)
        if not screenX or depth < NEAREST then return end
        count = count + 1
        local sprite = sprites[count]
        if not sprite then
            sprite = {}
            sprites[count] = sprite
        end
        sprite.thing, sprite.kind, sprite.screenX, sprite.depth, sprite.index = thing, kind, screenX, depth, index
    end
    for index, flipper in ipairs(game.flippers.all) do
        add(flipper, "flipper", index)
    end
    if game.puzzle then
        for index, pedestal in ipairs(game.puzzle.pedestals) do
            add(pedestal, "pedestal", index)
        end
        for index, item in ipairs(game.puzzle.items) do
            if item.state == Puzzle.STATES.GROUND then add(item, "item", index) end
        end
    end
    for index = count + 1, #sprites do
        sprites[index] = nil
    end
    table.sort(sprites, byDepthFarthestFirst)
end

-- Clips to the columns where the sprite is nearer than the wall. Returns false if there are none.
local function clipToVisibleColumns(depths, centerX, halfWidth, depth)
    local columnWidth = MazeView.SCREEN.columnWidth
    local firstColumn = math.max(1, math.floor((centerX - halfWidth) / columnWidth) + 1)
    local lastColumn = math.min(#depths, math.floor((centerX + halfWidth) / columnWidth) + 1)
    local firstVisible, lastVisible
    for column = firstColumn, lastColumn do
        if depths[column] > depth then
            firstVisible = firstVisible or column
            lastVisible = column
        end
    end
    if not firstVisible then return false end
    playdate.graphics.setClipRect(
        (firstVisible - 1) * columnWidth,
        0,
        (lastVisible - firstVisible + 1) * columnWidth,
        MazeView.SCREEN.height
    )
    return true
end

local function drawSprite(sprite, depths)
    local scale = PROJECTION / sprite.depth
    local floorY = horizon + scale / 2
    local centerX = sprite.screenX
    local itemSize = ITEM_SIZE * scale

    if sprite.kind == "flipper" then
        -- An octahedron turning on the spot: a diamond whose width swings as it spins
        local size = FLIPPER_SIZE * scale
        local halfWidth = math.max(1, math.abs(math.cos(frame * FLIPPER_SPIN + sprite.index)) * size / 2)
        if not clipToVisibleColumns(depths, centerX, size / 2, sprite.depth) then return end
        local top, bottom = horizon - size / 2, horizon + size / 2
        playdate.graphics.setColor(playdate.graphics.kColorWhite)
        playdate.graphics.fillPolygon(
            centerX,
            top,
            centerX + halfWidth,
            horizon,
            centerX,
            bottom,
            centerX - halfWidth,
            horizon
        )
        playdate.graphics.setColor(playdate.graphics.kColorBlack)
        playdate.graphics.setLineWidth(2)
        playdate.graphics.drawPolygon(
            centerX,
            top,
            centerX + halfWidth,
            horizon,
            centerX,
            bottom,
            centerX - halfWidth,
            horizon
        )
        playdate.graphics.setLineWidth(1)
        playdate.graphics.drawLine(centerX - halfWidth, horizon, centerX + halfWidth, horizon)
        playdate.graphics.drawLine(centerX, top, centerX, bottom)
    elseif sprite.kind == "item" then
        if not clipToVisibleColumns(depths, centerX, itemSize / 2, sprite.depth) then return end
        local hover = ITEM_HOVER_BELOW_EYE + Bob.hoverOffset(frame, sprite.index)
        ShapeArt.drawSolid(sprite.thing.shape, centerX, horizon + hover * scale, itemSize)
    else
        local width, height = PEDESTAL_WIDTH * scale, PEDESTAL_HEIGHT * scale
        if not clipToVisibleColumns(depths, centerX, width / 2, sprite.depth) then return end
        playdate.graphics.setColor(playdate.graphics.kColorWhite)
        playdate.graphics.fillRect(centerX - width / 2, floorY - height, width, height)
        playdate.graphics.setColor(playdate.graphics.kColorBlack)
        playdate.graphics.drawRect(centerX - width / 2, floorY - height, width, height)
        local iconSize = PEDESTAL_ICON_SIZE * scale
        ShapeArt.drawHollow(sprite.thing.shape, centerX, floorY - height + iconSize, iconSize)
        if sprite.thing.isFilled then
            ShapeArt.drawSolid(sprite.thing.shape, centerX, floorY - height - itemSize / 2, itemSize)
        end
    end
    playdate.graphics.clearClipRect()
end

-- A mark is a square or a diamond lying flat, black on a floor and white on a ceiling, solid or
-- in outline: four looks, so that marks near each other differ
local markCornersX, markCornersY = {}, {}
local SQUARE <const> = { -1, -1, 1, -1, 1, 1, -1, 1 }
local DIAMOND <const> = { 0, -1.3, 1.3, 0, 0, 1.3, -1.3, 0 }

local function drawMark(mark, maze, depths)
    local centerWorldX, centerWorldY = maze:blockCenter(mark.gridX, mark.gridY)
    local centerX, centerHeight = projectWallPoint(centerWorldX, centerWorldY)
    if not centerX then return end
    local outline = mark.motif % 2 == 0 and DIAMOND or SQUARE
    local sign = mark.kind == "floor" and 1 or -1
    local halfWidth = 0
    for corner = 1, 4 do
        local x, height = projectWallPoint(
            centerWorldX + outline[2 * corner - 1] * MARK_HALF_SIZE,
            centerWorldY + outline[2 * corner] * MARK_HALF_SIZE
        )
        -- Standing on it, or nearly: it is underfoot and out of view
        if not x then return end
        markCornersX[corner], markCornersY[corner] = x, horizon + sign * height / 2
        halfWidth = math.max(halfWidth, math.abs(x - centerX))
    end
    if not clipToVisibleColumns(depths, centerX, halfWidth, PROJECTION / centerHeight) then return end

    playdate.graphics.setColor(mark.kind == "floor" and playdate.graphics.kColorBlack or playdate.graphics.kColorWhite)
    local x, y = markCornersX, markCornersY
    if mark.motif % 4 < 2 then
        playdate.graphics.fillPolygon(x[1], y[1], x[2], y[2], x[3], y[3], x[4], y[4])
    else
        playdate.graphics.setLineWidth(2)
        playdate.graphics.drawPolygon(x[1], y[1], x[2], y[2], x[3], y[3], x[4], y[4])
        playdate.graphics.setLineWidth(1)
    end
    playdate.graphics.clearClipRect()
end

local function drawScene(game, headOffset)
    horizon = HORIZON_AT_REST + headOffset
    frame = game.frames
    background = background or drawBackground()
    background:draw(0, headOffset - BOB_ROOM)

    local player = game.player
    local radians = math.rad(player.angle)
    viewX, viewY, forwardX, forwardY = player.x, player.y, math.cos(radians), math.sin(radians)
    gateLift = game.gateLift
    landmarks = game.landmarks
    local scan = Raycaster.scan(game.maze, player.x, player.y, player.angle, MazeView.SCREEN)
    local runs = scan.runs
    for index = 1, #runs do
        drawRun(runs[index])
    end

    for _, mark in ipairs(landmarks.marks) do
        drawMark(mark, game.maze, scan.depths)
    end
    collectSprites(game)
    for index = 1, #sprites do
        drawSprite(sprites[index], scan.depths)
    end
end

-- Where the scene is drawn while the world is upside down, before being turned over on to the screen
local flippedScene

-- headOffset is how many pixels the view has bobbed down by, from a Bob
function MazeView.draw(game, headOffset)
    if not game.isFlipped then
        drawScene(game, headOffset)
        return
    end
    flippedScene = flippedScene or playdate.graphics.image.new(MazeView.SCREEN.width, MazeView.SCREEN.height)
    playdate.graphics.pushContext(flippedScene)
    drawScene(game, headOffset)
    playdate.graphics.popContext()
    flippedScene:draw(0, 0, playdate.graphics.kImageFlippedY)
end
