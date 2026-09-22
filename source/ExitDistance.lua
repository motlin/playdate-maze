-- How far every cell of a maze is from the exit, walking along the corridors: the music follows
-- this, so it must not be fooled by a cell that is next door to the exit but a long walk away.

import "Maze"

ExitDistance = {}
ExitDistance.__index = ExitDistance

-- Custom maps can connect through any open block. The gate is the zero-distance target,
-- even while locked; only open blocks join the search, so walls and the outside stay unreachable.
local function blockDistances(maze)
    local distances = setmetatable({ maze = maze, byBlock = {}, farthest = 0 }, ExitDistance)
    distances.byBlock[(maze.exitGridY - 1) * maze.gridWidth + maze.exitGridX] = 0
    local queue, head = { { maze.exitGridX, maze.exitGridY } }, 1
    while head <= #queue do
        local gridX, gridY = queue[head][1], queue[head][2]
        head = head + 1
        local distance = distances.byBlock[(gridY - 1) * maze.gridWidth + gridX]
        for _, direction in ipairs(Maze.DIRECTIONS) do
            local offset = Maze.OFFSETS[direction]
            local nextX, nextY = gridX + offset[1], gridY + offset[2]
            local key = (nextY - 1) * maze.gridWidth + nextX
            if maze:blockValue(nextX, nextY) == Maze.BLOCKS.OPEN and not distances.byBlock[key] then
                distances.byBlock[key] = distance + 1
                distances.farthest = math.max(distances.farthest, distance + 1)
                queue[#queue + 1] = { nextX, nextY }
            end
        end
    end
    return distances
end

function ExitDistance.new(maze, isHandMade)
    if isHandMade then return blockDistances(maze) end
    local exitColumn, exitRow = maze:nearestCell(maze:blockCenter(maze.exitGridX, maze.exitGridY))
    local distances = setmetatable({ maze = maze, byCell = {}, farthest = 0 }, ExitDistance)
    distances.byCell[(exitRow - 1) * maze.columns + exitColumn] = 0
    local queue, head = { { exitColumn, exitRow } }, 1
    while head <= #queue do
        local column, row = queue[head][1], queue[head][2]
        head = head + 1
        local distance = distances.byCell[(row - 1) * maze.columns + column]
        for _, direction in ipairs(Maze.DIRECTIONS) do
            local offset = Maze.OFFSETS[direction]
            local nextColumn, nextRow = column + offset[1], row + offset[2]
            local isInside = nextColumn >= 1 and nextColumn <= maze.columns and nextRow >= 1 and nextRow <= maze.rows
            local key = (nextRow - 1) * maze.columns + nextColumn
            if isInside and not distances.byCell[key] and maze:hasPassage(column, row, direction) then
                distances.byCell[key] = distance + 1
                distances.farthest = math.max(distances.farthest, distance + 1)
                queue[#queue + 1] = { nextColumn, nextRow }
            end
        end
    end
    return distances
end

-- Generated-maze cell distances. Disconnected cells count as one further than the farthest.
function ExitDistance:cells(column, row) return self.byCell[(row - 1) * self.maze.columns + column] or self.farthest + 1 end

-- From 0 at the farthest reachable position to 1 at the exit (its cell in generated mazes).
function ExitDistance:proximity(x, y)
    if self.byBlock then
        local gridX, gridY = self.maze:blockAt(x, y)
        local distance = self.byBlock[(gridY - 1) * self.maze.gridWidth + gridX] or self.farthest + 1
        return 1 - math.min(1, distance / math.max(1, self.farthest))
    end
    local column, row = self.maze:nearestCell(x, y)
    return 1 - math.min(1, self:cells(column, row) / math.max(1, self.farthest))
end
