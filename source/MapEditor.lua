-- The hands of the map editor: a cursor on a MapDesign, a dial of tools, and what adding (A) and
-- removing (B) do with each tool, still or on the move. It draws nothing and reads no buttons, so
-- the editor's screen is a thin shell over it. `message` is what the last action has to say.

import "MapDesign"
import "Maze"

---@class EditorTool
---@field name string
---@field label string
---@field hint string
---@field kind? string
---@field shape? string

---@class MapEditor
---@field design MapDesign
---@field cursorX integer
---@field cursorY integer
---@field toolIndex integer
---@field message string?
---@field hasUnsavedChanges boolean
MapEditor = {}
MapEditor.__index = MapEditor

-- In the order the dial turns. `kind` and `shape` are what MapDesign:place is given.
local PLACING_HINT <const> = "Ⓐ place here\nⒷ take away"
MapEditor.TOOLS = {
    {
        name = "cells",
        label = "Walls between cells",
        hint = "Hold Ⓐ and move to carve\nHold Ⓑ and push to wall up",
    },
    { name = "blocks", label = "Single blocks", hint = "Ⓐ open  Ⓑ fill\nHold either to paint" },
    { name = "start", label = "Start", kind = "start", hint = "Ⓐ start here" },
    { name = "exit", label = "Exit", kind = "exit", hint = "Ⓐ in the outer wall\nⒷ take away" },
    { name = "circle", label = "Circle", kind = "item", shape = "circle", hint = PLACING_HINT },
    { name = "triangle", label = "Triangle", kind = "item", shape = "triangle", hint = PLACING_HINT },
    { name = "square", label = "Square", kind = "item", shape = "square", hint = PLACING_HINT },
    { name = "circle pedestal", label = "Circle's pedestal", kind = "pedestal", shape = "circle", hint = PLACING_HINT },
    {
        name = "triangle pedestal",
        label = "Triangle's pedestal",
        kind = "pedestal",
        shape = "triangle",
        hint = PLACING_HINT,
    },
    { name = "square pedestal", label = "Square's pedestal", kind = "pedestal", shape = "square", hint = PLACING_HINT },
}

local DIRECTIONS <const> = { ["1,0"] = "east", ["-1,0"] = "west", ["0,1"] = "south", ["0,-1"] = "north" }

---@param design MapDesign
---@return MapEditor
function MapEditor.new(design)
    return setmetatable({
        design = design,
        cursorX = design.start.gridX,
        cursorY = design.start.gridY,
        toolIndex = 1,
        message = nil,
        hasUnsavedChanges = false,
    }, MapEditor)
end

-- Replacing a drawing starts at its entrance with the cells tool, and needs saving.
---@param random Random
---@return nil
function MapEditor:generateMaze(random)
    self.design = MapDesign.fromMaze(Maze.generate(self.design.columns, self.design.rows, random))
    self.cursorX, self.cursorY = self.design.start.gridX, self.design.start.gridY
    self.toolIndex = 1
    self.message = "A new maze to alter"
    self.hasUnsavedChanges = true
end

-- A failed play attempt explains the problem without changing the drawing's save state.
---@return MapDesign?
function MapEditor:designToPlay()
    local problem = self.design:problems()[1]
    if problem then
        self.message = problem
        return nil
    end
    return self.design
end

---@return EditorTool
function MapEditor:tool() return MapEditor.TOOLS[self.toolIndex] end

-- The nearest cell's block along one axis: cells are the even blocks inside the outer wall
local function nearestCellBlock(value, gridSize)
    return math.max(2, math.min(gridSize - 1, 2 * math.floor(value / 2 + 0.5)))
end

---@param steps integer
---@return nil
function MapEditor:turnTool(steps)
    self.toolIndex = (self.toolIndex - 1 + steps) % #MapEditor.TOOLS + 1
    -- The cells tool's cursor lives on cells
    if self:tool().name == "cells" then
        self.cursorX = nearestCellBlock(self.cursorX, self.design.gridWidth)
        self.cursorY = nearestCellBlock(self.cursorY, self.design.gridHeight)
    end
