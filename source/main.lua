import "CoreLibs/graphics"

import "SceneManager"
import "Settings"
import "SystemMenu"
import "scenes/TitleScene"
import "scenes/FirstPersonScene"
import "scenes/TumbleScene"
import "scenes/SlimeScene"
import "scenes/EscapedScene"
import "scenes/MyMazesScene"
import "scenes/EditorScene"

playdate.update = SceneManager.update

playdate.gameWillPause = SceneManager.pause

playdate.deviceWillSleep = SceneManager.save
playdate.deviceWillLock = SceneManager.save
playdate.gameWillTerminate = SceneManager.save

math.randomseed(playdate.getSecondsSinceEpoch())
Settings.load()

SceneManager.onSwitch = SystemMenu.refresh
SceneManager.switch(TitleScene)
