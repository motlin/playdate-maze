-- The 2D map in the corner: the cells the game has revealed, the shapes and pedestals in them,
-- and an arrow for the player. Everything else is grey fog. The walls are drawn into an image
-- that is only redrawn when a new cell is revealed or the exit opens.

import "Maze"
import "Puzzle"
import "Shades"
import "ShapeArt"
import "Sizes"

local gfx <const> = playdate.graphics

Minimap = {}

local MARGIN <const> = 3
local ARROW_LENGTH <const> = 5
local FOG_SHADE <const> = 11

local wallsImage, wallsMaze, wallsHasOpenExit, wallsVisitedCount

-- Pixels per cell for the maze being drawn: wide mazes get smaller cells. Set by Minimap.draw.
local cellSize

function Minimap.size(maze)
    local cell = Sizes.mapCellSize(maze.columns)
    return maze.columns * cell + 1 + 2 * MARGIN, maze.rows * cell + 1 + 2 * MARGIN
end

local function cellCorner(column, row)
    return MARGIN + (column - 1) * cellSize, MARGIN + (row - 1) * cellSize
end

local function clearFog(column, row)
    local left, top = cellCorner(column, row)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(left, top, cellSize + 1, cellSize + 1)
end

local function drawCellWalls(maze, column, row)
    local left, top = cellCorner(column, row)
    gfx.setColor(gfx.kColorBlack)
    if not maze:hasPassage(column, row, "north") then gfx.drawLine(left, top, left + cellSize, top) end
    if not maze:hasPassage(column, row, "west") then gfx.drawLine(left, top, left, top + cellSize) end
    if not maze:hasPassage(column, row, "south") then gfx.drawLine(left, top + cellSize, left + cellSize, top + cellSize) end
    if not maze:hasPassage(column, row, "east") then gfx.drawLine(left + cellSize, top, left + cellSize, top + cellSize) end
end

local function forEachRevealedCell(game, action)
    for row = 1, game.maze.rows do
        for column = 1, game.maze.columns do
            if game:isRevealed(column, row) then action(column, row) end
        end
    end
end

local function drawWalls(game)
    local maze = game.maze
    local width, height = Minimap.size(maze)
    local image = gfx.image.new(width, height, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setPattern(Shades.pattern(FOG_SHADE))
    gfx.fillRect(MARGIN, MARGIN, width - 2 * MARGIN, height - 2 * MARGIN)
    -- All the fog goes before any wall, so clearing one cell cannot rub out its neighbour's wall
    forEachRevealedCell(game, clearFog)
    forEachRevealedCell(game, function(column, row) drawCellWalls(maze, column, row) end)

    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(0, 0, width, height)
    -- A locked exit is a thick bar; an open one is a gap in the wall
    local isLocked = maze:blockValue(maze.exitGridX, maze.exitGridY) == Maze.BLOCKS.DOOR
    if isLocked and game:isRevealed(maze.columns, maze.rows) then
        local left, top = cellCorner(maze.columns, maze.rows)
        gfx.fillRect(left + cellSize - 1, top + 1, 3, cellSize - 1)
    end
    gfx.popContext()
    return image
end

-- Blocks are half a cell wide on the map: world x = 1.5 is the middle of the first cell
local function toMap(left, top, worldX, worldY)
    return left + MARGIN + (worldX - 0.5) * cellSize / 2, top + MARGIN + (worldY - 0.5) * cellSize / 2
end

local function isRevealed(game, thing)
    return game:isRevealed(game.maze:nearestCell(game.maze:blockCenter(thing.gridX, thing.gridY)))
end

local function drawPuzzle(game, left, top)
    for _, pedestal in ipairs(game.puzzle.pedestals) do
        if isRevealed(game, pedestal) then
            local x, y = toMap(left, top, game.maze:blockCenter(pedestal.gridX, pedestal.gridY))
            if pedestal.isFilled then
                ShapeArt.drawBlack(pedestal.shape, x, y, cellSize - 2)
            else
                ShapeArt.drawHollow(pedestal.shape, x, y, cellSize - 2)
            end
        end
    end
    for _, item in ipairs(game.puzzle.items) do
        if item.state == Puzzle.STATES.GROUND and isRevealed(game, item) then
            local x, y = toMap(left, top, game.maze:blockCenter(item.gridX, item.gridY))
            ShapeArt.drawBlack(item.shape, x, y, cellSize - 2)
        end
    end
end

function Minimap.draw(game, left, top)
    local maze = game.maze
    cellSize = Sizes.mapCellSize(maze.columns)
    local hasOpenExit = maze:blockValue(maze.exitGridX, maze.exitGridY) == Maze.BLOCKS.EXIT
    if wallsMaze ~= maze or wallsHasOpenExit ~= hasOpenExit or wallsVisitedCount ~= game.visitedCount then
        wallsImage, wallsMaze = drawWalls(game), maze
        wallsHasOpenExit, wallsVisitedCount = hasOpenExit, game.visitedCount
    end
    wallsImage:draw(left, top)

    if game.puzzle then drawPuzzle(game, left, top) end

    local player = game.player
    local x, y = toMap(left, top, player.x, player.y)
    local radians = math.rad(player.angle)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x, y, 2)
    gfx.drawLine(x, y, x + math.cos(radians) * ARROW_LENGTH, y + math.sin(radians) * ARROW_LENGTH)
end
