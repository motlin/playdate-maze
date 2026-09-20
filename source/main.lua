import "CoreLibs/graphics"

import "SceneManager"
import "Music"
import "Sounds"
import "SystemMenu"
import "scenes/Title"
import "scenes/Play"
import "scenes/PlayTumble"
import "scenes/PlaySlime"
import "scenes/Escaped"

local pd <const> = playdate

function playdate.update()
    SceneManager.update()
end

-- Held notes would otherwise drone on behind the system menu
function playdate.gameWillPause()
    Sounds.stopHum()
    Music.stop()
end

math.randomseed(pd.getSecondsSinceEpoch())

pd.display.setRefreshRate(30)

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
