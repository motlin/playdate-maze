require("spec.support.playdate_stub")
import "Bob"

describe("Bob", function()
    describe("the head", function()
        it("is level to begin with", function()
            assert.are.equal(0, Bob.new():headOffset())
        end)

        it("bobs up and down as the player walks, by no more than a few pixels", function()
            local bob = Bob.new()
            local lowest, highest = 0, 0
            for _ = 1, 100 do
                bob:walk(0.08)
                lowest, highest = math.min(lowest, bob:headOffset()), math.max(highest, bob:headOffset())
            end
            assert.is_true(highest > 1.5 and highest <= Bob.HEAD_PIXELS)
            assert.is_true(lowest < -1.5 and lowest >= -Bob.HEAD_PIXELS)
        end)

        it("follows the distance walked, not the time taken: one bob for each stride", function()
            local slow, fast = Bob.new(), Bob.new()
            for _ = 1, 40 do slow:walk(0.04) end
            for _ = 1, 20 do fast:walk(0.08) end
            assert.is_near(slow.phase, fast.phase, 0.0001)
        end)

        it("settles back to level once the player stands still", function()
            local bob = Bob.new()
            for _ = 1, 30 do bob:walk(0.08) end
            for _ = 1, 40 do bob:walk(0) end
            assert.is_near(0, bob:headOffset(), 0.01)
        end)

        it("eases in rather than jolting on the first step", function()
            local bob = Bob.new()
            bob:walk(0.08)
            assert.is_true(math.abs(bob:headOffset()) < 0.5)
        end)
    end)

    describe("hovering shapes", function()
        it("drift up and down a few hundredths of a block", function()
            local lowest, highest = 0, 0
            for frame = 1, 200 do
                local offset = Bob.hoverOffset(frame, 1)
                lowest, highest = math.min(lowest, offset), math.max(highest, offset)
            end
            assert.is_near(Bob.HOVER_BLOCKS, highest, 0.002)
            assert.is_near(-Bob.HOVER_BLOCKS, lowest, 0.002)
        end)

        it("do not all move together", function()
            assert.are_not.equal(Bob.hoverOffset(50, 1), Bob.hoverOffset(50, 2))
            assert.are_not.equal(Bob.hoverOffset(50, 2), Bob.hoverOffset(50, 3))
        end)

        it("are where they were for the same frame, so screenshots can be compared", function()
            assert.are.equal(Bob.hoverOffset(123, 2), Bob.hoverOffset(123, 2))
        end)
    end)
end)
