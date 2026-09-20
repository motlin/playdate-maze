-- The first-person view of a Game. Walls come from Raycaster.scan as runs, each drawn as one
-- shaded trapezoid with a black edge. Shapes and pedestals are drawn over the walls, far to near,
-- clipped to the screen columns where nothing nearer hides them.

import "Puzzle"
import "Raycaster"
import "Shades"
import "ShapeArt"

local gfx <const> = playdate.graphics

MazeView = {}

MazeView.SCREEN = { width = 400, height = 240, columnWidth = 4, fieldOfView = 70, refinements = 2 }

local SCREEN <const> = MazeView.SCREEN
local HORIZON <const> = SCREEN.height / 2
-- Pixels per block for something one block away
local PROJECTION <const> = SCREEN.width / 2 / math.tan(math.rad(SCREEN.fieldOfView / 2))
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

local BLOCK_DOOR <const> = 2
local BLOCK_EXIT <const> = 3

local background

local function drawBackground()
    local image = gfx.image.new(SCREEN.width, SCREEN.height, gfx.kColorBlack)
    gfx.pushContext(image)
    local bandHeight <const> = 8
    for band = 0, HORIZON // bandHeight - 1 do
        -- The floor brightens towards the viewer; the ceiling stays nearly black
        gfx.setPattern(Shades.pattern(2 + band // 2))
        gfx.fillRect(0, HORIZON + band * bandHeight, SCREEN.width, bandHeight)
        gfx.setPattern(Shades.pattern(band // 5))
        gfx.fillRect(0, HORIZON - (band + 1) * bandHeight, SCREEN.width, bandHeight)
    end
    gfx.popContext()
    return image
end

-- The view for the frame being drawn, set by MazeView.draw
local viewX, viewY, forwardX, forwardY
local PLANE_SCALE <const> = math.tan(math.rad(SCREEN.fieldOfView / 2))

-- Returns the screen x of a point in the world and how tall a wall is there, or nil if the
-- point is too close or behind
local function projectWallPoint(worldX, worldY)
    local offsetX, offsetY = worldX - viewX, worldY - viewY
    local depth = offsetX * forwardX + offsetY * forwardY
    if depth < NEAREST then return nil end
    local sideways = -offsetX * forwardY + offsetY * forwardX
    return SCREEN.width / 2 * (1 + sideways / (depth * PLANE_SCALE)), PROJECTION / depth
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

local function drawGate(run, startTop, startHeight, endTop, endHeight)
    local startX, endX = run.startX, run.endX
    gfx.setColor(gfx.kColorWhite)
    for _, fraction in ipairs(GATE_CROSSBARS) do
        gfx.setLineWidth(math.max(2, (startHeight + endHeight) // 60))
        gfx.drawLine(startX, startTop + startHeight * fraction, endX, endTop + endHeight * fraction)
    end
    for bar = 1, GATE_BARS do
        local x, height = projectAlongFace(run, bar / (GATE_BARS + 1))
        -- Only the part of the face inside the run is in view
        if x and x > startX and x < endX then
            gfx.setLineWidth(math.max(2, height // 30))
            gfx.drawLine(x, HORIZON - height / 2, x, HORIZON + height / 2)
        end
    end
    gfx.setLineWidth(1)
end

local jointX, jointHeight = {}, {}

local function drawBricks(run, startTop, startHeight, endTop, endHeight)
    local tallest = math.max(startHeight, endHeight)
    if tallest < SHORTEST_WALL_WITH_COURSES then return end
    local startX, endX = run.startX, run.endX
    for course = 1, COURSES - 1 do
        local fraction = course / COURSES
        gfx.drawLine(startX, startTop + startHeight * fraction, endX, endTop + endHeight * fraction)
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
                local top = HORIZON - height / 2
                gfx.drawLine(x, top + height * (course - 1) / COURSES, x, top + height * course / COURSES)
            end
        end
    end
end

local function drawRun(run)
    local startHeight = PROJECTION / math.max(run.startDistance, NEAREST)
    local endHeight = PROJECTION / math.max(run.endDistance, NEAREST)
    local startX, endX = run.startX, run.endX
    local startTop, startBottom = HORIZON - startHeight / 2, HORIZON + startHeight / 2
    local endTop, endBottom = HORIZON - endHeight / 2, HORIZON + endHeight / 2

    if run.block == BLOCK_EXIT then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillPolygon(startX, startTop, endX, endTop, endX, endBottom, startX, startBottom)
        return
    end

    if run.block == BLOCK_DOOR then
        gfx.setPattern(Shades.pattern(GATE_SHADE))
    else
        local distance = (run.startDistance + run.endDistance) / 2
        local level = BRIGHTEST_WALL - math.floor(distance * SHADE_PER_BLOCK)
        if run.side == Raycaster.SIDES.X then level = level - SIDE_X_DARKENING end
        gfx.setPattern(Shades.pattern(math.max(DARKEST_WALL, level)))
    end
    gfx.fillPolygon(startX, startTop, endX, endTop, endX, endBottom, startX, startBottom)

    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(startX, startTop, endX, endTop)
    gfx.drawLine(startX, startBottom, endX, endBottom)
    gfx.drawLine(startX, startTop, startX, startBottom)
    if run.block == BLOCK_DOOR then
        drawGate(run, startTop, startHeight, endTop, endHeight)
    else
        drawBricks(run, startTop, startHeight, endTop, endHeight)
    end
end

-- Reused between frames
local sprites = {}
local function byDepthFarthestFirst(a, b) return a.depth > b.depth end

local function collectSprites(game)
    local count = 0
    local player = game.player
    local function add(thing, kind)
        local worldX, worldY = game.maze:blockCenter(thing.gridX, thing.gridY)
        local screenX, depth = Raycaster.project(player.x, player.y, player.angle, SCREEN, worldX, worldY)
        if not screenX or depth < NEAREST then return end
        count = count + 1
        local sprite = sprites[count]
        if not sprite then
            sprite = {}
            sprites[count] = sprite
        end
        sprite.thing, sprite.kind, sprite.screenX, sprite.depth = thing, kind, screenX, depth
    end
    for _, pedestal in ipairs(game.puzzle.pedestals) do add(pedestal, "pedestal") end
    for _, item in ipairs(game.puzzle.items) do
        if item.state == Puzzle.STATES.GROUND then add(item, "item") end
    end
    for index = count + 1, #sprites do sprites[index] = nil end
    table.sort(sprites, byDepthFarthestFirst)
end

-- Clips to the columns where the sprite is nearer than the wall. Returns false if there are none.
local function clipToVisibleColumns(depths, centerX, halfWidth, depth)
    local columnWidth = SCREEN.columnWidth
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
    gfx.setClipRect((firstVisible - 1) * columnWidth, 0, (lastVisible - firstVisible + 1) * columnWidth, SCREEN.height)
    return true
end

local function drawSprite(sprite, depths)
    local scale = PROJECTION / sprite.depth
    local floorY = HORIZON + scale / 2
    local centerX = sprite.screenX
    local itemSize = ITEM_SIZE * scale

    if sprite.kind == "item" then
        if not clipToVisibleColumns(depths, centerX, itemSize / 2, sprite.depth) then return end
        ShapeArt.drawSolid(sprite.thing.shape, centerX, HORIZON + ITEM_HOVER_BELOW_EYE * scale, itemSize)
    else
        local width, height = PEDESTAL_WIDTH * scale, PEDESTAL_HEIGHT * scale
        if not clipToVisibleColumns(depths, centerX, width / 2, sprite.depth) then return end
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(centerX - width / 2, floorY - height, width, height)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(centerX - width / 2, floorY - height, width, height)
        local iconSize = PEDESTAL_ICON_SIZE * scale
        ShapeArt.drawHollow(sprite.thing.shape, centerX, floorY - height + iconSize, iconSize)
        if sprite.thing.isFilled then
            ShapeArt.drawSolid(sprite.thing.shape, centerX, floorY - height - itemSize / 2, itemSize)
        end
    end
    gfx.clearClipRect()
end

function MazeView.draw(game)
    background = background or drawBackground()
    background:draw(0, 0)

    local player = game.player
    local radians = math.rad(player.angle)
    viewX, viewY, forwardX, forwardY = player.x, player.y, math.cos(radians), math.sin(radians)
    local scan = Raycaster.scan(game.maze, player.x, player.y, player.angle, SCREEN)
    local runs = scan.runs
    for index = 1, #runs do drawRun(runs[index]) end

    if game.puzzle then
        collectSprites(game)
        for index = 1, #sprites do drawSprite(sprites[index], scan.depths) end
    end
end
