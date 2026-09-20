-- Ariadne's thread: the way back to where the player started. It is laid as the player walks and
-- winds itself back in when they retrace their steps, so in a maze without loops it is always
-- the one route from the start to the player. rewindFrom() reels the player back along it.

Thread = {}
Thread.__index = Thread

-- How far apart the points are, in blocks
Thread.SPACING = 0.25
-- The oldest points are forgotten beyond this many, which is 200 blocks of thread
Thread.MOST_POINTS = 800

local SPACING <const> = Thread.SPACING
local MOST_POINTS <const> = Thread.MOST_POINTS

local function distanceBetween(fromX, fromY, toX, toY)
    local offsetX, offsetY = toX - fromX, toY - fromY
    return math.sqrt(offsetX * offsetX + offsetY * offsetY)
end

function Thread.new(x, y)
    return setmetatable({ points = { { x = x, y = y } } }, Thread)
end

function Thread:length()
    local length = 0
    for index = 2, #self.points do
        local from, to = self.points[index - 1], self.points[index]
        length = length + distanceBetween(from.x, from.y, to.x, to.y)
    end
    return length
end

-- Call with the player's position every frame they move under their own power
function Thread:record(x, y)
    local points = self.points
    -- Nearer the point before last than the last point is: the player has turned back
    while #points >= 2 do
        local last, previous = points[#points], points[#points - 1]
        local isRetracing = distanceBetween(x, y, previous.x, previous.y) < distanceBetween(last.x, last.y, previous.x, previous.y)
        if not isRetracing then break end
        points[#points] = nil
    end
    local last = points[#points]
    if distanceBetween(x, y, last.x, last.y) >= SPACING then
        points[#points + 1] = { x = x, y = y }
        if #points > MOST_POINTS then table.remove(points, 1) end
    end
end

-- Reels in `distance` blocks of thread from the player's position. Returns the new position and
-- the heading, in degrees, in which the thread was laid there; or nil at the very start.
function Thread:rewindFrom(x, y, distance)
    local points = self.points
    local heading
    while true do
        local last = points[#points]
        local stretch = distanceBetween(last.x, last.y, x, y)
        if stretch > 0 then heading = math.deg(math.atan(y - last.y, x - last.x)) % 360 end
        if stretch > distance then
            local share = distance / stretch
            x, y = x + (last.x - x) * share, y + (last.y - y) * share
            points[#points + 1] = { x = x, y = y }
            return x, y, heading
        end
        distance = distance - stretch
        x, y = last.x, last.y
        if #points == 1 then
            if not heading then return nil end
            return x, y, heading
        end
        points[#points] = nil
    end
end
