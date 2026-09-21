-- Where the player stands and which way they look.
-- Angles are in degrees, 0 facing east and growing clockwise. The body is a square of
-- RADIUS either side, moved one axis at a time so it slides along walls instead of sticking.

Player = {}
Player.__index = Player

Player.RADIUS = 0.2

local FACINGS <const> = { "east", "south", "west", "north" }

function Player.new(x, y, angle)
    return setmetatable({ x = x, y = y, angle = angle }, Player)
end

function Player:turn(degrees)
    self.angle = (self.angle + degrees) % 360
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
function Player:moveBy(maze, offsetX, offsetY)
    local targetX, targetY = self.x + offsetX, self.y + offsetY
    self.x = slide(self.x, targetX, function(x) return isBlocked(maze, x, self.y) end)
    local isBlockedX = self.x ~= targetX
    self.y = slide(self.y, targetY, function(y) return isBlocked(maze, self.x, y) end)
    return isBlockedX, self.y ~= targetY
end

-- Whether the body would overlap a wall if it were this far from where it is
function Player:wouldHit(maze, offsetX, offsetY)
    return isBlocked(maze, self.x + offsetX, self.y + offsetY)
end

-- Moves relative to the way the player faces
function Player:move(maze, forward, strafe)
    local radians = math.rad(self.angle)
    local cosine, sine = math.cos(radians), math.sin(radians)
    self:moveBy(maze, cosine * forward - sine * strafe, sine * forward + cosine * strafe)
end

function Player:facing()
    return FACINGS[math.floor((self.angle + 45) / 90) % 4 + 1]
end

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
function Player.isPathClear(maze, fromX, fromY, toX, toY)
    local left, top = maze:blockAt(math.min(fromX, toX) - Player.RADIUS, math.min(fromY, toY) - Player.RADIUS)
    local right, bottom = maze:blockAt(math.max(fromX, toX) + Player.RADIUS, math.max(fromY, toY) + Player.RADIUS)
    for gridY = top, bottom do
        for gridX = left, right do
            if maze:isWall(gridX, gridY) and crossesBox(fromX, fromY, toX, toY,
                gridX - 1 - Player.RADIUS, gridY - 1 - Player.RADIUS, gridX + Player.RADIUS, gridY + Player.RADIUS) then
                return false
            end
        end
    end
    return true
end
