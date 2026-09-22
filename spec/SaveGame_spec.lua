local stub = require("spec.support.playdate_stub")
import "Game"
import "SaveGame"
import "Bob"
import "CrankSteps"
import "PlayInput"

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

local function withRestorer(restore)
    local environment = setmetatable({
        import = function() end,
        Game = setmetatable({ fromSave = restore }, { __index = Game }),
    }, { __index = _G })
    assert(loadfile("source/SaveGame.lua", "t", environment))()
    return environment.SaveGame
end

describe("SaveGame", function()
    before_each(function() stub.reset() end)

    it("has nothing to continue at first", function()
        assert.is_false(SaveGame.exists())
        assert.is_nil(SaveGame.read())
    end)

    it("keeps a game with the mode and size it was being played in", function()
        local game = newGame()
        for _ = 1, 30 do
            game:update({ forward = 1 })
        end
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
        for _ = 1, 30 do
            second:update({ forward = 1 })
        end
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
    for name, corrupt in pairs({
        empty = function() return {} end,
        scalar = function() return false end,
        missingGame = function(save) save.game = nil end,
        wrongGame = function(save) save.game = "broken" end,
        version = function(save) save.game.version = 999 end,
        player = function(save) save.game.player = {} end,
        maze = function(save) save.game.maze.blocks[1] = {} end,
        puzzle = function(save) save.game.puzzle.items[1] = {} end,
        thread = function(save) save.game.thread = {} end,
        landmark = function(save) save.game.landmarks = { { kind = "picture" } } end,
        flipper = function(save) save.game.flippers = { false } end,
        mode = function(save) save.mode = "broken" end,
        size = function(save) save.sizeIndex = 0 end,
    }) do
        for _, operation in ipairs({ "exists", "read" }) do
            it("discards " .. name .. " data during " .. operation, function()
                SaveGame.write(newGame(), "explore", 2)
                local replacement = corrupt(stub.datastore[SaveGame.FILE])
                if replacement ~= nil then stub.datastore[SaveGame.FILE] = replacement end
                local result = SaveGame[operation]()
                if operation == "exists" then
                    assert.is_false(result)
                    result = nil
                end
                assert.are.same({ result = nil, datastore = {} }, {
                    result = result,
                    datastore = stub.datastore,
                })
            end)
        end
    end

    it("restores detached data without changing the stored snapshot", function()
        local game = newGame()
        SaveGame.write(game, "explore", 2)
        local expected = game:toSave()
        local loaded, mode, sizeIndex = SaveGame.read()
        assert.are.same({ expected, "explore", 2 }, { loaded:toSave(), mode, sizeIndex })
        loaded.puzzle.items[1].state = "placed"
        assert.are.same(expected, stub.datastore[SaveGame.FILE].game)
    end)

    it("preserves saves when restoration raises an unrelated programming error", function()
        SaveGame.write(newGame(), "explore", 2)
        local saving = withRestorer(function() error("restoration bug", 0) end)
        local ok, message = pcall(saving.read)
        assert.are.same({ false, "restoration bug" }, { ok, message })
        assert.is_true(SaveGame.exists())
    end)
    it("discards a save when restoration returns no game", function()
        SaveGame.write(newGame(), "explore", 2)
        local saving = withRestorer(function() return nil end)
        local result = saving.read()
        assert.are.same({ datastore = {} }, { result = result, datastore = stub.datastore })
    end)

    it("removes Continue when a save becomes unreadable after opening the title", function()
        local environment = setmetatable({ import = function() end }, { __index = _G })
        assert(loadfile("source/scenes/TitleScene.lua", "t", environment))()
        local entered, switched = 0, 0
        environment.TitleScene.enter = function() entered = entered + 1 end
        environment.SceneManager = { switch = function() switched = switched + 1 end }
        SaveGame.write(newGame(), "explore", 2)
        assert.is_true(SaveGame.exists())
        stub.datastore[SaveGame.FILE] = {}
        environment.TitleScene.continueSavedGame()
        assert.are.same({ entered = 1, switched = 0, datastore = {} }, {
            entered = entered,
            switched = switched,
            datastore = stub.datastore,
        })
    end)
end)
