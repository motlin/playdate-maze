-- Walking the maze, by hand or on autopilot.
-- Explore has the puzzle and ends at the Escaped scene. The daily maze is Explore with the date
-- as the seed, so everyone gets the same medium maze on the same day. The screensaver has no
-- puzzle, starts on autopilot, and rolls straight into a new maze whenever it finds the way out.

import "Game"
import "Hud"
import "MazeView"
import "SceneManager"
import "SeededRandom"
import "Sizes"

local pd <const> = playdate

PlayScene = {
    MODES = { EXPLORE = "explore", DAILY = "daily", SCREENSAVER = "screensaver" },
    game = nil,
    mode = nil,
    sizeIndex = Sizes.DEFAULT,
}

-- Degrees a frame when turning with the D-pad, which only happens while the crank is docked
local DPAD_TURN_SPEED <const> = 5
local BUTTONS <const> = {
    pd.kButtonUp, pd.kButtonDown, pd.kButtonLeft, pd.kButtonRight, pd.kButtonA, pd.kButtonB,
}

local MONTHS <const> = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local input = {}

local function newGame(isAutopilotOn)
    local size = Sizes.ALL[PlayScene.sizeIndex]
    local random = math.random
    local today
    if PlayScene.mode == PlayScene.MODES.DAILY then
        today = pd.getTime()
        random = SeededRandom.new(SeededRandom.seedForDate(today.year, today.month, today.day))
    end
    local game = Game.new({
        columns = size.columns,
        rows = size.rows,
        hasPuzzle = PlayScene.mode ~= PlayScene.MODES.SCREENSAVER,
        random = random,
    })
    game:setAutopilot(isAutopilotOn)
    if today then game:say("Daily maze: " .. today.day .. " " .. MONTHS[today.month]) end
    PlayScene.game = game
end

function PlayScene.enter(mode, sizeIndex)
    PlayScene.mode = mode
    -- The daily maze is the same size for everyone
    PlayScene.sizeIndex = mode == PlayScene.MODES.DAILY and Sizes.DEFAULT or sizeIndex
    newGame(mode == PlayScene.MODES.SCREENSAVER)
end

-- After escaping, the next maze is always a fresh random one, even after the daily maze
function PlayScene.playAgain()
    SceneManager.switch(PlayScene, PlayScene.MODES.EXPLORE, PlayScene.sizeIndex)
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
        if PlayScene.mode == PlayScene.MODES.SCREENSAVER then
            PlayScene.restart()
        else
            SceneManager.switch(EscapedScene, game.frames, PlayScene.playAgain)
            return
        end
    end

    MazeView.draw(PlayScene.game)
    Hud.draw(PlayScene.game)
end
