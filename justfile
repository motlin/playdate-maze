project_name := "Maze"
source_dir := "source"
output_dir := "builds"
pdx_file := output_dir / "Maze.pdx"
luarocks_bin := env_var("HOME") / ".luarocks/bin"

# 📋 List all recipes (default)
default:
    @just --list --unsorted

# 🔨 Build the Playdate project
build:
    mkdir -p "{{output_dir}}"
    pdc "{{source_dir}}" "{{pdx_file}}"

# 🎮 Run the Playdate Simulator
run: build
    open -a "Playdate Simulator" "{{pdx_file}}"

# 🧹 Clean build artifacts
clean:
    rm -rf "{{output_dir}}"

# 🧪 Run host-side specs
test:
    "{{luarocks_bin}}/busted"

# 🔍 Lint Lua sources
lint:
    "{{luarocks_bin}}/luacheck" .

# 📸 Capture every screen from the Simulator
screenshots output="builds/screenshots":
    tools/screenshots/run.sh tour "{{output}}"
    tools/screenshots/run.sh escape "{{output}}"
    tools/screenshots/run.sh screensaver "{{output}}"
    tools/screenshots/run.sh daily "{{output}}"
    tools/screenshots/run.sh tumble "{{output}}"
    tools/screenshots/run.sh slime "{{output}}"
    tools/screenshots/run.sh resume "{{output}}"
    tools/screenshots/run.sh editor "{{output}}"

# 🎴 Draw the launcher card and icon from the game itself
launcher:
    tools/screenshots/run.sh launcher_art builds/launcher
    mkdir -p "{{source_dir}}/launcher/card-highlighted"
    cp builds/launcher/card.png builds/launcher/icon.png "{{source_dir}}/launcher/"
    for frame in 1 2 3 4; do cp "builds/launcher/card-highlighted-$frame.png" "{{source_dir}}/launcher/card-highlighted/$frame.png"; done
    printf 'frames = 1x4, 2x4, 3x4, 4x4\n' > "{{source_dir}}/launcher/card-highlighted/animation.txt"

# 💨 Play through the game in the Simulator and fail on any crash
smoke: screenshots

# ✅ Pre-commit checks
precommit: lint test build
