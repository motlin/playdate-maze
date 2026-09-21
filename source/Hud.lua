-- Everything drawn over the 3D view: the minimap, which shapes are home, what is being carried,
-- and one line at the bottom that is either the game's latest message or a hint about A and B.

import "Compass"
import "Minimap"
import "Puzzle"
import "ShapeArt"

Hud = {}
local compassMarks = {}

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local EDGE <const> = 4
local PROGRESS_ICON_SIZE <const> = 12
local PROGRESS_ICON_SPACING <const> = 18
local CARRIED_BOX_SIZE <const> = 40
local CARRIED_ICON_SIZE <const> = 24
local LINE_HEIGHT <const> = 22
-- The compass sits top centre, between the progress icons and the widest minimap
local COMPASS_WIDTH <const> = 120
local COMPASS_HEIGHT <const> = 20
local COMPASS_SPAN <const> = 120
local COMPASS_TICK <const> = 4
local LINE_PADDING <const> = 8

local function drawPanel(left, top, width, height)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.fillRoundRect(left, top, width, height, 4)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.drawRoundRect(left, top, width, height, 4)
end

-- Which shapes are home: a hollow icon for each one still missing, a black one for each in place
function Hud.drawProgress(puzzle)
    local width = #puzzle.items * PROGRESS_ICON_SPACING + 6
    drawPanel(EDGE, EDGE, width, PROGRESS_ICON_SPACING + 4)
    for index, item in ipairs(puzzle.items) do
        local x = EDGE + 3 + (index - 0.5) * PROGRESS_ICON_SPACING
        local y = EDGE + 2 + PROGRESS_ICON_SPACING / 2
        if item.state == Puzzle.STATES.PLACED then
            ShapeArt.drawBlack(item.shape, x, y, PROGRESS_ICON_SIZE)
        else
            ShapeArt.drawHollow(item.shape, x, y, PROGRESS_ICON_SIZE)
        end
    end
end

local function drawCarried(item)
    local top = SCREEN_HEIGHT - EDGE - CARRIED_BOX_SIZE
    drawPanel(EDGE, top, CARRIED_BOX_SIZE, CARRIED_BOX_SIZE)
    ShapeArt.drawSolid(item.shape, EDGE + CARRIED_BOX_SIZE / 2, top + CARRIED_BOX_SIZE / 2, CARRIED_ICON_SIZE)
end

local function drawCompass(heading)
    local left = (SCREEN_WIDTH - COMPASS_WIDTH) / 2
    drawPanel(left, EDGE, COMPASS_WIDTH, COMPASS_HEIGHT)
    playdate.graphics.setClipRect(left + 2, EDGE, COMPASS_WIDTH - 4, COMPASS_HEIGHT)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    for _, mark in ipairs(Compass.marks(heading, COMPASS_WIDTH, COMPASS_SPAN, compassMarks)) do
        if mark.label then
            playdate.graphics.drawTextAligned(mark.label, left + mark.x, EDGE + 2, kTextAlignment.center)
        else
            playdate.graphics.drawLine(
                left + mark.x,
                EDGE + COMPASS_HEIGHT - COMPASS_TICK,
                left + mark.x,
                EDGE + COMPASS_HEIGHT - 1
            )
        end
    end
    playdate.graphics.clearClipRect()
    -- A notch marks dead ahead
    local middle = SCREEN_WIDTH / 2
    playdate.graphics.fillTriangle(
        middle - 4,
        EDGE + COMPASS_HEIGHT,
        middle + 4,
        EDGE + COMPASS_HEIGHT,
        middle,
        EDGE + COMPASS_HEIGHT - 5
    )
end

-- White text on a black pill, centred along the bottom
function Hud.drawLine(text)
    local width = playdate.graphics.getTextSize(text) + 2 * LINE_PADDING
    local left, top = (SCREEN_WIDTH - width) / 2, SCREEN_HEIGHT - EDGE - LINE_HEIGHT
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.fillRoundRect(left, top, width, LINE_HEIGHT, 4)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.drawRoundRect(left, top, width, LINE_HEIGHT, 4)
    playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeFillWhite)
    playdate.graphics.drawTextAligned(text, SCREEN_WIDTH / 2, top + 3, kTextAlignment.center)
    playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
end

function Hud.draw(game)
    local mapWidth = Minimap.size(game.maze)
    Minimap.draw(game, SCREEN_WIDTH - EDGE - mapWidth, EDGE)
    if game.heading then drawCompass(game:heading()) end
    if game.puzzle then
        Hud.drawProgress(game.puzzle)
        if game.puzzle.carried then drawCarried(game.puzzle.carried) end
    end
    local line = game.message or game:hint()
    if line then Hud.drawLine(line) end
end
