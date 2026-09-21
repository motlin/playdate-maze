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
import "scenes/MyMazes"
import "scenes/MazeEditor"

function playdate.update()
    SceneManager.update()
end

-- A run in the maze and a map in the editor are both kept on disk
local function saveRun()
    if SceneManager.isCurrent(FirstPersonScene) then FirstPersonScene.save() end
    if SceneManager.isCurrent(EditorScene) then EditorScene.save() end
end

-- Held notes would otherwise drone on behind the system menu
function playdate.gameWillPause()
    saveRun()
    Sounds.stopHum()
    Music.stop()
end

-- Work must survive the console sleeping or the game being closed
playdate.deviceWillSleep = saveRun
playdate.deviceWillLock = saveRun
playdate.gameWillTerminate = saveRun

math.randomseed(playdate.getSecondsSinceEpoch())
Settings.load()

playdate.display.setRefreshRate(30)

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
