require("spec.support.playdate_stub")
import "Maze"
import "Player"
import "Autopilot"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

-- A plus-shaped junction: the middle cell (2, 2) of a 3x3 maze opens in every direction
local function junction()
    local maze = Maze.new(3, 3)
    for _, direction in ipairs(Maze.DIRECTIONS) do
        maze:carve(2, 2, direction)
    end
    return maze
end

describe("Autopilot", function()
    describe("chooseDirection", function()
        it("turns left whenever it can", function()
            assert.are.equal("north", Autopilot.chooseDirection(junction(), 2, 2, "east"))
            assert.are.equal("west", Autopilot.chooseDirection(junction(), 2, 2, "north"))
        end)

        it("goes straight when there is no left turn", function()
            local maze = Maze.new(3, 1)
            maze:carve(1, 1, "east")
            maze:carve(2, 1, "east")
            assert.are.equal("east", Autopilot.chooseDirection(maze, 2, 1, "east"))
        end)

        it("turns right when that is the only way on", function()
            local maze = Maze.new(2, 2)
            maze:carve(1, 1, "east")
            maze:carve(2, 1, "south")
            assert.are.equal("south", Autopilot.chooseDirection(maze, 2, 1, "east"))
        end)

        it("turns back at a dead end", function()
            local maze = Maze.new(2, 1)
            maze:carve(1, 1, "east")
            assert.are.equal("west", Autopilot.chooseDirection(maze, 2, 1, "east"))
        end)

        it("leaves through the exit once it is open", function()
            local maze = Maze.generate(2, 1, function() return 1 end)
            maze:openExit()
            assert.are.equal("east", Autopilot.chooseDirection(maze, 2, 1, "east"))
        end)
    end)

    describe("update", function()
        it("never moves or turns faster than its limits, and never enters a wall", function()
            local maze = Maze.generate(6, 5, seededRandom(11))
            local player = Player.new(1.5, 1.5, 0)
            local autopilot = Autopilot.new(maze, player)
            for _ = 1, 3000 do
                local x, y, angle = player.x, player.y, player.angle
                autopilot:update()
                local distance = math.sqrt((player.x - x) ^ 2 + (player.y - y) ^ 2)
                local turned = math.abs((player.angle - angle + 180) % 360 - 180)
                assert.is_true(distance <= Autopilot.WALK_SPEED + 0.0001)
                assert.is_true(turned <= Autopilot.TURN_SPEED + 0.0001)
                assert.is_false(maze:isWall(maze:blockAt(player.x, player.y)))
            end
        end)

        it("does not walk and turn at the same time", function()
            local maze = Maze.generate(6, 5, seededRandom(11))
            local player = Player.new(1.5, 1.5, 0)
            local autopilot = Autopilot.new(maze, player)
            for _ = 1, 1000 do
                local x, y, angle = player.x, player.y, player.angle
                autopilot:update()
                local hasMoved = player.x ~= x or player.y ~= y
                assert.is_false(hasMoved and player.angle ~= angle)
            end
        end)

        it("visits every cell of the maze", function()
            local maze = Maze.generate(6, 5, seededRandom(12))
            local player = Player.new(1.5, 1.5, 0)
            local autopilot = Autopilot.new(maze, player)
            local visited, count = {}, 0
            for _ = 1, 6000 do
                autopilot:update()
                local column, row = maze:nearestCell(player.x, player.y)
                local key = (row - 1) * maze.columns + column
                if not visited[key] then
                    visited[key] = true
                    count = count + 1
                end
            end
            assert.are.equal(30, count)
        end)

        it("first walks to the middle of the nearest cell when it takes over part-way", function()
            local maze = Maze.new(3, 1)
            maze:carve(1, 1, "east")
            maze:carve(2, 1, "east")
            local player = Player.new(2.7, 1.3, 37)
            local autopilot = Autopilot.new(maze, player)
            for _ = 1, 15 do
                autopilot:update()
            end
            assert.is_near(3.5, player.x, 0.0001)
            assert.is_near(1.5, player.y, 0.0001)
        end)

        it("walks out of the open exit", function()
            local maze = Maze.generate(3, 1, function() return 1 end)
            maze:openExit()
            local player = Player.new(1.5, 1.5, 0)
            local autopilot = Autopilot.new(maze, player)
            local hasEscaped = false
            for _ = 1, 500 do
                autopilot:update()
                if maze:isExit(player.x, player.y) then
                    hasEscaped = true
                    break
                end
            end
            assert.is_true(hasEscaped)
        end)
    end)
end)
