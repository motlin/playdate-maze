-- The map editor's screen: the map on the left with a cursor, and on the right which tool is in
-- hand, what A and B do with it, and whether the map can be played yet. MapEditor has the rules.
-- The D-pad moves, the crank picks the tool, A adds and B takes away. The map is saved to its
-- slot whenever the editor is left, so there is nothing to remember to do.

import "CoreLibs/graphics"

import "CrankSteps"
import "Hud"
import "MapEditor"
import "MapSlots"
import "MapView"
import "Maze"
import "PlayInput"
import "SceneManager"

EditorScene = { editor = nil, slot = nil }

local MAP_WIDTH <const> = 278
local MAP_HEIGHT <const> = 232
local PANEL_LEFT <const> = 286
local PANEL_WIDTH <const> = 110
-- Holding a direction moves again after a pause, then keeps moving
local REPEAT_AFTER_FRAMES <const> = 9
local REPEAT_EVERY_FRAMES <const> = 3
local CRANK_DEGREES_PER_TOOL <const> = 40
local MESSAGE_FRAMES <const> = 60

local DIRECTIONS <const> = {
    { button = playdate.kButtonLeft, x = -1, y = 0 },
    { button = playdate.kButtonRight, x = 1, y = 0 },
    { button = playdate.kButtonUp, x = 0, y = -1 },
    { button = playdate.kButtonDown, x = 0, y = 1 },
}

local controls = PlayInput.new()
local crankSteps = CrankSteps.new(CRANK_DEGREES_PER_TOOL)
local heldFrames = 0
local messageFrames = 0

function EditorScene.enter(slot, design)
    EditorScene.slot = slot
    EditorScene.editor = MapEditor.new(design)
    crankSteps:reset()
    heldFrames, messageFrames = 0, 0
end

-- Called when the editor is left, and when the game pauses, sleeps, or quits
function EditorScene.save()
    MapSlots.write(EditorScene.slot, EditorScene.editor.design)
    EditorScene.editor:markSaved()
end

function EditorScene.exit()
    EditorScene.save()
end

function EditorScene.say(message)
    EditorScene.editor.message = message
end

function EditorScene.play()
    local editor = EditorScene.editor
    local problem = editor.design:problems()[1]
    if problem then
        EditorScene.say(problem)
        return
    end
    SceneManager.switch(FirstPersonScene, FirstPersonScene.SUBMODES.CUSTOM, TitleScene.sizeIndex, nil, editor.design)
end

-- Throws the drawing away for a freshly generated maze of the same size, to alter
function EditorScene.randomMaze()
    local design = EditorScene.editor.design
    local maze = Maze.generate(design.columns, design.rows, math.random)
    EditorScene.editor = MapEditor.new(MapDesign.fromMaze(maze))
    EditorScene.editor.hasUnsavedChanges = true
    EditorScene.say("A new maze to alter")
end

-- For the system menu, which has room for two items beside Title screen
EditorScene.menuItems = {
    { label = "Play", action = function() EditorScene.play() end },
    { label = "Random maze", action = function() EditorScene.randomMaze() end },
}

-- The step to take this frame, if any: at once on a press, then repeating while held
local function stepFrom(input)
    for _, direction in ipairs(DIRECTIONS) do
        if input:isPressed(direction.button) then
            heldFrames = 0
            return direction
        end
    end
    for _, direction in ipairs(DIRECTIONS) do
        if input:isDown(direction.button) then
            heldFrames = heldFrames + 1
            local isRepeating = heldFrames >= REPEAT_AFTER_FRAMES and (heldFrames - REPEAT_AFTER_FRAMES) % REPEAT_EVERY_FRAMES == 0
            return isRepeating and direction or nil
        end
    end
    heldFrames = 0
    return nil
end

function EditorScene.handleInput()
    local editor = EditorScene.editor
    local input = controls:read()
    local messageBefore = editor.message

    local toolSteps = crankSteps:turn(input.crankChange)
    if toolSteps ~= 0 then editor:turnTool(toolSteps) end

    local step = stepFrom(input)
    if step then
        editor:move(step.x, step.y, input:isDown(playdate.kButtonA), input:isDown(playdate.kButtonB))
    else
        if input:isPressed(playdate.kButtonA) then editor:add() end
        if input:isPressed(playdate.kButtonB) then editor:remove() end
    end
    if editor.message ~= messageBefore then messageFrames = MESSAGE_FRAMES end
end

local function drawPanel(editor)
    local tool = editor:tool()
    playdate.graphics.setColor(playdate.graphics.kColorWhite)
    playdate.graphics.fillRect(PANEL_LEFT - 4, 0, PANEL_WIDTH + 8, 240)
    playdate.graphics.setColor(playdate.graphics.kColorBlack)
    playdate.graphics.drawLine(PANEL_LEFT - 4, 0, PANEL_LEFT - 4, 240)

    playdate.graphics.drawText("*Map " .. EditorScene.slot .. "*", PANEL_LEFT, 6)
    playdate.graphics.drawText("Crank: tool " .. editor.toolIndex .. "/" .. #MapEditor.TOOLS, PANEL_LEFT, 30)
    playdate.graphics.drawTextInRect("*" .. tool.label .. "*", PANEL_LEFT, 50, PANEL_WIDTH, 40)
    playdate.graphics.drawTextInRect(tool.hint, PANEL_LEFT, 94, PANEL_WIDTH, 84)
    playdate.graphics.drawLine(PANEL_LEFT, 182, PANEL_LEFT + PANEL_WIDTH, 182)
    playdate.graphics.drawTextInRect(editor:status(), PANEL_LEFT, 188, PANEL_WIDTH, 50)
end

function EditorScene.update()
    EditorScene.handleInput()
    if not SceneManager.isCurrent(EditorScene) then return end
    local editor = EditorScene.editor

    playdate.graphics.clear(playdate.graphics.kColorWhite)
    local blockSize = MapView.blockSizeToFit(editor.design, MAP_WIDTH, MAP_HEIGHT)
    local width, height = MapView.size(editor.design, blockSize)
    local left, top = (MAP_WIDTH - width) // 2 + 2, (240 - height) // 2
    MapView.draw(editor.design, left, top, blockSize)
    MapView.drawCursor(left, top, blockSize, editor.cursorX, editor.cursorY)
    drawPanel(editor)

    if messageFrames > 0 then
        messageFrames = messageFrames - 1
        if editor.message then Hud.drawLine(editor.message) end
    end
end
