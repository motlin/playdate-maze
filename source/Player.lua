-- Where the player stands and which way they look.
-- Angles are in degrees, 0 facing east and growing clockwise. The body is a square of
-- RADIUS either side, moved one axis at a time so it slides along walls instead of sticking.

---@class Player
---@field x number
---@field y number
---@field angle number
Player = {}
Player.__index = Player

Player.RADIUS = 0.2

local FACINGS <const> = { "east", "south", "west", "north" }

---@param x number
---@param y number
---@param angle number
---@return Player
function Player.new(x, y, angle) return setmetatable({ x = x, y = y, angle = angle }, Player) end

---@param degrees number
---@return nil
function Player:turn(degrees) self.angle = (self.angle + degrees) % 360 end

-- Reset a reusable simulation body without sharing the live player's state.
---@param player Player
---@return nil
function Player:copyFrom(player)
    self.x, self.y, self.angle = player.x, player.y, player.angle
end

-- Follow a navigation target without overshooting it. The route supplies clear cell centers.
---@param targetX number
---@param targetY number
---@param speed number
---@return boolean
function Player:walkTowards(targetX, targetY, speed)
    local offsetX, offsetY = targetX - self.x, targetY - self.y
    local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
    if distance == 0 then return false end
    if distance <= speed then
        self.x, self.y = targetX, targetY
    else
        self.x = self.x + offsetX / distance * speed
        self.y = self.y + offsetY / distance * speed
    end
    return true
end

-- The thread checks the swept path; follow its position and ease toward its backward heading.
---@param thread Thread
---@param distance number
---@param turnSpeed number
---@return boolean, boolean?
function Player:rewindAlong(thread, distance, turnSpeed)
    local x, y, heading, blocked = thread:rewindFrom(self.x, self.y, distance)
    if not x then return false, blocked end
    ---@cast y number
    ---@cast heading number
    self.x, self.y = x, y
    local turn = (heading - self.angle + 180) % 360 - 180
    self:turn(math.max(-turnSpeed, math.min(turnSpeed, turn)))
    return true, blocked
end

local function isBlocked(maze, x, y)
    return maze:isWall(maze:blockAt(x - Player.RADIUS, y - Player.RADIUS))
        or maze:isWall(maze:blockAt(x + Player.RADIUS, y - Player.RADIUS))
        or maze:isWall(maze:blockAt(x - Player.RADIUS, y + Player.RADIUS))
        or maze:isWall(maze:blockAt(x + Player.RADIUS, y + Player.RADIUS))
end

-- Just short of touching, so a body resting against a wall is not counted as inside it
local GAP <const> = 0.000001

-- Where the body ends up on one axis: at `to`, or resting against whatever is in the way
local function slide(from, to, isBlockedAt)
    if not isBlockedAt(to) then return to end
    local edge
    if to > from then
        edge = math.floor(to + Player.RADIUS) - Player.RADIUS - GAP
    else
        edge = math.ceil(to - Player.RADIUS) + Player.RADIUS + GAP
    end
    -- Only rest somewhere between where the body was and where it wanted to go
    local isBetween = (edge - from) * (to - from) >= 0
    if isBetween and not isBlockedAt(edge) then return edge end
    return from
end

-- Moves by an offset in the world. Returns whether the way was blocked along x and along y.
---@param maze Maze
---@param offsetX number
---@param offsetY number
---@return boolean, boolean
function Player:moveBy(maze, offsetX, offsetY)
    local targetX, targetY = self.x + offsetX, self.y + offsetY
    self.x = slide(self.x, targetX, function(x) return isBlocked(maze, x, self.y) end)
    local isBlockedX = self.x ~= targetX
    self.y = slide(self.y, targetY, function(y) return isBlocked(maze, self.x, y) end)
    return isBlockedX, self.y ~= targetY
end

-- Whether the body would overlap a wall if it were this far from where it is
---@param maze Maze
---@param offsetX number
---@param offsetY number
---@return boolean
function Player:wouldHit(maze, offsetX, offsetY) return isBlocked(maze, self.x + offsetX, self.y + offsetY) end

-- Moves relative to the way the player faces
---@param maze Maze
---@param forward number
---@param strafe number
---@return nil
function Player:move(maze, forward, strafe)
    local radians = math.rad(self.angle)
    local cosine, sine = math.cos(radians), math.sin(radians)
    self:moveBy(maze, cosine * forward - sine * strafe, sine * forward + cosine * strafe)
end

---@return string
function Player:facing() return FACINGS[math.floor((self.angle + 45) / 90) % 4 + 1] end

local function crossesBox(fromX, fromY, toX, toY, left, top, right, bottom)
    local enter, leave = 0, 1
    local offsetX, offsetY = toX - fromX, toY - fromY
    if offsetX == 0 then
        if fromX < left or fromX > right then return false end
    else
        local first, last = (left - fromX) / offsetX, (right - fromX) / offsetX
        enter, leave = math.max(enter, math.min(first, last)), math.min(leave, math.max(first, last))
    end
    if offsetY == 0 then
        if fromY < top or fromY > bottom then return false end
    else
        local first, last = (top - fromY) / offsetY, (bottom - fromY) / offsetY
        enter, leave = math.max(enter, math.min(first, last)), math.min(leave, math.max(first, last))
    end
    return enter <= leave
end

-- Sweep the square body along the whole segment, including corners between its endpoints.
---@param maze Maze
---@param fromX number
---@param fromY number
---@param toX number
---@param toY number
---@return boolean
function Player.isPathClear(maze, fromX, fromY, toX, toY)
    local left, top = maze:blockAt(math.min(fromX, toX) - Player.RADIUS, math.min(fromY, toY) - Player.RADIUS)
    local right, bottom = maze:blockAt(math.max(fromX, toX) + Player.RADIUS, math.max(fromY, toY) + Player.RADIUS)
    for gridY = top, bottom do
        for gridX = left, right do
            if
                maze:isWall(gridX, gridY)
                and crossesBox(
                    fromX,
                    fromY,
                    toX,
                    toY,
                    gridX - 1 - Player.RADIUS,
                    gridY - 1 - Player.RADIUS,
                    gridX + Player.RADIUS,
                    gridY + Player.RADIUS
                )
            then
                return false
            end
        end
    end
    return true
end
