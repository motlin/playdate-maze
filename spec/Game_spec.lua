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

        it("scatters landmarks, the same ones for the same random numbers", function()
            local game = newGame()
            assert.are.equal(30 // 5, #game.landmarks.all)
            assert.are.same(game.landmarks.all, newGame().landmarks.all)
            assert.is_true(#newGame({ hasPuzzle = false }).landmarks.all > 0)
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

        it("has a compass heading that follows the view", function()
            local game = newGame()
            game.player.angle = 0
            game:update({ turn = 270 })
            assert.are.equal(270, game:heading())
        end)

        describe("distanceWalked", function()
            it("is how far the player went this frame", function()
                local game = newGame()
                game:update({ forward = 1 })
                assert.is_near(Game.WALK_SPEED, game.distanceWalked, 0.0001)
                game:update({})
                assert.are.equal(0, game.distanceWalked)
            end)

            it("is nothing when a wall stops the player, however hard they push", function()
                local game = newGame()
                game.player.angle = (game.player.angle + 180) % 360
                for _ = 1, 20 do game:update({ forward = 1 }) end
                assert.are.equal(0, game.distanceWalked)
            end)

            it("counts the autopilot's walking", function()
                local game = newGame()
                game:setAutopilot(true)
                local most = 0
                for _ = 1, 100 do
                    game:update({})
                    most = math.max(most, game.distanceWalked)
                end
                assert.is_near(Game.WALK_SPEED, most, 0.0001)
            end)

            it("does not count being reeled along the thread, which is not walking", function()
                local game = newGame()
                for _ = 1, 25 do game:update({ forward = 1 }) end
                game:update({ reel = 90 })
                assert.are.equal(0, game.distanceWalked)
            end)
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

    describe("the thread", function()
        local function distanceFromStart(game)
            return math.sqrt((game.player.x - 1.5) ^ 2 + (game.player.y - 1.5) ^ 2)
        end

        it("is laid as the player walks", function()
            local game = newGame()
            assert.are.equal(0, game.thread:length())
            for _ = 1, 25 do game:update({ forward = 1 }) end
            assert.is_near(2, game.thread:length(), 0.3)
        end)

        it("is laid by the autopilot too", function()
            local game = newGame()
            game:setAutopilot(true)
            for _ = 1, 100 do game:update({}) end
            assert.is_true(game.thread:length() > 1)
        end)

        it("reels the player back along it, a block for every half turn of the crank", function()
            local game = newGame()
            for _ = 1, 25 do game:update({ forward = 1 }) end
            local before = distanceFromStart(game)
            game:update({ reel = 90 })
            game:update({ reel = 90 })
            assert.is_near(before - 1, distanceFromStart(game), 0.05)
        end)

        it("ignores the D-pad and the crank's turning while reeling", function()
            local game = newGame()
            for _ = 1, 25 do game:update({ forward = 1 }) end
            local before = distanceFromStart(game)
            game:update({ reel = 90, forward = 1, turn = 45 })
            assert.is_true(distanceFromStart(game) < before)
        end)

        it("keeps the player looking the way they originally walked, like a film run backwards", function()
            local game = newGame()
            local angle = game.player.angle
            for _ = 1, 25 do game:update({ forward = 1 }) end
            for _ = 1, 10 do game:update({ reel = 20 }) end
            assert.is_near(angle, game.player.angle, 0.001)
        end)

        it("turns the view gradually when the thread goes round a corner", function()
            local game = newGame()
            for _ = 1, 25 do game:update({ forward = 1 }) end
            game.player.angle = (game.player.angle + 90) % 360
            local angle = game.player.angle
            game:update({ reel = 10 })
            local turned = math.abs((game.player.angle - angle + 180) % 360 - 180)
            assert.is_true(turned > 0 and turned <= Game.REEL_TURN_SPEED + 0.0001)
        end)

        it("stops at the start and says so", function()
            local game = newGame()
            for _ = 1, 25 do game:update({ forward = 1 }) end
            for _ = 1, 10 do game:update({ reel = 180 }) end
            assert.is_near(0, distanceFromStart(game), 0.0001)
            assert.are.equal("The thread begins here", game.message)
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

        it("unlocks the gate when the last shape is placed, but leaves it down", function()
            local game = newGame()
            assert.is_false(game.isGateUnlocked)
            solve(game)
            assert.is_true(game.isGateUnlocked)
            assert.are.equal("The gate is unlocked! Crank it open", game.message)
            assert.is_false(game.maze:hasPassage(6, 5, "east"))
        end)

        it("clears a message after a couple of seconds", function()
            local game = newGame()
            game:update({ pickUp = true })
            for _ = 1, Game.MESSAGE_FRAMES do game:update({}) end
            assert.is_nil(game.message)
        end)
    end)

    describe("hint", function()
        it("has nothing to suggest in an empty corridor", function()
            assert.is_nil(newGame():hint())
        end)

        it("offers to pick up a shape within reach", function()
            local game = newGame()
            standOn(game, game.puzzle.items[2])
            assert.are.equal("Ⓐ Pick up the triangle", game:hint())
        end)

        it("offers to place the carried shape when its pedestal is within reach", function()
            local game = newGame()
            standOn(game, game.puzzle.items[1])
            game:update({ pickUp = true })
            assert.is_nil(game:hint())
            standOn(game, game.puzzle.pedestals[1])
            assert.are.equal("Ⓑ Place the circle", game:hint())
        end)

        it("says how to take over from the autopilot", function()
            local game = newGame()
            game:setAutopilot(true)
            assert.are.equal("Autopilot: press any button to take over", game:hint())
        end)

        it("has nothing to suggest when there is no puzzle", function()
            assert.is_nil(newGame({ hasPuzzle = false }):hint())
        end)
    end)

    describe("the gate", function()
        -- Solved, and standing in the last cell looking at the gate
        local function atTheGate()
            local game = newGame()
            solve(game)
            game.player.x, game.player.y = game.maze:cellCenter(6, 5)
            game.player.angle = 0
            return game
        end

        it("starts fully down", function()
            assert.are.equal(0, newGame().gateLift)
        end)

        it("rises as the crank is turned forwards, taking two full turns to open", function()
            local game = atTheGate()
            for _ = 1, 12 do game:update({ crank = 30, turn = 30 }) end
            assert.is_near(0.5, game.gateLift, 0.01)
            assert.is_false(game.maze:hasPassage(6, 5, "east"))
        end)

        it("does not turn the view while the crank is lifting it", function()
            local game = atTheGate()
            game:update({ crank = 30, turn = 30 })
            assert.are.equal(0, game.player.angle)
        end)

        it("opens the exit for good once it is all the way up", function()
            local game = atTheGate()
            for _ = 1, 24 do game:update({ crank = 30, turn = 30 }) end
            assert.is_true(game.maze:hasPassage(6, 5, "east"))
            assert.are.equal("The exit is open!", game.message)
            assert.are.equal(1, game.gateLift)
            for _ = 1, 200 do game:update({}) end
            assert.are.equal(1, game.gateLift)
        end)

        it("sags back down when the cranking stops", function()
            local game = atTheGate()
            for _ = 1, 12 do game:update({ crank = 30, turn = 30 }) end
            for _ = 1, 30 do game:update({}) end
            assert.is_true(game.gateLift < 0.45 and game.gateLift > 0)
            for _ = 1, 600 do game:update({}) end
            assert.are.equal(0, game.gateLift)
        end)

        it("does not move for a backwards crank, which looks around as usual", function()
            local game = atTheGate()
            game:update({ crank = -20, turn = -20 })
            assert.are.equal(0, game.gateLift)
            assert.are.equal(340, game.player.angle)
        end)

        it("does not move for the D-pad's turning, only for the crank itself", function()
            local game = atTheGate()
            game:update({ turn = 5 })
            assert.are.equal(0, game.gateLift)
            assert.are.equal(5, game.player.angle)
        end)

        it("cannot be cranked while it is still locked", function()
            local game = newGame()
            game.player.x, game.player.y = game.maze:cellCenter(6, 5)
            game.player.angle = 0
            game:update({ crank = 30, turn = 30 })
            assert.are.equal(0, game.gateLift)
            assert.are.equal(30, game.player.angle)
        end)

        it("cannot be cranked from far away, or with your back to it", function()
            local game = atTheGate()
            game.player.angle = 180
            game:update({ crank = 30, turn = 30 })
            assert.are.equal(0, game.gateLift)

            game.player.x, game.player.y = game.maze:cellCenter(1, 1)
            game.player.angle = 0
            game:update({ crank = 30, turn = 30 })
            assert.are.equal(0, game.gateLift)
        end)

        it("tells the player what to do with it", function()
            local game = atTheGate()
            assert.are.equal("Crank forwards to raise the gate", game:hint())
        end)
    end)

    describe("escaping", function()
        it("has not escaped while inside the maze", function()
            assert.is_false(newGame().hasEscaped)
        end)

        it("escapes by walking out once the gate has been cranked open", function()
            local game = newGame()
            solve(game)
            game.player.x, game.player.y = game.maze:cellCenter(6, 5)
            game.player.angle = 0
            for _ = 1, 24 do game:update({ crank = 30, turn = 30 }) end
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
