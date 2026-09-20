-- The title screen: a menu over a maze that wanders by itself in the background.

import "Game"
import "MazeView"
import "SceneManager"
import "Sizes"

local pd <const> = playdate
local gfx <const> = playdate.graphics

TitleScene = { selection = 1, sizeIndex = Sizes.DEFAULT }

local PANEL_LEFT <const> = 100
local PANEL_TOP <const> = 16
local PANEL_WIDTH <const> = 200
local PANEL_HEIGHT <const> = 208
local TITLE_SCALE <const> = 3
local ROWS_TOP <const> = PANEL_TOP + 76
local ROW_HEIGHT <const> = 26

local function play(mode)
    return function() SceneManager.switch(PlayScene, mode, TitleScene.sizeIndex) end
end

local function nextSize() TitleScene.sizeIndex = Sizes.next(TitleScene.sizeIndex) end
local function previousSize() TitleScene.sizeIndex = Sizes.previous(TitleScene.sizeIndex) end

-- Each row has a label and what A does; left and right are optional
local ROWS <const> = {
    { label = function() return "Explore" end, confirm = play("explore") },
    { label = function() return "Daily maze" end, confirm = play("daily") },
    {
        label = function() return "Tumble" end,
        confirm = function() SceneManager.switch(TumbleScene, TitleScene.sizeIndex) end,
    },
    { label = function() return "Screensaver" end, confirm = play("screensaver") },
    {
        label = function() return "Size: " .. Sizes.ALL[TitleScene.sizeIndex].name end,
        confirm = nextSize,
        left = previousSize,
        right = nextSize,
    },
}

local backdrop
local titleImage

local function newBackdrop()
    local size = Sizes.ALL[Sizes.DEFAULT]
    backdrop = Game.new({ columns = size.columns, rows = size.rows, hasPuzzle = false, random = math.random })
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

local function handleInput()
    local row = ROWS[TitleScene.selection]
    if pd.buttonJustPressed(pd.kButtonUp) then TitleScene.selection = math.max(1, TitleScene.selection - 1) end
    if pd.buttonJustPressed(pd.kButtonDown) then TitleScene.selection = math.min(#ROWS, TitleScene.selection + 1) end
    if pd.buttonJustPressed(pd.kButtonLeft) and row.left then row.left() end
    if pd.buttonJustPressed(pd.kButtonRight) and row.right then row.right() end
    if pd.buttonJustPressed(pd.kButtonA) then row.confirm() end
end

function TitleScene.update()
    handleInput()
    if not SceneManager.isCurrent(TitleScene) then return end

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
    titleImage:drawScaled(PANEL_LEFT + (PANEL_WIDTH - titleWidth) / 2, PANEL_TOP + 10, TITLE_SCALE)

    for index, row in ipairs(ROWS) do
        local top = ROWS_TOP + (index - 1) * ROW_HEIGHT
        if index == TitleScene.selection then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(PANEL_LEFT + 20, top, PANEL_WIDTH - 40, ROW_HEIGHT - 4, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawTextAligned(row.label(), PANEL_LEFT + PANEL_WIDTH / 2, top + 3, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
