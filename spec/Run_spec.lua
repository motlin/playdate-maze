require("spec.support.playdate_stub")
import "Maze"
import "Player"
import "Run"

local function newRun()
    local maze = Maze.new(3, 2)
    maze:carve(1, 1, "east")
    maze:carve(2, 1, "east")
    return Run.new(maze, Player.new(1.5, 1.5, 0))
end

describe("Run", function()
    it("starts at frame zero, not escaped, with nothing to say", function()
        local run = newRun()
        assert.are.same({ 0, false }, { run.frames, run.hasEscaped })
        assert.is_nil(run.message)
    end)

    it("has no autopilot unless a mode provides one", function() assert.is_false(newRun():isAutopilotOn()) end)

    describe("visiting", function()
        it("has visited the cell the player starts in", function()
            local run = newRun()
            assert.is_true(run:hasVisited(1, 1))
            assert.is_false(run:hasVisited(2, 1))
            assert.are.equal(1, run.visitedCount)
        end)

        it("visits the cell the player has moved to, once", function()
            local run = newRun()
            run.player.x = 3.5
            run:visit()
            run:visit()
            assert.is_true(run:hasVisited(2, 1))
            assert.are.equal(2, run.visitedCount)
        end)
    end)

    describe("the map", function()
        it(
            "reveals everything when there is no puzzle to hide",
            function() assert.is_true(newRun():isRevealed(3, 2)) end
        )

        it("reveals only visited cells when there is a puzzle", function()
            local run = newRun()
            run.puzzle = {}
            assert.is_true(run:isRevealed(1, 1))
            assert.is_false(run:isRevealed(3, 2))
        end)
    end)

    describe("events", function()
        it("has none to begin with", function() assert.are.same({}, newRun().events) end)

        it("collects what happened during a frame, in order", function()
            local run = newRun()
            run:tick()
            run:emit("step")
            run:emit("bump")
            assert.are.same({ "step", "bump" }, run.events)
        end)

        it("forgets them at the start of the next frame, keeping the same list", function()
            local run = newRun()
            local events = run.events
            run:tick()
            run:emit("step")
            run:tick()
            assert.are.same({}, run.events)
            assert.are.equal(events, run.events)
        end)
    end)

    describe("messages", function()
        it("keeps a message for a couple of seconds of ticks", function()
            local run = newRun()
            run:say("Hello")
            for _ = 1, Run.MESSAGE_FRAMES - 1 do
                run:tick()
            end
            assert.are.equal("Hello", run.message)
            run:tick()
            assert.is_nil(run.message)
        end)

        it("starts the wait again for a new message", function()
            local run = newRun()
            run:say("First")
            for _ = 1, 30 do
                run:tick()
            end
            run:say("Second")
            for _ = 1, 40 do
                run:tick()
            end
            assert.are.equal("Second", run.message)
        end)

        it("counts a frame for every tick", function()
            local run = newRun()
            for _ = 1, 45 do
                run:tick()
            end
            assert.are.equal(45, run.frames)
        end)
    end)
end)
