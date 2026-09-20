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

    describe("deadEnds", function()
        it("lists cells with a single passage", function()
            local maze = Maze.new(3, 1)
            maze:carve(1, 1, "east")
            maze:carve(2, 1, "east")
            assert.are.same({ { 1, 1 }, { 3, 1 } }, maze:deadEnds())
        end)
    end)
end)
