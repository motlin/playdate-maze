require("spec.support.playdate_stub")
import "Maze"
import "Flippers"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

describe("Flippers", function()
    describe("scatter", function()
        it("puts one in a small maze and two in a bigger one", function()
            assert.are.equal(1, #Flippers.scatter(Maze.generate(6, 4, seededRandom(1)), seededRandom(2), {}).all)
            assert.are.equal(2, #Flippers.scatter(Maze.generate(8, 6, seededRandom(1)), seededRandom(2), {}).all)
        end)

        it("keeps clear of the start and of blocks that already hold something", function()
            local maze = Maze.generate(6, 4, seededRandom(1))
            local taken = {}
            for row = 1, 4 do
                for column = 1, 6 do
                    local gridX, gridY = maze:cellBlock(column, row)
                    if not (column == 6 and row == 4) then taken[#taken + 1] = { gridX = gridX, gridY = gridY } end
                end
            end
            local flippers = Flippers.scatter(maze, seededRandom(2), taken)
            assert.are.same({ maze:cellBlock(6, 4) }, { flippers.all[1].gridX, flippers.all[1].gridY })
        end)

        it("is the same for the same random numbers", function()
            local maze = Maze.generate(8, 6, seededRandom(1))
            assert.are.same(Flippers.scatter(maze, seededRandom(2), {}).all, Flippers.scatter(maze, seededRandom(2), {}).all)
        end)
    end)

    describe("touch", function()
        local function oneFlipper()
            local flippers = Flippers.scatter(Maze.generate(6, 4, seededRandom(1)), seededRandom(2), {})
            local flipper = flippers.all[1]
            return flippers, flipper.gridX - 0.5, flipper.gridY - 0.5
        end

        it("says nothing was touched from a distance", function()
            local flippers, x, y = oneFlipper()
            assert.is_false(flippers:touch(x + 1, y))
        end)

        it("is touched by walking into it", function()
            local flippers, x, y = oneFlipper()
            assert.is_true(flippers:touch(x + 0.3, y))
        end)

        it("is touched only once however long the player stands in it", function()
            local flippers, x, y = oneFlipper()
            flippers:touch(x, y)
            for _ = 1, 50 do assert.is_false(flippers:touch(x + 0.1, y)) end
        end)

        it("can be touched again after the player has walked well away", function()
            local flippers, x, y = oneFlipper()
            flippers:touch(x, y)
            assert.is_false(flippers:touch(x + 0.8, y))
            assert.is_false(flippers:touch(x, y))
            flippers:touch(x + 1.2, y)
            assert.is_true(flippers:touch(x, y))
        end)
    end)
end)
