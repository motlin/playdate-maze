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

function playdate.gameWillPause()
    SceneManager.save()
    -- Held notes would otherwise drone on behind the system menu
    Sounds.stopHum()
    Music.stop()
end

-- Work must survive the console sleeping or the game being closed
playdate.deviceWillSleep = SceneManager.save
playdate.deviceWillLock = SceneManager.save
playdate.gameWillTerminate = SceneManager.save

math.randomseed(playdate.getSecondsSinceEpoch())
Settings.load()

playdate.display.setRefreshRate(30)

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
