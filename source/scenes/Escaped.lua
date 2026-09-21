-- Shown after walking out of the exit: how long it took, and what next.

import "SceneManager"

EscapedScene = { seconds = 0, playAgain = nil, detail = nil }

local FRAMES_PER_SECOND <const> = 30
local titleImage

local function drawTitleImage()
    local text <const> = "You escaped!"
    local width, height = playdate.graphics.getTextSize(text)
    local image = playdate.graphics.image.new(width, height)
    playdate.graphics.pushContext(image)
    playdate.graphics.drawText(text, 0, 0)
    playdate.graphics.popContext()
    return image
end

-- playAgain() starts a new maze of whatever kind was just escaped. detail is an optional extra
-- line about the run, such as how many throws it took.
function EscapedScene.enter(frames, playAgain, detail)
    EscapedScene.seconds = frames // FRAMES_PER_SECOND
    EscapedScene.playAgain = playAgain
    EscapedScene.detail = detail
    titleImage = titleImage or drawTitleImage()
end

function EscapedScene.update()
    if playdate.buttonJustPressed(playdate.kButtonA) then
        EscapedScene.playAgain()
        return
    end
    if playdate.buttonJustPressed(playdate.kButtonB) then
        SceneManager.switch(TitleScene)
        return
    end

    playdate.graphics.clear(playdate.graphics.kColorWhite)
    titleImage:drawScaled((400 - titleImage.width * 2) / 2, 50, 2)
    local time = string.format("%d:%02d", EscapedScene.seconds // 60, EscapedScene.seconds % 60)
    playdate.graphics.drawTextAligned("Time  *" .. time .. "*", 200, 120, kTextAlignment.center)
    if EscapedScene.detail then playdate.graphics.drawTextAligned(EscapedScene.detail, 200, 146, kTextAlignment.center) end
    playdate.graphics.drawTextAligned("Ⓐ New maze     Ⓑ Title screen", 200, 190, kTextAlignment.center)
end
