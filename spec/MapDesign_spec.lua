require("spec.support.playdate_stub")
import "Maze"
import "MapDesign"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

-- A 3x2 design with a corridor carved along the top row and down the east side: cells (1,1),
-- (2,1), (3,1), (3,2) are joined, and the exit is in the east wall beside cell (3,2)
local function corridorDesign()
    local design = MapDesign.new(3, 2)
    design:setPassage(1, 1, "east", true)
    design:setPassage(2, 1, "east", true)
    design:setPassage(3, 1, "south", true)
    assert(design:place("exit", nil, 7, 4))
    return design
end

local function hasProblem(design, text)
    for _, problem in ipairs(design:problems()) do
        if problem == text then return true end
    end
    return false
end

describe("MapDesign", function()
    describe("new", function()
        it("is a grid of walled-in cells, with the start in the first and no exit yet", function()
            local design = MapDesign.new(3, 2)
            assert.are.same({ 7, 5 }, { design.gridWidth, design.gridHeight })
            assert.is_true(design:isOpen(2, 2))
            assert.is_false(design:isOpen(3, 2))
            assert.are.same({ gridX = 2, gridY = 2 }, design.start)
            assert.is_nil(design.exit)
        end)

        it("can start from a generated maze instead, keeping its exit", function()
            local maze = Maze.generate(6, 4, seededRandom(3))
            local design = MapDesign.fromMaze(maze)
            assert.are.same({ gridX = maze.exitGridX, gridY = maze.exitGridY }, design.exit)
            assert.are.same({}, design:problems())
            for gridY = 1, maze.gridHeight do
                for gridX = 1, maze.gridWidth do
                    assert.are.equal(not maze:isWall(gridX, gridY), design:isOpen(gridX, gridY))
                end
            end
        end)
    end)

    describe("editing walls between cells", function()
        it("knocks a wall through, seen from both sides, and builds it back", function()
            local design = MapDesign.new(3, 2)
            assert.is_true(design:setPassage(1, 1, "east", true))
            assert.is_true(design:hasPassage(1, 1, "east"))
            assert.is_true(design:hasPassage(2, 1, "west"))
            assert.is_true(design:setPassage(2, 1, "west", false))
            assert.is_false(design:hasPassage(1, 1, "east"))
        end)

        it("leaves the outer wall alone", function()
            local design = MapDesign.new(3, 2)
            assert.is_false(design:setPassage(1, 1, "north", true))
            assert.is_false(design:setPassage(3, 2, "east", true))
            assert.is_false(design:isOpen(1, 2))
        end)
    end)

    describe("editing single blocks", function()
        it("opens and fills any block inside the outer wall", function()
            local design = MapDesign.new(3, 2)
            assert.is_true(design:setBlock(3, 3, true))
            assert.is_true(design:isOpen(3, 3))
            assert.is_true(design:setBlock(2, 4, false))
            assert.is_false(design:isOpen(2, 4))
        end)

        it("never opens the outer wall, which keeps the player and the view inside the map", function()
            local design = MapDesign.new(3, 2)
            assert.is_false(design:setBlock(1, 3, true))
            assert.is_false(design:setBlock(4, 5, true))
            assert.is_false(design:setBlock(7, 1, true))
        end)

        it("will not wall up a block with something standing on it", function()
            local design = corridorDesign()
            design:place("item", "circle", 4, 2)
            assert.is_false(design:setBlock(4, 2, false))
            assert.is_false(design:setBlock(2, 2, false))
            assert.is_true(design:isOpen(4, 2))
        end)
    end)

    describe("placing things", function()
        it("stands a shape or a pedestal on an open block", function()
            local design = corridorDesign()
            assert.is_true(design:place("item", "circle", 4, 2))
            assert.is_true(design:place("pedestal", "circle", 6, 4))
            assert.are.same({ gridX = 4, gridY = 2 }, design.items.circle)
            assert.are.same({ gridX = 6, gridY = 4 }, design.pedestals.circle)
        end)

        it("says what is on a block", function()
            local design = corridorDesign()
            design:place("item", "square", 4, 2)
            assert.are.same({ "item", "square" }, { design:thingAt(4, 2) })
            assert.are.same({ "start" }, { design:thingAt(2, 2) })
            assert.are.same({ "exit" }, { design:thingAt(7, 4) })
            assert.is_nil(design:thingAt(6, 2))
        end)

        it("moves a thing that is placed a second time, rather than making two", function()
            local design = corridorDesign()
            design:place("item", "circle", 4, 2)
            design:place("item", "circle", 6, 2)
            assert.are.same({ gridX = 6, gridY = 2 }, design.items.circle)
            assert.is_nil(design:thingAt(4, 2))
        end)

        it("refuses a wall, and a block that already holds something else", function()
            local design = corridorDesign()
            assert.is_false(design:place("item", "circle", 3, 3))
            assert.is_false(design:place("item", "circle", 2, 2))
            design:place("item", "circle", 4, 2)
            assert.is_false(design:place("pedestal", "square", 4, 2))
        end)

        it("moves the start", function()
            local design = corridorDesign()
            assert.is_true(design:place("start", nil, 6, 2))
            assert.are.same({ gridX = 6, gridY = 2 }, design.start)
            assert.is_nil(design:thingAt(2, 2))
        end)

        it("puts the exit only in the outer wall, beside an open block, and never in a corner", function()
            local design = MapDesign.new(3, 2)
            assert.is_true(design:place("exit", nil, 1, 2))
            assert.are.same({ gridX = 1, gridY = 2 }, design.exit)
            assert.is_true(design:place("exit", nil, 4, 5))
            assert.are.same({ gridX = 4, gridY = 5 }, design.exit)
            assert.is_false(design:place("exit", nil, 1, 3))
            assert.is_false(design:place("exit", nil, 1, 1))
            assert.is_false(design:place("exit", nil, 3, 3))
            assert.are.same({ gridX = 4, gridY = 5 }, design.exit)
        end)

        it("takes a thing away, all but the start", function()
            local design = corridorDesign()
            design:place("item", "circle", 4, 2)
            assert.is_true(design:remove(4, 2))
            assert.is_nil(design.items.circle)
            assert.is_true(design:remove(7, 4))
            assert.is_nil(design.exit)
            assert.is_false(design:remove(2, 2))
            assert.is_false(design:remove(6, 2))
        end)

        it("will not wall up the block inside the exit, which would seal it", function()
            local design = corridorDesign()
            assert.is_false(design:setBlock(6, 4, false))
        end)
    end)

    describe("problems", function()
        it("finds none in a finished map", function()
            assert.are.same({}, MapDesign.fromMaze(Maze.generate(6, 4, seededRandom(3))):problems())
        end)

        it("finds none in a small map once everything has been placed by hand", function()
            local design = corridorDesign()
            design:place("item", "circle", 3, 2)
            design:place("item", "triangle", 4, 2)
            design:place("item", "square", 5, 2)
            design:place("pedestal", "circle", 6, 2)
            design:place("pedestal", "triangle", 6, 3)
            design:place("pedestal", "square", 6, 4)
            assert.are.same({}, design:problems())
        end)

        it("wants an exit", function()
            local design = corridorDesign()
            design:remove(7, 4)
            assert.is_true(hasProblem(design, "There is no exit"))
        end)

        it("wants the exit to be reachable from the start", function()
            local design = corridorDesign()
            design:setPassage(3, 1, "south", false)
            assert.is_true(hasProblem(design, "The exit cannot be reached"))
        end)

        it("wants every placed shape and pedestal to be reachable", function()
            local design = corridorDesign()
            design:place("item", "triangle", 2, 4)
            design:place("pedestal", "square", 4, 4)
            assert.is_true(hasProblem(design, "The triangle cannot be reached"))
            assert.is_true(hasProblem(design, "The square's pedestal cannot be reached"))
        end)

        it("wants room for whatever has not been placed, which will be scattered", function()
            -- Four cells can be reached and one holds the start, leaving three for six things
            local design = corridorDesign()
            assert.is_true(hasProblem(design, "There is not room to scatter what is not placed"))
            -- Placing three by hand on passage blocks leaves three to scatter into three cells
            design:place("item", "circle", 3, 2)
            design:place("item", "triangle", 5, 2)
            design:place("item", "square", 6, 3)
            assert.is_false(hasProblem(design, "There is not room to scatter what is not placed"))
        end)

        it("counts the cells that scattering can use: open, reachable, and empty", function()
            local design = corridorDesign()
            assert.are.equal(3, #design:freeCells())
            design:place("item", "circle", 4, 2)
            assert.are.equal(2, #design:freeCells())
        end)
    end)

    describe("saving", function()
        it("comes back the same", function()
            local design = corridorDesign()
            design:place("item", "circle", 4, 2)
            design:place("pedestal", "square", 6, 2)
            design:setBlock(3, 3, true)
            local loaded = MapDesign.fromSave(design:toSave())
            assert.are.same(design.blocks, loaded.blocks)
            assert.are.same(design.start, loaded.start)
            assert.are.same(design.exit, loaded.exit)
            assert.are.same(design.items, loaded.items)
            assert.are.same(design.pedestals, loaded.pedestals)
            assert.are.same(design:problems(), loaded:problems())
        end)

        it("saves a map with no exit yet, so that work in progress is not lost", function()
            local loaded = MapDesign.fromSave(MapDesign.new(3, 2):toSave())
            assert.is_nil(loaded.exit)
        end)

        it("refuses a save from a version it does not know", function()
            local save = corridorDesign():toSave()
            save.version = MapDesign.SAVE_VERSION + 1
            assert.has_error(function() MapDesign.fromSave(save) end)
        end)
    end)
end)
