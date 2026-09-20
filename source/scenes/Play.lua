-- Walking the maze, by hand or on autopilot.
-- Explore has the puzzle and ends at the Escaped scene. The screensaver has no puzzle, starts on
-- autopilot, and rolls straight into a new maze whenever it finds the way out.

import "Game"
import "Hud"
import "MazeView"
import "SceneManager"
import "Sizes"

local pd <const> = playdate

PlayScene = {
    MODES = { EXPLORE = "explore", SCREENSAVER = "screensaver" },
    game = nil,
    mode = nil,
    sizeIndex = Sizes.DEFAULT,
}

-- Degrees a frame when turning with the D-pad, which only happens while the crank is docked
local DPAD_TURN_SPEED <const> = 5
local BUTTONS <const> = {
    pd.kButtonUp, pd.kButtonDown, pd.kButtonLeft, pd.kButtonRight, pd.kButtonA, pd.kButtonB,
}

local input = {}

local function newGame(isAutopilotOn)
    local size = Sizes.ALL[PlayScene.sizeIndex]
    local game = Game.new({
        columns = size.columns,
        rows = size.rows,
        hasPuzzle = PlayScene.mode == PlayScene.MODES.EXPLORE,
        random = math.random,
    })
    game:setAutopilot(isAutopilotOn)
    PlayScene.game = game
end

function PlayScene.enter(mode, sizeIndex)
    PlayScene.mode = mode
    PlayScene.sizeIndex = sizeIndex
    newGame(mode == PlayScene.MODES.SCREENSAVER)
end

function PlayScene.restart()
    newGame(PlayScene.game:isAutopilotOn())
    SystemMenu.setAutopilot(PlayScene.game:isAutopilotOn())
end

local function isAnyButtonJustPressed()
    for _, button in ipairs(BUTTONS) do
        if pd.buttonJustPressed(button) then return true end
    end
    return false
end

local function axis(negativeButton, positiveButton)
    local value = 0
    if pd.buttonIsPressed(negativeButton) then value = value - 1 end
    if pd.buttonIsPressed(positiveButton) then value = value + 1 end
    return value
end

local function readInput()
    local sideways = axis(pd.kButtonLeft, pd.kButtonRight)
    input.forward = axis(pd.kButtonDown, pd.kButtonUp)
    input.turn = pd.getCrankChange()
    input.strafe = 0
    -- With the crank out, it does the looking and the D-pad sidesteps. Docked, the D-pad turns.
    if pd.isCrankDocked() then
        input.turn = sideways * DPAD_TURN_SPEED
    else
        input.strafe = sideways
    end
    input.pickUp = pd.buttonJustPressed(pd.kButtonA)
    input.drop = pd.buttonJustPressed(pd.kButtonB)
    return input
end

function PlayScene.update()
    local game = PlayScene.game
    if game:isAutopilotOn() and isAnyButtonJustPressed() then
        game:setAutopilot(false)
        SystemMenu.setAutopilot(false)
        -- The press that takes over does nothing else
        readInput()
        input.pickUp, input.drop = false, false
        game:update(input)
    else
        game:update(readInput())
    end

    if game.hasEscaped then
        if PlayScene.mode == PlayScene.MODES.EXPLORE then
            SceneManager.switch(EscapedScene, game.frames)
            return
        end
        PlayScene.restart()
    end

    MazeView.draw(PlayScene.game)
    Hud.draw(PlayScene.game)
end
