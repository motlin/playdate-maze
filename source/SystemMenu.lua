-- Items in the Playdate system menu, which holds at most three custom items. Every mode gets
-- New maze, Music, and Title screen; the title screen gets Music alone. A scene with two items
-- of its own, as `menuItems`, gets those and Title screen, and has no room for Music.

import "Music"
import "SceneManager"
import "Settings"

SystemMenu = {}

local menu = playdate.getSystemMenu()

function SystemMenu.refresh(scene)
    menu:removeAllMenuItems()

    if scene.menuItems then
        assert(#scene.menuItems <= 2, "the system menu has room for two items beside Title screen")
        for _, item in ipairs(scene.menuItems) do menu:addMenuItem(item.label, item.action) end
    else
        if scene.restart then menu:addMenuItem("New maze", scene.restart) end
        menu:addCheckmarkMenuItem("Music", Settings.isMusicOn(), function(isOn)
            Settings.setMusicOn(isOn)
            if not isOn then Music.stop() end
        end)
    end

    if scene ~= TitleScene then
        menu:addMenuItem("Title screen", function() SceneManager.switch(TitleScene) end)
    end
end
