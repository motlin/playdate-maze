-- Ariadne's thread: the way back to where the player started. It is laid as the player walks and
-- winds itself back in when they retrace their steps, so in a maze without loops it is always
-- the one route from the start to the player. rewindFrom() reels the player back along it.

import "Player"

Thread = {}
Thread.__index = Thread

-- How far apart the points are, in blocks
Thread.SPACING = 0.25
-- Bound trail memory, including extra points that preserve clearance around corners
Thread.MOST_POINTS = 800

local function distanceBetween(fromX, fromY, toX, toY)
    local offsetX, offsetY = toX - fromX, toY - fromY
    return math.sqrt(offsetX * offsetX + offsetY * offsetY)
end

function Thread.new(maze, x, y)
    return setmetatable({ maze = maze, lastX = x, lastY = y, points = { { x = x, y = y } } }, Thread)
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
        if not isRetracing or not Player.isPathClear(self.maze, previous.x, previous.y, x, y) then break end
        points[#points] = nil
    end
    local last = points[#points]
    if not Player.isPathClear(self.maze, last.x, last.y, x, y) then
        points[#points + 1] = { x = self.lastX, y = self.lastY }
        last = points[#points]
    end
    if distanceBetween(x, y, last.x, last.y) >= Thread.SPACING then
        points[#points + 1] = { x = x, y = y }
    end
    while #points > Thread.MOST_POINTS do table.remove(points, 1) end
    self.lastX, self.lastY = x, y
end

-- Reels in `distance` blocks of thread from the player's position. Returns the new position and
-- the heading in degrees, plus whether a wall blocked progress. Position is nil if nothing moved.
function Thread:rewindFrom(x, y, distance)
    local points = self.points
    local heading, blocked
    while true do
        local last = points[#points]
        local stretch = distanceBetween(last.x, last.y, x, y)
        local share = stretch > 0 and math.min(1, distance / stretch) or 1
        local targetX, targetY = x + (last.x - x) * share, y + (last.y - y) * share
        if not Player.isPathClear(self.maze, x, y, targetX, targetY) then
            blocked = true
            break
        end
        if stretch > 0 then heading = math.deg(math.atan(y - last.y, x - last.x)) % 360 end
        x, y = targetX, targetY
        if stretch > distance then
            points[#points + 1] = { x = x, y = y }
            break
        end
        distance = distance - stretch
        if #points == 1 then break end
        points[#points] = nil
    end
    self.lastX, self.lastY = x, y
    if not heading then return nil, nil, nil, blocked end
    return x, y, heading, blocked
end

-- A thread again from its saved points
function Thread.fromSave(maze, points, x, y)
    assert(#points >= 1, "a thread has at least the point it started from")
    return setmetatable({ maze = maze, points = points, lastX = x, lastY = y }, Thread)
end
