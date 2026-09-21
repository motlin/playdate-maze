-- Shades of grey for a 1-bit screen: 8x8 ordered-dither patterns for gfx.setPattern.
-- Level 0 is black and Shades.WHITE is white. Each level lights one more pixel of every 4x4 tile.

Shades = {}

Shades.WHITE = 16

local BAYER <const> = {
    { 0, 8, 2, 10 },
    { 12, 4, 14, 6 },
    { 3, 11, 1, 9 },
    { 15, 7, 13, 5 },
}

local patterns = {}
for level = 0, Shades.WHITE do
    local pattern = {}
    for row = 1, 8 do
        local byte = 0
        for column = 1, 8 do
            local isWhite = BAYER[(row - 1) % 4 + 1][(column - 1) % 4 + 1] < level
            byte = byte * 2 + (isWhite and 1 or 0)
        end
        pattern[row] = byte
    end
    patterns[level] = pattern
end

function Shades.pattern(level) return patterns[level] or error("no such shade: " .. tostring(level)) end
