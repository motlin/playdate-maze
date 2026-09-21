-- A maze being drawn by hand in the editor: which blocks are open, where the player starts, where
-- the exit is, and where the shapes and their pedestals stand. Anything not placed is scattered
-- when the map is played. It uses Maze's grid, with corridors one block wide, so a cell is the
-- block at (2 * column, 2 * row); but blocks can also be opened and filled one at a time, so a
-- design need not be a proper maze. problems() says what stops it being played.

import "Maze"

---@class MapDesignSave
---@field version integer
---@field columns integer
---@field rows integer
---@field blocks boolean[][]
---@field start GridPoint
---@field exit GridPoint?
---@field items table<string, GridPoint>
---@field pedestals table<string, GridPoint>

---@class MapDesign
---@field columns integer
---@field rows integer
---@field gridWidth integer
---@field gridHeight integer
---@field blocks boolean[][]
---@field start GridPoint
---@field exit GridPoint?
---@field items table<string, GridPoint>
---@field pedestals table<string, GridPoint>
MapDesign = {}
MapDesign.__index = MapDesign

MapDesign.SAVE_VERSION = 1
MapDesign.SHAPES = { "circle", "triangle", "square" }

local function newDesign(columns, rows)
    return setmetatable({
        columns = columns,
        rows = rows,
        gridWidth = 2 * columns + 1,
        gridHeight = 2 * rows + 1,
        -- true for an open block. The exit is kept apart, as it is a gate in the outer wall.
        blocks = {},
        start = { gridX = 2, gridY = 2 },
        exit = nil,
        items = {},
        pedestals = {},
    }, MapDesign)
end

-- Every cell walled in, ready to be carved
---@param columns integer
---@param rows integer
---@return MapDesign
function MapDesign.new(columns, rows)
    local design = newDesign(columns, rows)
    for gridY = 1, design.gridHeight do
        local line = {}
        for gridX = 1, design.gridWidth do line[gridX] = gridX % 2 == 0 and gridY % 2 == 0 end
        design.blocks[gridY] = line
    end
    return design
end

-- A copy of a generated maze to start from, with its exit
---@param maze Maze
---@return MapDesign
function MapDesign.fromMaze(maze)
    assert(maze.corridorWidth == 1, "a design has corridors one block wide")
    local design = newDesign(maze.columns, maze.rows)
    for gridY = 1, design.gridHeight do
        local line = {}
        for gridX = 1, design.gridWidth do line[gridX] = maze:blockValue(gridX, gridY) == Maze.BLOCKS.OPEN end
        design.blocks[gridY] = line
    end
    design.exit = { gridX = maze.exitGridX, gridY = maze.exitGridY }
    return design
end

---@param gridX integer
---@param gridY integer
---@return boolean
function MapDesign:isInside(gridX, gridY)
    return gridX > 1 and gridX < self.gridWidth and gridY > 1 and gridY < self.gridHeight
end

---@param gridX integer
---@param gridY integer
---@return boolean
function MapDesign:isOpen(gridX, gridY)
    local line = self.blocks[gridY]
    return line ~= nil and line[gridX] == true
end

local function isAt(place, gridX, gridY)
    return place ~= nil and place.gridX == gridX and place.gridY == gridY
end

-- What stands on a block: "start", "exit", or "item" or "pedestal" with its shape; or nil
---@param gridX integer
---@param gridY integer
---@return string?, string?
function MapDesign:thingAt(gridX, gridY)
    if isAt(self.start, gridX, gridY) then return "start" end
    if isAt(self.exit, gridX, gridY) then return "exit" end
    for _, shape in ipairs(MapDesign.SHAPES) do
        if isAt(self.items[shape], gridX, gridY) then return "item", shape end
        if isAt(self.pedestals[shape], gridX, gridY) then return "pedestal", shape end
    end
    return nil
end

-- The block just inside the outer wall from a block of it, or nil for a corner or an inside block
---@param gridX integer
---@param gridY integer
---@return integer?, integer?
function MapDesign:blockInsideWall(gridX, gridY)
    local isOnSide = (gridX == 1 or gridX == self.gridWidth) and gridY > 1 and gridY < self.gridHeight
    local isOnEnd = (gridY == 1 or gridY == self.gridHeight) and gridX > 1 and gridX < self.gridWidth
    if isOnSide then return gridX == 1 and 2 or gridX - 1, gridY end
    if isOnEnd then return gridX, gridY == 1 and 2 or gridY - 1 end
    return nil
end

-- Opens or fills one block. Returns whether it could: the outer wall is never opened, and a block
-- is never filled while something stands on it or it is the way in to the exit.
---@param gridX integer
---@param gridY integer
---@param isOpen boolean
---@return boolean
function MapDesign:setBlock(gridX, gridY, isOpen)
    if not self:isInside(gridX, gridY) then return false end
    if not isOpen then
        if self:thingAt(gridX, gridY) then return false end
        if self.exit and isAt({ gridX = gridX, gridY = gridY }, self:blockInsideWall(self.exit.gridX, self.exit.gridY)) then
            return false
        end
    end
    self.blocks[gridY][gridX] = isOpen
    return true
end

local function passageBlock(column, row, direction)
    local offset = Maze.OFFSETS[direction]
    return 2 * column + offset[1], 2 * row + offset[2]
end

---@param column integer
---@param row integer
---@param direction string
---@return boolean
function MapDesign:hasPassage(column, row, direction)
    return self:isOpen(passageBlock(column, row, direction))
