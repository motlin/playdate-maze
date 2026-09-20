-- Walking the maze, by hand or on autopilot.
-- Explore has the puzzle and ends at the Escaped scene. The daily maze is Explore with the date
-- as the seed, so everyone gets the same medium maze on the same day. The screensaver has no
-- puzzle, starts on autopilot, and rolls straight into a new maze whenever it finds the way out.

import "Bob"
import "DockTimer"
import "Game"
import "Hud"
import "MazeView"
import "Music"
import "SaveGame"
import "SceneManager"
import "SeededRandom"
import "Sounds"
import "Sizes"
import "TapOrReel"

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

-- Where the screensaver's music sits between far from the exit (0) and beside it (1)
local SCREENSAVER_MUSIC <const> = 0.3
local MONTHS <const> = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local input = {}
-- B is tapped to put a shape down, or held while cranking backwards to reel in the thread
local bButton = TapOrReel.new()
-- Putting the crank away and leaving the game alone hands over to the autopilot
local dockTimer = DockTimer.new()
local headBob = Bob.new()

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
    if today then
        game:say("Daily maze: " .. today.day .. " " .. MONTHS[today.month])
    elseif game.puzzle then
        game:say("Lost? Hold Ⓑ and crank backwards")
    end
    PlayScene.game = game
end

-- savedGame, if given, is a game from SaveGame to carry on with instead of starting a new one
function PlayScene.enter(mode, sizeIndex, savedGame)
    PlayScene.mode = mode
    dockTimer = DockTimer.new()
    headBob = Bob.new()
    -- The daily maze is the same size for everyone
    PlayScene.sizeIndex = mode == PlayScene.MODES.DAILY and Sizes.DEFAULT or sizeIndex
    if savedGame then
        PlayScene.game = savedGame
        return
    end
    -- A new maze with a puzzle replaces whatever was saved; the screensaver leaves it be
    if mode ~= PlayScene.MODES.SCREENSAVER then SaveGame.delete() end
    newGame(mode == PlayScene.MODES.SCREENSAVER)
end

-- Keeps the run on disk so that it can be continued. Called when the game pauses, sleeps,
-- quits, or is left for the title screen.
function PlayScene.save()
    local game = PlayScene.game
    if game.puzzle and not game.hasEscaped then SaveGame.write(game, PlayScene.mode, PlayScene.sizeIndex) end
end

-- After escaping, the next maze is always a fresh random one, even after the daily maze
function PlayScene.playAgain()
    SceneManager.switch(PlayScene, PlayScene.MODES.EXPLORE, PlayScene.sizeIndex)
end

function PlayScene.exit()
    PlayScene.save()
    Sounds.stopHum()
    Music.stop()
end

function PlayScene.restart()
    if PlayScene.mode ~= PlayScene.MODES.SCREENSAVER then SaveGame.delete() end
    newGame(PlayScene.game:isAutopilotOn())
    SystemMenu.setAutopilot(PlayScene.game:isAutopilotOn())
end

local function isAnyButtonJustPressed()
    for _, button in ipairs(BUTTONS) do
        if pd.buttonJustPressed(button) then return true end
    end
    return false
end

local function isAnyButtonDown()
    for _, button in ipairs(BUTTONS) do
        if pd.buttonIsPressed(button) then return true end
    end
    return false
end

local function setAutopilot(isOn)
    PlayScene.game:setAutopilot(isOn)
    SystemMenu.setAutopilot(isOn)
end

local function dockToDream()
    local game = PlayScene.game
    local action = dockTimer:update(pd.isCrankDocked(), isAnyButtonDown() or isAnyButtonJustPressed())
    if action == DockTimer.ACTIONS.HAND_OVER and not game:isAutopilotOn() then
        setAutopilot(true)
        game:say("Crank docked: autopilot")
    elseif action == DockTimer.ACTIONS.TAKE_BACK and game:isAutopilotOn() then
        setAutopilot(false)
        game:say("You have the controls")
    end
end

local function axis(negativeButton, positiveButton)
    local value = 0
    if pd.buttonIsPressed(negativeButton) then value = value - 1 end
    if pd.buttonIsPressed(positiveButton) then value = value + 1 end
    return value
end

local function readInput()
    local sideways = axis(pd.kButtonLeft, pd.kButtonRight)
    local crankChange = pd.getCrankChange()
    local reel, isBTapped = bButton:update(
        pd.buttonJustPressed(pd.kButtonB), pd.buttonIsPressed(pd.kButtonB), pd.buttonJustReleased(pd.kButtonB), crankChange
    )
    input.forward = axis(pd.kButtonDown, pd.kButtonUp)
    -- While B is held the crank belongs to the thread, not the view
    input.turn = bButton:isHeld() and 0 or crankChange
    -- The crank's own movement, which also works the gate; the D-pad's turning must not
    input.crank = input.turn
    input.reel = reel
    input.strafe = 0
    -- With the crank out, it does the looking and the D-pad sidesteps. Docked, the D-pad turns.
    if pd.isCrankDocked() then
        input.turn = sideways * DPAD_TURN_SPEED
    else
        input.strafe = sideways
    end
    input.pickUp = pd.buttonJustPressed(pd.kButtonA)
    input.drop = isBTapped
    return input
end

function PlayScene.update()
    local game = PlayScene.game
    dockToDream()
    if game:isAutopilotOn() and isAnyButtonJustPressed() then
        setAutopilot(false)
        -- The press that takes over does nothing else, not even when it is let go
        readInput()
        bButton:ignoreThisPress()
        input.pickUp, input.drop, input.reel = false, false, 0
        game:update(input)
    else
        game:update(readInput())
    end

    Sounds.play(game.events)
    Sounds.hum(game)
    -- The screensaver's music stays calm and level; otherwise it follows the way to the exit
    Music.update(game, PlayScene.mode == PlayScene.MODES.SCREENSAVER and SCREENSAVER_MUSIC or nil)
    if game.hasEscaped then
        if PlayScene.mode == PlayScene.MODES.SCREENSAVER then
            PlayScene.restart()
        else
            SaveGame.delete()
            SceneManager.switch(EscapedScene, game.frames, PlayScene.playAgain)
            return
        end
    end

    headBob:walk(PlayScene.game.distanceWalked)
    MazeView.draw(PlayScene.game, headBob:headOffset())
    Hud.draw(PlayScene.game)
end
