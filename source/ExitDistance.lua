-- How far every cell of a maze is from the exit, walking along the corridors: the music follows
-- this, so it must not be fooled by a cell that is next door to the exit but a long walk away.

import "Maze"

ExitDistance = {}
ExitDistance.__index = ExitDistance

function ExitDistance.new(maze)
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

-- How many cells must be walked through to get from this cell to the exit's cell. In a map drawn
-- by hand some cells may have no way to the exit at all: they count as one further than the farthest.
function ExitDistance:cells(column, row)
    return self.byCell[(row - 1) * self.maze.columns + column] or self.farthest + 1
end

-- From 0, as far from the exit as the maze allows, to 1, in the exit's own cell
function ExitDistance:proximity(x, y)
    local column, row = self.maze:nearestCell(x, y)
    return 1 - math.min(1, self:cells(column, row) / math.max(1, self.farthest))
end
