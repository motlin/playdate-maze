require("spec.support.playdate_stub")
import "MapEditor"
import "Player"
import "Thread"
import "Slime"
import "Raycaster"
import "Compass"
import "Hum"
import "Game"
import "WalkingActions"
import "TumbleActions"
import "SlimeActions"
import "PlayInput"

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
        assert.are_not.equal(first, second)
        assert.are.same(firstLanding, { second.landingX, second.landingY })
        assert.are.same({ x = 2.5, y = 2.5, angle = 0 }, slime.player)
    end)
end)

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do
        result[key] = copy(item)
    end
    return result
end

describe("returned value ownership", function()
    local cases = {
        compass = function(output, changed) return Compass.marks(changed and 90 or 0, 120, 120, output) end,
        hum = function(output, changed)
            return Hum.levels(1.5, 1.5, changed and 180 or 0, { { gridX = 3, gridY = 2, state = "ground" } }, output)
        end,
        scan = function(output, changed)
            return Raycaster.scan(
                Maze.new(2, 1),
                1.5,
                1.5,
                changed and 90 or 0,
                { width = 40, columnWidth = 4, fieldOfView = 70, refinements = 2 },
                output
            )
        end,
    }
    local slime = Slime.inMaze(Maze.new(1, 1, 3), Puzzle.new({}, {}))
    cases.arc = function(output, changed)
        slime.aimAngle = changed and 90 or 0
        return slime:arc(output)
    end
    for name, calculate in pairs(cases) do
        it("retains independent " .. name .. " results including nested values", function()
            local first = calculate(nil, false)
            local expected = copy(first)
            local second = calculate(nil, true)
            assert.are_not.equal(first, second)
            assert.are.same(expected, first)
            for key in pairs(second) do
                second[key] = nil
            end
            assert.are.same(expected, first)
        end)
        it("only overwrites the supplied " .. name .. " buffer", function()
            local first = calculate(nil, false)
            local expected = copy(first)
            local second = calculate(nil, false)
            local nested = second.runs and second.runs[1] or second.points and second.points[1] or second[1]
            assert.are.equal(second, calculate(second, true))
            assert.are.equal(nested, second.runs and second.runs[1] or second.points and second.points[1] or second[1])
            assert.are.same(expected, first)
        end)
    end
    for _, mapper in ipairs({ WalkingActions, TumbleActions, SlimeActions }) do
        it("keeps an action result stable across reads of one mapper", function()
            local controls = PlayInput.new()
            controls.current, controls.pressed, controls.released = 0, 0, 0
            controls.crankChange, controls.crankPosition = 0, 0
            controls.isCrankDocked = false
            local actions = mapper.new(controls)
            local first = mapper == WalkingActions and actions:read(false) or actions:read()
            local expected = copy(first)
            controls.current, controls.pressed = playdate.kButtonA, playdate.kButtonA
            controls.crankChange, controls.crankPosition = 90, 90
            if mapper == WalkingActions then
                actions:read(false)
            else
                actions:read()
            end
            assert.are.same(expected, first)
            local buffer = {}
            local result = mapper == WalkingActions and actions:read(false, buffer) or actions:read(buffer)
            assert.are.equal(buffer, result)
            assert.are.same(mapper == WalkingActions and actions:read(false) or actions:read(), buffer)
            assert.are.same(expected, first)
        end)
    end
    it("detaches nested game snapshots from subsequent play and caller edits", function()
        local game = Game.new({ columns = 4, rows = 3, random = firstChoice, hasPuzzle = true })
        local saved = game:toSave()
        local expected = copy(saved)
        game.maze:openExit()
        game.puzzle.items[1].state = "placed"
        game.thread.points[1].x = 100
        game.flippers.all[1].isArmed = false
        assert.are.same(expected, saved)
        local live = copy(game:toSave())
        saved.maze.blocks[2][2] = 100
        saved.puzzle.items[1].gridX = 100
        assert.are.same(live, game:toSave())
    end)
    it("detaches every nested map design value from its save", function()
        local design = MapDesign.new(2, 1)
        local saved = design:toSave()
        local expected = copy(saved)
        design.start.gridX = 100
        design.blocks[2][2] = 100
        assert.are.same(expected, saved)
    end)
end)
