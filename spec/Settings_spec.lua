local stub = require("spec.support.playdate_stub")
import "Settings"

describe("Settings", function()
    before_each(function()
        stub.reset()
        Settings.load()
    end)

    it("has the music on until the player turns it off", function() assert.is_true(Settings.isMusicOn()) end)

    it("turns the music off and on", function()
        Settings.setMusicOn(false)
        assert.is_false(Settings.isMusicOn())
        Settings.setMusicOn(true)
        assert.is_true(Settings.isMusicOn())
    end)

    it("remembers the choice the next time the game is started", function()
        Settings.setMusicOn(false)
        Settings.load()
        assert.is_false(Settings.isMusicOn())
    end)

    it("writes to disk only when something changes", function()
        Settings.setMusicOn(true)
        assert.is_nil(stub.writeCounts[Settings.FILE])
        Settings.setMusicOn(false)
        Settings.setMusicOn(false)
        assert.are.equal(1, stub.writeCounts[Settings.FILE])
    end)

    it("keeps its file apart from the saved game's", function() assert.are_not.equal("run", Settings.FILE) end)
end)
