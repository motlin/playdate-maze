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
local function saveRun()
    if SceneManager.isCurrent(PlayScene) then PlayScene.save() end
end

function playdate.gameWillPause()
    saveRun()
    Sounds.stopHum()
    Music.stop()
end

-- A run must survive the console sleeping or the game being closed
playdate.deviceWillSleep = saveRun
playdate.deviceWillLock = saveRun
playdate.gameWillTerminate = saveRun

math.randomseed(pd.getSecondsSinceEpoch())

pd.display.setRefreshRate(30)

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
