local stub = require("spec.support.playdate_stub")
import "MapDesign"
import "MapSlots"

local function design()
    local map = MapDesign.new(3, 2)
    map:setPassage(1, 1, "east", true)
    map:place("exit", nil, 1, 2)
    return map
end

describe("MapSlots", function()
    before_each(function() stub.reset() end)

    it("has four slots, lettered A to D", function() assert.are.same({ "A", "B", "C", "D" }, MapSlots.NAMES) end)

    it("is empty to begin with", function()
        for _, name in ipairs(MapSlots.NAMES) do
            assert.is_false(MapSlots.exists(name))
            assert.is_nil(MapSlots.read(name))
        end
    end)

    it("keeps a map in a slot and gives it back", function()
        local map = design()
        MapSlots.write("B", map)
        assert.is_true(MapSlots.exists("B"))
        local loaded = MapSlots.read("B")
        assert.are.same(map.blocks, loaded.blocks)
        assert.are.same(map.exit, loaded.exit)
        assert.is_true(loaded:hasPassage(1, 1, "east"))
    end)

    it("keeps each slot apart from the others", function()
        MapSlots.write("A", design())
        assert.is_false(MapSlots.exists("C"))
        local other = MapDesign.new(6, 4)
        MapSlots.write("C", other)
        assert.are.equal(3, MapSlots.read("A").columns)
        assert.are.equal(6, MapSlots.read("C").columns)
    end)

    it("replaces what was in a slot", function()
        MapSlots.write("A", design())
        MapSlots.write("A", MapDesign.new(6, 4))
        assert.are.equal(6, MapSlots.read("A").columns)
    end)

    it("empties a slot", function()
        MapSlots.write("D", design())
        MapSlots.delete("D")
        assert.is_false(MapSlots.exists("D"))
    end)

    it("refuses a slot that does not exist", function()
        assert.has_error(function() MapSlots.write("E", design()) end)
        assert.has_error(function() MapSlots.read("a") end)
    end)

    it("treats a map it cannot load as an empty slot, rather than crashing the list of maps", function()
        MapSlots.write("A", design())
        stub.datastore[MapSlots.fileFor("A")].version = 999
        assert.is_nil(MapSlots.read("A"))
        assert.is_false(MapSlots.exists("A"))
    end)

    it("keeps its files apart from the saved run and the settings", function()
        for _, name in ipairs(MapSlots.NAMES) do
            assert.are_not.equal("run", MapSlots.fileFor(name))
            assert.are_not.equal("settings", MapSlots.fileFor(name))
        end
    end)
end)
