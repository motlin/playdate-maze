-- Keeps one game on the Playdate's disk, so a run can be carried on after the console sleeps or
-- the game is closed. Only mazes with a puzzle are kept: the screensaver has nothing to lose.

import "Game"
import "SaveData"
import "Sizes"

---@class SaveGame
SaveGame = {}

SaveGame.FILE = "run"

---@return boolean
function SaveGame.exists() return SaveGame.read() ~= nil end

-- Keep the on-disk "mode" key so existing saves retain their first-person submode.
---@param game Game
---@param submode string
---@param sizeIndex integer
---@return nil
function SaveGame.write(game, submode, sizeIndex)
    playdate.datastore.write({ game = game:toSave(), mode = submode, sizeIndex = sizeIndex }, SaveGame.FILE)
end

---@return nil
function SaveGame.delete() playdate.datastore.delete(SaveGame.FILE) end

-- Validate external data before calling constructors; programming errors in those constructors
-- still propagate instead of silently deleting an otherwise readable save.
local function number(value) return type(value) == "number" and value > -math.huge and value < math.huge end
local function integer(value) return number(value) and value % 1 == 0 end
local function positive(value) return integer(value) and value > 0 end
local function boolean(value) return type(value) == "boolean" end
local function record(value, fields)
    if type(value) ~= "table" then return false end
    for key, valid in pairs(fields) do
        if not valid(value[key]) then return false end
    end
    return true
end
local function list(value, valid)
    if type(value) ~= "table" then return false end
    local count = 0
    for key, item in pairs(value) do
        if not positive(key) or not valid(item) then return false end
        count = count + 1
    end
    return count == #value
end
local function point(value) return record(value, { x = number, y = number }) end
local function gridPoint(value) return record(value, { gridX = positive, gridY = positive }) end
local function shape(value) return value == "circle" or value == "triangle" or value == "square" end
local function item(value)
    return gridPoint(value)
        and shape(value.shape)
        and (value.state == "ground" or value.state == "carried" or value.state == "placed")
end
local function pedestal(value) return gridPoint(value) and shape(value.shape) and boolean(value.isFilled) end
local function puzzle(value)
    return type(value) == "table"
        and list(value.items, item)
        and list(value.pedestals, pedestal)
        and #value.items == 3
        and #value.pedestals == 3
        and integer(value.carriedIndex)
        and value.carriedIndex >= 0
        and value.carriedIndex <= #value.items
end
local function landmark(value)
    if not gridPoint(value) or not record(value, { column = positive, row = positive, motif = positive }) then
        return false
    end
    if value.kind == "picture" then return positive(value.face) and value.face <= 4 end
    return value.kind == "floor" or value.kind == "ceiling"
end
local function flipper(value) return gridPoint(value) and boolean(value.isArmed) end
local function maze(value)
    if not record(value, { columns = positive, rows = positive, exitGridX = positive, exitGridY = positive }) then
        return false
    end
    -- Older version-one saves omit corridorWidth, which Maze.fromSave defaults to one.
    local width = value.corridorWidth
    if width == nil then width = 1 end
    if not positive(width) then return false end
    local gridWidth, gridHeight = value.columns * (width + 1) + 1, value.rows * (width + 1) + 1
    local function block(cell) return integer(cell) and cell >= 0 and cell <= 3 end
    local function row(cells) return list(cells, block) and #cells == gridWidth end
    return list(value.blocks, row)
        and #value.blocks == gridHeight
        and value.exitGridX <= gridWidth
        and value.exitGridY <= gridHeight
end
local function game(value)
    return record(value, {
        maze = maze,
        player = function(player) return point(player) and number(player.angle) end,
        puzzle = puzzle,
        landmarks = function(all) return list(all, landmark) end,
        flippers = function(all) return list(all, flipper) end,
        thread = function(points) return list(points, point) and #points > 0 end,
        visited = function(keys) return list(keys, positive) end,
        frames = function(frames) return integer(frames) and frames >= 0 end,
        isFlipped = boolean,
        isGateUnlocked = boolean,
        gateDegrees = number,
    }) and value.version == Game.SAVE_VERSION and (value.isHandMade == nil or boolean(value.isHandMade))
end
local function envelope(save)
    return type(save) == "table"
        and game(save.game)
        and (save.mode == "explore" or save.mode == "daily" or save.mode == "custom")
        and positive(save.sizeIndex)
        and save.sizeIndex <= #Sizes.ALL
end

-- Returns the game, its first-person submode, and its size, or nil if there is no saved game.
-- A save from a version of the game that cannot read it is thrown away: an update to the game
-- must never leave the player with a Continue that crashes.
---@return Game?, string?, integer?
function SaveGame.read()
    local save = playdate.datastore.read(SaveGame.FILE)
    if save == nil then return nil end
    if not envelope(save) then
        SaveGame.delete()
        return nil
    end
    local restored = Game.fromSave(SaveData.copy(save.game))
    if not restored then
        SaveGame.delete()
        return nil
    end
    return restored, save.mode, save.sizeIndex
end
