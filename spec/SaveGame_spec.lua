local stub = require("spec.support.playdate_stub")
import "Game"
import "SaveGame"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

local function newGame(hasPuzzle)
    return Game.new({ columns = 6, rows = 5, hasPuzzle = hasPuzzle ~= false, random = seededRandom(21) })
end

describe("SaveGame", function()
    before_each(function() stub.reset() end)

    it("has nothing to continue at first", function()
        assert.is_false(SaveGame.exists())
        assert.is_nil(SaveGame.read())
    end)

    it("keeps a game with the mode and size it was being played in", function()
        local game = newGame()
        for _ = 1, 30 do game:update({ forward = 1 }) end
        SaveGame.write(game, "daily", 3)
        assert.is_true(SaveGame.exists())

        local loaded, mode, sizeIndex = SaveGame.read()
        assert.are.same({ game.player.x, game.player.y }, { loaded.player.x, loaded.player.y })
        assert.are.equal(game.frames, loaded.frames)
        assert.are.equal("daily", mode)
        assert.are.equal(3, sizeIndex)
    end)

    it("keeps only the latest game", function()
        local first, second = newGame(), newGame()
        for _ = 1, 30 do second:update({ forward = 1 }) end
        SaveGame.write(first, "explore", 2)
        SaveGame.write(second, "explore", 2)
        assert.are.equal(second.frames, (SaveGame.read()).frames)
    end)

    it("can be thrown away", function()
        SaveGame.write(newGame(), "explore", 2)
        SaveGame.delete()
        assert.is_false(SaveGame.exists())
    end)

    it("throws away a save it cannot load, and says there is nothing to continue", function()
        SaveGame.write(newGame(), "explore", 2)
        stub.datastore[SaveGame.FILE].game.version = 999
        assert.is_nil(SaveGame.read())
        assert.is_false(SaveGame.exists())
    end)
end)
