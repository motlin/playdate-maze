-- Works out what a compass strip shows: the marks within view of the way the player faces, and
-- where along the strip each one goes. Angles are the game's: 0 is east and they grow clockwise,
-- so 270 is north.

Compass = {}

local STEP <const> = 15
local LABELS <const> = {
    [0] = "E",
    [45] = "SE",
    [90] = "S",
    [135] = "SW",
    [180] = "W",
    [225] = "NW",
    [270] = "N",
    [315] = "NE",
}

-- Returns a list of { x, label }, left to right, for a strip `width` pixels wide that shows
-- `span` degrees. A mark without a label is a tick. A supplied buffer and its entries are overwritten; otherwise the result is fresh.
function Compass.marks(angle, width, span, marks)
    marks = marks or {}
    local count = 0
    local first = math.ceil((angle - span / 2) / STEP) * STEP
    for markAngle = first, angle + span / 2, STEP do
        local offset = markAngle - angle
        -- The very ends of the strip are left clear
        if math.abs(offset) < span / 2 then
            count = count + 1
            local mark = marks[count]
            if not mark then
                mark = {}
                marks[count] = mark
            end
            mark.x = width / 2 + offset / span * width
            mark.label = LABELS[markAngle % 360]
        end
    end
    for index = count + 1, #marks do
        marks[index] = nil
    end
    return marks
end
