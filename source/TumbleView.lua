-- Draws a Tumble: the maze from the side, turned about the player, who stays upright in the
-- middle of the screen.

import "Player"
import "SideView"

local gfx <const> = playdate.graphics

TumbleView = {}

local PIXELS_PER_BLOCK <const> = 40
local BODY_SIZE <const> = 2 * Player.RADIUS * PIXELS_PER_BLOCK
local CENTER_X <const> = SideView.CENTER_X
local CENTER_Y <const> = SideView.CENTER_Y

-- Always upright, looking the way it last walked
local function drawPlayer(tumble)
    local half = BODY_SIZE / 2
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(CENTER_X - half, CENTER_Y - half, BODY_SIZE, BODY_SIZE, 4)
    gfx.setColor(gfx.kColorWhite)
    local eyeX = CENTER_X + tumble.facing * 2
    gfx.fillRect(eyeX - 4, CENTER_Y - 4, 3, 4)
    gfx.fillRect(eyeX + 1, CENTER_Y - 4, 3, 4)
end

function TumbleView.draw(tumble)
    SideView.look(tumble, tumble.angle, PIXELS_PER_BLOCK)
    SideView.drawMaze()
    drawPlayer(tumble)
end
