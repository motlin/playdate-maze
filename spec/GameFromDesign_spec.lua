require("spec.support.playdate_stub")
import "Game"
import "MapDesign"
import "ExitDistance"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

-- A 6x4 map: a generated maze with a room knocked into it, a filled-in cell, and a sealed-off cell
local function roomyDesign()
    local design = MapDesign.fromMaze(Maze.generate(6, 4, seededRandom(3)))
    for gridY = 2, 4 do
        for gridX = 6, 8 do design:setBlock(gridX, gridY, true) end
    end
    return design
end

local function key(thing) return thing.gridY * 256 + thing.gridX end

describe("Game.fromDesign", function()
    it("builds the maze as drawn, with the gate where the exit was put", function()
        local design = roomyDesign()
        local game = Game.fromDesign(design, seededRandom(9))
        for gridY = 1, design.gridHeight do
            for gridX = 1, design.gridWidth do
                local isExit = gridX == design.exit.gridX and gridY == design.exit.gridY
                if not isExit then assert.are.equal(design:isOpen(gridX, gridY), not game.maze:isWall(gridX, gridY)) end
            end
        end
        assert.are.equal(Maze.BLOCKS.DOOR, game.maze:blockValue(design.exit.gridX, design.exit.gridY))
        assert.are.same({ design.exit.gridX, design.exit.gridY }, { game.maze.exitGridX, game.maze.exitGridY })
    end)

    it("starts the player where the start was put, looking along an open way", function()
        local design = roomyDesign()
        design:place("start", nil, 7, 3)
        local game = Game.fromDesign(design, seededRandom(9))
        assert.are.same({ 6.5, 2.5 }, { game.player.x, game.player.y })
        local radians = math.rad(game.player.angle)
        local aheadX, aheadY = game.player.x + math.cos(radians), game.player.y + math.sin(radians)
        assert.is_false(game.maze:isWall(game.maze:blockAt(aheadX, aheadY)))
    end)

    it("stands the shapes and pedestals where they were put", function()
        local design = roomyDesign()
        design:place("item", "triangle", 7, 3)
        design:place("pedestal", "circle", 6, 2)
        local game = Game.fromDesign(design, seededRandom(9))
        assert.are.same({ "triangle", 7, 3 }, { game.puzzle.items[2].shape, game.puzzle.items[2].gridX, game.puzzle.items[2].gridY })
        assert.are.same({ "circle", 6, 2 }, { game.puzzle.pedestals[1].shape, game.puzzle.pedestals[1].gridX, game.puzzle.pedestals[1].gridY })
    end)

    it("scatters whatever was not placed, only where the player can get to, one thing to a block", function()
        local design = roomyDesign()
        -- Seal a cell off completely, and fill another in
        design:setBlock(12, 2, true)
        for _, neighbour in ipairs({ { 11, 2 }, { 12, 3 } }) do design:setBlock(neighbour[1], neighbour[2], false) end
        design:setBlock(2, 8, false)
        for seed = 1, 20 do
            local game = Game.fromDesign(design, seededRandom(seed))
            local reachable, seen = design:reachable(), { [key(design.start)] = true }
            local things = {}
            for _, item in ipairs(game.puzzle.items) do things[#things + 1] = item end
            for _, pedestal in ipairs(game.puzzle.pedestals) do things[#things + 1] = pedestal end
            for _, flipper in ipairs(game.flippers.all) do things[#things + 1] = flipper end
            assert.is_true(#things >= 7)
            for _, thing in ipairs(things) do
                assert.is_true(reachable[key(thing)], "something was put where the player cannot go")
                assert.is_nil(seen[key(thing)], "two things share a block")
                seen[key(thing)] = true
            end
        end
    end)

    it("keeps its landmarks out of filled-in cells", function()
        local design = roomyDesign()
        design:setBlock(2, 8, false)
        for seed = 1, 20 do
            local game = Game.fromDesign(design, seededRandom(seed))
            for _, mark in ipairs(game.landmarks.marks) do
                assert.is_false(game.maze:isWall(mark.gridX, mark.gridY))
            end
        end
    end)

    it("can be solved and escaped like any other", function()
        local design = roomyDesign()
        local game = Game.fromDesign(design, seededRandom(9))
        for index, item in ipairs(game.puzzle.items) do
            game.player.x, game.player.y = game.maze:blockCenter(item.gridX, item.gridY)
            game:update({ pickUp = true })
            local pedestal = game.puzzle.pedestals[index]
            game.player.x, game.player.y = game.maze:blockCenter(pedestal.gridX, pedestal.gridY)
            game:update({ drop = true })
        end
        assert.is_true(game.isGateUnlocked)
    end)

    it("refuses a map that still has problems", function()
        local design = roomyDesign()
        design:remove(design.exit.gridX, design.exit.gridY)
        assert.has_error(function() Game.fromDesign(design, seededRandom(9)) end)
    end)

    describe("the autopilot", function()
        it("is not offered, because following a wall only works in a true maze", function()
            local game = Game.fromDesign(roomyDesign(), seededRandom(9))
            assert.is_true(game.isHandMade)
            assert.is_false(game:canAutopilot())
            assert.has_error(function() game:setAutopilot(true) end)
        end)

        it("is offered in a generated maze", function()
            local game = Game.new({ columns = 6, rows = 4, hasPuzzle = true, random = seededRandom(3) })
            assert.is_false(game.isHandMade)
            assert.is_true(game:canAutopilot())
        end)
    end)

    it("saves and loads, still hand-made", function()
        local game = Game.fromDesign(roomyDesign(), seededRandom(9))
        local loaded = Game.fromSave(game:toSave())
        assert.is_true(loaded.isHandMade)
        assert.are.same(game.maze.blocks, loaded.maze.blocks)
    end)
end)

describe("ExitDistance in a hand-made map", function()
    it("counts a cell that cannot reach the exit as being as far away as anything", function()
        local design = MapDesign.new(3, 2)
        design:setPassage(1, 1, "east", true)
        design:place("exit", nil, 1, 2)
        local game = { maze = Maze.new(3, 2) }
        for gridY = 1, 5 do
            for gridX = 1, 7 do game.maze.blocks[gridY][gridX] = design:isOpen(gridX, gridY) and 0 or 1 end
        end
        game.maze.exitGridX, game.maze.exitGridY = 1, 2
        local distances = ExitDistance.new(game.maze)
        assert.are.equal(0, distances:cells(1, 1))
        assert.are.equal(1, distances:cells(2, 1))
        assert.are.equal(1, distances:proximity(game.maze:cellCenter(1, 1)))
        assert.are.equal(0, distances:proximity(game.maze:cellCenter(3, 2)))
    end)

    it("does not divide by nothing when the exit's cell is the only one that can reach it", function()
        local maze = Maze.new(3, 2)
        maze.exitGridX, maze.exitGridY = 1, 2
        local distances = ExitDistance.new(maze)
        assert.are.equal(1, distances:proximity(maze:cellCenter(1, 1)))
        assert.are.equal(0, distances:proximity(maze:cellCenter(3, 2)))
    end)
end)
