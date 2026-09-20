-- The spinning things from the Windows 95 maze that turn the world upside down when touched.
-- Each sits in the middle of a block. One that has been touched does nothing more until the
-- player has walked well away, so the world does not flicker while they stand in it.

Flippers = {}
Flippers.__index = Flippers

-- How near the middle counts as touching, and how far away the player must go to touch it again
Flippers.TOUCH = 0.4
Flippers.REARM = 1

-- Mazes with at least this many cells get a second flipper
local CELLS_FOR_TWO <const> = 40

-- taken is a list of things with gridX and gridY whose blocks are already in use.
-- random(n) is like math.random.
function Flippers.scatter(maze, random, taken)
    local isTaken = {}
    for _, thing in ipairs(taken) do isTaken[thing.gridY * 256 + thing.gridX] = true end
    local free = {}
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            local gridX, gridY = maze:cellBlock(column, row)
            local isStart = column == 1 and row == 1
            if not isStart and not isTaken[gridY * 256 + gridX] then free[#free + 1] = { gridX = gridX, gridY = gridY } end
        end
    end
    local count = math.min(#free, maze.columns * maze.rows >= CELLS_FOR_TWO and 2 or 1)
    local flippers = setmetatable({ all = {} }, Flippers)
    for index = 1, count do
        local flipper = table.remove(free, random(#free))
        flipper.isArmed = true
        flippers.all[index] = flipper
    end
    return flippers
end

-- Call every frame with the player's position. Returns whether a flipper was just touched.
function Flippers:touch(x, y)
    local wasTouched = false
    for _, flipper in ipairs(self.all) do
        local offsetX, offsetY = flipper.gridX - 0.5 - x, flipper.gridY - 0.5 - y
        local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
        if flipper.isArmed and distance < Flippers.TOUCH then
            flipper.isArmed = false
            wasTouched = true
        elseif not flipper.isArmed and distance > Flippers.REARM then
            flipper.isArmed = true
        end
    end
    return wasTouched
end

-- Flippers again from their saved list, which is `all`
function Flippers.fromSave(all)
    return setmetatable({ all = all }, Flippers)
end
