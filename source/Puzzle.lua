-- The way out: three shapes lie around the maze and each has a pedestal somewhere else.
-- The player carries one shape at a time. Standing every shape on its own pedestal solves it.
-- Shapes and pedestals sit in the middle of a block, given as gridX, gridY.

Puzzle = {}
Puzzle.__index = Puzzle

Puzzle.SHAPES = { "circle", "triangle", "square" }
Puzzle.STATES = { GROUND = "ground", CARRIED = "carried", PLACED = "placed" }
Puzzle.RESULTS = { DROPPED = "dropped", PLACED = "placed", BLOCKED = "blocked" }
-- How far the player can reach, in blocks. Cells are two blocks apart, so nothing can be
-- reached through a wall.
Puzzle.REACH = 1.25

local GROUND <const> = Puzzle.STATES.GROUND
local CARRIED <const> = Puzzle.STATES.CARRIED
local PLACED <const> = Puzzle.STATES.PLACED
local REACH <const> = Puzzle.REACH

-- items and pedestals are lists of { shape, gridX, gridY }
function Puzzle.new(items, pedestals)
    for _, item in ipairs(items) do item.state = GROUND end
    for _, pedestal in ipairs(pedestals) do pedestal.isFilled = false end
    return setmetatable({ items = items, pedestals = pedestals, carried = nil }, Puzzle)
end

-- random(n) returns an integer from 1 to n, like math.random
function Puzzle.scatter(maze, random)
    local cells = {}
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            local isStart = column == 1 and row == 1
            if not isStart then cells[#cells + 1] = { column, row } end
        end
    end
    assert(#cells >= 2 * #Puzzle.SHAPES, "the maze is too small to hold every shape and pedestal")
    for index = #cells, 2, -1 do
        local other = random(index)
        cells[index], cells[other] = cells[other], cells[index]
    end

    local items, pedestals = {}, {}
    for index, shape in ipairs(Puzzle.SHAPES) do
        local itemCell, pedestalCell = cells[2 * index - 1], cells[2 * index]
        items[index] = { shape = shape, gridX = 2 * itemCell[1], gridY = 2 * itemCell[2] }
        pedestals[index] = { shape = shape, gridX = 2 * pedestalCell[1], gridY = 2 * pedestalCell[2] }
    end
    return Puzzle.new(items, pedestals)
end

local function distanceTo(thing, x, y)
    local offsetX, offsetY = thing.gridX - 0.5 - x, thing.gridY - 0.5 - y
    return math.sqrt(offsetX * offsetX + offsetY * offsetY)
end

-- The shape A would pick up from here, if any
function Puzzle:itemInReach(x, y)
    if self.carried then return nil end
    local nearest, nearestDistance = nil, REACH
    for _, item in ipairs(self.items) do
        local distance = distanceTo(item, x, y)
        if item.state == GROUND and distance <= nearestDistance then
            nearest, nearestDistance = item, distance
        end
    end
    return nearest
end

function Puzzle:pickUp(x, y)
    local item = self:itemInReach(x, y)
    if not item then return nil end
    item.state = CARRIED
    self.carried = item
    return item
end

-- The carried shape's own empty pedestal, if it is close enough to put the shape on
function Puzzle:pedestalInReach(x, y)
    if not self.carried then return nil end
    for _, pedestal in ipairs(self.pedestals) do
        local isMatch = pedestal.shape == self.carried.shape and not pedestal.isFilled
        if isMatch and distanceTo(pedestal, x, y) <= REACH then return pedestal end
    end
    return nil
end

local function isOccupied(self, gridX, gridY)
    for _, pedestal in ipairs(self.pedestals) do
        if pedestal.gridX == gridX and pedestal.gridY == gridY then return true end
    end
    for _, item in ipairs(self.items) do
        if item.state == GROUND and item.gridX == gridX and item.gridY == gridY then return true end
    end
    return false
end

-- Returns one of Puzzle.RESULTS, or nil when nothing is being carried
function Puzzle:drop(x, y)
    local item = self.carried
    if not item then return nil end

    local pedestal = self:pedestalInReach(x, y)
    if pedestal then
        pedestal.isFilled = true
        item.gridX, item.gridY, item.state = pedestal.gridX, pedestal.gridY, PLACED
        self.carried = nil
        return Puzzle.RESULTS.PLACED
    end

    local gridX, gridY = math.floor(x) + 1, math.floor(y) + 1
    if isOccupied(self, gridX, gridY) then return Puzzle.RESULTS.BLOCKED end
    item.gridX, item.gridY, item.state = gridX, gridY, GROUND
    self.carried = nil
    return Puzzle.RESULTS.DROPPED
end

function Puzzle:isSolved()
    for _, pedestal in ipairs(self.pedestals) do
        if not pedestal.isFilled then return false end
    end
    return true
end
