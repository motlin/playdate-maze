-- The platformer mode: see Tumble for the rules. The crank turns the maze, left and right walk,
-- and A, B, or up jumps.

import "CoreLibs/ui"

import "Hud"
import "Music"
import "SceneManager"
import "Sizes"
import "Sounds"
import "Tumble"
import "TumbleView"

local pd <const> = playdate

TumbleScene = { tumble = nil, sizeIndex = Sizes.DEFAULT }

local input = {}

local function newTumble()
    local size = Sizes.ALL[TumbleScene.sizeIndex]
    TumbleScene.tumble = Tumble.new({ columns = size.columns, rows = size.rows, random = math.random })
end

function TumbleScene.enter(sizeIndex)
    TumbleScene.sizeIndex = sizeIndex
    newTumble()
end

function TumbleScene.exit()
    Music.stop()
end

function TumbleScene.restart()
    newTumble()
end

local function playAgain()
    SceneManager.switch(TumbleScene, TumbleScene.sizeIndex)
end

local function readInput()
    input.turn = pd.getCrankChange()
    input.move = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then input.move = input.move - 1 end
    if pd.buttonIsPressed(pd.kButtonRight) then input.move = input.move + 1 end
    input.jump = pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) or pd.buttonJustPressed(pd.kButtonUp)
    return input
end

function TumbleScene.update()
    local tumble = TumbleScene.tumble
    tumble:update(readInput())
    Sounds.play(tumble.events)
    Music.update(tumble)
    if tumble.hasEscaped then
        SceneManager.switch(EscapedScene, tumble.frames, playAgain)
        return
    end

    TumbleView.draw(tumble)
    Hud.draw(tumble)
    -- Nothing turns the maze but the crank
    if pd.isCrankDocked() then pd.ui.crankIndicator:draw() end
end
