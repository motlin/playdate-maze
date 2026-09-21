require("spec.support.playdate_stub")
import "Compass"

-- A strip 120 pixels wide showing 120 degrees, so one pixel is one degree
local function labels(angle)
    local found = {}
    for _, mark in ipairs(Compass.marks(angle, 120, 120)) do
        if mark.label then found[mark.label] = mark.x end
    end
    return found
end

describe("Compass", function()
    it("puts the way the player faces in the middle: angle 270 is north", function()
        assert.are.equal(60, labels(270).N)
        assert.are.equal(60, labels(0).E)
        assert.are.equal(60, labels(90).S)
        assert.are.equal(60, labels(180).W)
    end)

    it("puts what is to the player's right on the right", function()
        local found = labels(0)
        assert.are.equal(15, found.NE)
        assert.are.equal(105, found.SE)
    end)

    it("leaves out what is behind or beside the player", function()
        local found = labels(0)
        assert.is_nil(found.S)
        assert.is_nil(found.N)
        assert.is_nil(found.W)
    end)

    it("slides the letters the opposite way as the player turns", function()
        assert.are.equal(50, labels(10).E)
        assert.are.equal(70, labels(350).E)
    end)

    it("carries on smoothly across the join between 359 and 0 degrees", function()
        local found = labels(350)
        assert.are.equal(70, found.E)
        assert.are.equal(25, found.NE)
        assert.are.equal(115, found.SE)
    end)

    it("marks every fifteen degrees with a tick, and only the eight winds with a letter", function()
        local ticks, letters = 0, 0
        for _, mark in ipairs(Compass.marks(0, 120, 120)) do
            if mark.label then
                letters = letters + 1
            else
                ticks = ticks + 1
            end
        end
        -- From 45 degrees left to 45 degrees right: NE, E, and SE, with a tick between and beside them
        assert.are.equal(3, letters)
        assert.are.equal(4, ticks)
    end)

    it("lists the marks from left to right", function()
        local marks = Compass.marks(200, 120, 120)
        for index = 2, #marks do
            assert.is_true(marks[index].x > marks[index - 1].x)
        end
    end)

    it("scales to the width of the strip", function()
        local found = {}
        for _, mark in ipairs(Compass.marks(0, 240, 120)) do
            if mark.label then found[mark.label] = mark.x end
        end
        assert.are.equal(120, found.E)
        assert.are.equal(30, found.NE)
    end)
end)
