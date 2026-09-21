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
import "PlayInput"
import "SaveGame"
import "SceneManager"
import "SeededRandom"
import "Sizes"
import "Sounds"
import "WalkingActions"

local pd <const> = playdate

FirstPersonScene = {
    SUBMODES = { EXPLORE = "explore", DAILY = "daily", SCREENSAVER = "screensaver" },
    game = nil,
    submode = nil,
    sizeIndex = Sizes.DEFAULT,
}

-- Where the screensaver's music sits between far from the exit (0) and beside it (1)
local SCREENSAVER_MUSIC <const> = 0.3
local MONTHS <const> = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local controls = PlayInput.new()
local walkingActions = WalkingActions.new(controls)
-- Putting the crank away and leaving the game alone hands over to the autopilot
local dockTimer = DockTimer.new()
local headBob = Bob.new()

function FirstPersonScene.newGame(isAutopilotOn)
    local size = Sizes.ALL[FirstPersonScene.sizeIndex]
    local random = math.random
    local today
    if FirstPersonScene.submode == FirstPersonScene.SUBMODES.DAILY then
        today = pd.getTime()
        random = SeededRandom.new(SeededRandom.seedForDate(today.year, today.month, today.day))
    end
    local game = Game.new({
        columns = size.columns,
        rows = size.rows,
        hasPuzzle = FirstPersonScene.submode ~= FirstPersonScene.SUBMODES.SCREENSAVER,
        random = random,
    })
    game:setAutopilot(isAutopilotOn)
    if today then
        game:say("Daily maze: " .. today.day .. " " .. MONTHS[today.month])
    elseif game.puzzle then
        game:say("Lost? Hold Ⓑ and crank backwards")
    end
    FirstPersonScene.game = game
end

-- savedGame, if given, is a game from SaveGame to carry on with instead of starting a new one
function FirstPersonScene.enter(submode, sizeIndex, savedGame)
    FirstPersonScene.submode = submode
    dockTimer = DockTimer.new()
    headBob = Bob.new()
    -- The daily maze is the same size for everyone
    FirstPersonScene.sizeIndex = submode == FirstPersonScene.SUBMODES.DAILY and Sizes.DEFAULT or sizeIndex
    if savedGame then
        FirstPersonScene.game = savedGame
        return
    end
    -- A new maze with a puzzle replaces whatever was saved; the screensaver leaves it be
    if submode ~= FirstPersonScene.SUBMODES.SCREENSAVER then SaveGame.delete() end
    FirstPersonScene.newGame(submode == FirstPersonScene.SUBMODES.SCREENSAVER)
end

-- Keeps the run on disk so that it can be continued. Called when the game pauses, sleeps,
-- quits, or is left for the title screen.
function FirstPersonScene.save()
    local game = FirstPersonScene.game
    if game.puzzle and not game.hasEscaped then SaveGame.write(game, FirstPersonScene.submode, FirstPersonScene.sizeIndex) end
end

-- After escaping, the next maze is always a fresh random one, even after the daily maze
function FirstPersonScene.playAgain()
    SceneManager.switch(FirstPersonScene, FirstPersonScene.SUBMODES.EXPLORE, FirstPersonScene.sizeIndex)
end

function FirstPersonScene.exit()
    FirstPersonScene.save()
    Sounds.stopHum()
    Music.stop()
end

function FirstPersonScene.restart()
    if FirstPersonScene.submode ~= FirstPersonScene.SUBMODES.SCREENSAVER then SaveGame.delete() end
    FirstPersonScene.newGame(FirstPersonScene.game:isAutopilotOn())
end

function FirstPersonScene.applyDockAction(action)
    local game = FirstPersonScene.game
    if action == DockTimer.ACTIONS.HAND_OVER and not game:isAutopilotOn() then
        game:setAutopilot(true)
        game:say("Crank docked: autopilot")
    elseif action == DockTimer.ACTIONS.TAKE_BACK and game:isAutopilotOn() then
        game:setAutopilot(false)
        game:say("You have the controls")
    end
end

function FirstPersonScene.update()
    local game = FirstPersonScene.game
    local input = controls:read()
    local dockAction = dockTimer:update(input.isCrankDocked, input.current ~= 0 or input.pressed ~= 0)
    FirstPersonScene.applyDockAction(dockAction)
    local takingOver = game:isAutopilotOn() and input.pressed ~= 0
    if takingOver then game:setAutopilot(false) end
    game:update(walkingActions:read(takingOver))

    Sounds.play(game.events)
    Sounds.hum(game)
    -- The screensaver's music stays calm and level; otherwise it follows the way to the exit
    Music.update(game, FirstPersonScene.submode == FirstPersonScene.SUBMODES.SCREENSAVER and SCREENSAVER_MUSIC or nil)
    if game.hasEscaped then
        if FirstPersonScene.submode == FirstPersonScene.SUBMODES.SCREENSAVER then
            FirstPersonScene.restart()
        else
            SaveGame.delete()
            SceneManager.switch(EscapedScene, game.frames, FirstPersonScene.playAgain)
            return
        end
    end

    headBob:walk(FirstPersonScene.game.distanceWalked)
    MazeView.draw(FirstPersonScene.game, headBob:headOffset())
    Hud.draw(FirstPersonScene.game)
end
