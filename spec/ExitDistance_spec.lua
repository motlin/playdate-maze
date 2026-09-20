require("spec.support.playdate_stub")
import "Maze"
import "ExitDistance"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

describe("ExitDistance", function()
    it("counts the cells to walk through to reach the exit's cell", function()
        local distances = ExitDistance.new(Maze.generate(3, 1, seededRandom(1)))
        assert.are.equal(0, distances:cells(3, 1))
        assert.are.equal(1, distances:cells(2, 1))
        assert.are.equal(2, distances:cells(1, 1))
        assert.are.equal(2, distances.farthest)
    end)

    it("follows the corridors, not the crow", function()
        -- A U-shaped maze: the first cell is next door to the exit's cell, but five cells' walk away
        local maze = Maze.new(2, 3)
        maze:carve(1, 3, "north")
        maze:carve(1, 2, "north")
        maze:carve(1, 1, "east")
        maze:carve(2, 1, "south")
        maze:carve(2, 2, "south")
        maze.exitGridX, maze.exitGridY = maze.gridWidth, 6
        local distances = ExitDistance.new(maze)
        assert.are.equal(0, distances:cells(2, 3))
        assert.are.equal(5, distances:cells(1, 3))
    end)

    it("gives every cell of a generated maze a distance one different from each cell it opens on to", function()
        local maze = Maze.generate(8, 6, seededRandom(5))
        local distances = ExitDistance.new(maze)
        for row = 1, 6 do
            for column = 1, 8 do
                for _, direction in ipairs(Maze.DIRECTIONS) do
                    local offset = Maze.OFFSETS[direction]
                    local nextColumn, nextRow = column + offset[1], row + offset[2]
                    local isInside = nextColumn >= 1 and nextColumn <= 8 and nextRow >= 1 and nextRow <= 6
                    if isInside and maze:hasPassage(column, row, direction) then
                        assert.are.equal(1, math.abs(distances:cells(column, row) - distances:cells(nextColumn, nextRow)))
                    end
                end
            end
        end
    end)

    it("works in a maze with wide corridors", function()
        local distances = ExitDistance.new(Maze.generate(4, 3, seededRandom(5), 3))
        assert.are.equal(0, distances:cells(4, 3))
        assert.is_true(distances.farthest >= 5)
    end)

    describe("proximity", function()
        it("is 1 at the exit's cell and 0 at the farthest cell from it", function()
            local maze = Maze.generate(3, 1, seededRandom(1))
            local distances = ExitDistance.new(maze)
            assert.are.equal(1, distances:proximity(maze:cellCenter(3, 1)))
            assert.are.equal(0.5, distances:proximity(maze:cellCenter(2, 1)))
            assert.are.equal(0, distances:proximity(maze:cellCenter(1, 1)))
        end)
    end)
end)
