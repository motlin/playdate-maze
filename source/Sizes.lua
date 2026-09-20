-- The maze sizes on offer, which double as the difficulty setting.

Sizes = {}

Sizes.ALL = {
    { name = "Small", columns = 6, rows = 4 },
    { name = "Medium", columns = 8, rows = 6 },
    { name = "Large", columns = 12, rows = 9 },
}
Sizes.DEFAULT = 2

-- The most pixels the minimap's cells may span, so that it stays a corner of the screen
Sizes.WIDEST_MAP = 84
local ROOMIEST_MAP_CELL <const> = 7

function Sizes.next(index)
    return index % #Sizes.ALL + 1
end

function Sizes.previous(index)
    return (index - 2) % #Sizes.ALL + 1
end

-- How many pixels wide to draw each cell of a maze this many columns across
function Sizes.mapCellSize(columns)
    return math.min(ROOMIEST_MAP_CELL, Sizes.WIDEST_MAP // columns)
end