end

---@return nil
function MapEditor:markSaved() self.hasUnsavedChanges = false end

-- Records the outcome of trying to change the design
local function changed(self, didChange, message)
    if didChange then self.hasUnsavedChanges = true end
    self.message = message
    return didChange
end

local function setBlock(self, gridX, gridY, isOpen)
    local design = self.design
    if design:isOpen(gridX, gridY) == isOpen and design:isInside(gridX, gridY) then return false end
    if design:setBlock(gridX, gridY, isOpen) then return changed(self, true, nil) end
    if not design:isInside(gridX, gridY) then return changed(self, false, "The outer wall stays solid") end
    if design:thingAt(gridX, gridY) then return changed(self, false, "Something is standing there") end
    return changed(self, false, "That block is the way in to the exit")
end

-- Moves the cursor a step. isAdding and isRemoving say whether A or B is held as it moves.
---@param stepX integer
---@param stepY integer
---@param isAdding boolean?
---@param isRemoving boolean?
---@return nil
function MapEditor:move(stepX, stepY, isAdding, isRemoving)
    local design = self.design
    if self:tool().name == "cells" then
        local column, row = self.cursorX // 2, self.cursorY // 2
        local nextColumn, nextRow = column + stepX, row + stepY
        local isInside = nextColumn >= 1 and nextColumn <= design.columns and nextRow >= 1 and nextRow <= design.rows
        if not isInside then return end
        local direction = DIRECTIONS[stepX .. "," .. stepY]
        if isRemoving then
            -- Pushing at a wall with B builds it back, without stepping through
            setBlock(self, 2 * column + stepX, 2 * row + stepY, false)
            return
        end
        -- Moving with A held carves the way through
        if isAdding and design:setPassage(column, row, direction, true) then self.hasUnsavedChanges = true end
        self.cursorX, self.cursorY = 2 * nextColumn, 2 * nextRow
        return
    end

    self.cursorX = math.max(1, math.min(design.gridWidth, self.cursorX + stepX))
    self.cursorY = math.max(1, math.min(design.gridHeight, self.cursorY + stepY))
    if self:tool().name == "blocks" then
        if isAdding then setBlock(self, self.cursorX, self.cursorY, true) end
        if isRemoving then setBlock(self, self.cursorX, self.cursorY, false) end
    end
end

local function nameOf(kind, shape)
    if kind == "item" then return "the " .. shape end
    if kind == "pedestal" then return "the " .. shape .. "'s pedestal" end
    return "the " .. kind
end

-- A, pressed where the cursor stands
---@return nil
function MapEditor:add()
    local tool, design = self:tool(), self.design
    if tool.name == "cells" then return end
    if tool.name == "blocks" then
        setBlock(self, self.cursorX, self.cursorY, true)
        return
    end
    if design:place(tool.kind, tool.shape, self.cursorX, self.cursorY) then
        changed(self, true, "Placed " .. nameOf(tool.kind, tool.shape))
    elseif tool.kind == "exit" then
        changed(self, false, "The exit goes in the outer wall, beside an open block")
    elseif design:thingAt(self.cursorX, self.cursorY) then
        changed(self, false, "Something is already there")
    else
        changed(self, false, "That is a wall")
    end
end

-- B, pressed where the cursor stands
---@return nil
function MapEditor:remove()
    local design = self.design
    if self:tool().name == "cells" then return end
    if self:tool().name == "blocks" then
        setBlock(self, self.cursorX, self.cursorY, false)
        return
    end
    local kind, shape = design:thingAt(self.cursorX, self.cursorY)
    if kind == "start" then
        changed(self, false, "The start can be moved, not removed")
    elseif kind then
        design:remove(self.cursorX, self.cursorY)
        changed(self, true, "Removed " .. nameOf(kind, shape))
    end
end

-- One line on whether the map can be played yet
---@return string
function MapEditor:status() return self.design:problems()[1] or "Ready to play" end
