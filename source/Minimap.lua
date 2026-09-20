-- The 2D map in the corner: the whole maze, where the shapes and pedestals are, and an arrow
-- for the player. The walls are drawn once into an image and again when the exit opens.

import "Maze"
import "Puzzle"
import "ShapeArt"

local gfx <const> = playdate.graphics

Minimap = {}

local CELL <const> = 7
local MARGIN <const> = 3
local SHAPE_SIZE <const> = 5
local ARROW_LENGTH <const> = 5

local wallsImage, wallsMaze, wallsHasOpenExit

function Minimap.size(maze)
    return maze.columns * CELL + 1 + 2 * MARGIN, maze.rows * CELL + 1 + 2 * MARGIN
end

local function drawWalls(maze)
    local width, height = Minimap.size(maze)
    local image = gfx.image.new(width, height, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(0, 0, width, height)
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            local left, top = MARGIN + (column - 1) * CELL, MARGIN + (row - 1) * CELL
            if not maze:hasPassage(column, row, "north") then gfx.drawLine(left, top, left + CELL, top) end
            if not maze:hasPassage(column, row, "west") then gfx.drawLine(left, top, left, top + CELL) end
            if not maze:hasPassage(column, row, "south") then gfx.drawLine(left, top + CELL, left + CELL, top + CELL) end
            if not maze:hasPassage(column, row, "east") then gfx.drawLine(left + CELL, top, left + CELL, top + CELL) end
        end
    end
    -- A locked exit is a thick bar; an open one is a gap in the wall
    if maze:blockValue(maze.exitGridX, maze.exitGridY) == Maze.BLOCKS.DOOR then
        gfx.fillRect(MARGIN + maze.columns * CELL - 1, MARGIN + (maze.rows - 1) * CELL + 1, 3, CELL - 1)
    end
    gfx.popContext()
    return image
end

-- Blocks are half a cell wide on the map: world x = 1.5 is the middle of the first cell
local function toMap(left, top, worldX, worldY)
    return left + MARGIN + (worldX - 0.5) * CELL / 2, top + MARGIN + (worldY - 0.5) * CELL / 2
end

function Minimap.draw(game, left, top)
    local maze = game.maze
    local hasOpenExit = maze:blockValue(maze.exitGridX, maze.exitGridY) == Maze.BLOCKS.EXIT
    if wallsMaze ~= maze or wallsHasOpenExit ~= hasOpenExit then
        wallsImage, wallsMaze, wallsHasOpenExit = drawWalls(maze), maze, hasOpenExit
    end
    wallsImage:draw(left, top)

    if game.puzzle then
        for _, pedestal in ipairs(game.puzzle.pedestals) do
            local x, y = toMap(left, top, maze:blockCenter(pedestal.gridX, pedestal.gridY))
            if pedestal.isFilled then
                ShapeArt.drawBlack(pedestal.shape, x, y, SHAPE_SIZE)
            else
                ShapeArt.drawHollow(pedestal.shape, x, y, SHAPE_SIZE)
            end
        end
        for _, item in ipairs(game.puzzle.items) do
            if item.state == Puzzle.STATES.GROUND then
                local x, y = toMap(left, top, maze:blockCenter(item.gridX, item.gridY))
                ShapeArt.drawBlack(item.shape, x, y, SHAPE_SIZE)
            end
        end
    end

    local player = game.player
    local x, y = toMap(left, top, player.x, player.y)
    local radians = math.rad(player.angle)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x, y, 2)
    gfx.drawLine(x, y, x + math.cos(radians) * ARROW_LENGTH, y + math.sin(radians) * ARROW_LENGTH)
end
