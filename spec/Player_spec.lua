require("spec.support.playdate_stub")
import "Maze"
import "Player"

-- A 3x1 corridor running east: open blocks x = 2..6 on grid row 2, so world x 1..6, y 1..2
local function corridor()
    local maze = Maze.new(3, 1)
    maze:carve(1, 1, "east")
    maze:carve(2, 1, "east")
    return maze
end

describe("Player", function()
    it("starts where it is put", function()
        local player = Player.new(1.5, 1.5, 90)
        assert.are.same({ 1.5, 1.5, 90 }, { player.x, player.y, player.angle })
    end)

    describe("turn", function()
        it("turns clockwise for positive degrees", function()
            local player = Player.new(1.5, 1.5, 0)
            player:turn(30)
            assert.are.equal(30, player.angle)
        end)

        it("keeps the angle between 0 and 360", function()
            local player = Player.new(1.5, 1.5, 350)
            player:turn(20)
            assert.are.equal(10, player.angle)
            player:turn(-30)
            assert.are.equal(340, player.angle)
        end)
    end)

    describe("move", function()
        it("walks forward along the facing direction", function()
            local player = Player.new(1.5, 1.5, 0)
            player:move(corridor(), 0.5, 0)
            assert.is_near(2.0, player.x, 0.0001)
            assert.is_near(1.5, player.y, 0.0001)
        end)

        it("walks backward for a negative distance", function()
            local player = Player.new(3.5, 1.5, 0)
            player:move(corridor(), -0.5, 0)
            assert.is_near(3.0, player.x, 0.0001)
        end)

        it("strafes to the right of the facing direction", function()
            local player = Player.new(1.5, 1.5, 270)
            player:move(corridor(), 0, 0.5)
            assert.is_near(2.0, player.x, 0.0001)
            assert.is_near(1.5, player.y, 0.0001)
        end)

        it("stops a body's width short of a wall", function()
            local player = Player.new(5.5, 1.5, 0)
            for _ = 1, 20 do player:move(corridor(), 0.1, 0) end
            assert.is_near(6 - Player.RADIUS, player.x, 0.0001)
        end)

        it("slides along a wall when walking into it at an angle", function()
            local player = Player.new(1.5, 1.5, 45)
            for _ = 1, 20 do player:move(corridor(), 0.1, 0) end
            assert.is_near(2 - Player.RADIUS, player.y, 0.0001)
            assert.is_true(player.x > 2.5)
        end)

        it("cannot cut through the corner of a wall", function()
            -- An L-shaped maze: the corner block at grid (3, 3) must stay solid
            local maze = Maze.new(2, 2)
            maze:carve(1, 1, "east")
            maze:carve(2, 1, "south")
            local player = Player.new(2.5, 1.5, 45)
            for _ = 1, 40 do player:move(maze, 0.1, 0) end
            local gridX, gridY = maze:blockAt(player.x, player.y)
            assert.is_false(maze:isWall(gridX, gridY))
            assert.is_false(maze:isWall(maze:blockAt(player.x - Player.RADIUS, player.y + Player.RADIUS)))
        end)

        it("walks into the exit once it is open", function()
            local maze = Maze.generate(2, 1, function() return 1 end)
            maze:openExit()
            local player = Player.new(3.5, 1.5, 0)
            for _ = 1, 10 do player:move(maze, 0.1, 0) end
            assert.is_true(maze:isExit(player.x, player.y))
        end)
    end)

    describe("moveBy", function()
        it("moves by an offset in the world, whichever way the player faces", function()
            local player = Player.new(1.5, 1.5, 123)
            player:moveBy(corridor(), 0.5, 0)
            assert.is_near(2.0, player.x, 0.0001)
            assert.is_near(1.5, player.y, 0.0001)
        end)

        it("says nothing was in the way of a free move", function()
            local player = Player.new(1.5, 1.5, 0)
            assert.are.same({ false, false }, { player:moveBy(corridor(), 0.1, 0) })
        end)

        it("says which way was blocked, so a falling body knows it has landed", function()
            local player = Player.new(3.5, 1.5, 0)
            local isBlockedX, isBlockedY = player:moveBy(corridor(), 0.1, 0.5)
            assert.is_false(isBlockedX)
            assert.is_true(isBlockedY)
            assert.is_near(3.6, player.x, 0.0001)
            assert.is_near(2 - Player.RADIUS, player.y, 0.0001)
        end)

        it("keeps saying so while resting against the wall", function()
            local player = Player.new(3.5, 1.5, 0)
            player:moveBy(corridor(), 0, 0.5)
            local _, isBlockedY = player:moveBy(corridor(), 0, 0.01)
            assert.is_true(isBlockedY)
        end)
    end)

    describe("wouldHit", function()
        it("knows there is a wall just beyond the body", function()
            local player = Player.new(3.5, 2 - Player.RADIUS - 0.000001, 0)
            assert.is_true(player:wouldHit(corridor(), 0, 0.05))
            assert.is_false(player:wouldHit(corridor(), 0, -0.05))
            assert.is_false(player:wouldHit(corridor(), 0.05, 0))
        end)

        it("does not move the player", function()
            local player = Player.new(3.5, 1.5, 0)
            player:wouldHit(corridor(), 0, 0.4)
            assert.are.same({ 3.5, 1.5 }, { player.x, player.y })
        end)
    end)

    describe("cell", function()
        it("faces the nearest compass direction", function()
            assert.are.equal("east", Player.new(1.5, 1.5, 10):facing())
            assert.are.equal("south", Player.new(1.5, 1.5, 100):facing())
            assert.are.equal("west", Player.new(1.5, 1.5, 200):facing())
            assert.are.equal("north", Player.new(1.5, 1.5, 300):facing())
            assert.are.equal("east", Player.new(1.5, 1.5, 350):facing())
        end)
    end)
end)
