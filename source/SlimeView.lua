-- Draws a Slime: the upright maze from the side with the slime in the middle of the screen,
-- squashed against whatever it is stuck to, the clock on its grip, and the arc of the throw
-- being aimed.

import "SideView"
import "Slime"

SlimeView = {}

local PIXELS_PER_BLOCK <const> = 24
-- Half the body's collision square, in pixels: the blob is drawn flush with this
local HALF_BODY <const> = Slime.RADIUS * PIXELS_PER_BLOCK
-- The blob: long and short sides when squashed against something, and round in the air
local SQUASHED_LONG <const> = 16
local SQUASHED_SHORT <const> = 10
local SLIDING_LONG <const> = 20
local ROUND <const> = 12
local CLOCK_RADIUS <const> = 14
local ARC_DOT_RADIUS <const> = 1.5
local LANDING_RADIUS <const> = 5
local POINTER_FROM <const> = 12
local POINTER_TO <const> = 20

-- The blob's rectangle: flush against its surface, centred along it
local function blobRect(slime)
    local state, surface = slime.state, slime.surface
    if state == Slime.STATES.FLYING then
        return SideView.CENTER_X - ROUND / 2, SideView.CENTER_Y - ROUND / 2, ROUND, ROUND
    end
    if surface == "floor" then
        return SideView.CENTER_X - SQUASHED_LONG / 2,
            SideView.CENTER_Y + HALF_BODY - SQUASHED_SHORT,
            SQUASHED_LONG,
            SQUASHED_SHORT
    elseif surface == "ceiling" then
        return SideView.CENTER_X - SQUASHED_LONG / 2, SideView.CENTER_Y - HALF_BODY, SQUASHED_LONG, SQUASHED_SHORT
    end
    local long = state == Slime.STATES.SLIDING and SLIDING_LONG or SQUASHED_LONG
    local left = surface == "right" and SideView.CENTER_X + HALF_BODY - SQUASHED_SHORT or SideView.CENTER_X - HALF_BODY
    return left, SideView.CENTER_Y - long / 2, SQUASHED_SHORT, long
end

local function drawBlob(slime)
    local left, top, width, height = blobRect(slime)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.fillEllipseInRect(left, top, width, height)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    local eyeY = top + height / 2 - 2
    playdate.graphics.fillRect(left + width / 2 - 3, eyeY, 2, 3)
    playdate.graphics.fillRect(left + width / 2 + 1, eyeY, 2, 3)
end

-- A ring round the slime that empties as its grip on a wall or ceiling runs out
local function drawClock(slime)
    if slime.state ~= Slime.STATES.CLINGING then return end
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.setLineWidth(3)
    playdate.graphics.drawArc(
        SideView.CENTER_X,
        SideView.CENTER_Y,
        CLOCK_RADIUS,
        0,
        360 * slime.stickFrames / Slime.STICK_FRAMES
    )
    playdate.graphics.setLineWidth(1)
end

-- A short tick showing where the crank points, so a throw can be lined up before A is pressed
local function drawPointer(slime)
    local radians = math.rad(slime.aimAngle)
    local x, y = math.sin(radians), -math.cos(radians)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.setLineWidth(2)
    playdate.graphics.drawLine(
        SideView.CENTER_X + x * POINTER_FROM,
        SideView.CENTER_Y + y * POINTER_FROM,
        SideView.CENTER_X + x * POINTER_TO,
        SideView.CENTER_Y + y * POINTER_TO
    )
    playdate.graphics.setLineWidth(1)
end

local function drawArc(slime)
    local arc = slime:arc()
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    for _, point in ipairs(arc.points) do
        local x, y = SideView.toScreen(point.x, point.y)
        playdate.graphics.fillCircleAtPoint(x, y, ARC_DOT_RADIUS)
    end
    local x, y = SideView.toScreen(arc.landingX, arc.landingY)
    playdate.graphics.setLineWidth(2)
    playdate.graphics.drawCircleAtPoint(x, y, LANDING_RADIUS)
    playdate.graphics.setLineWidth(1)
end

function SlimeView.draw(slime)
    SideView.look(slime, 0, PIXELS_PER_BLOCK)
    SideView.drawMaze()
    if slime.isAiming then
        drawArc(slime)
    elseif slime:canThrow() then
        drawPointer(slime)
    end
    drawClock(slime)
    drawBlob(slime)
end
