-- Each shape still lying in the maze hums, so it can be found by ear: louder as the player gets
-- nearer, and louder in the ear on the side it lies. One behind the player is in both ears and
-- quieter. This works out the loudness for each ear; Sounds does the humming.
-- Angles are the game's: degrees, 0 facing east, growing clockwise because y grows southwards.

Hum = {}

-- The pitch of each shape's hum, in hertz: an A, the E above it, and the A above that
Hum.FREQUENCIES = { circle = 110, triangle = 164.81, square = 220 }
Hum.LOUDEST = 0.25
-- Silent from this far away, in blocks, and at its loudest from this near
Hum.FARTHEST = 6
Hum.NEAREST = 0.5
-- A shape directly behind is this share as loud as one straight ahead
local BEHIND <const> = 0.3

-- Reused between frames
local levels = {}

-- items is a list of shapes with gridX, gridY, and state. Returns a list of { left, right }
-- loudnesses from 0 to Hum.LOUDEST, one for each item in order; the list is reused by the next call.
function Hum.levels(x, y, angle, items)
    for index, item in ipairs(items) do
        local level = levels[index]
        if not level then
            level = {}
            levels[index] = level
        end
        level.left, level.right = 0, 0
        if item.state == "ground" then
            local offsetX, offsetY = item.gridX - 0.5 - x, item.gridY - 0.5 - y
            local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
            local nearness = (Hum.FARTHEST - distance) / (Hum.FARTHEST - Hum.NEAREST)
            nearness = math.max(0, math.min(1, nearness))
            if nearness > 0 then
                -- How far round to the right the shape is from where the player faces
                local bearing = math.atan(offsetY, offsetX) - math.rad(angle)
                local facing = BEHIND + (1 - BEHIND) * (1 + math.cos(bearing)) / 2
                local loudness = Hum.LOUDEST * nearness * (distance < Hum.NEAREST and 1 or facing)
                local pan = distance < Hum.NEAREST and 0 or math.sin(bearing)
                level.left = loudness * math.min(1, 1 - pan)
                level.right = loudness * math.min(1, 1 + pan)
            end
        end
    end
    for index = #items + 1, #levels do levels[index] = nil end
    return levels
end
