-- The list of hand-made maps: four slots, A to D. From here a map is played, edited, started, or
-- thrown away. B goes back to the title screen.

import "CoreLibs/graphics"

import "CrankSteps"
import "MapDesign"
import "MapSlots"
import "MapView"
import "Maze"
import "PlayInput"
import "SceneManager"
import "Sizes"

local pd <const> = playdate
local gfx <const> = playdate.graphics

MyMazesScene = { selection = 1, designs = {}, isDeleteArmed = false }

local LIST_LEFT <const> = 16
local LIST_TOP <const> = 44
local ROW_HEIGHT <const> = 30
local LIST_WIDTH <const> = 190
local THUMBNAIL_LEFT <const> = 222
local THUMBNAIL_TOP <const> = 44
local THUMBNAIL_WIDTH <const> = 162
local THUMBNAIL_HEIGHT <const> = 124
local CRANK_DEGREES_PER_ROW <const> = 45

local controls = PlayInput.new()
local crankSteps = CrankSteps.new(CRANK_DEGREES_PER_ROW)

function MyMazesScene.enter()
    MyMazesScene.isDeleteArmed = false
    for index, name in ipairs(MapSlots.NAMES) do MyMazesScene.designs[index] = MapSlots.read(name) or false end
    crankSteps:reset()
end

function MyMazesScene.selectedSlot()
    return MapSlots.NAMES[MyMazesScene.selection]
end

function MyMazesScene.selectedDesign()
    return MyMazesScene.designs[MyMazesScene.selection] or nil
end

-- A new map is every cell walled in, at the size chosen on the title screen
function MyMazesScene.newDesign()
    local size = Sizes.ALL[TitleScene.sizeIndex]
    return MapDesign.new(size.columns, size.rows)
end

function MyMazesScene.edit()
    local design = MyMazesScene.selectedDesign() or MyMazesScene.newDesign()
    SceneManager.switch(EditorScene, MyMazesScene.selectedSlot(), design)
end

-- A map that cannot be played yet opens in the editor instead, which says what is wrong with it
function MyMazesScene.playOrEdit()
    local design = MyMazesScene.selectedDesign()
    if design and #design:problems() == 0 then
        SceneManager.switch(FirstPersonScene, FirstPersonScene.SUBMODES.CUSTOM, TitleScene.sizeIndex, nil, design)
    else
        MyMazesScene.edit()
    end
end

-- Left once asks, left again throws the map away; anything else calls it off
function MyMazesScene.delete()
    if not MyMazesScene.selectedDesign() then return end
    if not MyMazesScene.isDeleteArmed then
        MyMazesScene.isDeleteArmed = true
        return
    end
    MapSlots.delete(MyMazesScene.selectedSlot())
    MyMazesScene.designs[MyMazesScene.selection] = false
    MyMazesScene.isDeleteArmed = false
end

function MyMazesScene.moveSelection(steps)
    MyMazesScene.selection = math.max(1, math.min(#MapSlots.NAMES, MyMazesScene.selection + steps))
    MyMazesScene.isDeleteArmed = false
end

function MyMazesScene.handleInput()
    local input = controls:read()
    local steps = crankSteps:turn(input.crankChange)
    if input:isPressed(pd.kButtonUp) then steps = -1 end
    if input:isPressed(pd.kButtonDown) then steps = 1 end
    if steps ~= 0 then MyMazesScene.moveSelection(steps) end

    if input:isPressed(pd.kButtonLeft) then
        MyMazesScene.delete()
    elseif input:isPressed(pd.kButtonA) then
        MyMazesScene.playOrEdit()
    elseif input:isPressed(pd.kButtonRight) then
        MyMazesScene.edit()
    elseif input:isPressed(pd.kButtonB) then
        SceneManager.switch(TitleScene)
    end
end

local function describe(design)
    if not design then return "empty" end
    local size = design.columns .. "x" .. design.rows
    return size .. (#design:problems() == 0 and "" or ", unfinished")
end

local function footer(design)
    if MyMazesScene.isDeleteArmed then return "⬅️ again to delete" end
    if not design then return "Ⓐ New map    Ⓑ Back" end
    if #design:problems() > 0 then return "Ⓐ Edit   ⬅️ Delete   Ⓑ Back" end
    return "Ⓐ Play   ➡️ Edit   ⬅️ Delete   Ⓑ Back"
end

function MyMazesScene.update()
    MyMazesScene.handleInput()
    if not SceneManager.isCurrent(MyMazesScene) then return end

    gfx.clear(gfx.kColorWhite)
    gfx.drawText("*My mazes*", LIST_LEFT, 12)
    for index, name in ipairs(MapSlots.NAMES) do
        local top = LIST_TOP + (index - 1) * ROW_HEIGHT
        local design = MyMazesScene.designs[index] or nil
        if index == MyMazesScene.selection then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(LIST_LEFT, top, LIST_WIDTH, ROW_HEIGHT - 4, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawText("*" .. name .. "*   " .. describe(design), LIST_LEFT + 8, top + 4)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end

    local design = MyMazesScene.selectedDesign()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(THUMBNAIL_LEFT - 2, THUMBNAIL_TOP - 2, THUMBNAIL_WIDTH + 4, THUMBNAIL_HEIGHT + 4)
    if design then
        local blockSize = MapView.blockSizeToFit(design, THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT)
        local width, height = MapView.size(design, blockSize)
        MapView.draw(design, THUMBNAIL_LEFT + (THUMBNAIL_WIDTH - width) // 2, THUMBNAIL_TOP + (THUMBNAIL_HEIGHT - height) // 2, blockSize)
    else
        gfx.drawTextAligned("A new map will be", THUMBNAIL_LEFT + THUMBNAIL_WIDTH / 2, THUMBNAIL_TOP + 40, kTextAlignment.center)
        gfx.drawTextAligned("*" .. Sizes.ALL[TitleScene.sizeIndex].name .. "*", THUMBNAIL_LEFT + THUMBNAIL_WIDTH / 2, THUMBNAIL_TOP + 62, kTextAlignment.center)
    end
    gfx.drawTextAligned(footer(design), 200, 212, kTextAlignment.center)
end
