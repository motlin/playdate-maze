require("spec.support.playdate_stub")
import "Maze"

-- A repeatable stand-in for math.random(n)
local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

local function countReachableCells(maze)
    local seen = { [1 .. "," .. 1] = true }
    local queue = { { 1, 1 } }
    local count = 0
    while #queue > 0 do
        local cell = table.remove(queue)
        count = count + 1
        for _, direction in ipairs(Maze.DIRECTIONS) do
            if maze:hasPassage(cell[1], cell[2], direction) then
                local column = cell[1] + Maze.OFFSETS[direction][1]
                local row = cell[2] + Maze.OFFSETS[direction][2]
                local key = column .. "," .. row
                if not seen[key] then
                    seen[key] = true
                    queue[#queue + 1] = { column, row }
                end
            end
        end
    end
    return count
end

local function countPassages(maze)
    local count = 0
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            if maze:hasPassage(column, row, "east") then count = count + 1 end
            if maze:hasPassage(column, row, "south") then count = count + 1 end
        end
    end
    return count
end

describe("Maze", function()
    describe("new", function()
        it("starts with every cell walled in", function()
            local maze = Maze.new(3, 2)
            for _, direction in ipairs(Maze.DIRECTIONS) do
                assert.is_false(maze:hasPassage(2, 1, direction))
            end
        end)

        it("is a block grid with a wall between and around the cells", function()
            local maze = Maze.new(3, 2)
            assert.are.equal(7, maze.gridWidth)
            assert.are.equal(5, maze.gridHeight)
            assert.is_false(maze:isWall(2, 2))
            assert.is_true(maze:isWall(3, 2))
            assert.is_true(maze:isWall(1, 1))
        end)

        it("treats everything outside the grid as wall", function()
            local maze = Maze.new(3, 2)
            assert.is_true(maze:isWall(0, 2))
            assert.is_true(maze:isWall(8, 2))
            assert.is_true(maze:isWall(2, 0))
            assert.is_true(maze:isWall(2, 6))
        end)
    end)

    describe("carve", function()
        it("opens a passage seen from both sides", function()
            local maze = Maze.new(3, 2)
            maze:carve(1, 1, "east")
            assert.is_true(maze:hasPassage(1, 1, "east"))
            assert.is_true(maze:hasPassage(2, 1, "west"))
            assert.is_false(maze:isWall(3, 2))
        end)

        it("refuses to carve through the outer wall", function()
            local maze = Maze.new(3, 2)
            assert.has_error(function() maze:carve(1, 1, "north") end)
        end)
    end)

    describe("generate", function()
        it("connects every cell", function()
            local maze = Maze.generate(10, 8, seededRandom(1))
            assert.are.equal(80, countReachableCells(maze))
        end)

        it("has no loops: exactly one fewer passage than cells", function()
            local maze = Maze.generate(10, 8, seededRandom(2))
            assert.are.equal(79, countPassages(maze))
        end)

        it("builds the same maze from the same random sequence", function()
            local first = Maze.generate(6, 5, seededRandom(7))
            local second = Maze.generate(6, 5, seededRandom(7))
            assert.are.same(first.blocks, second.blocks)
        end)

        it("builds different mazes from different random sequences", function()
            local first = Maze.generate(6, 5, seededRandom(7))
            local second = Maze.generate(6, 5, seededRandom(8))
            assert.are_not.same(first.blocks, second.blocks)
        end)
    end)

    describe("coordinates", function()
        it("puts a cell's centre in the middle of its block", function()
            local maze = Maze.new(3, 2)
            local x, y = maze:cellCenter(1, 1)
            assert.are.equal(1.5, x)
            assert.are.equal(1.5, y)
            x, y = maze:cellCenter(3, 2)
            assert.are.equal(5.5, x)
            assert.are.equal(3.5, y)
        end)

        it("finds the block under a world position", function()
            local maze = Maze.new(3, 2)
            assert.are.same({ 2, 2 }, { maze:blockAt(1.5, 1.9) })
            assert.are.same({ 3, 2 }, { maze:blockAt(2.0, 1.5) })
        end)

        it("finds the cell nearest a world position, even from inside a passage", function()
            local maze = Maze.new(3, 2)
            assert.are.same({ 1, 1 }, { maze:nearestCell(1.5, 1.5) })
            assert.are.same({ 2, 1 }, { maze:nearestCell(2.9, 1.5) })
        end)
    end)

    describe("exit", function()
        it("is a closed door in the east wall of the last cell", function()
            local maze = Maze.generate(4, 3, seededRandom(3))
            assert.are.equal(Maze.BLOCKS.DOOR, maze:blockValue(9, 6))
            assert.is_true(maze:isWall(9, 6))
        end)

        it("can be walked into once it is open", function()
            local maze = Maze.generate(4, 3, seededRandom(3))
            maze:openExit()
            assert.are.equal(Maze.BLOCKS.EXIT, maze:blockValue(9, 6))
            assert.is_false(maze:isWall(9, 6))
        end)

        it("is a passage out of the last cell only once it is open", function()
            local maze = Maze.generate(4, 3, seededRandom(3))
            assert.is_false(maze:hasPassage(4, 3, "east"))
            maze:openExit()
            assert.is_true(maze:hasPassage(4, 3, "east"))
        end)

        it("knows when a position is inside the open exit", function()
            local maze = Maze.generate(4, 3, seededRandom(3))
            maze:openExit()
            assert.is_true(maze:isExit(8.5, 5.5))
            assert.is_false(maze:isExit(7.5, 5.5))
        end)
    end)

    describe("with wide corridors", function()
        it("makes every cell and passage that many blocks across, with one-block walls between", function()
            local maze = Maze.new(3, 2, 3)
            assert.are.equal(3, maze.corridorWidth)
            assert.are.equal(13, maze.gridWidth)
            assert.are.equal(9, maze.gridHeight)
            for gridY = 2, 4 do
                for gridX = 2, 4 do
                    assert.is_false(maze:isWall(gridX, gridY))
                end
            end
            assert.is_true(maze:isWall(5, 3))
            assert.is_true(maze:isWall(3, 5))
            assert.is_true(maze:isWall(1, 3))
        end)

        it("carves a passage as wide as the corridor", function()
            local maze = Maze.new(3, 2, 3)
            maze:carve(1, 1, "east")
            for gridY = 2, 4 do
                assert.is_false(maze:isWall(5, gridY))
            end
            assert.is_true(maze:isWall(5, 1))
            assert.is_true(maze:isWall(5, 5))
            assert.is_true(maze:hasPassage(1, 1, "east"))
            assert.is_true(maze:hasPassage(2, 1, "west"))
            assert.is_false(maze:hasPassage(1, 1, "south"))

            maze:carve(1, 1, "south")
            for gridX = 2, 4 do
                assert.is_false(maze:isWall(gridX, 5))
            end
            assert.is_true(maze:hasPassage(1, 2, "north"))
        end)

        it("knows where the middle of a cell is, in the world and as a block", function()
            local maze = Maze.new(3, 2, 3)
            assert.are.same({ 2.5, 2.5 }, { maze:cellCenter(1, 1) })
            assert.are.same({ 10.5, 6.5 }, { maze:cellCenter(3, 2) })
            assert.are.same({ 3, 3 }, { maze:cellBlock(1, 1) })
            assert.are.same({ 11, 7 }, { maze:cellBlock(3, 2) })
        end)

        it("finds the nearest cell from anywhere in a cell or passage", function()
            local maze = Maze.new(3, 2, 3)
            assert.are.same({ 1, 1 }, { maze:nearestCell(1.2, 3.8) })
            assert.are.same({ 2, 1 }, { maze:nearestCell(7.9, 1.1) })
            assert.are.same({ 3, 2 }, { maze:nearestCell(11.5, 7.5) })
        end)

        it("still generates a maze that connects every cell without loops", function()
            local maze = Maze.generate(6, 4, seededRandom(4), 3)
            assert.are.equal(24, countReachableCells(maze))
            assert.are.equal(23, countPassages(maze))
        end)

        it("puts the exit door at floor level in the east wall of the last cell", function()
            local maze = Maze.generate(6, 4, seededRandom(4), 3)
            assert.are.same({ 25, 16 }, { maze.exitGridX, maze.exitGridY })
            assert.are.equal(Maze.BLOCKS.DOOR, maze:blockValue(25, 16))
            assert.are.equal(Maze.BLOCKS.WALL, maze:blockValue(25, 15))
            maze:openExit()
            assert.is_true(maze:isExit(24.5, 15.5))
        end)
    end)

    describe("with the usual one-block corridors", function()
        it("has a corridor width of one unless told otherwise", function()
            assert.are.equal(1, Maze.new(3, 2).corridorWidth)
            assert.are.equal(1, Maze.generate(3, 2, seededRandom(1)).corridorWidth)
        end)

        it("gives the block of a cell", function()
            assert.are.same({ 2, 2 }, { Maze.new(3, 2):cellBlock(1, 1) })
            assert.are.same({ 6, 4 }, { Maze.new(3, 2):cellBlock(3, 2) })
        end)
    end)

    describe("openRuns", function()
        it("joins the open blocks of each row into runs", function()
            local maze = Maze.new(3, 2)
            maze:carve(1, 1, "east")
            maze:carve(1, 1, "south")
            assert.are.same({
                { startGridX = 2, endGridX = 4, gridY = 2 },
                { startGridX = 6, endGridX = 6, gridY = 2 },
                { startGridX = 2, endGridX = 2, gridY = 3 },
                { startGridX = 2, endGridX = 2, gridY = 4 },
                { startGridX = 4, endGridX = 4, gridY = 4 },
                { startGridX = 6, endGridX = 6, gridY = 4 },
            }, maze:openRuns())
        end)

        it("leaves out the locked exit and takes in the open one", function()
            local maze = Maze.generate(2, 1, function() return 1 end)
            assert.are.same({ { startGridX = 2, endGridX = 4, gridY = 2 } }, maze:openRuns())
            maze:openExit()
            assert.are.same({ { startGridX = 2, endGridX = 5, gridY = 2 } }, maze:openRuns())
        end)
    end)

    describe("deadEnds", function()
        it("lists cells with a single passage", function()
            local maze = Maze.new(3, 1)
            maze:carve(1, 1, "east")
            maze:carve(2, 1, "east")
            assert.are.same({ { 1, 1 }, { 3, 1 } }, maze:deadEnds())
        end)
    end)
end)
