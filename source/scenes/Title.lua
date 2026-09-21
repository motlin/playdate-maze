-- The title screen: a menu over a maze that wanders by itself in the background.

import "Bob"
import "CrankSteps"
import "Game"
import "MazeView"
import "SaveGame"
import "SceneManager"
import "Sizes"

local pd <const> = playdate
local gfx <const> = playdate.graphics

-- rows is the menu as it stands: it starts with Continue only when there is a game to continue
TitleScene = { selection = 1, sizeIndex = Sizes.DEFAULT, rows = {} }

local PANEL_LEFT <const> = 100
local PANEL_TOP <const> = 8
local PANEL_WIDTH <const> = 200
local PANEL_HEIGHT <const> = 224
local TITLE_SCALE <const> = 2
local ROWS_TOP <const> = PANEL_TOP + 46
local ROW_HEIGHT <const> = 21
-- An eighth of a turn of the crank moves the highlight one row
local CRANK_DEGREES_PER_ROW <const> = 45

local function playFirstPerson(submode)
    return function() SceneManager.switch(FirstPersonScene, submode, TitleScene.sizeIndex) end
end

function TitleScene.nextSize() TitleScene.sizeIndex = Sizes.next(TitleScene.sizeIndex) end
function TitleScene.previousSize() TitleScene.sizeIndex = Sizes.previous(TitleScene.sizeIndex) end

function TitleScene.continueSavedGame()
    local game, submode, sizeIndex = SaveGame.read()
    -- A save this version cannot read has just been thrown away: show the menu without it
    if not game then
        TitleScene.enter()
        return
    end
    SceneManager.switch(FirstPersonScene, submode, sizeIndex, game)
end

-- Each row has a name, a label, and what A does; left and right are optional
local CONTINUE_ROW <const> = { name = "continue", label = function() return "Continue" end, confirm = TitleScene.continueSavedGame }
local PLAY_ROWS <const> = {
    { name = "explore", label = function() return "Explore" end, confirm = playFirstPerson("explore") },
    { name = "daily", label = function() return "Daily maze" end, confirm = playFirstPerson("daily") },
    {
        name = "tumble",
        label = function() return "Tumble" end,
        confirm = function() SceneManager.switch(TumbleScene, TitleScene.sizeIndex) end,
    },
    {
        name = "slime",
        label = function() return "Slime" end,
        confirm = function() SceneManager.switch(SlimeScene, TitleScene.sizeIndex) end,
    },
    { name = "myMazes", label = function() return "My mazes" end, confirm = function() SceneManager.switch(MyMazesScene) end },
    { name = "screensaver", label = function() return "Screensaver" end, confirm = playFirstPerson("screensaver") },
    {
        name = "size",
        label = function() return "Size: " .. Sizes.ALL[TitleScene.sizeIndex].name end,
        confirm = TitleScene.nextSize,
        left = TitleScene.previousSize,
        right = TitleScene.nextSize,
    },
}

local function buildRows()
    local rows = {}
    if SaveGame.exists() then rows[1] = CONTINUE_ROW end
    for _, row in ipairs(PLAY_ROWS) do rows[#rows + 1] = row end
    return rows
end

local backdrop
local headBob = Bob.new()
local crankSteps = CrankSteps.new(CRANK_DEGREES_PER_ROW)
local titleImage

local function newBackdrop()
    local size = Sizes.ALL[Sizes.DEFAULT]
    local game = Game.new({ columns = size.columns, rows = size.rows, hasPuzzle = false, random = math.random })
    game:setAutopilot(true)
    return game
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
    TitleScene.rows = buildRows()
    TitleScene.selection = 1
    crankSteps:reset()
    backdrop = newBackdrop()
    titleImage = titleImage or drawTitleImage()
end

function TitleScene.handleInput()
    local rows = TitleScene.rows
    local row = rows[TitleScene.selection]
    local move = crankSteps:turn(pd.getCrankChange())
    if pd.buttonJustPressed(pd.kButtonUp) then move = -1 end
    if pd.buttonJustPressed(pd.kButtonDown) then move = 1 end
    -- A press of the D-pad is a fresh start for the crank
    if move ~= 0 and (pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonDown)) then crankSteps:reset() end
    TitleScene.selection = math.max(1, math.min(#rows, TitleScene.selection + move))
    if pd.buttonJustPressed(pd.kButtonLeft) and row.left then row.left() end
    if pd.buttonJustPressed(pd.kButtonRight) and row.right then row.right() end
    if pd.buttonJustPressed(pd.kButtonA) then row.confirm() end
end

function TitleScene.update()
    TitleScene.handleInput()
    if not SceneManager.isCurrent(TitleScene) then return end

    backdrop:update({})
    if backdrop.hasEscaped then backdrop = newBackdrop() end
    headBob:walk(backdrop.distanceWalked)
    MazeView.draw(backdrop, headBob:headOffset())

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(PANEL_LEFT, PANEL_TOP, PANEL_WIDTH, PANEL_HEIGHT, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawRoundRect(PANEL_LEFT, PANEL_TOP, PANEL_WIDTH, PANEL_HEIGHT, 8)
    gfx.setLineWidth(1)

    local titleWidth = titleImage.width * TITLE_SCALE
    titleImage:drawScaled(PANEL_LEFT + (PANEL_WIDTH - titleWidth) / 2, PANEL_TOP + 6, TITLE_SCALE)

    for index, row in ipairs(TitleScene.rows) do
        local top = ROWS_TOP + (index - 1) * ROW_HEIGHT
        if index == TitleScene.selection then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(PANEL_LEFT + 20, top, PANEL_WIDTH - 40, ROW_HEIGHT - 2, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawTextAligned(row.label(), PANEL_LEFT + PANEL_WIDTH / 2, top + 2, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
