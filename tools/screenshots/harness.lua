
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
    local justReleased = {}
    local held = {}
    local crank = 0
    local docked = false
    local pendingShot = nil
    local shotCount = 0

    -- Silent, but still playing every note, so that the sound code runs here as it will for a player
    Sounds.setVolume(0)
    Music.setVolume(0)

    -- Deterministic runs: the same mazes every time, so two runs of the same code produce
    -- byte-identical screenshots.
    math.randomseed(1995)

    pd.buttonJustPressed = function(button) return justPressed[button] == true end
    pd.buttonIsPressed = function(button) return held[button] == true end
    pd.buttonJustReleased = function(button) return justReleased[button] == true end
    -- Like the device: travel since the previous call, taking the short way round
    local reportedCrank = 0
    pd.getCrankChange = function()
        local change = (crank - reportedCrank + 180) % 360 - 180
        reportedCrank = crank
        return change
    end
    pd.isCrankDocked = function() return docked end
    pd.getCrankPosition = function() return crank end
    -- The daily maze is seeded from the date, so the date is pinned too
    local today = { year = 2026, month = 9, day = 19 }
    pd.getTime = function() return today end

    local function log(message)
        print("[harness] " .. message)
        local file = pd.file.open("harness-log.txt", pd.file.kFileAppend)
        if file then
            file:write(message .. "\n")
            file:close()
        end
    end

    local function frames(count) for _ = 1, (count or 1) do coroutine.yield() end end
    -- The frame after a button comes up, the game is told it was just released
    local function release(button)
        justPressed[button], held[button] = nil, nil
        justReleased[button] = true
        coroutine.yield()
        justReleased[button] = nil
    end
    local function press(button, settle)
        justPressed[button], held[button] = true, true
        coroutine.yield()
        release(button)
        frames(settle or 2)
    end
    local function hold(button, count)
        justPressed[button], held[button] = true, true
        coroutine.yield()
        justPressed[button] = nil
        frames(count - 1)
        release(button)
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

    -- Moves the title screen's highlight to a named row by pressing up and down, as a player would
    local function titleRow(name)
        local wanted
        for index, row in ipairs(TitleScene.rows) do
            if row.name == name then wanted = index end
        end
        expect(wanted, "the title screen has a " .. name .. " row")
        for _ = 1, #TitleScene.rows do press(pd.kButtonUp, 0) end
        for _ = 2, wanted do press(pd.kButtonDown, 0) end
        frames(2)
        expect(TitleScene.selection == wanted, "the title highlight reaches the " .. name .. " row")
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
        titleRow("daily"); shot("title-daily-selected")
        titleRow("tumble"); shot("title-tumble-selected")
        titleRow("slime"); shot("title-slime-selected")
        titleRow("screensaver"); shot("title-screensaver-selected")
        titleRow("size")
        expect(TitleScene.sizeIndex == Sizes.DEFAULT, "the size starts on medium")
        press(pd.kButtonRight); shot("title-size-large")
        expect(Sizes.ALL[TitleScene.sizeIndex].name == "Large", "right picks the next size up")
        press(pd.kButtonA); press(pd.kButtonA)
        expect(Sizes.ALL[TitleScene.sizeIndex].name == "Medium", "A cycles the size, wrapping round")
        press(pd.kButtonLeft); press(pd.kButtonLeft)
        expect(Sizes.ALL[TitleScene.sizeIndex].name == "Large", "left wraps from small to large")
        titleRow("explore")
        press(pd.kButtonA, 3)
        expect(PlayScene.game.maze.columns == 12 and PlayScene.game.maze.rows == 9, "Explore starts a maze of the chosen size")
        shot("play-large")
        PlayScene.game.player.x, PlayScene.game.player.y = PlayScene.game.maze:cellCenter(12, 9)
        frames(2); shot("play-large-far-corner-on-map")
        SceneManager.switch(TitleScene)
        TitleScene.sizeIndex = Sizes.DEFAULT
        frames(2)
        titleRow("explore")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(PlayScene), "A on Explore starts the game")
        shot("play-start")
        expect(PlayScene.game.visitedCount == 1, "the map starts with only the first cell revealed")
        expect(not PlayScene.game:isRevealed(PlayScene.game.maze.columns, PlayScene.game.maze.rows), "the far corner starts hidden in fog")

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

        -- Head bob: the view rises and falls with each stride, and settles when standing
        hold(pd.kButtonUp, 6); shot("play-bob-mid-stride")
        hold(pd.kButtonUp, 7); shot("play-bob-later-in-the-stride")
        hold(pd.kButtonDown, 13)
        frames(40)
        player.x, player.y = startX, startY

        -- Ariadne's thread: walk away, then hold B and crank backwards to be reeled back
        hold(pd.kButtonUp, 25)
        local walkedX, walkedY = player.x, player.y
        expect(PlayScene.game.thread:length() > 1.5, "walking lays the thread")
        shot("play-thread-laid")
        justPressed[pd.kButtonB], held[pd.kButtonB] = true, true
        coroutine.yield()
        justPressed[pd.kButtonB] = nil
        local angleBeforeReeling = player.angle
        for _ = 1, 12 do turnCrank(-30); frames(1) end
        shot("play-thread-reeled-in")
        release(pd.kButtonB); frames(2)
        local reeled = math.sqrt((player.x - walkedX) ^ 2 + (player.y - walkedY) ^ 2)
        expect(reeled > 1.5, "holding B and cranking backwards reels the player back along the thread")
        expect(player.angle == angleBeforeReeling, "and the crank does not turn the view meanwhile")
        expect(PlayScene.game.message ~= "Nothing to put down", "letting go of B after reeling is not a drop")
        hold(pd.kButtonUp, 1)
        player.x, player.y = startX, startY

        hold(pd.kButtonRight, 5); shot("play-strafed-right")
        expect(player.angle == startAngle, "with the crank out, left and right sidestep")
        docked = true
        hold(pd.kButtonRight, 9); shot("play-docked-turned-right")
        expect(player.angle == (startAngle + 45) % 360, "with the crank docked, left and right turn")
        docked = false

        press(pd.kButtonA, 2); shot("play-nothing-to-pick-up")
        press(pd.kButtonB, 2); shot("play-nothing-to-put-down")

        -- Dock to dream: put the crank away and leave it, and the autopilot takes over
        docked = true
        frames(DockTimer.DELAY_FRAMES - 10)
        expect(not PlayScene.game:isAutopilotOn(), "the autopilot waits three seconds after the crank is docked")
        frames(15); shot("play-docked-autopilot")
        expect(PlayScene.game:isAutopilotOn(), "then takes over")
        docked = false
        frames(2); shot("play-undocked-in-control")
        expect(not PlayScene.game:isAutopilotOn(), "pulling the crank out takes control back")
        docked = true
        frames(DockTimer.DELAY_FRAMES + 5)
        expect(PlayScene.game:isAutopilotOn(), "docking again hands over again")
        press(pd.kButtonA, 2)
        expect(not PlayScene.game:isAutopilotOn(), "and any button takes control back with the crank still docked")
        docked = false
        frames(2)

        -- Landmarks: look at one of each kind from as far back along a corridor as there is room
        local ANGLES <const> = { east = 0, south = 90, west = 180, north = 270 }
        local OPPOSITE <const> = { east = "west", west = "east", north = "south", south = "north" }
        -- How many open blocks lie beyond a cell's block in a direction, up to three
        local function roomBeyond(game, cellX, cellY, direction)
            local offset = Maze.OFFSETS[direction]
            for blocks = 1, 3 do
                if game.maze:isWall(cellX + offset[1] * blocks, cellY + offset[2] * blocks) then return blocks - 1 end
            end
            return 3
        end
        -- Whether a landmark can be seen from a couple of blocks away, and the view that does so
        local function viewOf(game, landmark)
            local cellX, cellY = game.maze:cellBlock(landmark.column, landmark.row)
            local candidates = landmark.kind == "picture" and { OPPOSITE[landmark.direction] } or Maze.DIRECTIONS
            for _, direction in ipairs(candidates) do
                local blocks = roomBeyond(game, cellX, cellY, direction)
                if blocks >= 2 then
                    local offset = Maze.OFFSETS[direction]
                    local x, y = game.maze:blockCenter(cellX + offset[1] * blocks, cellY + offset[2] * blocks)
                    return x, y, ANGLES[OPPOSITE[direction]]
                end
            end
            return nil
        end
        local function lookAt(x, y, angle, name)
            player.x, player.y, player.angle = x, y, angle
            frames(1); shot(name)
            player.angle = (angle + 12) % 360
            frames(1); shot(name .. "-at-an-angle")
        end
        local seenKinds = {}
        for _, landmark in ipairs(PlayScene.game.landmarks.all) do
            local x, y, angle = viewOf(PlayScene.game, landmark)
            if x and not seenKinds[landmark.kind] then
                seenKinds[landmark.kind] = true
                lookAt(x, y, angle, "play-landmark-" .. landmark.kind)
            end
        end
        expect(seenKinds.picture and seenKinds.floor and seenKinds.ceiling, "a medium maze has every kind of landmark somewhere it can be seen from down a corridor")

        -- The flipper: walk into it and the world turns over; walk away and back, and it turns back
        local flipper = PlayScene.game.flippers.all[1]
        standFacing(flipper); frames(8); shot("play-flipper-ahead")
        frames(6); shot("play-flipper-spinning")
        hold(pd.kButtonUp, 12); shot("play-flipped")
        expect(PlayScene.game.isFlipped, "walking into the flipper turns the world over")
        hold(pd.kButtonDown, 20); shot("play-flipped-looking-back")
        expect(PlayScene.game.isFlipped, "and it stays over after walking away")
        hold(pd.kButtonUp, 20)
        expect(not PlayScene.game.isFlipped, "until the flipper is touched again")
        hold(pd.kButtonDown, 20)

        -- The compass: north in the middle, and the letters carry on across 359 to 0 degrees
        player.angle = 270; frames(1); shot("play-compass-north")
        player.angle = 352; frames(1); shot("play-compass-across-the-join")

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
        expect(game.isGateUnlocked, "which unlocks the gate")
        expect(not game.maze:hasPassage(game.maze.columns, game.maze.rows, "east"), "but does not raise it")

        -- Stand at the gate and winch it up with the crank
        game.player.x, game.player.y = game.maze:cellCenter(game.maze.columns, game.maze.rows)
        game.player.angle = 0
        frames(70); shot("gate-unlocked")
        for _ = 1, 12 do turnCrank(30); frames(1) end
        shot("gate-half-raised")
        expect(game.gateLift > 0.45 and game.gateLift < 0.55, "a full turn of the crank raises the gate half-way")
        expect(game.player.angle == 0, "and does not swing the view")
        frames(40); shot("gate-sagging")
        expect(game.gateLift < 0.45, "left alone, the gate sags back down")
        for _ = 1, 30 do
            if game.gateLift == 1 then break end
            turnCrank(30); frames(1)
        end
        expect(game.gateLift == 1, "cranking on raises it all the way")
        expect(game.maze:hasPassage(game.maze.columns, game.maze.rows, "east"), "which opens the exit")
        frames(2); shot("exit-open")
        hold(pd.kButtonUp, 40)
        expect(SceneManager.isCurrent(EscapedScene), "walking into the exit escapes")
        shot("escaped")
        press(pd.kButtonA, 3); shot("new-maze")
        expect(SceneManager.isCurrent(PlayScene) and PlayScene.game ~= game, "A starts a new maze")

        local exit = { gridX = PlayScene.game.maze.exitGridX, gridY = PlayScene.game.maze.exitGridY }
        standFacing(exit); frames(2); shot("exit-locked")
        hold(pd.kButtonDown, 12); frames(1); shot("exit-locked-from-further-back")
    end

    -- The daily maze is the same all day and different the next day
    scenarios.daily = function()
        frames(5)
        TitleScene.sizeIndex = 3
        titleRow("daily")
        press(pd.kButtonA, 3)
        expect(PlayScene.mode == PlayScene.MODES.DAILY, "the daily row starts the daily maze")
        shot("daily-start")
        expect(PlayScene.game.message == "Daily maze: 19 Sep", "the daily maze says which day it is for")
        expect(PlayScene.game.maze.columns == 8, "the daily maze is medium whatever size is selected")
        expect(PlayScene.game.puzzle ~= nil, "the daily maze has the puzzle")
        local blocks, firstItem = PlayScene.game.maze.blocks, PlayScene.game.puzzle.items[1]

        local function isSameMaze(other)
            for gridY, line in ipairs(blocks) do
                for gridX, block in ipairs(line) do
                    if other[gridY][gridX] ~= block then return false end
                end
            end
            return true
        end

        math.random(100)
        PlayScene.restart(); frames(2)
        expect(PlayScene.game.maze.blocks ~= blocks and isSameMaze(PlayScene.game.maze.blocks), "the same day gives the same maze")
        local sameItem = PlayScene.game.puzzle.items[1]
        expect(sameItem.gridX == firstItem.gridX and sameItem.gridY == firstItem.gridY, "and the same hiding places")

        today.day = 20
        PlayScene.restart(); frames(2); shot("daily-next-day")
        expect(not isSameMaze(PlayScene.game.maze.blocks), "the next day gives a different maze")
    end

    -- The platformer: fall, walk, jump, turn the maze, collect the shapes, and leave
    scenarios.tumble = function()
        frames(5)
        titleRow("tumble")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(TumbleScene), "the Tumble row starts the platformer")
        local tumble = TumbleScene.tumble
        shot("start")
        frames(40); shot("landed")
        expect(tumble.isGrounded, "the player falls to the floor of the first cell")

        docked = true; frames(2); shot("crank-docked"); docked = false

        local x, y = tumble.player.x, tumble.player.y
        press(pd.kButtonA, 4); shot("jumping")
        expect(not tumble.isGrounded, "A jumps")
        frames(40)
        expect(tumble.isGrounded, "and comes back down")

        for step = 1, 9 do
            turnCrank(10); frames(1)
            if step == 3 or step == 6 then shot("turning-" .. step * 10) end
        end
        expect(tumble.angle == 90, "the crank turns the maze degree for degree")
        frames(60); shot("turned-90-settled")
        expect(tumble.isGrounded, "the player settles on what is now the floor")

        hold(pd.kButtonRight, 15); shot("walking-right")
        hold(pd.kButtonLeft, 15); shot("walking-left")
        expect(tumble.facing == -1, "the player faces the way it walks")
        expect(tumble.player.x ~= x or tumble.player.y ~= y, "and has moved")

        -- Collect the shapes by dropping the player next to each one
        for index, item in ipairs(tumble.puzzle.items) do
            tumble.player.x, tumble.player.y = tumble.maze:blockCenter(item.gridX, item.gridY)
            tumble.velocityX, tumble.velocityY = 0, 0
            frames(2); shot("collected-" .. item.shape)
            expect(item.state == Puzzle.STATES.PLACED, "touching the " .. item.shape .. " collects it")
            local isLast = index == #tumble.puzzle.items
            expect(tumble.maze:hasPassage(tumble.maze.columns, tumble.maze.rows, "east") == isLast, "the exit opens with the last shape")
        end

        -- Stand in the last cell with the exit to the right of the screen and walk out
        turnCrank(-tumble.angle); frames(2)
        tumble.player.x, tumble.player.y = tumble.maze:cellCenter(tumble.maze.columns, tumble.maze.rows)
        tumble.velocityX, tumble.velocityY = 0, 0
        frames(30); shot("beside-the-open-exit")
        hold(pd.kButtonRight, 40)
        expect(SceneManager.isCurrent(EscapedScene), "walking out of the exit escapes")
        shot("escaped")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(TumbleScene) and TumbleScene.tumble ~= tumble, "A starts another Tumble maze")
        shot("another-maze")
    end

    -- The throwing mode: aim with the crank, throw, cling, slide, collect, and leave
    scenarios.slime = function()
        local STATES <const> = Slime.STATES
        local function setCrank(degrees) crank = degrees % 360 end
        local function holdA() justPressed[pd.kButtonA], held[pd.kButtonA] = true, true; coroutine.yield(); justPressed[pd.kButtonA] = nil end
        local function waitUntilStuck(slime)
            for _ = 1, 400 do
                if slime.state ~= STATES.FLYING then return end
                frames(1)
            end
            error("the slime never landed")
        end

        frames(5)
        titleRow("slime")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(SlimeScene), "the Slime row starts the throwing mode")
        local slime = SlimeScene.slime
        shot("dropping-in")
        waitUntilStuck(slime); frames(2); shot("resting")
        expect(slime.state == STATES.RESTING, "the slime drops to the floor of the first cell and rests")
        docked = true; frames(2); shot("crank-docked"); docked = false

        setCrank(40); frames(2); shot("pointer-before-aiming")
        holdA(); frames(2); shot("aiming-up-right")
        expect(slime.isAiming, "holding A aims")
        setCrank(320); frames(2); shot("aiming-up-left")
        press(pd.kButtonB, 1); shot("aim-cancelled")
        expect(not slime.isAiming, "B calls off the aim")
        release(pd.kButtonA); frames(2)
        expect(slime.throws == 0 and slime.state == STATES.RESTING, "and letting go of A then throws nothing")

        hold(pd.kButtonRight, 10)
        expect(slime.player.x > 2.5, "right crawls along the floor")
        hold(pd.kButtonLeft, 10)

        -- Throw up and to the left, on to the first cell's outer wall
        setCrank(300); holdA(); frames(1); release(pd.kButtonA)
        expect(slime.state == STATES.FLYING and slime.throws == 1, "letting go of A throws")
        frames(2); shot("flying")
        waitUntilStuck(slime); shot("clinging")
        expect(slime.state == STATES.CLINGING and slime.surface == "left", "it sticks to the wall it hits")
        frames(30); shot("clinging-half-the-clock")
        holdA(); setCrank(60); frames(3); shot("aiming-from-the-wall")
        release(pd.kButtonA)
        expect(slime.throws == 2, "and can throw itself off again")
        frames(6)
        setCrank(0); holdA(); frames(1); release(pd.kButtonA)
        expect(slime.throws == 3, "with one more throw in mid-air")
        frames(3); holdA(); frames(1)
        expect(not slime.isAiming, "but not a second")
        release(pd.kButtonA)
        waitUntilStuck(slime); frames(2)

        -- Let the clock run out on a wall
        slime.player.x, slime.player.y = slime.maze:cellCenter(1, 1)
        slime.state, slime.velocityX, slime.velocityY = STATES.FLYING, 0, 0
        waitUntilStuck(slime)
        setCrank(300); holdA(); frames(1); release(pd.kButtonA)
        waitUntilStuck(slime)
        frames(Slime.STICK_FRAMES + 5); shot("sliding")
        expect(slime.state == STATES.SLIDING, "when the clock runs out it slides down the wall")
        for _ = 1, 200 do
            if slime.state == STATES.RESTING then break end
            frames(1)
        end
        expect(slime.state == STATES.RESTING, "down to the floor")

        -- Collect the shapes by dropping the slime on to each
        for index, item in ipairs(slime.puzzle.items) do
            slime.player.x, slime.player.y = slime.maze:blockCenter(item.gridX, item.gridY)
            slime.state, slime.velocityX, slime.velocityY = STATES.FLYING, 0, 0
            frames(2); shot("collected-" .. item.shape)
            expect(item.state == Puzzle.STATES.PLACED, "touching the " .. item.shape .. " collects it")
            local isLast = index == #slime.puzzle.items
            expect(slime.maze:hasPassage(slime.maze.columns, slime.maze.rows, "east") == isLast, "the exit opens with the last shape")
        end

        slime.player.x, slime.player.y = slime.maze:cellCenter(slime.maze.columns, slime.maze.rows)
        slime.state, slime.velocityX, slime.velocityY = STATES.FLYING, 0, 0
        waitUntilStuck(slime); frames(2); shot("beside-the-open-exit")
        hold(pd.kButtonRight, 80)
        expect(SceneManager.isCurrent(EscapedScene), "crawling out of the exit escapes")
        shot("escaped")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(SlimeScene) and SlimeScene.slime ~= slime, "A starts another Slime maze")
    end

    -- Leave a game part-way through, and carry on with it from the title screen
    scenarios.resume = function()
        frames(5)
        expect(TitleScene.rows[1].name == "explore", "with nothing saved, the title does not offer Continue")
        titleRow("explore")
        press(pd.kButtonA, 3)
        local game = PlayScene.game
        hold(pd.kButtonUp, 25)
        local item = game.puzzle.items[2]
        standFacing(item); frames(2)
        press(pd.kButtonA, 2)
        expect(game.puzzle.carried == item, "a shape is in hand")
        turnCrank(40); frames(2)
        local x, y, angle, played = game.player.x, game.player.y, game.player.angle, game.frames
        shot("before-leaving")

        SceneManager.switch(TitleScene); frames(3)
        shot("title-offers-continue")
        expect(TitleScene.rows[1].name == "continue" and TitleScene.selection == 1, "the title now offers Continue, first and selected")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(PlayScene) and PlayScene.game ~= game, "Continue loads the game from disk")
        local resumed = PlayScene.game
        shot("after-continuing")
        expect(math.abs(resumed.player.x - x) < 0.001 and math.abs(resumed.player.y - y) < 0.001, "in the same place")
        expect(math.abs(resumed.player.angle - angle) < 0.001, "looking the same way")
        expect(resumed.puzzle.carried and resumed.puzzle.carried.shape == item.shape, "holding the same shape")
        expect(resumed.frames >= played and resumed.frames < played + 10, "with the clock where it was")
        expect(resumed.visitedCount == game.visitedCount, "and the same map uncovered")
        expect(PlayScene.mode == PlayScene.MODES.EXPLORE, "as the same kind of game")

        PlayScene.restart(); frames(2)
        expect(not SaveGame.exists(), "starting a new maze throws the old save away")
        SceneManager.switch(TitleScene); frames(3)
        expect(TitleScene.rows[1].name == "continue", "and leaving that one saves it in turn")
    end

    -- Let the screensaver wander, then take over
    scenarios.screensaver = function()
        frames(5)
        -- A small maze, so the wall-follower reaches the exit well inside run.sh's time limit
        TitleScene.sizeIndex = 1
        titleRow("screensaver")
        press(pd.kButtonA, 3)
        expect(PlayScene.game:isAutopilotOn(), "the screensaver starts on autopilot")
        expect(PlayScene.game:isRevealed(PlayScene.game.maze.columns, PlayScene.game.maze.rows), "the screensaver shows the whole map")
        for index = 1, 8 do
            frames(40); shot("wandering-" .. index)
        end
        local game = PlayScene.game
        for _ = 1, 6000 do
            if PlayScene.game ~= game then break end
            frames(1)
        end
        expect(PlayScene.game ~= game, "the screensaver finds the exit and starts a new maze")
        expect(
            PlayScene.game:isAutopilotOn(),
            string.format(
                "and keeps wandering (mode %s, old maze escaped %s after %d frames, in play scene %s)",
                PlayScene.mode, tostring(game.hasEscaped), game.frames, tostring(SceneManager.isCurrent(PlayScene))
            )
        )
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
