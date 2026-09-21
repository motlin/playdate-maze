require("spec.support.playdate_stub")
import "MapEditor"
import "Player"
import "Thread"
import "Slime"

local function firstChoice() return 1 end

describe("state ownership", function()
    it("replaces a drawing with a fresh maze and resets editing state together", function()
        local original = MapDesign.new(4, 2)
        local editor = MapEditor.new(original)
        editor:turnTool(1)
        editor:move(1, 0, true, false)
        editor:markSaved()
        editor:generateMaze(firstChoice)
        assert.are.same({
            columns = 4,
            rows = 2,
            cursor = { 2, 2 },
            tool = "cells",
            message = "A new maze to alter",
            hasUnsavedChanges = true,
            problems = {},
        }, {
            columns = editor.design.columns,
            rows = editor.design.rows,
            cursor = { editor.cursorX, editor.cursorY },
            tool = editor:tool().name,
            message = editor.message,
            hasUnsavedChanges = editor.hasUnsavedChanges,
            problems = editor.design:problems(),
        })
        assert.are.same(MapDesign.fromMaze(Maze.generate(4, 2, firstChoice)):toSave(), editor.design:toSave())
        editor:markSaved()
        assert.are.same(false, editor.hasUnsavedChanges)
    end)

    it("reports a failed play attempt without dirtying a saved drawing", function()
        local editor = MapEditor.new(MapDesign.new(4, 2))
        local design = editor:designToPlay()
        assert.are.same(
            { message = "There is no exit", hasUnsavedChanges = false },
            { design = design, message = editor.message, hasUnsavedChanges = editor.hasUnsavedChanges }
        )
    end)

    it("accepts a playable design without clearing unsaved changes", function()
        local editor = MapEditor.new(MapDesign.new(4, 2))
        editor:generateMaze(firstChoice)
        assert.are.equal(editor.design, editor:designToPlay())
        assert.are.same(true, editor.hasUnsavedChanges)
    end)

    it("copies a drawing into an independent maze with a closed gate", function()
        local design = MapDesign.new(2, 1)
        design:setPassage(1, 1, "east", true)
        design:place("exit", nil, 5, 2)
        local maze = Maze.fromDesign(design)
        assert.are.same({
            columns = 2,
            rows = 1,
            corridorWidth = 1,
            exitGridX = 5,
            exitGridY = 2,
            blocks = { { 1, 1, 1, 1, 1 }, { 1, 0, 0, 0, 2 }, { 1, 1, 1, 1, 1 } },
        }, maze:toSave())
        design:setPassage(1, 1, "east", false)
        maze:openExit()
        assert.are.same(
            { passage = 0, exit = 3, drawingExit = { gridX = 5, gridY = 2 } },
            { passage = maze:blockValue(3, 2), exit = maze:blockValue(5, 2), drawingExit = design.exit }
        )
    end)

    it("follows a target at bounded speed and lands exactly without changing heading", function()
        local player = Player.new(1.5, 1.5, 90)
        local poses = {}
        for _ = 1, 3 do
            local moved = player:walkTowards(2.5, 1.5, 0.75)
            poses[#poses + 1] = { moved = moved, x = player.x, y = player.y, angle = player.angle }
        end
        assert.are.same({
            { moved = true, x = 2.25, y = 1.5, angle = 90 },
            { moved = true, x = 2.5, y = 1.5, angle = 90 },
            { moved = false, x = 2.5, y = 1.5, angle = 90 },
        }, poses)
    end)

    it("rewinds position and heading together and stops when the thread begins", function()
        local maze = Maze.new(2, 1)
        maze:carve(1, 1, "east")
        local player = Player.new(2.5, 1.5, 90)
        local thread = Thread.new(maze, 1.5, 1.5)
        local moved, blocked = player:rewindAlong(thread, 2, 12)
        assert.are.same(
            { moved = true, x = 1.5, y = 1.5, angle = 78 },
            { moved = moved, blocked = blocked, x = player.x, y = player.y, angle = player.angle }
        )
        assert.are.same({ false }, { player:rewindAlong(thread, 2, 12) })
        assert.are.same({ x = 1.5, y = 1.5, angle = 78 }, player)
    end)

    it("does not move or turn while a saved thread segment is blocked", function()
        local maze = Maze.new(2, 1)
        local player = Player.new(3.5, 1.5, 90)
        local thread = Thread.new(maze, 1.5, 1.5)
        assert.are.same({ false, true }, { player:rewindAlong(thread, 10, 12) })
        assert.are.same({ x = 3.5, y = 1.5, angle = 90 }, player)
    end)

    it("resets the prediction body without changing or sharing the live player's pose", function()
        local player = Player.new(1.5, 1.5, 90)
        local scout = Player.new(3.5, 1.5, 0)
        scout:copyFrom(player)
        scout:turn(90)
        scout:walkTowards(2.5, 1.5, 1)
        assert.are.same({ x = 1.5, y = 1.5, angle = 90 }, player)
        assert.are.same({ x = 2.5, y = 1.5, angle = 180 }, scout)
    end)

    it("reuses the trajectory body and leaves the live player unchanged across previews", function()
        local slime = Slime.inMaze(Maze.new(1, 1, 3), Puzzle.new({}, {}))
        local scout = slime.scout
        local first = slime:arc()
        local firstLanding = { first.landingX, first.landingY }
        local second = slime:arc()
        assert.are.equal(scout, slime.scout)
        assert.are.equal(first, second)
        assert.are.same(firstLanding, { second.landingX, second.landingY })
        assert.are.same({ x = 2.5, y = 2.5, angle = 0 }, slime.player)
    end)
end)
