-- Draws a maze from the side, for the modes played that way: the screen starts as solid wall and
-- the corridors are cut out of it as white rectangles, one for each of the maze's open runs, so
-- a whole row of corridor is one shape. The view is centred on the player and may be turned.
-- Call look() first each frame; then toScreen() places anything else a mode wants to draw.

import "Maze"
import "Puzzle"
import "Shades"
import "ShapeArt"

SideView = {}

SideView.CENTER_X = 200
SideView.CENTER_Y = 120

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local CENTER_X <const> = SideView.CENTER_X
local CENTER_Y <const> = SideView.CENTER_Y
-- Corridors are drawn this much too big, in blocks, so neighbouring ones leave no hairline between them
local OVERLAP <const> = 0.02
local WALL_SHADE <const> = 5
local GATE_PATTERN <const> = { 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0 }
-- How big a shape is drawn, in blocks
local SHAPE_BLOCKS <const> = 0.5

-- The view for the frame being drawn
local run, playerX, playerY, sine, cosine, scale, visibleDistance

-- run is a Run; angle is how far the maze is turned clockwise, in degrees; pixelsPerBlock is the zoom
function SideView.look(viewedRun, angle, pixelsPerBlock)
    local radians = math.rad(angle)
    run, scale = viewedRun, pixelsPerBlock
    playerX, playerY, sine, cosine = run.player.x, run.player.y, math.sin(radians), math.cos(radians)
    -- Further than this from the player, in blocks, nothing can reach the screen's corners
    visibleDistance = math.sqrt(CENTER_X * CENTER_X + CENTER_Y * CENTER_Y) / scale + 1
end

function SideView.toScreen(worldX, worldY)
    local offsetX, offsetY = worldX - playerX, worldY - playerY
    return CENTER_X + (offsetX * cosine - offsetY * sine) * scale, CENTER_Y + (offsetX * sine + offsetY * cosine) * scale
end

local function fillWorldRect(left, top, right, bottom)
    local x1, y1 = SideView.toScreen(left, top)
    local x2, y2 = SideView.toScreen(right, top)
    local x3, y3 = SideView.toScreen(right, bottom)
    local x4, y4 = SideView.toScreen(left, bottom)
    playdate.graphics.fillPolygon(x1, y1, x2, y2, x3, y3, x4, y4)
end

-- The open runs only change when the exit opens
local runs, runsMaze, runsHasOpenExit

local function openRuns(maze)
    local hasOpenExit = maze:blockValue(maze.exitGridX, maze.exitGridY) == Maze.BLOCKS.EXIT
    if runsMaze ~= maze or runsHasOpenExit ~= hasOpenExit then
        runs, runsMaze, runsHasOpenExit = maze:openRuns(), maze, hasOpenExit
    end
    return runs
end

local function drawCorridors(maze)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    for _, openRun in ipairs(openRuns(maze)) do
        local left, right = openRun.startGridX - 1, openRun.endGridX
        local top, bottom = openRun.gridY - 1, openRun.gridY
        -- Skip runs that are wholly out of sight: nearest point of the run to the player
        local nearestX = math.max(left, math.min(right, playerX))
        local nearestY = math.max(top, math.min(bottom, playerY))
        local distanceX, distanceY = nearestX - playerX, nearestY - playerY
        if distanceX * distanceX + distanceY * distanceY < visibleDistance * visibleDistance then
            fillWorldRect(left - OVERLAP, top - OVERLAP, right + OVERLAP, bottom + OVERLAP)
        end
    end
end

local function drawExit(maze)
    local gridX, gridY = maze.exitGridX, maze.exitGridY
    if maze:blockValue(gridX, gridY) == Maze.BLOCKS.DOOR then
        playdate.graphics.setPattern(GATE_PATTERN)
        fillWorldRect(gridX - 1, gridY - 1, gridX, gridY)
    else
        local x, y = SideView.toScreen(maze:blockCenter(gridX, gridY))
        playdate.graphics.setColor(playdate.graphics.kColorBlack)
        playdate.graphics.setLineWidth(2)
        playdate.graphics.drawCircleAtPoint(x, y, scale / 4)
        playdate.graphics.drawCircleAtPoint(x, y, scale / 8)
        playdate.graphics.setLineWidth(1)
    end
end

local function drawShapes()
    for _, item in ipairs(run.puzzle.items) do
        if item.state == Puzzle.STATES.GROUND then
            local x, y = SideView.toScreen(run.maze:blockCenter(item.gridX, item.gridY))
            ShapeArt.drawSolid(item.shape, x, y, SHAPE_BLOCKS * scale)
        end
    end
end

-- The walls, the corridors, the exit, and the shapes still to be collected
function SideView.drawMaze()
    playdate.graphics.setPattern(Shades.pattern(WALL_SHADE))
    playdate.graphics.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    drawCorridors(run.maze)
    drawExit(run.maze)
    drawShapes()
end
