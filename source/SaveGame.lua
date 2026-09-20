-- Keeps one game on the Playdate's disk, so a run can be carried on after the console sleeps or
-- the game is closed. Only mazes with a puzzle are kept: the screensaver has nothing to lose.

import "Game"

local datastore <const> = playdate.datastore

SaveGame = {}

SaveGame.FILE = "run"

function SaveGame.exists()
    return datastore.read(SaveGame.FILE) ~= nil
end

-- mode and sizeIndex are the play scene's, so that the run resumes as the kind of game it was
function SaveGame.write(game, mode, sizeIndex)
    datastore.write({ game = game:toSave(), mode = mode, sizeIndex = sizeIndex }, SaveGame.FILE)
end

function SaveGame.delete()
    datastore.delete(SaveGame.FILE)
end

-- Returns the game, its mode, and its size, or nil if there is nothing that can be continued.
-- A save from a version of the game that cannot read it is thrown away: an update to the game
-- must never leave the player with a Continue that crashes.
function SaveGame.read()
    local save = datastore.read(SaveGame.FILE)
    if not save then return nil end
    if save.game.version ~= Game.SAVE_VERSION then
        SaveGame.delete()
        return nil
    end
    return Game.fromSave(save.game), save.mode, save.sizeIndex
end
