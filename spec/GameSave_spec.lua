require("spec.support.playdate_stub")
import "Game"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

local function newGame()
    return Game.new({ columns = 6, rows = 5, hasPuzzle = true, random = seededRandom(21) })
end

-- What JSON does to a table: only lists and string-keyed tables survive, so anything else is an error
local function throughJson(value, path)
    if type(value) ~= "table" then
        assert(type(value) == "number" or type(value) == "string" or type(value) == "boolean", path .. " cannot be saved")
        return value
    end
    local copy, count = {}, 0
    for _ in pairs(value) do count = count + 1 end
    local isList = count == #value
    for key, item in pairs(value) do
        assert(isList or type(key) == "string", path .. " mixes list and named entries, or has number keys")
        copy[key] = throughJson(item, path .. "." .. tostring(key))
    end
    return copy
end

-- A game part-way through: walked about, one shape home, another in hand, the world turned over
local function gameInProgress()
    local game = newGame()
    for _ = 1, 40 do game:update({ forward = 1, turn = 2 }) end
    local puzzle = game.puzzle
    game.player.x, game.player.y = game.maze:blockCenter(puzzle.items[1].gridX, puzzle.items[1].gridY)
    game:update({ pickUp = true })
    game.player.x, game.player.y = game.maze:blockCenter(puzzle.pedestals[1].gridX, puzzle.pedestals[1].gridY)
    game:update({ drop = true })
    game.player.x, game.player.y = game.maze:blockCenter(puzzle.items[2].gridX, puzzle.items[2].gridY)
    game:update({ pickUp = true })
    local flipper = game.flippers.all[1]
    game.player.x, game.player.y = flipper.gridX - 0.5, flipper.gridY - 0.5
    game:update({})
    return game
end

describe("saving a game", function()
    it("writes only what JSON can hold", function()
        throughJson(gameInProgress():toSave(), "save")
    end)

    it("says which version of the save it is", function()
        assert.are.equal(Game.SAVE_VERSION, gameInProgress():toSave().version)
    end)

    describe("and loading it again", function()
        local function restored(game)
            return Game.fromSave(throughJson(game:toSave(), "save"))
        end

        it("brings back the same maze, player, and clock", function()
            local game = gameInProgress()
            local loaded = restored(game)
            assert.are.same(game.maze.blocks, loaded.maze.blocks)
            assert.are.same({ game.maze.columns, game.maze.rows }, { loaded.maze.columns, loaded.maze.rows })
            assert.are.same({ game.player.x, game.player.y, game.player.angle }, { loaded.player.x, loaded.player.y, loaded.player.angle })
            assert.are.equal(game.frames, loaded.frames)
        end)

        it("brings back the puzzle as it stood, with the carried shape still in hand", function()
            local game = gameInProgress()
            local loaded = restored(game)
            assert.are.equal(Puzzle.STATES.PLACED, loaded.puzzle.items[1].state)
            assert.is_true(loaded.puzzle.pedestals[1].isFilled)
            assert.are.equal(loaded.puzzle.items[2], loaded.puzzle.carried)
            assert.are.equal(Puzzle.STATES.GROUND, loaded.puzzle.items[3].state)
        end)

        it("brings back the map's fog, the thread, the flipped world, and the landmarks", function()
            local game = gameInProgress()
            local loaded = restored(game)
            assert.are.equal(game.visitedCount, loaded.visitedCount)
            for row = 1, 5 do
                for column = 1, 6 do assert.are.equal(game:hasVisited(column, row), loaded:hasVisited(column, row)) end
            end
            assert.is_near(game.thread:length(), loaded.thread:length(), 0.0001)
            assert.is_true(loaded.isFlipped)
            assert.are.same(game.landmarks.all, loaded.landmarks.all)
            local picture
            for _, landmark in ipairs(loaded.landmarks.all) do
                if landmark.kind == "picture" then picture = landmark end
            end
            assert.are.equal(picture.motif, loaded.landmarks:pictureOn(picture.gridX, picture.gridY, picture.face))
        end)

        it("brings back a gate that was part-way up", function()
            local game = newGame()
            for index, item in ipairs(game.puzzle.items) do
                game.player.x, game.player.y = game.maze:blockCenter(item.gridX, item.gridY)
                game:update({ pickUp = true })
                local pedestal = game.puzzle.pedestals[index]
                game.player.x, game.player.y = game.maze:blockCenter(pedestal.gridX, pedestal.gridY)
                game:update({ drop = true })
            end
            game.player.x, game.player.y = game.maze:cellCenter(6, 5)
            game.player.angle = 0
            for _ = 1, 10 do game:update({ crank = 30, turn = 30 }) end
            local loaded = restored(game)
            assert.is_true(loaded.isGateUnlocked)
            assert.are.equal(game.gateDegrees, loaded.gateDegrees)
            assert.are.equal(game.gateLift, loaded.gateLift)
        end)

        it("plays on exactly as the original would have", function()
            local game = gameInProgress()
            local loaded = restored(game)
            local random = seededRandom(5)
            for _ = 1, 300 do
                local input = { turn = random(11) - 6, forward = random(3) - 2, strafe = random(3) - 2 }
                game:update(input)
                loaded:update(input)
            end
            assert.are.same({ game.player.x, game.player.y, game.player.angle }, { loaded.player.x, loaded.player.y, loaded.player.angle })
            assert.are.equal(game.visitedCount, loaded.visitedCount)
            assert.are.equal(game.isFlipped, loaded.isFlipped)
        end)

        it("does not resume on autopilot", function()
            local game = gameInProgress()
            game:setAutopilot(true)
            assert.is_false(restored(game):isAutopilotOn())
        end)
    end)

    it("refuses a save from a version it does not know, rather than half-loading it", function()
        local save = gameInProgress():toSave()
        save.version = Game.SAVE_VERSION + 1
        assert.has_error(function() Game.fromSave(save) end)
    end)

    it("refuses to save a maze with no puzzle, which is the screensaver's", function()
        local game = Game.new({ columns = 6, rows = 5, hasPuzzle = false, random = seededRandom(21) })
        assert.has_error(function() game:toSave() end)
    end)
end)
