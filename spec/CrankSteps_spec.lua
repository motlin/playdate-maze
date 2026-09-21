require("spec.support.playdate_stub")
import "CrankSteps"

describe("CrankSteps", function()
    it("does not step until the crank has travelled a whole step's worth", function()
        local steps = CrankSteps.new(45)
        assert.are.equal(0, steps:turn(44))
        assert.are.equal(1, steps:turn(1))
    end)

    it("steps backwards for a crank turned backwards", function()
        local steps = CrankSteps.new(45)
        assert.are.equal(-1, steps:turn(-45))
    end)

    it("takes several steps at once for a fast crank, and keeps what is left over", function()
        local steps = CrankSteps.new(45)
        assert.are.equal(2, steps:turn(100))
        assert.are.equal(1, steps:turn(35))
    end)

    it("works for the slowest steady cranking, a degree a frame", function()
        local steps = CrankSteps.new(45)
        local total = 0
        for _ = 1, 90 do
            total = total + steps:turn(1)
        end
        assert.are.equal(2, total)
    end)

    it("gets nowhere for a crank that only trembles", function()
        local steps = CrankSteps.new(45)
        for _ = 1, 200 do
            assert.are.equal(0, steps:turn(1))
            assert.are.equal(0, steps:turn(-1))
        end
    end)

    it("needs a whole step of travel the other way to step back, so the highlight does not flutter", function()
        local steps = CrankSteps.new(45)
        steps:turn(45)
        assert.are.equal(0, steps:turn(-30))
        assert.are.equal(-1, steps:turn(-15))
    end)

    it("forgets leftover travel when reset, as when the D-pad moves the highlight instead", function()
        local steps = CrankSteps.new(45)
        steps:turn(40)
        steps:reset()
        assert.are.equal(0, steps:turn(10))
    end)

    it("comes back to where it started after a full turn, without drifting", function()
        local steps = CrankSteps.new(45)
        local total = 0
        for _ = 1, 360 do
            total = total + steps:turn(1)
        end
        for _ = 1, 360 do
            total = total + steps:turn(-1)
        end
        assert.are.equal(0, total)
    end)
end)
