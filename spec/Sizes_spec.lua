require("spec.support.playdate_stub")
import "Sizes"

describe("Sizes", function()
    it("offers small, medium, and large mazes, in that order", function()
        local names = {}
        for index, size in ipairs(Sizes.ALL) do names[index] = size.name end
        assert.are.same({ "Small", "Medium", "Large" }, names)
    end)

    it("makes each size bigger than the last in both directions", function()
        for index = 2, #Sizes.ALL do
            assert.is_true(Sizes.ALL[index].columns > Sizes.ALL[index - 1].columns)
            assert.is_true(Sizes.ALL[index].rows > Sizes.ALL[index - 1].rows)
        end
    end)

    it("starts on medium", function()
        assert.are.equal("Medium", Sizes.ALL[Sizes.DEFAULT].name)
        assert.are.same({ 8, 6 }, { Sizes.ALL[Sizes.DEFAULT].columns, Sizes.ALL[Sizes.DEFAULT].rows })
    end)

    it("has room in every size for the three shapes and their pedestals", function()
        for _, size in ipairs(Sizes.ALL) do
            assert.is_true(size.columns * size.rows - 1 >= 6)
        end
    end)

    describe("for Slime, whose corridors are three blocks wide", function()
        it("has fewer cells at every size, so the maze is not enormous", function()
            for _, size in ipairs(Sizes.ALL) do
                assert.is_true(size.slimeColumns < size.columns)
                assert.is_true(size.slimeRows < size.rows)
            end
        end)

        it("still grows with each size and has room for the three shapes", function()
            for index, size in ipairs(Sizes.ALL) do
                assert.is_true(size.slimeColumns * size.slimeRows - 1 >= 3)
                if index > 1 then
                    assert.is_true(size.slimeColumns > Sizes.ALL[index - 1].slimeColumns)
                    assert.is_true(size.slimeRows > Sizes.ALL[index - 1].slimeRows)
                end
            end
        end)
    end)

    describe("next", function()
        it("steps to the next size", function()
            assert.are.equal(2, Sizes.next(1))
            assert.are.equal(3, Sizes.next(2))
        end)

        it("wraps from the largest back to the smallest", function()
            assert.are.equal(1, Sizes.next(3))
        end)
    end)

    describe("previous", function()
        it("steps to the previous size and wraps from the smallest to the largest", function()
            assert.are.equal(1, Sizes.previous(2))
            assert.are.equal(3, Sizes.previous(1))
        end)
    end)

    describe("mapCellSize", function()
        it("draws the default size with roomy cells", function()
            assert.are.equal(7, Sizes.mapCellSize(8))
        end)

        it("shrinks the cells of a wide maze so the map stays in its corner", function()
            local cell = Sizes.mapCellSize(12)
            assert.is_true(12 * cell <= Sizes.WIDEST_MAP)
            assert.is_true(cell >= 5)
        end)
    end)
end)
