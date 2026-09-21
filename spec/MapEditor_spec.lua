require("spec.support.playdate_stub")
import "MapDesign"
import "MapEditor"

local function newEditor() return MapEditor.new(MapDesign.new(3, 2)) end

-- Turns the tool dial until the named tool is in hand
local function pick(editor, name)
    for _ = 1, #MapEditor.TOOLS do
        if editor:tool().name == name then return end
        editor:turnTool(1)
    end
    error("there is no tool called " .. name)
end

describe("MapEditor", function()
    it("starts on the start, holding the tool for walls between cells", function()
        local editor = newEditor()
        assert.are.same({ 2, 2 }, { editor.cursorX, editor.cursorY })
        assert.are.equal("cells", editor:tool().name)
    end)

    describe("the tool dial", function()
        it("offers walls, blocks, the start, the exit, and each shape and its pedestal", function()
            local names = {}
            for index, tool in ipairs(MapEditor.TOOLS) do
                names[index] = tool.name
            end
            assert.are.same({
                "cells",
                "blocks",
                "start",
                "exit",
                "circle",
                "triangle",
                "square",
                "circle pedestal",
                "triangle pedestal",
                "square pedestal",
            }, names)
        end)

        it("turns both ways and goes round", function()
            local editor = newEditor()
            editor:turnTool(1)
            assert.are.equal("blocks", editor:tool().name)
            editor:turnTool(-2)
            assert.are.equal("square pedestal", editor:tool().name)
            editor:turnTool(1)
            assert.are.equal("cells", editor:tool().name)
        end)

        it("has a label and a hint for the screen for every tool", function()
            for _, tool in ipairs(MapEditor.TOOLS) do
                assert.is_true(#tool.label > 0)
                assert.is_true(#tool.hint > 0)
            end
        end)
    end)

    describe("with the cells tool", function()
        it("steps from cell to cell, walls or no walls", function()
            local editor = newEditor()
            editor:move(1, 0, false, false)
            assert.are.same({ 4, 2 }, { editor.cursorX, editor.cursorY })
            editor:move(0, 1, false, false)
            assert.are.same({ 4, 4 }, { editor.cursorX, editor.cursorY })
            assert.is_false(editor.design:hasPassage(1, 1, "east"))
        end)

        it("stops at the edge of the map", function()
            local editor = newEditor()
            editor:move(-1, 0, false, false)
            editor:move(0, -1, false, false)
            assert.are.same({ 2, 2 }, { editor.cursorX, editor.cursorY })
        end)

        it("carves a passage as it moves with A held", function()
            local editor = newEditor()
            editor:move(1, 0, true, false)
            editor:move(0, 1, true, false)
            assert.are.same({ 4, 4 }, { editor.cursorX, editor.cursorY })
            assert.is_true(editor.design:hasPassage(1, 1, "east"))
            assert.is_true(editor.design:hasPassage(2, 1, "south"))
        end)

        it("builds the wall back in the way it pushes with B held, and stays put", function()
            local editor = newEditor()
            editor:move(1, 0, true, false)
            editor:move(-1, 0, false, true)
            assert.are.same({ 4, 2 }, { editor.cursorX, editor.cursorY })
            assert.is_false(editor.design:hasPassage(1, 1, "east"))
        end)

        it("does not carve through the outer wall", function()
            local editor = newEditor()
            editor:move(-1, 0, true, false)
            assert.are.same({ 2, 2 }, { editor.cursorX, editor.cursorY })
            assert.is_false(editor.design:isOpen(1, 2))
        end)

        it("does nothing for a tap of A or B alone, which only mean something on the move", function()
            local editor = newEditor()
            editor.design:place("item", "circle", 2, 4)
            editor:move(0, 1, false, false)
            editor:remove()
            editor:add()
            assert.are.same({ gridX = 2, gridY = 4 }, editor.design.items.circle)
            assert.is_nil(editor.message)
        end)

        it("snaps the cursor on to a cell when the tool is picked up", function()
            local editor = newEditor()
            pick(editor, "blocks")
            editor:move(1, 0, false, false)
            editor:move(0, 1, false, false)
            assert.are.same({ 3, 3 }, { editor.cursorX, editor.cursorY })
            pick(editor, "cells")
            assert.are.same({ 0, 0 }, { editor.cursorX % 2, editor.cursorY % 2 })
        end)
    end)

    describe("with the blocks tool", function()
        it("steps one block at a time over the whole grid, outer wall and all", function()
            local editor = newEditor()
            pick(editor, "blocks")
            editor:move(-1, 0, false, false)
            assert.are.same({ 1, 2 }, { editor.cursorX, editor.cursorY })
            editor:move(-1, 0, false, false)
            assert.are.same({ 1, 2 }, { editor.cursorX, editor.cursorY })
        end)

        it("opens the block under the cursor with A and fills it with B", function()
            local editor = newEditor()
            pick(editor, "blocks")
            editor:move(1, 0, false, false)
            editor:add()
            assert.is_true(editor.design:isOpen(3, 2))
            editor:remove()
            assert.is_false(editor.design:isOpen(3, 2))
        end)

        it("paints as it moves with A or B held", function()
            local editor = newEditor()
            pick(editor, "blocks")
            editor:move(1, 0, true, false)
            editor:move(0, 1, true, false)
            assert.is_true(editor.design:isOpen(3, 2))
            assert.is_true(editor.design:isOpen(3, 3))
            editor:move(0, -1, false, true)
            assert.is_false(editor.design:isOpen(3, 2))
        end)

        it("says why when a block cannot be changed", function()
            local editor = newEditor()
            pick(editor, "blocks")
            editor:remove()
            assert.are.equal("Something is standing there", editor.message)
            editor:move(-1, 0, false, false)
            editor:add()
            assert.are.equal("The outer wall stays solid", editor.message)
        end)
    end)

    describe("with a placing tool", function()
        it("puts its thing down with A and says so", function()
            local editor = newEditor()
            editor:move(1, 0, true, false)
            pick(editor, "triangle")
            editor:add()
            assert.are.same({ gridX = 4, gridY = 2 }, editor.design.items.triangle)
            assert.are.equal("Placed the triangle", editor.message)
        end)

        it("puts a pedestal down", function()
            local editor = newEditor()
            editor:move(1, 0, true, false)
            pick(editor, "square pedestal")
            editor:add()
            assert.are.same({ gridX = 4, gridY = 2 }, editor.design.pedestals.square)
        end)

        it("says why when it cannot", function()
            local editor = newEditor()
            pick(editor, "circle")
            editor:add()
            assert.are.equal("Something is already there", editor.message)
            editor:move(1, 0, false, false)
            editor:add()
            assert.are.equal("That is a wall", editor.message)
        end)

        it("puts the exit in the outer wall, and explains itself anywhere else", function()
            local editor = newEditor()
            pick(editor, "exit")
            editor:move(-1, 0, false, false)
            editor:add()
            assert.are.same({ gridX = 1, gridY = 2 }, editor.design.exit)
            editor:move(1, 0, false, false)
            editor:move(1, 0, false, false)
            editor:add()
            assert.are.equal("The exit goes in the outer wall, beside an open block", editor.message)
        end)

        it("takes away whatever is under the cursor with B", function()
            local editor = newEditor()
            editor:move(1, 0, true, false)
            pick(editor, "triangle")
            editor:add()
            pick(editor, "circle")
            editor:remove()
            assert.is_nil(editor.design.items.triangle)
            assert.are.equal("Removed the triangle", editor.message)
        end)

        it("will not take away the start, only move it", function()
            local editor = newEditor()
            pick(editor, "start")
            editor:remove()
            assert.are.equal("The start can be moved, not removed", editor.message)
            editor:move(1, 0, false, false)
            editor:move(1, 0, false, false)
            editor.design:setBlock(3, 2, true)
            editor:add()
            assert.are.same({ gridX = 4, gridY = 2 }, editor.design.start)
        end)
    end)

    describe("status", function()
        it(
            "says what is still wrong with the map",
            function() assert.are.equal("There is no exit", newEditor():status()) end
        )

        it("says when the map is ready", function()
            local design = MapDesign.new(6, 4)
            for column = 1, 5 do
                design:setPassage(column, 1, "east", true)
            end
            for row = 1, 3 do
                design:setPassage(6, row, "south", true)
            end
            design:place("exit", nil, 13, 8)
            assert.are.equal("Ready to play", MapEditor.new(design):status())
        end)
    end)

    it("knows whether anything has changed since it was last saved", function()
        local editor = newEditor()
        assert.is_false(editor.hasUnsavedChanges)
        editor:move(1, 0, false, false)
        assert.is_false(editor.hasUnsavedChanges)
        editor:move(1, 0, true, false)
        assert.is_true(editor.hasUnsavedChanges)
        editor:markSaved()
        assert.is_false(editor.hasUnsavedChanges)
    end)
end)
