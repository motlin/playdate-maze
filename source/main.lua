import "CoreLibs/graphics"

import "SceneManager"
import "Settings"
import "Music"
import "Sounds"
import "SystemMenu"
import "scenes/Title"
import "scenes/FirstPerson"
import "scenes/PlayTumble"
import "scenes/PlaySlime"
import "scenes/Escaped"

local pd <const> = playdate

function playdate.update()
    SceneManager.update()
end

-- Held notes would otherwise drone on behind the system menu
local function saveRun()
    if SceneManager.isCurrent(FirstPersonScene) then FirstPersonScene.save() end
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
Settings.load()

pd.display.setRefreshRate(30)

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
