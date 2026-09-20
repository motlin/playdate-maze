-- Items in the Playdate system menu, which holds at most three custom items. Every mode gets
-- New maze, Music, and Title screen; the title screen gets Music alone.

import "Music"
import "SceneManager"
import "Settings"

local pd <const> = playdate

SystemMenu = {}

local menu = pd.getSystemMenu()

function SystemMenu.refresh(scene)
    menu:removeAllMenuItems()

    if scene.restart then menu:addMenuItem("New maze", scene.restart) end

    menu:addCheckmarkMenuItem("Music", Settings.isMusicOn(), function(isOn)
        Settings.setMusicOn(isOn)
        if not isOn then Music.stop() end
    end)

    if scene ~= TitleScene then
        menu:addMenuItem("Title screen", function() SceneManager.switch(TitleScene) end)
    end
end
