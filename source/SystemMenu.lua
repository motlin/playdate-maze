-- Items in the Playdate system menu, which holds at most three custom items.

import "SceneManager"

local pd <const> = playdate

SystemMenu = {}

local menu = pd.getSystemMenu()
local autopilotItem

function SystemMenu.refresh(scene)
    menu:removeAllMenuItems()
    autopilotItem = nil

    if scene == PlayScene then
        autopilotItem = menu:addCheckmarkMenuItem("Autopilot", PlayScene.game:isAutopilotOn(), function(isOn)
            PlayScene.game:setAutopilot(isOn)
        end)
        menu:addMenuItem("New maze", PlayScene.restart)
    end

    if scene == TumbleScene then menu:addMenuItem("New maze", TumbleScene.restart) end
    if scene == SlimeScene then menu:addMenuItem("New maze", SlimeScene.restart) end

    if scene ~= TitleScene then
        menu:addMenuItem("Title screen", function() SceneManager.switch(TitleScene) end)
    end
end

-- Keeps the checkmark honest when the autopilot is switched some other way
function SystemMenu.setAutopilot(isOn)
    if autopilotItem then autopilotItem:setValue(isOn) end
end
