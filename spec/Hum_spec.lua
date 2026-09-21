require("spec.support.playdate_stub")
import "Hum"

-- A shape lying on the ground in the block whose middle is at x, y
local function shapeAt(x, y, shape)
    return { shape = shape or "circle", gridX = x + 0.5, gridY = y + 0.5, state = "ground" }
end

-- The left and right loudness of the one shape, heard from 5, 5 facing east unless told otherwise
local function hear(item, angle)
    local levels = Hum.levels(5, 5, angle or 0, { item })
    return levels[1].left, levels[1].right
end

describe("Hum", function()
    describe("loudness", function()
        it("is silent from six blocks away or more", function()
            assert.are.same({ 0, 0 }, { hear(shapeAt(11, 5)) })
            assert.are.same({ 0, 0 }, { hear(shapeAt(30, 5)) })
        end)

        it("is at its loudest from half a block away or less", function()
            local left, right = hear(shapeAt(5.5, 5))
            assert.is_near(Hum.LOUDEST, math.max(left, right), 0.0001)
            local nearerLeft, nearerRight = hear(shapeAt(5.1, 5))
            assert.is_near(Hum.LOUDEST, math.max(nearerLeft, nearerRight), 0.0001)
        end)

        it("grows steadily as the player gets nearer", function()
            local previous = 0
            for distance = 6, 1, -1 do
                local left, right = hear(shapeAt(5 + distance, 5))
                assert.is_true(math.max(left, right) >= previous)
                previous = math.max(left, right)
            end
            assert.is_true(previous > 0)
        end)

        it("is never loud enough to be tiresome", function() assert.is_true(Hum.LOUDEST <= 0.3) end)
    end)

    describe("direction", function()
        it("is equal in both ears for a shape straight ahead", function()
            local left, right = hear(shapeAt(8, 5))
            assert.is_near(left, right, 0.0001)
            assert.is_true(left > 0)
        end)

        it("is louder in the right ear for a shape to the right", function()
            -- Facing east, south is to the right, because y grows southwards
            local left, right = hear(shapeAt(5, 8))
            assert.is_true(right > left)
            assert.is_near(0, left, 0.0001)
        end)

        it("is louder in the left ear for a shape to the left", function()
            local left, right = hear(shapeAt(5, 2))
            assert.is_true(left > right)
        end)

        it("turns with the player", function()
            local left, right = hear(shapeAt(5, 8), 90)
            assert.is_near(left, right, 0.0001)
        end)

        it("is centred and quieter for a shape directly behind", function()
            local aheadLeft = hear(shapeAt(8, 5))
            local behindLeft, behindRight = hear(shapeAt(2, 5))
            assert.is_near(behindLeft, behindRight, 0.0001)
            assert.is_true(behindLeft < aheadLeft * 0.6)
            assert.is_true(behindLeft > 0)
        end)
    end)

    describe("which shapes hum", function()
        it("is silent for a shape being carried or already home", function()
            local carried, placed = shapeAt(6, 5), shapeAt(6, 5)
            carried.state, placed.state = "carried", "placed"
            local levels = Hum.levels(5, 5, 0, { carried, placed })
            assert.are.same({ 0, 0, 0, 0 }, { levels[1].left, levels[1].right, levels[2].left, levels[2].right })
        end)

        it("gives each shape its own pitch, the circle lowest and the square highest", function()
            assert.is_true(Hum.FREQUENCIES.circle < Hum.FREQUENCIES.triangle)
            assert.is_true(Hum.FREQUENCIES.triangle < Hum.FREQUENCIES.square)
        end)

        it("answers for every shape in the order given, reusing its tables", function()
            local items = { shapeAt(6, 5), shapeAt(5, 7, "square") }
            local first = Hum.levels(5, 5, 0, items)
            assert.are.equal(2, #first)
            assert.are.equal(first, Hum.levels(5, 5, 0, items))
        end)
    end)
end)
