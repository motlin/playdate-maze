-- The throwing mode: see Slime for the rules. Hold A to aim with the crank and let go to throw,
-- B calls off an aim, and left and right crawl along a floor.

import "CoreLibs/ui"

import "Hud"
import "Music"
import "SceneManager"
import "Sizes"
import "Slime"
import "SlimeView"
import "Sounds"

local pd <const> = playdate

SlimeScene = { slime = nil, sizeIndex = Sizes.DEFAULT }

local input = {}

local function newSlime()
    local size = Sizes.ALL[SlimeScene.sizeIndex]
    SlimeScene.slime = Slime.new({ columns = size.slimeColumns, rows = size.slimeRows, random = math.random })
end

function SlimeScene.enter(sizeIndex)
    SlimeScene.sizeIndex = sizeIndex
    newSlime()
end

function SlimeScene.exit()
    Music.stop()
end

function SlimeScene.restart()
    newSlime()
end

local function playAgain()
    SceneManager.switch(SlimeScene, SlimeScene.sizeIndex)
end

local function readInput()
    input.aim = pd.getCrankPosition()
    input.isAimHeld = pd.buttonIsPressed(pd.kButtonA)
    input.cancel = pd.buttonJustPressed(pd.kButtonB)
    input.move = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then input.move = input.move - 1 end
    if pd.buttonIsPressed(pd.kButtonRight) then input.move = input.move + 1 end
    return input
end

function SlimeScene.update()
    local slime = SlimeScene.slime
    slime:update(readInput())
    Sounds.play(slime.events)
    Music.update(slime)
    if slime.hasEscaped then
        SceneManager.switch(EscapedScene, slime.frames, playAgain, slime.throws .. " throws")
        return
    end

    SlimeView.draw(slime)
    Hud.draw(slime)
    -- Nothing aims a throw but the crank
    if pd.isCrankDocked() then pd.ui.crankIndicator:draw() end
end
