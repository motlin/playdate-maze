require("spec.support.playdate_stub")
import "SeededRandom"

describe("SeededRandom", function()
    describe("advance", function()
        it("is the Park-Miller minimal standard generator", function()
            assert.are.equal(16807, SeededRandom.advance(1))
            assert.are.equal(282475249, SeededRandom.advance(16807))
        end)

        it("reaches the published check value after 10,000 steps from 1", function()
            local state = 1
            for _ = 1, 10000 do
                state = SeededRandom.advance(state)
            end
            assert.are.equal(1043618065, state)
        end)

        it("never leaves the range a 32-bit Playdate integer can hold", function()
            local state = 20260919
            for _ = 1, 10000 do
                state = SeededRandom.advance(state)
                assert.is_true(state >= 1 and state <= 2147483646)
                assert.are.equal("integer", math.type(state))
            end
        end)
    end)

    describe("new", function()
        it("gives the same sequence for the same seed", function()
            local first, second = SeededRandom.new(42), SeededRandom.new(42)
            for _ = 1, 100 do
                assert.are.equal(first(1000), second(1000))
            end
        end)

        it("gives different sequences for different seeds, even neighbouring ones", function()
            local first, second = SeededRandom.new(20260919), SeededRandom.new(20260920)
            local differences = 0
            for _ = 1, 100 do
                if first(4) ~= second(4) then differences = differences + 1 end
            end
            assert.is_true(differences > 50)
        end)

        it("returns whole numbers from 1 to n, like math.random", function()
            local random = SeededRandom.new(7)
            local seen = {}
            for _ = 1, 1000 do
                local value = random(4)
                assert.is_true(value >= 1 and value <= 4)
                seen[value] = true
            end
            assert.are.same({ true, true, true, true }, seen)
        end)

        it("refuses a seed the generator cannot use", function()
            assert.has_error(function() SeededRandom.new(0) end)
            assert.has_error(function() SeededRandom.new(1.5) end)
            assert.has_error(function() SeededRandom.new(2147483647) end)
        end)
    end)

    describe("seedForDate", function()
        it("is different every day", function()
            assert.are_not.equal(SeededRandom.seedForDate(2026, 9, 19), SeededRandom.seedForDate(2026, 9, 20))
            assert.are_not.equal(SeededRandom.seedForDate(2026, 1, 12), SeededRandom.seedForDate(2026, 11, 2))
        end)

        it("is the same all day", function() assert.are.equal(20260919, SeededRandom.seedForDate(2026, 9, 19)) end)
    end)
end)
