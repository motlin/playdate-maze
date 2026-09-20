-- The title screen: a menu over a maze that wanders by itself in the background.

import "Game"
import "MazeView"
import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics

TitleScene = { selection = 1 }

local OPTIONS <const> = {
    { label = "Explore", mode = "explore" },
    { label = "Screensaver", mode = "screensaver" },
}
local PANEL_LEFT <const> = 100
local PANEL_TOP <const> = 40
local PANEL_WIDTH <const> = 200
local PANEL_HEIGHT <const> = 160
local TITLE_SCALE <const> = 3
local ROW_HEIGHT <const> = 28

local backdrop
local titleImage

local function newBackdrop()
    backdrop = Game.new({ columns = 8, rows = 6, hasPuzzle = false, random = math.random })
    backdrop:setAutopilot(true)
end

local function drawTitleImage()
    local width, height = gfx.getTextSize("MAZE")
    local image = gfx.image.new(width, height)
    gfx.pushContext(image)
    gfx.drawText("MAZE", 0, 0)
    gfx.popContext()
    return image
end

function TitleScene.enter()
    newBackdrop()
    titleImage = titleImage or drawTitleImage()
end

function TitleScene.update()
    if pd.buttonJustPressed(pd.kButtonUp) then TitleScene.selection = math.max(1, TitleScene.selection - 1) end
    if pd.buttonJustPressed(pd.kButtonDown) then TitleScene.selection = math.min(#OPTIONS, TitleScene.selection + 1) end
    if pd.buttonJustPressed(pd.kButtonA) then
        SceneManager.switch(PlayScene, OPTIONS[TitleScene.selection].mode)
        return
    end

    backdrop:update({})
    if backdrop.hasEscaped then newBackdrop() end
    MazeView.draw(backdrop)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(PANEL_LEFT, PANEL_TOP, PANEL_WIDTH, PANEL_HEIGHT, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawRoundRect(PANEL_LEFT, PANEL_TOP, PANEL_WIDTH, PANEL_HEIGHT, 8)
    gfx.setLineWidth(1)

    local titleWidth = titleImage.width * TITLE_SCALE
    titleImage:drawScaled(PANEL_LEFT + (PANEL_WIDTH - titleWidth) / 2, PANEL_TOP + 14, TITLE_SCALE)

    for index, option in ipairs(OPTIONS) do
        local top = PANEL_TOP + 78 + (index - 1) * ROW_HEIGHT
        if index == TitleScene.selection then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(PANEL_LEFT + 20, top, PANEL_WIDTH - 40, ROW_HEIGHT - 4, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawTextAligned(option.label, PANEL_LEFT + PANEL_WIDTH / 2, top + 4, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
