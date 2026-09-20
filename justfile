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

# 💨 Play through the game in the Simulator and fail on any crash
smoke: screenshots

# ✅ Pre-commit checks
precommit: lint test build
