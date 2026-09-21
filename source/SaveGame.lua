-- Keeps one game on the Playdate's disk, so a run can be carried on after the console sleeps or
-- the game is closed. Only mazes with a puzzle are kept: the screensaver has nothing to lose.

import "Game"


---@class SaveGame
SaveGame = {}

SaveGame.FILE = "run"

---@return boolean
function SaveGame.exists()
    return playdate.datastore.read(SaveGame.FILE) ~= nil
end

-- Keep the on-disk "mode" key so existing saves retain their first-person submode.
---@param game Game
---@param submode string
---@param sizeIndex integer
---@return nil
function SaveGame.write(game, submode, sizeIndex)
    playdate.datastore.write({ game = game:toSave(), mode = submode, sizeIndex = sizeIndex }, SaveGame.FILE)
end

---@return nil
function SaveGame.delete()
    playdate.datastore.delete(SaveGame.FILE)
end

-- Returns the game, its first-person submode, and its size, or nil if there is no saved game.
-- A save from a version of the game that cannot read it is thrown away: an update to the game
-- must never leave the player with a Continue that crashes.
---@return Game?, string?, integer?
function SaveGame.read()
    local save = playdate.datastore.read(SaveGame.FILE)
    if not save then return nil end
    if save.game.version ~= Game.SAVE_VERSION then
        SaveGame.delete()
        return nil
    end
    return Game.fromSave(save.game), save.mode, save.sizeIndex
end
