-- Walks the player through the maze like a screensaver, keeping its left hand on the wall.
-- A perfect maze is a tree, so following one wall visits every cell. Each update() moves the
-- player by one frame: first to the middle of the nearest cell, then turn, walk a cell, repeat.

Autopilot = {}
Autopilot.__index = Autopilot

Autopilot.WALK_SPEED = 0.08
Autopilot.TURN_SPEED = 6

local WALK_SPEED <const> = Autopilot.WALK_SPEED
local TURN_SPEED <const> = Autopilot.TURN_SPEED
local ANGLES <const> = { east = 0, south = 90, west = 180, north = 270 }
local CLOCKWISE <const> = { "north", "east", "south", "west" }
local CLOCKWISE_INDEX <const> = { north = 1, east = 2, south = 3, west = 4 }
-- Quarter turns clockwise from the way it faces, in order of preference: left, ahead, right, back
local PREFERENCE <const> = { -1, 0, 1, 2 }

function Autopilot.chooseDirection(maze, column, row, facing)
    for _, quarterTurns in ipairs(PREFERENCE) do
        local direction = CLOCKWISE[(CLOCKWISE_INDEX[facing] - 1 + quarterTurns) % 4 + 1]
        if maze:hasPassage(column, row, direction) then return direction end
    end
    error("cell " .. column .. "," .. row .. " has no way out")
end

function Autopilot.new(maze, player)
    local column, row = maze:nearestCell(player.x, player.y)
    local autopilot = setmetatable({ maze = maze, player = player, column = column, row = row }, Autopilot)
    autopilot.targetX, autopilot.targetY = maze:cellCenter(column, row)
    return autopilot
end

function Autopilot:update()
    local player = self.player
    local offsetX, offsetY = self.targetX - player.x, self.targetY - player.y
    local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
    if distance > 0 then
        if distance <= WALK_SPEED then
            player.x, player.y = self.targetX, self.targetY
        else
            player.x = player.x + offsetX / distance * WALK_SPEED
            player.y = player.y + offsetY / distance * WALK_SPEED
        end
        return
    end

    if not self.direction then
        self.direction = Autopilot.chooseDirection(self.maze, self.column, self.row, player:facing())
    end
    -- The shortest way round to the chosen direction, from -180 up to but not including 180,
    -- so that turning back at a dead end always goes left
    local turn = (ANGLES[self.direction] - player.angle + 180) % 360 - 180
    if turn ~= 0 then
        player:turn(math.max(-TURN_SPEED, math.min(TURN_SPEED, turn)))
        return
    end

    local offset = Maze.OFFSETS[self.direction]
    self.column, self.row = self.column + offset[1], self.row + offset[2]
    self.targetX, self.targetY = self.maze:cellCenter(self.column, self.row)
    self.direction = nil
end
