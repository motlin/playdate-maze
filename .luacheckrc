std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua" }
globals = {
    "playdate",
    "PlayInput", "WalkingActions", "TumbleActions", "SlimeActions",
    "Maze", "Raycaster", "Player", "Autopilot", "Puzzle", "Game", "Run", "Tumble", "Slime", "Thread", "TapOrReel", "Landmarks", "Flippers", "SoundBook", "Sounds", "Hum", "ExitDistance", "MusicScore", "Music", "SaveGame", "Settings", "CrankSteps", "MapDesign", "MapSlots", "DockTimer", "Compass", "Bob", "Shades", "Sizes", "SeededRandom",
    "ShapeArt", "MazeView", "SideView", "TumbleView", "SlimeView", "Minimap", "Hud",
    "SceneManager", "SystemMenu",
    "TitleScene", "FirstPersonScene", "TumbleScene", "SlimeScene", "EscapedScene",
}
read_globals = { "import", "kTextAlignment" }
max_line_length = false
-- Methods that ignore self still read best called as methods
self = false

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }
