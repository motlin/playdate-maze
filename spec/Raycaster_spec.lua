require("spec.support.playdate_stub")
import "Maze"
import "Raycaster"

-- A 3x1 corridor running east from cell (1,1): open blocks x = 2..6 on grid row 2
local function corridor()
    local maze = Maze.new(3, 1)
    maze:carve(1, 1, "east")
    maze:carve(2, 1, "east")
    return maze
end

describe("Raycaster", function()
    describe("cast", function()
        it("measures the distance to the wall straight ahead", function()
            local distance, side, gridX, gridY, block = Raycaster.cast(corridor(), 1.5, 1.5, 1, 0)
            assert.are.equal(4.5, distance)
            assert.are.equal(7, gridX)
            assert.are.equal(2, gridY)
            assert.are.equal(Raycaster.SIDES.X, side)
            assert.are.equal(Maze.BLOCKS.WALL, block)
        end)

        it("measures the distance to a side wall", function()
            local distance, side, gridX, gridY = Raycaster.cast(corridor(), 1.5, 1.25, 0, -1)
            assert.are.equal(0.25, distance)
            assert.are.equal(2, gridX)
            assert.are.equal(1, gridY)
            assert.are.equal(Raycaster.SIDES.Y, side)
        end)

        it("looks west and south as well", function()
            assert.are.equal(0.5, (Raycaster.cast(corridor(), 1.5, 1.5, -1, 0)))
            assert.are.equal(0.5, (Raycaster.cast(corridor(), 1.5, 1.5, 0, 1)))
        end)

        it("reports how far along the ray the hit is for a diagonal ray", function()
            -- From (1.5, 1.5) heading (1, 1): the south wall y = 2 is reached at t = 0.5
            local distance, side = Raycaster.cast(corridor(), 1.5, 1.5, 1, 1)
            assert.are.equal(0.5, distance)
            assert.are.equal(Raycaster.SIDES.Y, side)
        end)

        it("stops at a closed door and says so", function()
            local maze = Maze.generate(2, 1, function() return 1 end)
            local distance, _, _, _, block = Raycaster.cast(maze, 3.5, 1.5, 1, 0)
            assert.are.equal(Maze.BLOCKS.DOOR, block)
            assert.are.equal(0.5, distance)
        end)

        it("stops at the open exit too, so there is always something to draw", function()
            local maze = Maze.generate(2, 1, function() return 1 end)
            maze:openExit()
            local _, _, _, _, block = Raycaster.cast(maze, 3.5, 1.5, 1, 0)
            assert.are.equal(Maze.BLOCKS.EXIT, block)
        end)
    end)

    describe("scan", function()
        local SCREEN <const> = { width = 400, columnWidth = 4, fieldOfView = 60, refinements = 2 }

        it("covers the whole screen with runs that touch", function()
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 0, SCREEN)
            assert.are.equal(0, scan.runs[1].startX)
            assert.are.equal(400, scan.runs[#scan.runs].endX)
            for index = 2, #scan.runs do
                assert.are.equal(scan.runs[index - 1].endX, scan.runs[index].startX)
            end
        end)

        it("puts the far wall in the middle, at its true distance", function()
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 0, SCREEN)
            local middle
            for _, run in ipairs(scan.runs) do
                if run.startX <= 200 and run.endX >= 200 then middle = run end
            end
            assert.are.equal(7, middle.gridX)
            assert.are.equal(Raycaster.SIDES.X, middle.side)
            assert.is_near(4.5, middle.startDistance, 0.0001)
            assert.is_near(4.5, middle.endDistance, 0.0001)
        end)

        it("is symmetrical when looking straight down a corridor", function()
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 0, SCREEN)
            local first, last = scan.runs[1], scan.runs[#scan.runs]
            assert.are.equal(first.endX - first.startX, last.endX - last.startX)
            assert.is_near(first.startDistance, last.endDistance, 0.0001)
        end)

        it("splits a long wall into one run per block", function()
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 0, SCREEN)
            local northBlocks = {}
            for _, run in ipairs(scan.runs) do
                if run.gridY == 1 then northBlocks[#northBlocks + 1] = run.gridX end
            end
            table.sort(northBlocks)
            -- The leftmost ray meets the north wall at x = 1.5 + 0.5 / tan(30 degrees) = 2.37,
            -- which is already block 3, so block 2 is out of view
            assert.are.same({ 3, 4, 5, 6 }, northBlocks)
        end)

        it("finds run edges more finely than the column width", function()
            -- Looking east from the corridor's west end, the far wall spans atan(0.5 / 4.5) either
            -- side of centre: 200 +- (0.5 / 4.5) / tan(30 degrees) * 200 = 200 +- 38.49
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 0, SCREEN)
            local middle
            for _, run in ipairs(scan.runs) do
                if run.gridX == 7 then middle = run end
            end
            assert.is_near(161.51, middle.startX, 1)
            assert.is_near(238.49, middle.endX, 1)
        end)

        it("records the depth of every column for hiding sprites behind walls", function()
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 0, SCREEN)
            assert.are.equal(100, #scan.depths)
            assert.is_near(4.5, scan.depths[50], 0.0001)
            assert.is_true(scan.depths[1] < 1)
        end)

        it("turns with the viewing angle", function()
            local scan = Raycaster.scan(corridor(), 1.5, 1.5, 90, SCREEN)
            assert.is_near(0.5, scan.depths[50], 0.0001)
        end)
    end)

    describe("project", function()
        local SCREEN <const> = { width = 400, columnWidth = 4, fieldOfView = 60, refinements = 2 }

        it("puts a point straight ahead in the middle of the screen", function()
            local screenX, depth = Raycaster.project(1.5, 1.5, 0, SCREEN, 4.5, 1.5)
            assert.is_near(200, screenX, 0.0001)
            assert.is_near(3, depth, 0.0001)
        end)

        it("puts a point at the edge of the field of view on the edge of the screen", function()
            local offset = 3 * math.tan(math.rad(30))
            local screenX = Raycaster.project(1.5, 1.5, 0, SCREEN, 4.5, 1.5 + offset)
            assert.is_near(400, screenX, 0.0001)
            screenX = Raycaster.project(1.5, 1.5, 0, SCREEN, 4.5, 1.5 - offset)
            assert.is_near(0, screenX, 0.0001)
        end)

        it("measures depth straight ahead, not along the line of sight, to match the walls", function()
            local _, depth = Raycaster.project(1.5, 1.5, 0, SCREEN, 4.5, 2.5)
            assert.is_near(3, depth, 0.0001)
        end)

        it("follows the viewing angle", function()
            local screenX, depth = Raycaster.project(1.5, 1.5, 90, SCREEN, 1.5, 3.5)
            assert.is_near(200, screenX, 0.0001)
            assert.is_near(2, depth, 0.0001)
        end)

        it("sees nothing behind the viewer", function()
            assert.is_nil(Raycaster.project(1.5, 1.5, 0, SCREEN, 0.5, 1.5))
        end)
    end)
end)
