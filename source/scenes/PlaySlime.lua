-- The throwing mode: see Slime for the rules. Hold A to aim with the crank and let go to throw,
-- B calls off an aim, and left and right crawl along a floor.

import "CoreLibs/ui"

import "Hud"
import "Music"
import "PlayInput"
import "SceneManager"
import "Sizes"
import "Slime"
import "SlimeActions"
import "SlimeView"
import "Sounds"

SlimeScene = { slime = nil, sizeIndex = Sizes.DEFAULT }

local controls = PlayInput.new()
local actions = SlimeActions.new(controls)
local actionBuffer = {}

function SlimeScene.newGame()
    local size = Sizes.ALL[SlimeScene.sizeIndex]
    SlimeScene.slime = Slime.new({ columns = size.slimeColumns, rows = size.slimeRows, random = math.random })
end

function SlimeScene.enter(sizeIndex)
    SlimeScene.sizeIndex = sizeIndex
    SlimeScene.newGame()
end

function SlimeScene.pause() Music.stop() end

function SlimeScene.exit() SlimeScene.pause() end

function SlimeScene.restart() SlimeScene.newGame() end

local function playAgain() SceneManager.switch(SlimeScene, SlimeScene.sizeIndex) end

function SlimeScene.update()
    local slime = SlimeScene.slime
    local input = controls:read()
    slime:update(actions:read(actionBuffer))
    Sounds.play(slime.events)
    Music.update(slime)
    if slime.hasEscaped then
        SceneManager.switch(EscapedScene, slime.frames, playAgain, slime.throws .. " throws")
        return
    end

    SlimeView.draw(slime)
    Hud.draw(slime)
    -- Nothing aims a throw but the crank
    if input.isCrankDocked then playdate.ui.crankIndicator:draw() end
end
