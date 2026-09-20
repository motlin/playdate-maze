-- Draws a Tumble: the maze from the side, turned about the player, who stays upright in the
-- middle of the screen. The screen starts as solid wall and the corridors are cut out of it as
-- white rectangles, one for each of the maze's open runs, so a whole row of corridor is one shape.

import "Maze"
import "Player"
import "Puzzle"
import "Shades"
import "ShapeArt"

local gfx <const> = playdate.graphics

TumbleView = {}

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local CENTER_X <const> = SCREEN_WIDTH / 2
local CENTER_Y <const> = SCREEN_HEIGHT / 2
-- Pixels per block
local SCALE <const> = 40
-- Further than this from the player, in blocks, nothing can reach the screen's corners
local VISIBLE_DISTANCE <const> = math.sqrt(CENTER_X * CENTER_X + CENTER_Y * CENTER_Y) / SCALE + 1
-- Corridors are drawn this much too big, in blocks, so neighbouring ones leave no hairline between them
local OVERLAP <const> = 0.02
local WALL_SHADE <const> = 5
local GATE_PATTERN <const> = { 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0 }
local SHAPE_SIZE <const> = 0.5 * SCALE
local BODY_SIZE <const> = 2 * Player.RADIUS * SCALE

-- The view for the frame being drawn
local playerX, playerY, sine, cosine

local function toScreen(worldX, worldY)
    local offsetX, offsetY = worldX - playerX, worldY - playerY
    return CENTER_X + (offsetX * cosine - offsetY * sine) * SCALE, CENTER_Y + (offsetX * sine + offsetY * cosine) * SCALE
end

local function fillWorldRect(left, top, right, bottom)
    local x1, y1 = toScreen(left, top)
    local x2, y2 = toScreen(right, top)
    local x3, y3 = toScreen(right, bottom)
    local x4, y4 = toScreen(left, bottom)
    gfx.fillPolygon(x1, y1, x2, y2, x3, y3, x4, y4)
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
    gfx.setColor(gfx.kColorWhite)
    for _, run in ipairs(openRuns(maze)) do
        local left, right = run.startGridX - 1, run.endGridX
        local top, bottom = run.gridY - 1, run.gridY
        -- Skip runs that are wholly out of sight: nearest point of the run to the player
        local nearestX = math.max(left, math.min(right, playerX))
        local nearestY = math.max(top, math.min(bottom, playerY))
        local distanceX, distanceY = nearestX - playerX, nearestY - playerY
        if distanceX * distanceX + distanceY * distanceY < VISIBLE_DISTANCE * VISIBLE_DISTANCE then
            fillWorldRect(left - OVERLAP, top - OVERLAP, right + OVERLAP, bottom + OVERLAP)
        end
    end
end

local function drawExit(maze)
    local gridX, gridY = maze.exitGridX, maze.exitGridY
    if maze:blockValue(gridX, gridY) == Maze.BLOCKS.DOOR then
        gfx.setPattern(GATE_PATTERN)
        fillWorldRect(gridX - 1, gridY - 1, gridX, gridY)
    else
        local x, y = toScreen(maze:blockCenter(gridX, gridY))
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawCircleAtPoint(x, y, SCALE / 4)
        gfx.drawCircleAtPoint(x, y, SCALE / 8)
        gfx.setLineWidth(1)
    end
end

local function drawShapes(tumble)
    for _, item in ipairs(tumble.puzzle.items) do
        if item.state == Puzzle.STATES.GROUND then
            local x, y = toScreen(tumble.maze:blockCenter(item.gridX, item.gridY))
            ShapeArt.drawSolid(item.shape, x, y, SHAPE_SIZE)
        end
    end
end

-- Always upright, looking the way it last walked
local function drawPlayer(tumble)
    local half = BODY_SIZE / 2
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(CENTER_X - half, CENTER_Y - half, BODY_SIZE, BODY_SIZE, 4)
    gfx.setColor(gfx.kColorWhite)
    local eyeX = CENTER_X + tumble.facing * 2
    gfx.fillRect(eyeX - 4, CENTER_Y - 4, 3, 4)
    gfx.fillRect(eyeX + 1, CENTER_Y - 4, 3, 4)
end

function TumbleView.draw(tumble)
    local radians = math.rad(tumble.angle)
    playerX, playerY, sine, cosine = tumble.player.x, tumble.player.y, math.sin(radians), math.cos(radians)

    gfx.setPattern(Shades.pattern(WALL_SHADE))
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    drawCorridors(tumble.maze)
    drawExit(tumble.maze)
    drawShapes(tumble)
    drawPlayer(tumble)
end
