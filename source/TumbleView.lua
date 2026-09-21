-- Draws a Tumble: the maze from the side, turned about the player, who stays upright in the
-- middle of the screen.

import "Player"
import "SideView"

TumbleView = {}

local PIXELS_PER_BLOCK <const> = 40
local BODY_SIZE <const> = 2 * Player.RADIUS * PIXELS_PER_BLOCK

-- Always upright, looking the way it last walked
local function drawPlayer(tumble)
    local half = BODY_SIZE / 2
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.fillRoundRect(SideView.CENTER_X - half, SideView.CENTER_Y - half, BODY_SIZE, BODY_SIZE, 4)
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    local eyeX = SideView.CENTER_X + tumble.facing * 2
    playdate.graphics.fillRect(eyeX - 4, SideView.CENTER_Y - 4, 3, 4)
    playdate.graphics.fillRect(eyeX + 1, SideView.CENTER_Y - 4, 3, 4)
end

function TumbleView.draw(tumble)
    SideView.look(tumble, tumble.angle, PIXELS_PER_BLOCK)
    SideView.drawMaze()
    drawPlayer(tumble)
end
