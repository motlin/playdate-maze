-- Walking the maze, by hand or on autopilot.
-- Explore has the puzzle and ends at the Escaped scene. The daily maze is Explore with the date
-- as the seed, so everyone gets the same medium maze on the same day. The screensaver has no
-- puzzle, starts on autopilot, and rolls straight into a new maze whenever it finds the way out.
-- Custom plays a map drawn in the editor, which has no autopilot.

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
    SUBMODES = { EXPLORE = "explore", DAILY = "daily", SCREENSAVER = "screensaver", CUSTOM = "custom" },
    game = nil,
    -- The map being played in the custom submode. A custom game carried on from a save has none,
    -- as only the game is saved, so it cannot be started afresh from here.
    design = nil,
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
    if FirstPersonScene.submode == FirstPersonScene.SUBMODES.CUSTOM then
        local game = Game.fromDesign(FirstPersonScene.design, math.random)
        game:say("Your maze. Lost? Hold Ⓑ and crank backwards")
        FirstPersonScene.game = game
        return
    end
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

-- savedGame, if given, is a game from SaveGame to carry on with instead of starting a new one.
-- design is the map to play in the custom submode.
function FirstPersonScene.enter(submode, sizeIndex, savedGame, design)
    FirstPersonScene.submode = submode
    FirstPersonScene.design = design
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

-- Whether the map being played is at hand to be played again from the start
function FirstPersonScene.hasDesign()
    return FirstPersonScene.submode == FirstPersonScene.SUBMODES.CUSTOM and FirstPersonScene.design ~= nil
end

-- After escaping, the next maze is a fresh random one, even after the daily maze; but a
-- hand-made map is played again, or chosen again if it was carried on from a save
function FirstPersonScene.playAgain()
    if FirstPersonScene.hasDesign() then
        SceneManager.switch(FirstPersonScene, FirstPersonScene.SUBMODES.CUSTOM, FirstPersonScene.sizeIndex, nil, FirstPersonScene.design)
    elseif FirstPersonScene.submode == FirstPersonScene.SUBMODES.CUSTOM then
        SceneManager.switch(MyMazesScene)
    else
        SceneManager.switch(FirstPersonScene, FirstPersonScene.SUBMODES.EXPLORE, FirstPersonScene.sizeIndex)
    end
end

function FirstPersonScene.exit()
    FirstPersonScene.save()
    Sounds.stopHum()
    Music.stop()
end

function FirstPersonScene.restart()
    if FirstPersonScene.submode ~= FirstPersonScene.SUBMODES.SCREENSAVER then SaveGame.delete() end
    if FirstPersonScene.submode == FirstPersonScene.SUBMODES.CUSTOM and not FirstPersonScene.hasDesign() then
        SceneManager.switch(MyMazesScene)
        return
    end
    FirstPersonScene.newGame(FirstPersonScene.game:isAutopilotOn())
end

function FirstPersonScene.applyDockAction(action)
    local game = FirstPersonScene.game
    if action == DockTimer.ACTIONS.HAND_OVER and game:canAutopilot() and not game:isAutopilotOn() then
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
