require("spec.support.playdate_stub")
import "Thread"
import "Maze"

local openMaze = { blockAt = Maze.blockAt, isWall = function() return false end }

-- Walks in a straight line from the thread's end, recording every tenth of a block
local function walk(thread, fromX, fromY, toX, toY)
    local steps = math.floor(math.max(math.abs(toX - fromX), math.abs(toY - fromY)) / 0.1 + 0.5)
    for step = 1, steps do
        thread:record(fromX + (toX - fromX) * step / steps, fromY + (toY - fromY) * step / steps)
    end
end

describe("Thread", function()
    it("starts as a single point with no length", function()
        local thread = Thread.new(openMaze, 1.5, 1.5)
        assert.are.equal(1, #thread.points)
        assert.are.equal(0, thread:length())
    end)

    describe("record", function()
        it("ignores moves too small to matter", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            thread:record(1.6, 1.5)
            assert.are.equal(1, #thread.points)
        end)

        it("adds a point for every stretch walked", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 5.5, 1.5)
            assert.is_near(4, thread:length(), Thread.SPACING)
            -- Steps of a tenth of a block lay a point every 0.3, the first multiple past the spacing
            assert.are.equal(14, #thread.points)
        end)

        it("winds itself back in when the player walks back along it", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 5.5, 1.5)
            walk(thread, 5.5, 1.5, 2.0, 1.5)
            assert.is_near(0.5, thread:length(), 2 * Thread.SPACING)
        end)

        it("stays the way back to the start after a trip into a dead end and out again", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 3.5, 1.5)
            walk(thread, 3.5, 1.5, 3.5, 5.5)
            walk(thread, 3.5, 5.5, 3.5, 1.5)
            walk(thread, 3.5, 1.5, 7.5, 1.5)
            assert.is_near(6, thread:length(), 4 * Thread.SPACING)
        end)

        it("forgets the oldest part rather than growing for ever", function()
            local thread = Thread.new(openMaze, 0, 0)
            for step = 1, Thread.MOST_POINTS * 2 do
                thread:record(step * Thread.SPACING, 0)
            end
            assert.are.equal(Thread.MOST_POINTS, #thread.points)
            assert.are.equal(Thread.MOST_POINTS * 2 * Thread.SPACING, thread.points[#thread.points].x)
        end)
    end)

    describe("rewindFrom", function()
        it("gives the place that far back along the thread", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 5.5, 1.5)
            local x, y = thread:rewindFrom(5.5, 1.5, 1)
            assert.is_near(4.5, x, 0.0001)
            assert.is_near(1.5, y, 0.0001)
        end)

        it("follows the thread round a corner", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 3.5, 1.5)
            walk(thread, 3.5, 1.5, 3.5, 3.5)
            local x, y = thread:rewindFrom(3.5, 3.5, 3)
            -- The thread cuts the corner by less than its spacing, so it is a little shorter
            assert.is_near(2.5, x, Thread.SPACING)
            assert.is_near(1.5, y, 0.0001)
        end)

        it("shortens the thread by as much as it rewound", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 5.5, 1.5)
            thread:rewindFrom(5.5, 1.5, 1)
            assert.is_near(3, thread:length(), 0.0001)
        end)

        it("says which way the thread was being laid there, so the view can look that way", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 3.5, 1.5)
            walk(thread, 3.5, 1.5, 3.5, 3.5)
            local _, _, heading = thread:rewindFrom(3.5, 3.5, 1)
            assert.is_near(90, heading, 0.0001)
            _, _, heading = thread:rewindFrom(3.5, 2.5, 2)
            assert.is_near(0, heading, 0.0001)
        end)

        it("stops at the start of the thread", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 3.5, 1.5)
            local x, y = thread:rewindFrom(3.5, 1.5, 50)
            assert.are.same({ 1.5, 1.5 }, { x, y })
            assert.are.equal(0, thread:length())
        end)

        it("has nowhere to go from the very start", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            assert.is_nil(thread:rewindFrom(1.5, 1.5, 1))
        end)

        it("counts the few steps taken since the last point", function()
            local thread = Thread.new(openMaze, 1.5, 1.5)
            walk(thread, 1.5, 1.5, 3.5, 1.5)
            local x = thread:rewindFrom(3.6, 1.5, 0.05)
            assert.is_near(3.55, x, 0.0001)
        end)
    end)
end)
