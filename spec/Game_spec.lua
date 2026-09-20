require("spec.support.playdate_stub")
import "Game"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

local function newGame(options)
    options = options or {}
    return Game.new({
        columns = options.columns or 6,
        rows = options.rows or 5,
        hasPuzzle = options.hasPuzzle ~= false,
        random = seededRandom(options.seed or 21),
    })
end

-- Stands the player in the middle of the block that holds `thing`
local function standOn(game, thing)
    game.player.x, game.player.y = game.maze:blockCenter(thing.gridX, thing.gridY)
end

local function solve(game)
    for index, item in ipairs(game.puzzle.items) do
        standOn(game, item)
        game:update({ pickUp = true })
        standOn(game, game.puzzle.pedestals[index])
        game:update({ drop = true })
    end
end

describe("Game", function()
    describe("new", function()
        it("starts the player in the middle of the first cell, looking down a passage", function()
            local game = newGame()
            assert.are.same({ 1.5, 1.5 }, { game.player.x, game.player.y })
            assert.is_true(game.maze:hasPassage(1, 1, game.player:facing()))
        end)

        it("locks the exit behind a puzzle", function()
            local game = newGame()
            assert.are.equal(3, #game.puzzle.items)
            assert.is_false(game.maze:hasPassage(6, 5, "east"))
        end)

        it("leaves the exit open when there is no puzzle", function()
            local game = newGame({ hasPuzzle = false })
            assert.is_nil(game.puzzle)
            assert.is_true(game.maze:hasPassage(6, 5, "east"))
        end)
    end)

    describe("walking", function()
        it("turns by the given number of degrees", function()
            local game = newGame()
            local angle = game.player.angle
            game:update({ turn = 12 })
            assert.are.equal((angle + 12) % 360, game.player.angle)
        end)

        it("walks forward at walking speed", function()
            local game = newGame()
            game:update({ forward = 1 })
            local distance = math.sqrt((game.player.x - 1.5) ^ 2 + (game.player.y - 1.5) ^ 2)
            assert.is_near(Game.WALK_SPEED, distance, 0.0001)
        end)

        it("counts the frames played", function()
            local game = newGame()
            for _ = 1, 45 do game:update({}) end
            assert.are.equal(45, game.frames)
        end)
    end)

    describe("exploring", function()
        it("has visited only the first cell to begin with", function()
            local game = newGame()
            assert.is_true(game:hasVisited(1, 1))
            assert.is_false(game:hasVisited(2, 1))
            assert.is_false(game:hasVisited(1, 2))
            assert.are.equal(1, game.visitedCount)
        end)

        it("marks a cell as visited when the player walks into it", function()
            local game = newGame()
            local offset = Maze.OFFSETS[game.player:facing()]
            for _ = 1, 30 do game:update({ forward = 1 }) end
            assert.is_true(game:hasVisited(1 + offset[1], 1 + offset[2]))
            assert.are.equal(2, game.visitedCount)
        end)

        it("counts a cell once however long the player stays in it", function()
            local game = newGame()
            for _ = 1, 50 do game:update({ turn = 5 }) end
            assert.are.equal(1, game.visitedCount)
        end)

        it("reveals on the map only what has been visited", function()
            local game = newGame()
            assert.is_true(game:isRevealed(1, 1))
            assert.is_false(game:isRevealed(6, 5))
        end)

        it("reveals the whole map when there is no puzzle, as the screensaver has nothing to hide", function()
            local game = newGame({ hasPuzzle = false })
            assert.is_true(game:isRevealed(6, 5))
        end)

        it("marks the cells the autopilot walks through", function()
            local game = newGame()
            game:setAutopilot(true)
            for _ = 1, 600 do game:update({}) end
            assert.is_true(game.visitedCount > 3)
        end)
    end)

    describe("the puzzle", function()
        it("picks up and says what was picked up", function()
            local game = newGame()
            standOn(game, game.puzzle.items[1])
            game:update({ pickUp = true })
            assert.are.equal("circle", game.puzzle.carried.shape)
            assert.are.equal("Picked up the circle", game.message)
        end)

        it("says so when there is nothing to pick up", function()
            local game = newGame()
            game:update({ pickUp = true })
            assert.are.equal("Nothing here to pick up", game.message)
        end)

        it("drops and says what was dropped", function()
            local game = newGame()
            standOn(game, game.puzzle.items[1])
            game:update({ pickUp = true })
            game.player.x, game.player.y = 1.5, 1.5
            game:update({ drop = true })
            assert.are.equal("Dropped the circle", game.message)
        end)

        it("says so when there is no room to drop", function()
            local game = newGame()
            standOn(game, game.puzzle.items[1])
            game:update({ pickUp = true })
            standOn(game, game.puzzle.pedestals[2])
            game:update({ drop = true })
            assert.are.equal("No room to put it down here", game.message)
        end)

        it("celebrates a shape reaching its pedestal", function()
            local game = newGame()
            standOn(game, game.puzzle.items[1])
            game:update({ pickUp = true })
            standOn(game, game.puzzle.pedestals[1])
            game:update({ drop = true })
            assert.are.equal("The circle fits!", game.message)
        end)

        it("opens the exit when the last shape is placed", function()
            local game = newGame()
            solve(game)
            assert.are.equal("The exit is open!", game.message)
            assert.is_true(game.maze:hasPassage(6, 5, "east"))
        end)

        it("clears a message after a couple of seconds", function()
            local game = newGame()
            game:update({ pickUp = true })
            for _ = 1, Game.MESSAGE_FRAMES do game:update({}) end
            assert.is_nil(game.message)
        end)
    end)

    describe("escaping", function()
        it("has not escaped while inside the maze", function()
            assert.is_false(newGame().hasEscaped)
        end)

        it("escapes by walking into the open exit", function()
            local game = newGame()
            solve(game)
            game.player.x, game.player.y = game.maze:cellCenter(6, 5)
            game.player.angle = 0
            for _ = 1, 30 do game:update({ forward = 1 }) end
            assert.is_true(game.hasEscaped)
        end)

        it("stops the clock once escaped", function()
            local game = newGame({ hasPuzzle = false })
            game.player.x, game.player.y = game.maze:cellCenter(6, 5)
            game.player.angle = 0
            for _ = 1, 100 do game:update({ forward = 1 }) end
            assert.is_true(game.frames < 30)
        end)
    end)

    describe("autopilot", function()
        it("is off to begin with", function()
            assert.is_false(newGame():isAutopilotOn())
        end)

        it("walks the maze by itself and ignores the D-pad", function()
            local game = newGame()
            game:setAutopilot(true)
            for _ = 1, 200 do game:update({ forward = -1 }) end
            local column, row = game.maze:nearestCell(game.player.x, game.player.y)
            assert.is_true(column > 1 or row > 1)
        end)

        it("hands control back when asked", function()
            local game = newGame()
            game:setAutopilot(true)
            for _ = 1, 50 do game:update({}) end
            game:setAutopilot(false)
            local x, y = game.player.x, game.player.y
            game:update({})
            assert.are.same({ x, y }, { game.player.x, game.player.y })
        end)

        it("finds its own way out of a maze with no puzzle", function()
            local game = newGame({ hasPuzzle = false })
            game:setAutopilot(true)
            for _ = 1, 20000 do
                game:update({})
                if game.hasEscaped then break end
            end
            assert.is_true(game.hasEscaped)
        end)
    end)
end)
