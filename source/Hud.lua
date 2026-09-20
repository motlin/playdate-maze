-- Everything drawn over the 3D view: the minimap, which shapes are home, what is being carried,
-- and one line at the bottom that is either the game's latest message or a hint about A and B.

import "Minimap"
import "ShapeArt"

local gfx <const> = playdate.graphics

Hud = {}

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local EDGE <const> = 4
local PROGRESS_ICON_SIZE <const> = 12
local PROGRESS_ICON_SPACING <const> = 18
local CARRIED_BOX_SIZE <const> = 40
local CARRIED_ICON_SIZE <const> = 24
local LINE_HEIGHT <const> = 22
local LINE_PADDING <const> = 8

local function drawPanel(left, top, width, height)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(left, top, width, height, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(left, top, width, height, 4)
end

-- Which shapes are home: a hollow icon for each one still missing, a black one for each in place
function Hud.drawProgress(puzzle)
    local width = #puzzle.pedestals * PROGRESS_ICON_SPACING + 6
    drawPanel(EDGE, EDGE, width, PROGRESS_ICON_SPACING + 4)
    for index, pedestal in ipairs(puzzle.pedestals) do
        local x = EDGE + 3 + (index - 0.5) * PROGRESS_ICON_SPACING
        local y = EDGE + 2 + PROGRESS_ICON_SPACING / 2
        if pedestal.isFilled then
            ShapeArt.drawBlack(pedestal.shape, x, y, PROGRESS_ICON_SIZE)
        else
            ShapeArt.drawHollow(pedestal.shape, x, y, PROGRESS_ICON_SIZE)
        end
    end
end

local function drawCarried(item)
    local top = SCREEN_HEIGHT - EDGE - CARRIED_BOX_SIZE
    drawPanel(EDGE, top, CARRIED_BOX_SIZE, CARRIED_BOX_SIZE)
    ShapeArt.drawSolid(item.shape, EDGE + CARRIED_BOX_SIZE / 2, top + CARRIED_BOX_SIZE / 2, CARRIED_ICON_SIZE)
end

-- White text on a black pill, centred along the bottom
function Hud.drawLine(text)
    local width = gfx.getTextSize(text) + 2 * LINE_PADDING
    local left, top = (SCREEN_WIDTH - width) / 2, SCREEN_HEIGHT - EDGE - LINE_HEIGHT
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(left, top, width, LINE_HEIGHT, 4)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(left, top, width, LINE_HEIGHT, 4)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(text, SCREEN_WIDTH / 2, top + 3, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Hud.draw(game)
    local mapWidth = Minimap.size(game.maze)
    Minimap.draw(game, SCREEN_WIDTH - EDGE - mapWidth, EDGE)
    if game.puzzle then
        Hud.drawProgress(game.puzzle)
        if game.puzzle.carried then drawCarried(game.puzzle.carried) end
    end
    local line = game.message or game:hint()
    if line then Hud.drawLine(line) end
end
