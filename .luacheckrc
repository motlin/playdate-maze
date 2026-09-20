std = "lua54"
include_files = { "source/**/*.lua", "spec/**/*.lua" }
globals = {
    "playdate",
    "Maze", "Raycaster", "Player", "Autopilot", "Puzzle", "Game", "Shades",
    "ShapeArt", "MazeView", "Minimap", "Hud",
    "SceneManager", "SystemMenu",
    "TitleScene", "PlayScene", "EscapedScene",
}
read_globals = { "import", "kTextAlignment" }
max_line_length = false
-- Methods that ignore self still read best called as methods
self = false

files["spec"] = { std = "+busted", globals = { "playdate", "import" } }
