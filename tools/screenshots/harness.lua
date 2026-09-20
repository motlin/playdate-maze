
-- ===== SCREENSHOT HARNESS (appended to a build copy of main.lua; never shipped) =====
-- It drives the game with simulator-only calls. If this build is ever uploaded to a device by
-- mistake, it stays out of the way and the game runs normally.
if playdate.isSimulator then
    local pd <const> = playdate
    local gfx <const> = playdate.graphics
    local OUT <const> = HARNESS_OUT
    local SCENARIO <const> = HARNESS_SCENARIO
    local realUpdate = playdate.update
    local justPressed = {}
    local held = {}
    local crank = 0
    local docked = false
    local pendingShot = nil
    local shotCount = 0

    -- Deterministic runs: the same mazes every time, so two runs of the same code produce
    -- byte-identical screenshots.
    math.randomseed(1995)

    pd.buttonJustPressed = function(button) return justPressed[button] == true end
    pd.buttonIsPressed = function(button) return held[button] == true end
    -- Like the device: travel since the previous call, taking the short way round
    local reportedCrank = 0
    pd.getCrankChange = function()
        local change = (crank - reportedCrank + 180) % 360 - 180
        reportedCrank = crank
        return change
    end
    pd.isCrankDocked = function() return docked end

    local function log(message)
        print("[harness] " .. message)
        local file = pd.file.open("harness-log.txt", pd.file.kFileAppend)
        if file then
            file:write(message .. "\n")
            file:close()
        end
    end

    local function frames(count) for _ = 1, (count or 1) do coroutine.yield() end end
    local function press(button, settle)
        justPressed[button], held[button] = true, true
        coroutine.yield()
        justPressed[button], held[button] = nil, nil
        frames(settle or 2)
    end
    local function hold(button, count)
        held[button] = true
        frames(count)
        held[button] = nil
    end
    local function shot(name)
        shotCount = shotCount + 1
        pendingShot = string.format("%s-%02d-%s", SCENARIO, shotCount, name)
        coroutine.yield()
    end
    local function turnCrank(degrees) crank = (crank + degrees) % 360 end
    local function expect(condition, message)
        if not condition then error("expectation failed: " .. message, 2) end
    end

    -- Stands the player one block away from a shape or pedestal, looking at it
    local ANGLE_TOWARDS <const> = { north = 90, east = 180, south = 270, west = 0 }
    local function standFacing(thing)
        local game = PlayScene.game
        for _, direction in ipairs(Maze.DIRECTIONS) do
            local offset = Maze.OFFSETS[direction]
            local gridX, gridY = thing.gridX + offset[1], thing.gridY + offset[2]
            if not game.maze:isWall(gridX, gridY) then
                game.player.x, game.player.y = game.maze:blockCenter(gridX, gridY)
                game.player.angle = ANGLE_TOWARDS[direction]
                return
            end
        end
        error("nowhere to stand beside block " .. thing.gridX .. "," .. thing.gridY)
    end

    local scenarios = {}

    -- Every screen, and every way of moving, without solving anything
    scenarios.tour = function()
        frames(10); shot("title")
        frames(60); shot("title-backdrop-moved-on")
        press(pd.kButtonDown); shot("title-screensaver-selected")
        press(pd.kButtonUp)
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(PlayScene), "A on Explore starts the game")
        shot("play-start")
        expect(PlayScene.game.visitedCount == 1, "the map starts with only the first cell revealed")
        expect(not PlayScene.game:isRevealed(PlayScene.COLUMNS, PlayScene.ROWS), "the far corner starts hidden in fog")

        local player = PlayScene.game.player
        local startAngle = player.angle
        turnCrank(45); frames(2); shot("play-crank-45")
        expect(player.angle == (startAngle + 45) % 360, "the crank turns the view degree for degree")
        turnCrank(-45); frames(2)

        local startX, startY = player.x, player.y
        hold(pd.kButtonUp, 20); shot("play-walked-forward")
        expect(player.x ~= startX or player.y ~= startY, "holding up walks forward")
        expect(PlayScene.game.visitedCount == 2, "walking into the next cell reveals it on the map")
        hold(pd.kButtonDown, 20)
        expect(math.abs(player.x - startX) < 0.001 and math.abs(player.y - startY) < 0.001, "holding down walks back")

        hold(pd.kButtonRight, 5); shot("play-strafed-right")
        expect(player.angle == startAngle, "with the crank out, left and right sidestep")
        docked = true
        hold(pd.kButtonRight, 9); shot("play-docked-turned-right")
        expect(player.angle == (startAngle + 45) % 360, "with the crank docked, left and right turn")
        docked = false

        press(pd.kButtonA, 2); shot("play-nothing-to-pick-up")
        press(pd.kButtonB, 2); shot("play-nothing-to-put-down")

        -- Look around from the middle of the maze
        player.x, player.y = PlayScene.game.maze:cellCenter(4, 3)
        for quarter = 0, 3 do
            player.angle = quarter * 90 + 20
            frames(1); shot("play-middle-" .. player.angle)
        end
    end

    -- Solve the puzzle and walk out
    scenarios.escape = function()
        frames(5)
        press(pd.kButtonA, 3)
        local game = PlayScene.game
        local puzzle = game.puzzle

        for index, item in ipairs(puzzle.items) do
            local pedestal = puzzle.pedestals[index]
            standFacing(item); frames(2); shot(item.shape .. "-in-view")
            press(pd.kButtonA, 2); shot(item.shape .. "-picked-up")
            expect(puzzle.carried == item, "A picks up the " .. item.shape)

            if index == 1 then
                press(pd.kButtonB, 2); shot(item.shape .. "-dropped")
                expect(puzzle.carried == nil, "B puts the shape down")
                hold(pd.kButtonDown, 8); frames(1); shot(item.shape .. "-seen-after-drop")
                press(pd.kButtonA, 2)
                expect(puzzle.carried == item, "A picks it up again")
                standFacing(puzzle.pedestals[2]); frames(2); shot("wrong-pedestal-in-view")
            end

            standFacing(pedestal); frames(2); shot(item.shape .. "-pedestal-in-view")
            press(pd.kButtonB, 2); shot(item.shape .. "-placed")
            expect(pedestal.isFilled, "B places the " .. item.shape .. " on its pedestal")
        end
        expect(puzzle:isSolved(), "all three shapes placed solves the puzzle")

        game.player.x, game.player.y = game.maze:cellCenter(PlayScene.COLUMNS - 1, PlayScene.ROWS)
        game.player.angle = 0
        frames(70); shot("exit-open-ahead")
        hold(pd.kButtonUp, 20); shot("exit-close")
        hold(pd.kButtonUp, 40)
        expect(SceneManager.isCurrent(EscapedScene), "walking into the exit escapes")
        shot("escaped")
        press(pd.kButtonA, 3); shot("new-maze")
        expect(SceneManager.isCurrent(PlayScene) and PlayScene.game ~= game, "A starts a new maze")

        local exit = { gridX = PlayScene.game.maze.exitGridX, gridY = PlayScene.game.maze.exitGridY }
        standFacing(exit); frames(2); shot("exit-locked")
        hold(pd.kButtonDown, 12); frames(1); shot("exit-locked-from-further-back")
    end

    -- Let the screensaver wander, then take over
    scenarios.screensaver = function()
        frames(5)
        press(pd.kButtonDown)
        press(pd.kButtonA, 3)
        expect(PlayScene.game:isAutopilotOn(), "the screensaver starts on autopilot")
        expect(PlayScene.game:isRevealed(PlayScene.COLUMNS, PlayScene.ROWS), "the screensaver shows the whole map")
        for index = 1, 8 do
            frames(40); shot("wandering-" .. index)
        end
        local game = PlayScene.game
        for _ = 1, 6000 do
            if PlayScene.game ~= game then break end
            frames(1)
        end
        expect(PlayScene.game ~= game, "the screensaver finds the exit and starts a new maze")
        expect(PlayScene.game:isAutopilotOn(), "and keeps wandering")
        shot("next-maze")

        press(pd.kButtonB, 2); shot("taken-over")
        expect(not PlayScene.game:isAutopilotOn(), "any button takes over from the autopilot")
    end

    local co = coroutine.create(function()
        log("scenario " .. SCENARIO .. " start")
        scenarios[SCENARIO]()
        shot("zz-done")
        log("scenario " .. SCENARIO .. " done")
    end)

    local dead = false
    function playdate.update()
        if dead then return end
        if coroutine.status(co) ~= "dead" then
            local ok, err = coroutine.resume(co)
            if not ok then
                log("SCRIPT ERROR: " .. tostring(err))
                dead = true
                return
            end
        end
        local ok, err = xpcall(realUpdate, (debug and debug.traceback) or function(e) return e end)
        if not ok then
            log("GAME CRASH: " .. tostring(err))
            pd.simulator.writeToFile(gfx.getWorkingImage(), OUT .. "/" .. SCENARIO .. "-CRASH.png")
            dead = true
            return
        end
        if pendingShot then
            pd.simulator.writeToFile(gfx.getWorkingImage(), OUT .. "/" .. pendingShot .. ".png")
            pendingShot = nil
        end
    end
end
