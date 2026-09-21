-- Draws a MapDesign from above: walls black, floor white, the start, the exit, and the shapes and
-- pedestals that have been placed. The editor draws it large with a cursor; the list of saved
-- maps draws it small as a thumbnail.

import "MapDesign"
import "ShapeArt"

MapView = {}

local GATE_PATTERN <const> = { 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA }

-- The biggest whole number of pixels per block that fits the design in a space
function MapView.blockSizeToFit(design, width, height)
    return math.max(1, math.min(width // design.gridWidth, height // design.gridHeight))
end

function MapView.size(design, blockSize)
    return design.gridWidth * blockSize, design.gridHeight * blockSize
end

local function blockMiddle(left, top, blockSize, place)
    return left + (place.gridX - 0.5) * blockSize, top + (place.gridY - 0.5) * blockSize
end

local function drawThings(design, left, top, blockSize)
    local thingSize = math.max(3, blockSize - 4)
    for _, shape in ipairs(MapDesign.SHAPES) do
        local item, pedestal = design.items[shape], design.pedestals[shape]
        if item then
            local x, y = blockMiddle(left, top, blockSize, item)
            ShapeArt.drawBlack(shape, x, y, thingSize)
        end
        if pedestal then
            local x, y = blockMiddle(left, top, blockSize, pedestal)
            ShapeArt.drawHollow(shape, x, y, thingSize)
        end
    end

    -- The start is a ring with a dot in it
    local x, y = blockMiddle(left, top, blockSize, design.start)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.drawCircleAtPoint(x, y, thingSize / 2)
    playdate.graphics.fillCircleAtPoint(x, y, math.max(1, thingSize / 5))
end

function MapView.draw(design, left, top, blockSize)
    local width, height = MapView.size(design, blockSize)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.fillRect(left, top, width, height)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    for gridY = 1, design.gridHeight do
        -- A row's walls are drawn a run at a time
        local runStart
        for gridX = 1, design.gridWidth + 1 do
            local isWall = gridX <= design.gridWidth and not design:isOpen(gridX, gridY)
            if isWall and not runStart then runStart = gridX end
            if not isWall and runStart then
                playdate.graphics.fillRect(left + (runStart - 1) * blockSize, top + (gridY - 1) * blockSize, (gridX - runStart) * blockSize, blockSize)
                runStart = nil
            end
        end
    end

    if design.exit then
        playdate.graphics.setPattern(GATE_PATTERN)
        playdate.graphics.fillRect(left + (design.exit.gridX - 1) * blockSize, top + (design.exit.gridY - 1) * blockSize, blockSize, blockSize)
    end
    drawThings(design, left, top, blockSize)
end

-- A frame round a block, which shows up over wall and floor alike
function MapView.drawCursor(left, top, blockSize, gridX, gridY)
    local x, y = left + (gridX - 1) * blockSize, top + (gridY - 1) * blockSize
    playdate.graphics.setColor(playdate.graphics.kColorXOR)
    playdate.graphics.setLineWidth(2)
    playdate.graphics.drawRect(x - 1, y - 1, blockSize + 2, blockSize + 2)
    playdate.graphics.setLineWidth(1)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.drawRect(x + 1, y + 1, blockSize - 2, blockSize - 2)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
end
