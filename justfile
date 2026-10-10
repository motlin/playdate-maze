import ".just/console.just"
import ".just/git.just"
import ".just/git-test.just"

project_name := "Maze"
source_dir := "source"
output_dir := "builds"
pdx_file := output_dir / project_name + ".pdx"
luarocks_bin := env_var("HOME") / ".luarocks/bin"

# 📋 List all recipes (default)
default:
    @just --list --unsorted

# `mise install`
mise:
    mise install --quiet
    mise current

# 🧰 Install busted and luacheck into ~/.luarocks
lua-tools:
    luarocks install --local busted 2.3.0-1
    luarocks install --local luacheck 1.2.0-1

# 🔨 Build the Playdate project
build:
    mkdir -p "{{ output_dir }}"
    pdc "{{ source_dir }}" "{{ pdx_file }}"

# 🎮 Run the Playdate Simulator
run: build
    open -a "Playdate Simulator" "{{ pdx_file }}"

# 🧹 Clean build artifacts
clean: _clean-git
    rm -rf "{{ output_dir }}"

# 🧪 Run host-side specs
test:
    "{{ luarocks_bin }}/busted"

# 🔍 Lint Lua sources
lint:
    "{{ luarocks_bin }}/luacheck" .

# 📸 Capture every screen from the Simulator
screenshots output="builds/screenshots":
    tools/screenshots/run.sh tour "{{ output }}"
    tools/screenshots/run.sh escape "{{ output }}"
    tools/screenshots/run.sh screensaver "{{ output }}"
    tools/screenshots/run.sh daily "{{ output }}"
    tools/screenshots/run.sh tumble "{{ output }}"
    tools/screenshots/run.sh slime "{{ output }}"
    tools/screenshots/run.sh resume "{{ output }}"
    tools/screenshots/run.sh editor "{{ output }}"

# 🎴 Draw the launcher card and icon from the game itself
launcher:
    tools/screenshots/run.sh launcher_art builds/launcher
    mkdir -p "{{ source_dir }}/launcher/card-highlighted"
    cp builds/launcher/card.png builds/launcher/icon.png "{{ source_dir }}/launcher/"
    for frame in 1 2 3 4; do cp "builds/launcher/card-highlighted-$frame.png" "{{ source_dir }}/launcher/card-highlighted/$frame.png"; done
    printf 'frames = 1x4, 2x4, 3x4, 4x4\n' > "{{ source_dir }}/launcher/card-highlighted/animation.txt"

# 💨 Play through the game in the Simulator and fail on any crash
smoke: screenshots

# python3 tools/typecheck/check.py
typecheck:
    python3 tools/typecheck/check.py

# `stylua source spec tools`
format:
    stylua source spec tools

# `stylua --check source spec tools`
format-check:
    stylua --check source spec tools

# ✅ Run pre-commit hooks, lint, typecheck, specs, and build
verify:
    pre-commit run --all-files
    just lint
    just typecheck
    just test
    just build

# Override this with a command called `woof` which notifies you in whatever ways you prefer.
# My `woof` command uses `echo`, `say`, and sends a Pushover notification.
echo_command := env('ECHO_COMMAND', "echo")
