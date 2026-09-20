-- Shown after walking out of the exit: how long it took, and what next.

import "SceneManager"

local pd <const> = playdate
local gfx <const> = playdate.graphics

EscapedScene = { seconds = 0 }

local FRAMES_PER_SECOND <const> = 30
local titleImage

local function drawTitleImage()
    local text <const> = "You escaped!"
    local width, height = gfx.getTextSize(text)
    local image = gfx.image.new(width, height)
    gfx.pushContext(image)
    gfx.drawText(text, 0, 0)
    gfx.popContext()
    return image
end

function EscapedScene.enter(frames)
    EscapedScene.seconds = frames // FRAMES_PER_SECOND
    titleImage = titleImage or drawTitleImage()
end

function EscapedScene.update()
    if pd.buttonJustPressed(pd.kButtonA) then
        SceneManager.switch(PlayScene, PlayScene.MODES.EXPLORE, PlayScene.sizeIndex)
        return
    end
    if pd.buttonJustPressed(pd.kButtonB) then
        SceneManager.switch(TitleScene)
        return
    end

    gfx.clear(gfx.kColorWhite)
    titleImage:drawScaled((400 - titleImage.width * 2) / 2, 50, 2)
    local time = string.format("%d:%02d", EscapedScene.seconds // 60, EscapedScene.seconds % 60)
    gfx.drawTextAligned("Time  *" .. time .. "*", 200, 120, kTextAlignment.center)
    gfx.drawTextAligned("Ⓐ New maze     Ⓑ Title screen", 200, 190, kTextAlignment.center)
end
