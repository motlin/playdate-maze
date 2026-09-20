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
-- How near the middle of a shape counts as touching it
Puzzle.TOUCH = 0.45

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

-- Every cell but the first, in a random order. random(n) is like math.random.
local function shuffledCells(maze, random)
    local cells = {}
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            local isStart = column == 1 and row == 1
            if not isStart then cells[#cells + 1] = { column, row } end
        end
    end
    for index = #cells, 2, -1 do
        local other = random(index)
        cells[index], cells[other] = cells[other], cells[index]
    end
    return cells
end

local function inCell(maze, shape, cell)
    local gridX, gridY = maze:cellBlock(cell[1], cell[2])
    return { shape = shape, gridX = gridX, gridY = gridY }
end

-- A shape and a pedestal for each of Puzzle.SHAPES, every one in a cell of its own
function Puzzle.scatter(maze, random)
    local cells = shuffledCells(maze, random)
    assert(#cells >= 2 * #Puzzle.SHAPES, "the maze is too small to hold every shape and pedestal")
    local items, pedestals = {}, {}
    for index, shape in ipairs(Puzzle.SHAPES) do
        items[index] = inCell(maze, shape, cells[2 * index - 1])
        pedestals[index] = inCell(maze, shape, cells[2 * index])
    end
    return Puzzle.new(items, pedestals)
end

-- Only the shapes, for a mode where they are collected rather than carried home
function Puzzle.scatterItems(maze, random)
    local cells = shuffledCells(maze, random)
    assert(#cells >= #Puzzle.SHAPES, "the maze is too small to hold every shape")
    local items = {}
    for index, shape in ipairs(Puzzle.SHAPES) do items[index] = inCell(maze, shape, cells[index]) end
    return Puzzle.new(items, {})
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

-- The shape the player's body is touching, for modes that collect by contact
function Puzzle:itemTouching(x, y)
    for _, item in ipairs(self.items) do
        if item.state == GROUND and distanceTo(item, x, y) <= Puzzle.TOUCH then return item end
    end
    return nil
end

-- Takes a shape out of the maze for good, as placing it on a pedestal does
function Puzzle:collect(item)
    assert(item.state == GROUND, "only a shape lying in the maze can be collected")
    item.state = PLACED
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

-- Solved once no shape is left lying around or in hand
function Puzzle:isSolved()
    for _, item in ipairs(self.items) do
        if item.state ~= PLACED then return false end
    end
    return true
end
