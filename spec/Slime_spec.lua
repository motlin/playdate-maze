require("spec.support.playdate_stub")
import "Maze"
import "Puzzle"
import "Slime"

local RESTING <const> = Slime.STATES.RESTING
local CLINGING <const> = Slime.STATES.CLINGING
local SLIDING <const> = Slime.STATES.SLIDING
local FLYING <const> = Slime.STATES.FLYING

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

-- One big open room, world x and y from 1 to 12, with the exit door at floor level in its east
-- wall (world x 12..13, y 11..12)
local function room(items)
    local maze = Maze.generate(3, 3, seededRandom(1), 3)
    for gridY = 2, 12 do
        for gridX = 2, 12 do maze.blocks[gridY][gridX] = Maze.BLOCKS.OPEN end
    end
    return Slime.inMaze(maze, Puzzle.new(items or { { shape = "circle", gridX = 2, gridY = 2 } }, {}))
end

-- A single cell three blocks across and three high: world x and y from 1 to 4
local function cell()
    return Slime.inMaze(Maze.new(1, 1, 3), Puzzle.new({ { shape = "circle", gridX = 2, gridY = 2 } }, {}))
end

local FLOOR <const> = 12 - Slime.RADIUS

local function restAt(slime, x, floorY)
    slime.player.x, slime.player.y = x, (floorY or 12) - Slime.RADIUS - 0.000001
    slime.velocityX, slime.velocityY = 0, 0
    slime.state = FLYING
    slime:update({ aim = 0 })
    assert(slime.state == RESTING, "the helper should leave the slime resting on a floor")
end

local function run(slime, frames, input)
    for _ = 1, frames do slime:update(input or { aim = slime.aimAngle }) end
end

-- Holds A for a frame at the given angle, then lets go
local function throw(slime, angle)
    slime:update({ aim = angle, isAimHeld = true })
    slime:update({ aim = angle })
end

local function runUntilStuck(slime)
    for _ = 1, 400 do
        if slime.state ~= FLYING then return end
        slime:update({ aim = slime.aimAngle })
    end
    error("the slime never landed")
end

