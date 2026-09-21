-- Draws the puzzle's shapes at any size, so the same art serves the 3D view, the minimap, and
-- the heads-up display. A solid shape is white with a black edge, a hollow one is only the edge,
-- and a black one is a silhouette for places too small for an edge.

ShapeArt = {}

local function trianglePoints(centerX, centerY, size)
    local half = size / 2
    return centerX, centerY - half, centerX + half, centerY + half, centerX - half, centerY + half
end

local fill <const> = {
    circle = function(centerX, centerY, size) playdate.graphics.fillCircleAtPoint(centerX, centerY, size / 2) end,
    triangle = function(centerX, centerY, size) playdate.graphics.fillPolygon(trianglePoints(centerX, centerY, size)) end,
    square = function(centerX, centerY, size) playdate.graphics.fillRect(centerX - size / 2, centerY - size / 2, size, size) end,
}

local outline <const> = {
    circle = function(centerX, centerY, size) playdate.graphics.drawCircleAtPoint(centerX, centerY, size / 2) end,
    triangle = function(centerX, centerY, size) playdate.graphics.drawPolygon(trianglePoints(centerX, centerY, size)) end,
    square = function(centerX, centerY, size) playdate.graphics.drawRect(centerX - size / 2, centerY - size / 2, size, size) end,
}

local function lineWidthFor(size)
    return math.max(1, math.min(3, size // 12))
end

function ShapeArt.drawSolid(shape, centerX, centerY, size)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    fill[shape](centerX, centerY, size)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.setLineWidth(lineWidthFor(size))
    outline[shape](centerX, centerY, size)
    playdate.graphics.setLineWidth(1)
end

function ShapeArt.drawHollow(shape, centerX, centerY, size)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.setLineWidth(lineWidthFor(size))
    outline[shape](centerX, centerY, size)
    playdate.graphics.setLineWidth(1)
end

function ShapeArt.drawBlack(shape, centerX, centerY, size)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    fill[shape](centerX, centerY, size)
end
