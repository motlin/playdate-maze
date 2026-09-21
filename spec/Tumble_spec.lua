require("spec.support.playdate_stub")
import "Maze"
import "Puzzle"
import "Tumble"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

-- One big open room, world x and y from 1 to 6, with the exit door in its east wall at y 5..6
local function room(items)
    local maze = Maze.generate(3, 3, seededRandom(1))
    for gridY = 2, 6 do
        for gridX = 2, 6 do
            maze.blocks[gridY][gridX] = Maze.BLOCKS.OPEN
        end
    end
    return Tumble.inMaze(maze, Puzzle.new(items or { { shape = "circle", gridX = 6, gridY = 2 } }, {}))
end

local function standOnFloor(tumble, x)
    tumble.player.x, tumble.player.y = x, 6 - Tumble.RADIUS - 0.000001
    tumble.velocityX, tumble.velocityY = 0, 0
    tumble:update({})
end

local function run(tumble, frames, input)
    for _ = 1, frames do
        tumble:update(input or {})
    end
end

describe("Tumble", function()
    describe("new", function()
        it("starts in the first cell of a fresh maze with three shapes to collect and the exit locked", function()
            local tumble = Tumble.new({ columns = 6, rows = 4, random = seededRandom(3) })
            assert.are.same({ 1.5, 1.5 }, { tumble.player.x, tumble.player.y })
            assert.are.equal(3, #tumble.puzzle.items)
            assert.are.equal(0, #tumble.puzzle.pedestals)
            assert.is_false(tumble.maze:hasPassage(6, 4, "east"))
            assert.are.equal(0, tumble.angle)
        end)
    end)

    describe("gravity", function()
        it("pulls the player down the screen until they land", function()
            local tumble = room()
            tumble.player.x, tumble.player.y = 3.5, 3.5
            run(tumble, 5)
            assert.is_true(tumble.player.y > 3.5)
            assert.is_false(tumble.isGrounded)
            run(tumble, 60)
            assert.is_near(6 - Tumble.RADIUS, tumble.player.y, 0.0001)
            assert.is_true(tumble.isGrounded)
            assert.are.equal(0, tumble.velocityY)
        end)

        it("never falls faster than the speed limit, so it cannot pass through a wall", function()
            local tumble = Tumble.new({ columns = 3, rows = 12, random = seededRandom(9) })
            for _ = 1, 600 do
                tumble:update({ turn = 7 })
                local speed = math.sqrt(tumble.velocityX ^ 2 + tumble.velocityY ^ 2)
                assert.is_true(speed <= Tumble.MAX_SPEED + 0.0001)
                assert.is_false(tumble.maze:isWall(tumble.maze:blockAt(tumble.player.x, tumble.player.y)))
            end
        end)
    end)

    describe("the crank", function()
        it("turns the maze, which turns which way is down inside it", function()
            local tumble = room()
            tumble.player.x, tumble.player.y = 3.5, 3.5
            tumble:update({ turn = 90 })
            assert.are.equal(90, tumble.angle)
            run(tumble, 80)
            -- A quarter turn clockwise on screen brings the maze's east wall underfoot
            assert.is_near(6 - Tumble.RADIUS, tumble.player.x, 0.0001)
            assert.is_true(tumble.isGrounded)
        end)

        it("keeps the angle between 0 and 360", function()
            local tumble = room()
            tumble:update({ turn = -30 })
            assert.are.equal(330, tumble.angle)
        end)

        it("points the player's arrow on the map the way gravity pulls", function()
            local tumble = room()
            assert.are.equal(90, tumble.player.angle)
            tumble:update({ turn = 90 })
            assert.are.equal(0, tumble.player.angle)
        end)
    end)

    describe("walking", function()
        it("walks along the floor to the right of the screen", function()
            local tumble = room()
            standOnFloor(tumble, 3.5)
            run(tumble, 20, { move = 1 })
            assert.is_true(tumble.player.x > 4.2)
            assert.is_near(6 - Tumble.RADIUS, tumble.player.y, 0.0001)
        end)

        it("walks right on screen even when the maze is upside down", function()
            local tumble = room()
            tumble.angle = 180
            tumble.player.x, tumble.player.y = 3.5, 1 + Tumble.RADIUS + 0.000001
            tumble:update({})
            run(tumble, 20, { move = 1 })
            assert.is_true(tumble.player.x < 2.8)
        end)

        it("comes to rest when the D-pad is let go", function()
            local tumble = room()
            standOnFloor(tumble, 3.5)
            run(tumble, 20, { move = 1 })
            run(tumble, 40)
            local x = tumble.player.x
            run(tumble, 10)
            assert.is_near(x, tumble.player.x, 0.001)
        end)

        it("faces the way it last walked", function()
            local tumble = room()
            standOnFloor(tumble, 3.5)
            assert.are.equal(1, tumble.facing)
            tumble:update({ move = -1 })
            assert.are.equal(-1, tumble.facing)
            tumble:update({})
            assert.are.equal(-1, tumble.facing)
        end)
    end)

    describe("jumping", function()
        it("jumps a little over a block high", function()
            local tumble = room()
            standOnFloor(tumble, 3.5)
            local highest = tumble.player.y
            tumble:update({ jump = true })
            for _ = 1, 60 do
                tumble:update({})
                highest = math.min(highest, tumble.player.y)
            end
            local height = (6 - Tumble.RADIUS) - highest
            assert.is_true(height > 1.05 and height < 1.5)
            assert.is_true(tumble.isGrounded)
        end)

        it("cannot jump again in mid-air", function()
            local tumble = room()
            standOnFloor(tumble, 3.5)
            tumble:update({ jump = true })
            run(tumble, 8)
            local rising = tumble.velocityY
            tumble:update({ jump = true })
            assert.is_true(tumble.velocityY > rising)
        end)

        it("stops rising when it bumps its head", function()
            local tumble = Tumble.inMaze(Maze.generate(3, 1, seededRandom(1)), Puzzle.new({}, {}))
            tumble.player.x, tumble.player.y = 1.5, 2 - Tumble.RADIUS - 0.000001
            tumble:update({})
            tumble:update({ jump = true })
            run(tumble, 6)
            assert.is_true(tumble.velocityY >= 0)
        end)

        it("jumps away from the floor whichever way the maze is turned", function()
            local tumble = room()
            tumble:update({ turn = 90 })
            run(tumble, 80)
            tumble:update({ jump = true })
            run(tumble, 5)
            assert.is_true(tumble.player.x < 6 - Tumble.RADIUS - 0.2)
        end)
    end)

    describe("a tilted maze", function()
        it("slides the player down the slope into the lowest corner", function()
            local tumble = room()
            standOnFloor(tumble, 2.5)
            tumble:update({ turn = 45 })
            run(tumble, 400)
            assert.is_near(6 - Tumble.RADIUS, tumble.player.x, 0.001)
            assert.is_near(6 - Tumble.RADIUS, tumble.player.y, 0.001)
        end)

        it("does not slide on a level floor", function()
            local tumble = room()
            standOnFloor(tumble, 2.5)
            run(tumble, 100)
            assert.is_near(2.5, tumble.player.x, 0.0001)
        end)
    end)

    describe("the shapes", function()
        it("collects a shape by touching it, and says how many are left", function()
            local tumble = room({
                { shape = "circle", gridX = 4, gridY = 6 },
                { shape = "square", gridX = 6, gridY = 2 },
            })
            standOnFloor(tumble, 2.5)
            run(tumble, 30, { move = 1 })
            assert.are.equal(Puzzle.STATES.PLACED, tumble.puzzle.items[1].state)
            assert.are.equal("Got the circle! 1 to go", tumble.message)
            assert.is_false(tumble.maze:hasPassage(3, 3, "east"))
        end)

        it("opens the exit when the last shape is collected", function()
            local tumble = room({ { shape = "circle", gridX = 4, gridY = 6 } })
            standOnFloor(tumble, 2.5)
            run(tumble, 30, { move = 1 })
            assert.are.equal("Got the circle! The exit is open", tumble.message)
            assert.is_true(tumble.maze:hasPassage(3, 3, "east"))
        end)
    end)

    describe("escaping", function()
        it("escapes by walking out of the open exit, and then stops the clock", function()
            local tumble = room({ { shape = "circle", gridX = 4, gridY = 6 } })
            standOnFloor(tumble, 2.5)
            run(tumble, 200, { move = 1 })
            assert.is_true(tumble.hasEscaped)
            local frames = tumble.frames
            run(tumble, 10, { move = 1 })
            assert.are.equal(frames, tumble.frames)
        end)
    end)

    describe("events, for the sounds", function()
        local function has(tumble, event)
            for _, name in ipairs(tumble.events) do
                if name == event then return true end
            end
            return false
        end

        it("reports a jump, and the landing after it", function()
            local tumble = room()
            standOnFloor(tumble, 3.5)
            tumble:update({ jump = true })
            assert.is_true(has(tumble, "jump"))
            local landings = 0
            for _ = 1, 60 do
                tumble:update({})
                if has(tumble, "land") then landings = landings + 1 end
            end
            assert.are.equal(1, landings)
        end)

        it("does not report a jump that did not happen", function()
            local tumble = room()
            tumble.player.x, tumble.player.y = 3.5, 3.5
            tumble:update({ jump = true })
            assert.is_false(has(tumble, "jump"))
        end)

        it("reports collecting a shape, the exit opening, and the escape", function()
            local tumble = room({ { shape = "circle", gridX = 4, gridY = 6 } })
            standOnFloor(tumble, 2.5)
            local seen = {}
            for _ = 1, 200 do
                tumble:update({ move = 1 })
                for _, name in ipairs(tumble.events) do
                    seen[name] = (seen[name] or 0) + 1
                end
            end
            assert.are.equal(1, seen.collect)
            assert.are.equal(1, seen.exitOpen)
            assert.are.equal(1, seen.escape)
        end)
    end)

    describe("hint", function()
        it("has nothing to suggest", function() assert.is_nil(room():hint()) end)
    end)

    describe("the map", function()
        it("reveals cells as the player reaches them", function()
            local tumble = room()
            standOnFloor(tumble, 1.5)
            assert.is_false(tumble:isRevealed(3, 1))
            assert.is_true(tumble:isRevealed(1, 3))
        end)
    end)
end)
