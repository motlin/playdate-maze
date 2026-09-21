std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua", "tools/screenshots/harness.lua" }
local modules = {
    "PlayInput", "WalkingActions", "TumbleActions", "SlimeActions",
    "Maze", "Raycaster", "Player", "Autopilot", "Puzzle", "Game", "Run", "Tumble", "Slime", "Thread", "TapOrReel", "Landmarks", "Flippers", "SoundBook", "Sounds", "Hum", "ExitDistance", "MusicScore", "Music", "SaveGame", "Settings", "CrankSteps", "MapDesign", "MapSlots", "MapEditor", "DockTimer", "Compass", "Bob", "Shades", "Sizes", "SeededRandom",
    "ShapeArt", "MazeView", "SideView", "MapView", "TumbleView", "SlimeView", "Minimap", "Hud",
    "SceneManager", "SystemMenu",
}
read_globals = { "import", "kTextAlignment", "playdate" }
for _, name in ipairs(modules) do
    read_globals[#read_globals + 1] = name
    files["source/" .. name .. ".lua"] = { globals = { name } }
end

local scenes = {
    Title = "TitleScene",
    FirstPerson = "FirstPersonScene",
    PlayTumble = "TumbleScene",
    PlaySlime = "SlimeScene",
    MyMazes = "MyMazesScene",
    MazeEditor = "EditorScene",
    Escaped = "EscapedScene",
}
for name, global in pairs(scenes) do
    read_globals[#read_globals + 1] = global
    files["source/scenes/" .. name .. ".lua"] = { globals = { global } }
end

files["source/main.lua"] = {
    globals = {
        "playdate.update", "playdate.gameWillPause", "playdate.deviceWillSleep",
        "playdate.deviceWillLock", "playdate.gameWillTerminate", "SceneManager.onSwitch",
    },
}
max_line_length = false

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }

files["spec/SceneManager_spec.lua"] = { globals = { "SceneManager.onSwitch" } }
files["tools/screenshots/harness.lua"] = {
    read_globals = {
        "HARNESS_OUT", "HARNESS_SCENARIO", "FirstPersonScene.game", "FirstPersonScene.game.player",
        "TumbleScene.tumble", "SlimeScene.slime",
    },
    globals = {
        "playdate.update", "playdate.getButtonState", "playdate.buttonJustPressed",
        "playdate.buttonIsPressed", "playdate.buttonJustReleased", "playdate.getCrankChange",
        "playdate.isCrankDocked", "playdate.getCrankPosition", "playdate.getTime",
        "FirstPersonScene.game.player.x", "FirstPersonScene.game.player.y", "FirstPersonScene.game.player.angle",
        "TitleScene.sizeIndex", "TumbleScene.tumble.velocityX", "TumbleScene.tumble.velocityY",
        "SlimeScene.slime.state", "SlimeScene.slime.velocityX", "SlimeScene.slime.velocityY",
    },
}
