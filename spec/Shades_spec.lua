require("spec.support.playdate_stub")
import "Shades"

local function countWhiteBits(pattern)
    local count = 0
    for _, byte in ipairs(pattern) do
        while byte > 0 do
            count = count + (byte & 1)
            byte = byte >> 1
        end
    end
    return count
end

describe("Shades", function()
    it("is black at level 0 and white at the top level", function()
        assert.are.same({ 0, 0, 0, 0, 0, 0, 0, 0 }, Shades.pattern(0))
        assert.are.same({ 255, 255, 255, 255, 255, 255, 255, 255 }, Shades.pattern(Shades.WHITE))
    end)

    it("lights one more pixel in every 4x4 tile with each level", function()
        for level = 0, Shades.WHITE do
            assert.are.equal(level * 4, countWhiteBits(Shades.pattern(level)))
        end
    end)

    it("only ever adds white pixels as the level rises, so shades do not flicker against each other", function()
        for level = 1, Shades.WHITE do
            local darker, lighter = Shades.pattern(level - 1), Shades.pattern(level)
            for row = 1, 8 do
                assert.are.equal(darker[row], darker[row] & lighter[row])
            end
        end
    end)

    it("refuses a level that does not exist", function()
        assert.has_error(function() Shades.pattern(17) end)
        assert.has_error(function() Shades.pattern(-1) end)
    end)
end)
