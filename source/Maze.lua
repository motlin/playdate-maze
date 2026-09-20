-- A perfect maze of cells, stored as a grid of unit blocks so it can be raycast.
-- Cell (column, row) is the open block at grid (2 * column, 2 * row); the blocks between cells
-- are either wall or a carved passage. Block (gridX, gridY) covers world x in
-- [gridX - 1, gridX) and y in [gridY - 1, gridY). North is -y, east is +x.
-- The exit is a door in the east wall of the last cell.

Maze = {}
Maze.__index = Maze

Maze.BLOCKS = { OPEN = 0, WALL = 1, DOOR = 2, EXIT = 3 }
Maze.DIRECTIONS = { "north", "east", "south", "west" }
Maze.OFFSETS = {
    north = { 0, -1 },
    east = { 1, 0 },
    south = { 0, 1 },
    west = { -1, 0 },
}

local OPEN <const> = Maze.BLOCKS.OPEN
local WALL <const> = Maze.BLOCKS.WALL
local DOOR <const> = Maze.BLOCKS.DOOR
local EXIT <const> = Maze.BLOCKS.EXIT

function Maze.new(columns, rows)
    local maze = setmetatable({
        columns = columns,
        rows = rows,
        gridWidth = 2 * columns + 1,
        gridHeight = 2 * rows + 1,
        blocks = {},
    }, Maze)
    for gridY = 1, maze.gridHeight do
        local line = {}
        for gridX = 1, maze.gridWidth do
            local isCell = gridX % 2 == 0 and gridY % 2 == 0
            line[gridX] = isCell and OPEN or WALL
        end
        maze.blocks[gridY] = line
    end
    return maze
end

-- random(n) returns an integer from 1 to n, like math.random
function Maze.generate(columns, rows, random)
    local maze = Maze.new(columns, rows)
    local visited = { [1] = true }
    local stack = { { 1, 1 } }
    while #stack > 0 do
        local column, row = stack[#stack][1], stack[#stack][2]
        local unvisited = {}
        for _, direction in ipairs(Maze.DIRECTIONS) do
            local nextColumn = column + Maze.OFFSETS[direction][1]
            local nextRow = row + Maze.OFFSETS[direction][2]
            local isInside = nextColumn >= 1 and nextColumn <= columns and nextRow >= 1 and nextRow <= rows
            if isInside and not visited[(nextRow - 1) * columns + nextColumn] then
                unvisited[#unvisited + 1] = direction
            end
        end
        if #unvisited == 0 then
            stack[#stack] = nil
        else
            local direction = unvisited[random(#unvisited)]
            maze:carve(column, row, direction)
            local nextColumn = column + Maze.OFFSETS[direction][1]
            local nextRow = row + Maze.OFFSETS[direction][2]
            visited[(nextRow - 1) * columns + nextColumn] = true
            stack[#stack + 1] = { nextColumn, nextRow }
        end
    end
    maze.exitGridX = maze.gridWidth
    maze.exitGridY = 2 * rows
    maze.blocks[maze.exitGridY][maze.exitGridX] = DOOR
    return maze
end

function Maze:carve(column, row, direction)
    local offset = Maze.OFFSETS[direction]
    local nextColumn, nextRow = column + offset[1], row + offset[2]
    assert(
        nextColumn >= 1 and nextColumn <= self.columns and nextRow >= 1 and nextRow <= self.rows,
        "cannot carve through the outer wall"
    )
    self.blocks[2 * row + offset[2]][2 * column + offset[1]] = OPEN
end

function Maze:blockValue(gridX, gridY)
    local line = self.blocks[gridY]
    return line and line[gridX] or WALL
end

function Maze:isWall(gridX, gridY)
    local value = self:blockValue(gridX, gridY)
    return value == WALL or value == DOOR
end

function Maze:hasPassage(column, row, direction)
    local offset = Maze.OFFSETS[direction]
    return not self:isWall(2 * column + offset[1], 2 * row + offset[2])
end

function Maze:openExit()
    self.blocks[self.exitGridY][self.exitGridX] = EXIT
end

function Maze:isExit(x, y)
    return self:blockValue(self:blockAt(x, y)) == EXIT
end

function Maze:cellCenter(column, row)
    return 2 * column - 0.5, 2 * row - 0.5
end

function Maze:blockCenter(gridX, gridY)
    return gridX - 0.5, gridY - 0.5
end

function Maze:blockAt(x, y)
    return math.floor(x) + 1, math.floor(y) + 1
end

function Maze:nearestCell(x, y)
    local column = math.floor((x + 0.5) / 2 + 0.5)
    local row = math.floor((y + 0.5) / 2 + 0.5)
    return math.max(1, math.min(self.columns, column)), math.max(1, math.min(self.rows, row))
end

function Maze:deadEnds()
    local deadEnds = {}
    for row = 1, self.rows do
        for column = 1, self.columns do
            local passages = 0
            for _, direction in ipairs(Maze.DIRECTIONS) do
                if self:hasPassage(column, row, direction) then passages = passages + 1 end
            end
            if passages == 1 then deadEnds[#deadEnds + 1] = { column, row } end
        end
    end
    return deadEnds
end
