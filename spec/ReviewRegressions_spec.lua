require("spec.support.playdate_stub")
import "Game"
import "SeededRandom"
import "Slime"
import "MusicScore"

local function cornerMaze()
    local maze = Maze.new(2, 2)
    maze:carve(1, 1, "east")
    maze:carve(2, 1, "south")
    return maze
end

local function supportedSlime()
    local maze = Maze.new(1, 1, 3)
    return Slime.inMaze(maze, Puzzle.new({}, {}))
end

describe("review regressions", function()
    it("places seed 180 landmarks without asking for a random wall in an open junction", function()
        local game = Game.new({ columns = 8, rows = 6, hasPuzzle = true, random = SeededRandom.new(180) })
        local junctionMarks = {}
        for _, mark in ipairs(game.landmarks.marks) do
            local passages = 0
            for _, direction in ipairs(Maze.DIRECTIONS) do
                if game.maze:hasPassage(mark.column, mark.row, direction) then passages = passages + 1 end
            end
            if passages == 4 then junctionMarks[#junctionMarks + 1] = mark end
        end
        assert.are.same({ { column = 3, row = 5, gridX = 6, gridY = 10, kind = "floor", motif = 1 } }, junctionMarks)
        assert.are.same(game.landmarks, Landmarks.fromSave(game.landmarks.all))
    end)

    it("does not throw when releasing A after ceiling grip expires", function()
        local slime = supportedSlime()
        slime.player.x, slime.player.y = 2.5, 1.200001
        slime.state, slime.surface, slime.stickFrames = Slime.STATES.CLINGING, "ceiling", 1
        slime:update({ aim = 0, isAimHeld = true })
        local aimingAfterFall = slime.isAiming
        slime:update({ aim = 0 })
        assert.are.same(
            { state = "flying", aimingAfterFall = false, throws = 0, events = {} },
            { state = slime.state, aimingAfterFall = aimingAfterFall, throws = slime.throws, events = slime.events }
        )
    end)

    it("does not throw when releasing A after crawling off a ledge", function()
        local slime = supportedSlime()
        slime.maze.blocks[3][2] = Maze.BLOCKS.WALL
        slime.player.x, slime.player.y = 2.199999, 1.799999
        slime.state = Slime.STATES.RESTING
        slime:update({ aim = 0, isAimHeld = true, move = 1 })
        local aimingAfterFall = slime.isAiming
        slime:update({ aim = 0 })
        assert.are.same(
            { state = "flying", aimingAfterFall = false, throws = 0, events = {} },
            { state = slime.state, aimingAfterFall = aimingAfterFall, throws = slime.throws, events = slime.events }
        )
    end)

    it("rejects an airborne release even if the aim flag was stale", function()
        local slime = supportedSlime()
        slime.isAiming = true
        slime:update({ aim = 0 })
        assert.are.same(
            { state = "flying", isAiming = false, throws = 0, events = {} },
            { state = slime.state, isAiming = slime.isAiming, throws = slime.throws, events = slime.events }
        )
    end)

    it("keeps body clearance on every rewind step around an inside corner", function()
        local maze = cornerMaze()
        local player = Player.new(2.7, 1.79, 0)
        local thread = Thread.new(maze, player.x, player.y)
        for _ = 1, 7 do
            player:moveBy(maze, 0.08, 0)
            thread:record(player.x, player.y)
        end
        for _ = 1, 10 do
            player:moveBy(maze, 0, 0.08)
            thread:record(player.x, player.y)
        end
        local collisions = {}
        for frame = 1, 100 do
            local x, y = thread:rewindFrom(player.x, player.y, 0.02)
            if not x then break end
            player.x, player.y = x, y
            if player:wouldHit(maze, 0, 0) then collisions[#collisions + 1] = frame end
        end
        assert.are.same({ collisions = {}, x = 2.7, y = 1.79 }, { collisions = collisions, x = player.x, y = player.y })
    end)

    it("stops at a blocked saved segment without consuming it or tunneling", function()
        local maze = cornerMaze()
        local points = { { x = 2.7, y = 1.79 }, { x = 3.21, y = 2.4 } }
        local thread = Thread.fromSave(maze, points, 3.21, 2.4)
        local x, y, heading, blocked = thread:rewindFrom(3.21, 2.4, 100)
        assert.are.same(
            { blocked = true, points = { { x = 2.7, y = 1.79 } } },
            { x = x, y = y, heading = heading, blocked = blocked, points = thread.points }
        )
    end)

    it("checks the swept body even when both endpoints are clear", function()
        local maze = cornerMaze()
        assert.are.same({ false, true, true, false }, {
            Player.isPathClear(maze, 2.7, 1.79, 3.21, 2.4),
            Player.isPathClear(maze, 2.7, 1.79, 3.21, 1.79),
            Player.isPathClear(maze, 3.21, 1.79, 3.21, 2.4),
            Player.isPathClear(maze, 1.5, 1.5, 1.5, 3.5),
        })
    end)

    it("preserves the original melody across walk and sway cycles", function()
        local checksum = 0
        for step = 1, 5000 do
            checksum = (checksum * 31 + MusicScore.noteAt(step)) % 1000000007
        end
        local notes = {}
        for _, step in ipairs({ 1, 12, 13, 14, 25, 26, 27, 100000, 100001 }) do
            notes[#notes + 1] = MusicScore.noteAt(step)
        end
        assert.are.same(
            { checksum = 220732617, notes = { 62, 60, 60, 62, 57, 64, 67, 60, 60 } },
            { checksum = checksum, notes = notes }
        )
    end)

    it("bounds note calculation work even after a very long session", function()
        debug.sethook(function() error("note calculation exceeded its instruction budget") end, "", 10000)
        local ok, note = pcall(MusicScore.noteAt, 1000000000000)
        debug.sethook()
        assert.are.same({ true, 64 }, { ok, note })
    end)
end)
