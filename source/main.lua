import "CoreLibs/graphics"

import "SceneManager"
import "Settings"
import "SystemMenu"
import "scenes/Title"
import "scenes/FirstPerson"
import "scenes/PlayTumble"
import "scenes/PlaySlime"
import "scenes/Escaped"
import "scenes/MyMazes"
import "scenes/MazeEditor"

function playdate.update() SceneManager.update() end

playdate.gameWillPause = SceneManager.pause

playdate.deviceWillSleep = SceneManager.save
playdate.deviceWillLock = SceneManager.save
playdate.gameWillTerminate = SceneManager.save

math.randomseed(playdate.getSecondsSinceEpoch())
Settings.load()

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
