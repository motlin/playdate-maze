import "CoreLibs/graphics"

import "SceneManager"
import "SystemMenu"
import "scenes/Title"
import "scenes/Play"
import "scenes/Tumble"
import "scenes/Escaped"

local pd <const> = playdate

function playdate.update()
    SceneManager.update()
end

math.randomseed(pd.getSecondsSinceEpoch())

pd.display.setRefreshRate(30)

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
