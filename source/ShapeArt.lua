-- Draws the puzzle's shapes at any size, so the same art serves the 3D view, the minimap, and
-- the heads-up display. A solid shape is white with a black edge, a hollow one is only the edge,
-- and a black one is a silhouette for places too small for an edge.

local gfx <const> = playdate.graphics

ShapeArt = {}

local function trianglePoints(centerX, centerY, size)
    local half = size / 2
    return centerX, centerY - half, centerX + half, centerY + half, centerX - half, centerY + half
end

local fill <const> = {
    circle = function(centerX, centerY, size) gfx.fillCircleAtPoint(centerX, centerY, size / 2) end,
    triangle = function(centerX, centerY, size) gfx.fillPolygon(trianglePoints(centerX, centerY, size)) end,
    square = function(centerX, centerY, size) gfx.fillRect(centerX - size / 2, centerY - size / 2, size, size) end,
}

local outline <const> = {
    circle = function(centerX, centerY, size) gfx.drawCircleAtPoint(centerX, centerY, size / 2) end,
    triangle = function(centerX, centerY, size) gfx.drawPolygon(trianglePoints(centerX, centerY, size)) end,
    square = function(centerX, centerY, size) gfx.drawRect(centerX - size / 2, centerY - size / 2, size, size) end,
}

local function lineWidthFor(size)
    return math.max(1, math.min(3, size // 12))
end

function ShapeArt.drawSolid(shape, centerX, centerY, size)
    gfx.setColor(gfx.kColorWhite)
    fill[shape](centerX, centerY, size)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(lineWidthFor(size))
    outline[shape](centerX, centerY, size)
    gfx.setLineWidth(1)
end

function ShapeArt.drawHollow(shape, centerX, centerY, size)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(lineWidthFor(size))
    outline[shape](centerX, centerY, size)
    gfx.setLineWidth(1)
end

function ShapeArt.drawBlack(shape, centerX, centerY, size)
    gfx.setColor(gfx.kColorBlack)
    fill[shape](centerX, centerY, size)
end
