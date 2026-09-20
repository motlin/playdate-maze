-- A perfect maze of cells, stored as a grid of unit blocks so it can be raycast or drawn.
-- Walls are one block thick and corridors are corridorWidth blocks across: usually 1, so that
-- cell (column, row) is the single open block at grid (2 * column, 2 * row). Block (gridX, gridY)
-- covers world x in [gridX - 1, gridX) and y in [gridY - 1, gridY). North is -y, east is +x.
-- The exit is a door one block big, at floor level in the east wall of the last cell.

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

-- The first and last grid index a cell spans along one axis; `number` is its column or row
local function cellSpan(maze, number)
    local pitch = maze.corridorWidth + 1
    return (number - 1) * pitch + 2, number * pitch
end

function Maze.new(columns, rows, corridorWidth)
    corridorWidth = corridorWidth or 1
    local maze = setmetatable({
        columns = columns,
        rows = rows,
        corridorWidth = corridorWidth,
        gridWidth = columns * (corridorWidth + 1) + 1,
        gridHeight = rows * (corridorWidth + 1) + 1,
        blocks = {},
    }, Maze)
    local pitch = corridorWidth + 1
    for gridY = 1, maze.gridHeight do
        local line = {}
        for gridX = 1, maze.gridWidth do
            -- Wall lines run along every grid index that is one more than a multiple of the pitch
            local isCell = gridX % pitch ~= 1 and gridY % pitch ~= 1
            line[gridX] = isCell and OPEN or WALL
        end
        maze.blocks[gridY] = line
    end
    return maze
end

-- random(n) returns an integer from 1 to n, like math.random
function Maze.generate(columns, rows, random, corridorWidth)
    local maze = Maze.new(columns, rows, corridorWidth)
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
    local _, lastRowBottom = cellSpan(maze, rows)
    maze.exitGridX = maze.gridWidth
    maze.exitGridY = lastRowBottom
    maze.blocks[maze.exitGridY][maze.exitGridX] = DOOR
    return maze
end

-- The blocks of the wall between a cell and its neighbour: x from, x to, y from, y to
local function wallBetween(maze, column, row, direction)
    local offset = Maze.OFFSETS[direction]
    local left, right = cellSpan(maze, column)
    local top, bottom = cellSpan(maze, row)
    if offset[1] ~= 0 then
        local gridX = offset[1] > 0 and right + 1 or left - 1
        return gridX, gridX, top, bottom
    end
    local gridY = offset[2] > 0 and bottom + 1 or top - 1
    return left, right, gridY, gridY
end

function Maze:carve(column, row, direction)
    local offset = Maze.OFFSETS[direction]
    local nextColumn, nextRow = column + offset[1], row + offset[2]
    assert(
        nextColumn >= 1 and nextColumn <= self.columns and nextRow >= 1 and nextRow <= self.rows,
        "cannot carve through the outer wall"
    )
    local fromX, toX, fromY, toY = wallBetween(self, column, row, direction)
    for gridY = fromY, toY do
        for gridX = fromX, toX do self.blocks[gridY][gridX] = OPEN end
    end
end

function Maze:blockValue(gridX, gridY)
    local line = self.blocks[gridY]
    return line and line[gridX] or WALL
end

function Maze:isWall(gridX, gridY)
    local value = self:blockValue(gridX, gridY)
    return value == WALL or value == DOOR
end

-- A passage is as wide as the corridor, except the exit, which is only its last block: so look
-- at the last block of the wall, which is the bottom one of an east or west wall
function Maze:hasPassage(column, row, direction)
    local _, toX, _, toY = wallBetween(self, column, row, direction)
    return not self:isWall(toX, toY)
end

function Maze:openExit()
    self.blocks[self.exitGridY][self.exitGridX] = EXIT
end

function Maze:isExit(x, y)
    return self:blockValue(self:blockAt(x, y)) == EXIT
end

function Maze:cellCenter(column, row)
    local left, right = cellSpan(self, column)
    local top, bottom = cellSpan(self, row)
    return (left - 1 + right) / 2, (top - 1 + bottom) / 2
end

-- The block in the middle of a cell
function Maze:cellBlock(column, row)
    local left, right = cellSpan(self, column)
    local top, bottom = cellSpan(self, row)
    return (left + right) // 2, (top + bottom) // 2
end

function Maze:blockCenter(gridX, gridY)
    return gridX - 0.5, gridY - 0.5
end

function Maze:blockAt(x, y)
    return math.floor(x) + 1, math.floor(y) + 1
end

-- A wall or passage belongs with the cell before it up to its middle, and the next cell after
function Maze:nearestCell(x, y)
    local pitch = self.corridorWidth + 1
    local column = math.floor((x - 0.5) / pitch) + 1
    local row = math.floor((y - 0.5) / pitch) + 1
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

-- Every stretch of blocks along a row that can be walked through, as { startGridX, endGridX, gridY },
-- for drawing the maze from above or from the side with few shapes
function Maze:openRuns()
    local runs = {}
    for gridY = 1, self.gridHeight do
        local startGridX
        for gridX = 1, self.gridWidth + 1 do
            local isOpen = not self:isWall(gridX, gridY)
            if isOpen and not startGridX then startGridX = gridX end
            if not isOpen and startGridX then
                runs[#runs + 1] = { startGridX = startGridX, endGridX = gridX - 1, gridY = gridY }
                startGridX = nil
            end
        end
    end
    return runs
end

-- What is needed to build this maze again, in a form that can be saved
function Maze:toSave()
    return {
        columns = self.columns,
        rows = self.rows,
        corridorWidth = self.corridorWidth,
        blocks = self.blocks,
        exitGridX = self.exitGridX,
        exitGridY = self.exitGridY,
    }
end

function Maze.fromSave(save)
    local maze = Maze.new(save.columns, save.rows, save.corridorWidth)
    maze.blocks, maze.exitGridX, maze.exitGridY = save.blocks, save.exitGridX, save.exitGridY
    return maze
end
