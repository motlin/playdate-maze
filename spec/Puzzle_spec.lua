require("spec.support.playdate_stub")
import "Maze"
import "Puzzle"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

-- A 5x1 corridor: open blocks x = 2..10 on grid row 2. The circle lies in cell 2 and its
-- pedestal stands in cell 4; the square lies in cell 3 and its pedestal stands in cell 5.
local function corridorPuzzle()
    return Puzzle.new(
        {
            { shape = "circle", gridX = 4, gridY = 2 },
            { shape = "square", gridX = 6, gridY = 2 },
        },
        {
            { shape = "circle", gridX = 8, gridY = 2 },
            { shape = "square", gridX = 10, gridY = 2 },
        }
    )
end

describe("Puzzle", function()
    describe("pickUp", function()
        it("picks up a shape within reach", function()
            local puzzle = corridorPuzzle()
            local item = puzzle:pickUp(3.0, 1.5)
            assert.are.equal("circle", item.shape)
            assert.are.equal(item, puzzle.carried)
            assert.are.equal(Puzzle.STATES.CARRIED, item.state)
        end)

        it("picks up nothing when nothing is within reach", function()
            local puzzle = corridorPuzzle()
            assert.is_nil(puzzle:pickUp(1.5, 1.5))
            assert.is_nil(puzzle.carried)
        end)

        it("picks the nearer of two shapes within reach", function()
            local puzzle = corridorPuzzle()
            assert.are.equal("square", puzzle:pickUp(4.7, 1.5).shape)
        end)

        it("carries only one shape at a time", function()
            local puzzle = corridorPuzzle()
            puzzle:pickUp(3.5, 1.5)
            assert.is_nil(puzzle:pickUp(5.5, 1.5))
            assert.are.equal("circle", puzzle.carried.shape)
        end)

        it("leaves a shape on its pedestal once it is placed", function()
            local puzzle = corridorPuzzle()
            puzzle:pickUp(3.5, 1.5)
            puzzle:drop(7.5, 1.5)
            assert.is_nil(puzzle:pickUp(7.5, 1.5))
        end)
    end)

    describe("itemInReach", function()
        it("tells the screen which shape A would pick up", function()
            local puzzle = corridorPuzzle()
            assert.are.equal("circle", puzzle:itemInReach(3.5, 1.5).shape)
            assert.is_nil(puzzle:itemInReach(1.5, 1.5))
        end)

        it("offers nothing while a shape is being carried", function()
            local puzzle = corridorPuzzle()
            puzzle:pickUp(3.5, 1.5)
            assert.is_nil(puzzle:itemInReach(5.5, 1.5))
        end)
    end)

    describe("drop", function()
        it("does nothing with empty hands", function()
            assert.is_nil(corridorPuzzle():drop(1.5, 1.5))
        end)

        it("puts the shape down in the middle of the block the player stands in", function()
            local puzzle = corridorPuzzle()
            local item = puzzle:pickUp(3.5, 1.5)
            assert.are.equal(Puzzle.RESULTS.DROPPED, puzzle:drop(1.7, 1.2))
            assert.is_nil(puzzle.carried)
            assert.are.same({ 2, 2, Puzzle.STATES.GROUND }, { item.gridX, item.gridY, item.state })
        end)

        it("places the shape on its own pedestal when that is within reach", function()
            local puzzle = corridorPuzzle()
            local item = puzzle:pickUp(3.5, 1.5)
            assert.are.equal(Puzzle.RESULTS.PLACED, puzzle:drop(7.0, 1.5))
            assert.are.same({ 8, 2, Puzzle.STATES.PLACED }, { item.gridX, item.gridY, item.state })
            assert.is_true(puzzle.pedestals[1].isFilled)
        end)

        it("will not put a shape on another shape's pedestal", function()
            local puzzle = corridorPuzzle()
            puzzle:pickUp(3.5, 1.5)
            assert.are.equal(Puzzle.RESULTS.BLOCKED, puzzle:drop(9.5, 1.5))
            assert.are.equal("circle", puzzle.carried.shape)
        end)

        it("will not put a shape down on top of another shape", function()
            local puzzle = corridorPuzzle()
            puzzle:pickUp(3.5, 1.5)
            assert.are.equal(Puzzle.RESULTS.BLOCKED, puzzle:drop(5.5, 1.5))
        end)

        it("puts a shape down beside another shape's pedestal", function()
            local puzzle = corridorPuzzle()
            local item = puzzle:pickUp(5.5, 1.5)
            assert.are.equal("square", item.shape)
            assert.are.equal(Puzzle.RESULTS.DROPPED, puzzle:drop(6.5, 1.5))
            assert.are.same({ 7, 2 }, { item.gridX, item.gridY })
        end)
    end)

    describe("isSolved", function()
        it("is solved once every shape stands on its pedestal", function()
            local puzzle = corridorPuzzle()
            assert.is_false(puzzle:isSolved())
            puzzle:pickUp(3.5, 1.5)
            puzzle:drop(7.5, 1.5)
            assert.is_false(puzzle:isSolved())
            puzzle:pickUp(5.5, 1.5)
            puzzle:drop(9.5, 1.5)
            assert.is_true(puzzle:isSolved())
        end)
    end)

    describe("scatter", function()
        it("hides each shape and stands each pedestal in a cell of its own, away from the start", function()
            local maze = Maze.generate(10, 8, seededRandom(5))
            local puzzle = Puzzle.scatter(maze, seededRandom(6))
            assert.are.equal(3, #puzzle.items)
            assert.are.equal(3, #puzzle.pedestals)
            local seen = {}
            local function check(thing)
                local key = thing.gridX .. "," .. thing.gridY
                assert.is_nil(seen[key])
                seen[key] = true
                assert.is_true(thing.gridX % 2 == 0 and thing.gridY % 2 == 0)
                assert.are_not.equal("2,2", key)
            end
            for index = 1, 3 do
                check(puzzle.items[index])
                check(puzzle.pedestals[index])
                assert.are.equal(Puzzle.SHAPES[index], puzzle.items[index].shape)
                assert.are.equal(Puzzle.SHAPES[index], puzzle.pedestals[index].shape)
            end
        end)

        it("scatters differently for a different random sequence", function()
            local maze = Maze.generate(10, 8, seededRandom(5))
            local first = Puzzle.scatter(maze, seededRandom(6))
            local second = Puzzle.scatter(maze, seededRandom(7))
            assert.are_not.same(first.items, second.items)
        end)

        it("refuses a maze too small to hold everything", function()
            assert.has_error(function() Puzzle.scatter(Maze.generate(3, 2, seededRandom(1)), seededRandom(1)) end)
        end)
    end)
end)