end

-- Knocks through, or builds back, the wall between a cell and its neighbour
---@param column integer
---@param row integer
---@param direction string
---@param isOpen boolean
---@return boolean
function MapDesign:setPassage(column, row, direction, isOpen)
    local gridX, gridY = passageBlock(column, row, direction)
    return self:setBlock(gridX, gridY, isOpen)
end

local function forget(self, kind, shape)
    if kind == "item" then self.items[shape] = nil end
    if kind == "pedestal" then self.pedestals[shape] = nil end
    if kind == "exit" then self.exit = nil end
end

-- Puts the start, the exit, or a shape's item or pedestal on a block, moving it if it was
-- somewhere else. Returns whether it could.
---@param kind string
---@param shape string?
---@param gridX integer
---@param gridY integer
---@return boolean
function MapDesign:place(kind, shape, gridX, gridY)
    local there, shapeThere = self:thingAt(gridX, gridY)
    local isSameThing = there == kind and shapeThere == shape
    if there and not isSameThing then return false end

    if kind == "exit" then
        local insideX, insideY = self:blockInsideWall(gridX, gridY)
        if not insideX then return false end
        -- blockInsideWall returns both coordinates together.
        ---@cast insideY integer
        if not self:isOpen(insideX, insideY) then return false end
        self.exit = { gridX = gridX, gridY = gridY }
        return true
    end

    if not self:isInside(gridX, gridY) or not self:isOpen(gridX, gridY) then return false end
    local place = { gridX = gridX, gridY = gridY }
    if kind == "start" then
        self.start = place
    elseif kind == "item" then
        self.items[shape] = place
    elseif kind == "pedestal" then
        self.pedestals[shape] = place
    else
        error("there is no such thing to place as " .. tostring(kind))
    end
    return true
end

-- Takes away whatever stands on a block. The start can only be moved, never taken away.
---@param gridX integer
---@param gridY integer
---@return boolean
function MapDesign:remove(gridX, gridY)
    local kind, shape = self:thingAt(gridX, gridY)
    if not kind or kind == "start" then return false end
    forget(self, kind, shape)
    return true
end

local function key(gridX, gridY)
    return gridY * 256 + gridX
end

-- The open blocks that can be walked to from the start, as a set keyed by key(gridX, gridY)
---@return table<integer, boolean>
function MapDesign:reachable()
    local seen = { [key(self.start.gridX, self.start.gridY)] = true }
    local queue, head = { self.start }, 1
    while head <= #queue do
        local block = queue[head]
        head = head + 1
        for _, direction in ipairs(Maze.DIRECTIONS) do
            local offset = Maze.OFFSETS[direction]
            local gridX, gridY = block.gridX + offset[1], block.gridY + offset[2]
            if self:isOpen(gridX, gridY) and not seen[key(gridX, gridY)] then
                seen[key(gridX, gridY)] = true
                queue[#queue + 1] = { gridX = gridX, gridY = gridY }
            end
        end
    end
    return seen
end

-- The cells that scattering may use: open, reachable, and with nothing on them. A list of
-- { gridX, gridY } in reading order.
---@return GridPoint[]
function MapDesign:freeCells()
    local reachable, cells = self:reachable(), {}
    for row = 1, self.rows do
        for column = 1, self.columns do
            local gridX, gridY = 2 * column, 2 * row
            if reachable[key(gridX, gridY)] and not self:thingAt(gridX, gridY) then
                cells[#cells + 1] = { gridX = gridX, gridY = gridY }
            end
        end
    end
    return cells
end

-- What stops this map being played, as sentences for the player; empty when it is ready
---@return string[]
function MapDesign:problems()
    local problems, reachable = {}, self:reachable()
    if not self.exit then
        problems[#problems + 1] = "There is no exit"
    else
        local insideX, insideY = self:blockInsideWall(self.exit.gridX, self.exit.gridY)
        if not reachable[key(insideX, insideY)] then problems[#problems + 1] = "The exit cannot be reached" end
    end

    local unplaced = 0
    for _, shape in ipairs(MapDesign.SHAPES) do
        local item, pedestal = self.items[shape], self.pedestals[shape]
        if not item then
            unplaced = unplaced + 1
        elseif not reachable[key(item.gridX, item.gridY)] then
            problems[#problems + 1] = "The " .. shape .. " cannot be reached"
        end
        if not pedestal then
            unplaced = unplaced + 1
        elseif not reachable[key(pedestal.gridX, pedestal.gridY)] then
            problems[#problems + 1] = "The " .. shape .. "'s pedestal cannot be reached"
        end
    end
    if unplaced > #self:freeCells() then problems[#problems + 1] = "There is not room to scatter what is not placed" end
    return problems
end

-- Lists and named entries only, so that it can be written as JSON
---@return MapDesignSave
function MapDesign:toSave()
    return {
        version = MapDesign.SAVE_VERSION,
        columns = self.columns,
        rows = self.rows,
        blocks = self.blocks,
        start = self.start,
        exit = self.exit,
        items = self.items,
        pedestals = self.pedestals,
    }
end

---@param save MapDesignSave
---@return MapDesign
function MapDesign.fromSave(save)
    assert(save.version == MapDesign.SAVE_VERSION, "this map is version " .. tostring(save.version) .. ", which this game cannot load")
    local design = newDesign(save.columns, save.rows)
    design.blocks, design.start, design.exit = save.blocks, save.start, save.exit
    design.items, design.pedestals = save.items, save.pedestals
    return design
end