describe("Slime", function()
    describe("new", function()
        it("makes a fresh maze with corridors three blocks wide and three shapes to collect", function()
            local slime = Slime.new({ columns = 4, rows = 3, random = seededRandom(3) })
            assert.are.equal(3, slime.maze.corridorWidth)
            assert.are.equal(3, #slime.puzzle.items)
            assert.are.equal(0, #slime.puzzle.pedestals)
            assert.is_false(slime.maze:hasPassage(4, 3, "east"))
        end)

        it("drops the slime into the first cell, where it comes to rest on the floor", function()
            local slime = Slime.new({ columns = 4, rows = 3, random = seededRandom(3) })
            assert.are.same({ 2.5, 2.5 }, { slime.player.x, slime.player.y })
            runUntilStuck(slime)
            assert.are.equal(RESTING, slime.state)
            assert.is_near(4 - Slime.RADIUS, slime.player.y, 0.0001)
        end)
    end)

    describe("resting on a floor", function()
        it("is safe for as long as you like", function()
            local slime = room()
            restAt(slime, 6)
            run(slime, 500)
            assert.are.equal(RESTING, slime.state)
            assert.is_near(FLOOR, slime.player.y, 0.0001)
        end)

        it("crawls left and right with the D-pad", function()
            local slime = room()
            restAt(slime, 6)
            run(slime, 10, { aim = 0, move = 1 })
            assert.is_near(6 + 10 * Slime.CRAWL_SPEED, slime.player.x, 0.0001)
            run(slime, 20, { aim = 0, move = -1 })
            assert.is_near(6 - 10 * Slime.CRAWL_SPEED, slime.player.x, 0.0001)
        end)

        it("falls off the end of a ledge it crawls over", function()
            local slime = room()
            for gridX = 5, 7 do slime.maze.blocks[9][gridX] = Maze.BLOCKS.WALL end
            restAt(slime, 6.6, 8)
            run(slime, 30, { aim = 0, move = 1 })
            assert.is_true(slime.player.y > 8)
            runUntilStuck(slime)
            assert.are.equal(RESTING, slime.state)
            assert.is_near(FLOOR, slime.player.y, 0.0001)
        end)
    end)

    describe("aiming", function()
        it("points wherever the crank handle points, even before A is pressed", function()
            local slime = room()
            restAt(slime, 6)
            slime:update({ aim = 135 })
            assert.are.equal(135, slime.aimAngle)
            assert.is_false(slime.isAiming)
        end)

        it("begins when A is held", function()
            local slime = room()
            restAt(slime, 6)
            slime:update({ aim = 45, isAimHeld = true })
            assert.is_true(slime.isAiming)
            assert.are.equal(RESTING, slime.state)
        end)

        it("is called off by B, and stays off until A is let go and pressed again", function()
            local slime = room()
            restAt(slime, 6)
            slime:update({ aim = 45, isAimHeld = true })
            slime:update({ aim = 45, isAimHeld = true, cancel = true })
            assert.is_false(slime.isAiming)
            slime:update({ aim = 45, isAimHeld = true })
            assert.is_false(slime.isAiming)
            slime:update({ aim = 45 })
            assert.are.equal(RESTING, slime.state)
            slime:update({ aim = 45, isAimHeld = true })
            assert.is_true(slime.isAiming)
        end)

        it("does nothing when A was never held", function()
            local slime = room()
            restAt(slime, 6)
            run(slime, 5, { aim = 45 })
            assert.are.equal(RESTING, slime.state)
            assert.are.equal(0, slime.throws)
        end)
    end)

    describe("throwing", function()
        it("launches on letting go of A, straight up when the crank points up", function()
            local slime = room()
            restAt(slime, 6)
            throw(slime, 0)
            assert.are.equal(FLYING, slime.state)
            assert.is_false(slime.isAiming)
            assert.are.equal(1, slime.throws)
            assert.is_near(0, slime.velocityX, 0.0001)
            assert.is_true(slime.velocityY < 0)
        end)

        it("goes to the right when the crank points right, and left when it points left", function()
            local slime = room()
            restAt(slime, 6)
            throw(slime, 80)
            assert.is_true(slime.velocityX > 0.3)
            restAt(slime, 6)
            throw(slime, 280)
            assert.is_true(slime.velocityX < -0.3)
        end)

        it("goes nowhere when thrown flat along the floor it is resting on", function()
            local slime = room()
            restAt(slime, 6)
            throw(slime, 90)
            assert.are.equal(RESTING, slime.state)
        end)

        it("always throws at full power: about four blocks straight up", function()
            local slime = room()
            restAt(slime, 6)
            throw(slime, 0)
            local highest = slime.player.y
            for _ = 1, 200 do
                slime:update({ aim = 0 })
                highest = math.min(highest, slime.player.y)
            end
            assert.is_near(4, FLOOR - highest, 0.25)
            assert.are.equal(RESTING, slime.state)
        end)

        it("can be thrown again once in mid-air, and not twice", function()
            local slime = room()
            restAt(slime, 6)
            throw(slime, 0)
            run(slime, 10)
            throw(slime, 90)
            assert.is_true(slime.velocityX > 0.3)
            assert.are.equal(2, slime.throws)

            run(slime, 3)
            slime:update({ aim = 270, isAimHeld = true })
            assert.is_false(slime.isAiming)
            slime:update({ aim = 270 })
            assert.is_true(slime.velocityX > 0)
            assert.are.equal(2, slime.throws)
        end)

        it("gets its mid-air throw back by sticking to anything", function()
            local slime = room()
            restAt(slime, 6)
            throw(slime, 0)
            run(slime, 5)
            throw(slime, 0)
            runUntilStuck(slime)
            throw(slime, 0)
            run(slime, 5)
            slime:update({ aim = 90, isAimHeld = true })
            assert.is_true(slime.isAiming)
        end)
    end)

    describe("clinging to a wall", function()
        -- In the single cell, three blocks across, so the far wall is within a throw's reach
        local CELL_FLOOR <const> = 4 - Slime.RADIUS

        local function onTheRightWall()
            local slime = cell()
            restAt(slime, 2.5, 4)
            throw(slime, 60)
            runUntilStuck(slime)
            return slime
        end

        it("sticks where it hits, with a couple of seconds on the clock", function()
            local slime = onTheRightWall()
            assert.are.equal(CLINGING, slime.state)
            assert.are.equal("right", slime.surface)
            assert.is_near(4 - Slime.RADIUS, slime.player.x, 0.0001)
            assert.are.same({ 0, 0 }, { slime.velocityX, slime.velocityY })
            assert.are.equal(Slime.STICK_FRAMES, slime.stickFrames)
        end)

        it("holds still until the time runs out, then slides slowly down", function()
            local slime = onTheRightWall()
            local y = slime.player.y
            run(slime, Slime.STICK_FRAMES - 1)
            assert.are.equal(CLINGING, slime.state)
            assert.are.equal(y, slime.player.y)
            run(slime, 1)
            assert.are.equal(SLIDING, slime.state)
            run(slime, 10)
            assert.is_near(y + 10 * Slime.SLIDE_SPEED, slime.player.y, 0.0001)
        end)

        it("keeps the clock ticking while aiming", function()
            local slime = onTheRightWall()
            run(slime, Slime.STICK_FRAMES, { aim = 300, isAimHeld = true })
            assert.are.equal(SLIDING, slime.state)
            assert.is_true(slime.isAiming)
        end)

        it("can still throw while sliding", function()
            local slime = onTheRightWall()
            run(slime, Slime.STICK_FRAMES + 5)
            throw(slime, 300)
            assert.are.equal(FLYING, slime.state)
            assert.is_true(slime.velocityX < 0)
        end)

        it("comes to rest when it slides all the way down to a floor", function()
            local slime = onTheRightWall()
            run(slime, 1000)
            assert.are.equal(RESTING, slime.state)
            assert.is_near(CELL_FLOOR, slime.player.y, 0.0001)
        end)

        it("cannot crawl", function()
            local slime = onTheRightWall()
            local x, y = slime.player.x, slime.player.y
            run(slime, 10, { aim = 0, move = -1 })
            assert.are.same({ x, y }, { slime.player.x, slime.player.y })
        end)

        it("does not win more time by throwing itself at the wall it is already on", function()
            local slime = onTheRightWall()
            run(slime, 30)
            throw(slime, 90)
            runUntilStuck(slime)
            assert.are.equal(CLINGING, slime.state)
            assert.is_true(slime.stickFrames <= Slime.STICK_FRAMES - 30)
        end)

        it("gets a full clock from a different wall", function()
            local slime = onTheRightWall()
            run(slime, 30)
            throw(slime, 300)
            runUntilStuck(slime)
            assert.are.equal("left", slime.surface)
            assert.are.equal(Slime.STICK_FRAMES, slime.stickFrames)
        end)
    end)

    describe("clinging to a ceiling", function()
        it("sticks, and drops off when the time runs out", function()
            local slime = cell()
            restAt(slime, 2.5, 4)
            throw(slime, 0)
            runUntilStuck(slime)
            assert.are.equal(CLINGING, slime.state)
            assert.are.equal("ceiling", slime.surface)
            assert.is_near(1 + Slime.RADIUS, slime.player.y, 0.0001)

            run(slime, Slime.STICK_FRAMES)
            assert.are.equal(FLYING, slime.state)
            runUntilStuck(slime)
            assert.are.equal(RESTING, slime.state)
        end)
    end)

    describe("the arc", function()
        it("shows where the slime will land: exactly where it then does land", function()
            for _, angle in ipairs({ 0, 20, 45, 70, 90, 120, 250, 290, 315, 340 }) do
                local slime = room()
                restAt(slime, 6)
                slime:update({ aim = angle, isAimHeld = true })
                local arc = slime:arc()
                local landingX, landingY = arc.landingX, arc.landingY
                slime:update({ aim = angle })
                runUntilStuck(slime)
                assert.is_near(landingX, slime.player.x, 0.000001)
                assert.is_near(landingY, slime.player.y, 0.000001)
            end
        end)

        it("is a trail of points that starts at the slime and ends at the landing", function()
            local slime = room()
            restAt(slime, 6)
            slime:update({ aim = 45, isAimHeld = true })
            local arc = slime:arc()
            assert.is_true(#arc.points > 5)
            -- The first dot is three frames into the flight
            assert.is_near(6, arc.points[1].x, 1)
            local last = arc.points[#arc.points]
            assert.is_near(arc.landingX, last.x, 1.2)
            assert.is_true(arc.landingX > 9)
        end)

        it("follows the crank round", function()
            local slime = room()
            restAt(slime, 6)
            slime:update({ aim = 45, isAimHeld = true })
            local rightwards = slime:arc().landingX
            slime:update({ aim = 315, isAimHeld = true })
            assert.is_true(slime:arc().landingX < 6)
            assert.is_true(rightwards > 6)
        end)

        it("works from a wall and in mid-air too", function()
            local slime = room()
            restAt(slime, 10)
            throw(slime, 60)
            runUntilStuck(slime)
            slime:update({ aim = 300, isAimHeld = true })
            local arc = slime:arc()
            slime:update({ aim = 300 })
            runUntilStuck(slime)
            assert.is_near(arc.landingX, slime.player.x, 0.000001)
            assert.is_near(arc.landingY, slime.player.y, 0.000001)
        end)
    end)

    describe("the shapes and the exit", function()
        it("collects a shape by touching it and says how many are left", function()
            local slime = room({
                { shape = "circle", gridX = 8, gridY = 12 },
                { shape = "square", gridX = 2, gridY = 2 },
            })
            restAt(slime, 6)
            run(slime, 60, { aim = 0, move = 1 })
            assert.are.equal(Puzzle.STATES.PLACED, slime.puzzle.items[1].state)
            assert.are.equal("Got the circle! 1 to go", slime.message)
        end)

        it("opens the exit with the last shape, and escapes through it", function()
            local slime = room({ { shape = "circle", gridX = 8, gridY = 12 } })
            restAt(slime, 6)
            run(slime, 60, { aim = 0, move = 1 })
            assert.are.equal("Got the circle! The exit is open", slime.message)
            assert.is_true(slime.maze:hasPassage(3, 3, "east"))
            run(slime, 200, { aim = 0, move = 1 })
            assert.is_true(slime.hasEscaped)
        end)
    end)

    describe("events, for the sounds", function()
        local function eventsOver(slime, frames, input)
            local seen = {}
            for _ = 1, frames do
                slime:update(input or { aim = slime.aimAngle })
                for _, name in ipairs(slime.events) do seen[name] = (seen[name] or 0) + 1 end
            end
            return seen
        end

        it("reports a throw and the splat at the end of it", function()
            local slime = room()
            restAt(slime, 6)
            slime:update({ aim = 30, isAimHeld = true })
            local seen = eventsOver(slime, 200)
            assert.are.equal(1, seen.throw)
            assert.are.equal(1, seen.splat)
        end)

        it("reports losing its grip on a wall", function()
            local slime = cell()
            restAt(slime, 2.5, 4)
            slime:update({ aim = 60, isAimHeld = true })
            local seen = eventsOver(slime, Slime.STICK_FRAMES + 30)
            assert.are.equal(1, seen.slip)
        end)

        it("reports collecting a shape, the exit opening, and the escape", function()
            local slime = room({ { shape = "circle", gridX = 8, gridY = 12 } })
            restAt(slime, 6)
            local seen = eventsOver(slime, 300, { aim = 0, move = 1 })
            assert.are.equal(1, seen.collect)
            assert.are.equal(1, seen.exitOpen)
            assert.are.equal(1, seen.escape)
        end)
    end)

    describe("hint", function()
        it("teaches the throw until the first one has been made", function()
            local slime = room()
            restAt(slime, 6)
            assert.are.equal("Hold Ⓐ, aim with the crank, let go", slime:hint())
            throw(slime, 0)
            runUntilStuck(slime)
            assert.is_nil(slime:hint())
        end)
    end)

    it("never ends up inside a wall, whatever it is thrown at", function()
        local slime = Slime.new({ columns = 4, rows = 3, random = seededRandom(8) })
        local random = seededRandom(99)
        for frame = 1, 5000 do
            local angle = random(360)
            slime:update({ aim = angle, isAimHeld = frame % 23 < 3, move = random(3) - 2 })
            local R = Slime.RADIUS
            for _, corner in ipairs({ { -R, -R }, { R, -R }, { -R, R }, { R, R } }) do
                local gridX, gridY = slime.maze:blockAt(slime.player.x + corner[1], slime.player.y + corner[2])
                assert.is_false(slime.maze:isWall(gridX, gridY))
            end
            if slime.hasEscaped then break end
        end
    end)
end)
