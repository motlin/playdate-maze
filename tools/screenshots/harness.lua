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

    -- The game this one replaced saves its run or its map as it quits, which can be after run.sh
    -- has emptied the data folder. So start every scenario from nothing, whatever is on disk.
    SaveGame.delete()
    for _, name in ipairs(MapSlots.NAMES) do
        MapSlots.delete(name)
    end
    -- Deterministic runs: the same mazes every time, so two runs of the same code produce
    -- byte-identical screenshots.
    math.randomseed(1995)

    TitleScene.enter()

    -- Silent, but still playing every note, so that the sound code runs here as it will for a player
    Sounds.setVolume(0)
    Music.setVolume(0)

    local function buttonMask(buttons)
        local mask = 0
        for button, down in pairs(buttons) do
            if down then mask = mask | button end
        end
        return mask
    end
    pd.getButtonState = function() return buttonMask(held), buttonMask(justPressed), buttonMask(justReleased) end
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

    local function frames(count)
        for _ = 1, (count or 1) do
            coroutine.yield()
        end
    end
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
        for _ = 1, #TitleScene.rows do
            press(pd.kButtonUp, 0)
        end
        for _ = 2, wanted do
            press(pd.kButtonDown, 0)
        end
        frames(2)
        expect(TitleScene.selection == wanted, "the title highlight reaches the " .. name .. " row")
    end

    -- Stands the player one block away from a shape or pedestal, looking at it
    local ANGLE_TOWARDS <const> = { north = 90, east = 180, south = 270, west = 0 }
    local function standFacing(thing)
        local game = FirstPersonScene.game
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
        frames(10)
        shot("title")
        frames(60)
        shot("title-backdrop-moved-on")
        -- The crank scrolls the menu: an eighth of a turn a row, stopping at the ends
        titleRow("explore")
        local firstRow = TitleScene.selection
        turnCrank(30)
        frames(1)
        expect(TitleScene.selection == firstRow, "a small turn of the crank does not move the highlight")
        turnCrank(20)
        frames(1)
        shot("title-cranked-down-one")
        expect(TitleScene.selection == firstRow + 1, "an eighth of a turn moves it down a row")
        for _ = 1, 3 do
            turnCrank(30)
            frames(1)
        end
        expect(TitleScene.selection == firstRow + 3, "and it keeps going as the crank keeps turning")
        for _ = 1, 20 do
            turnCrank(30)
            frames(1)
        end
        expect(TitleScene.selection == #TitleScene.rows, "stopping at the last row")
        for _ = 1, 30 do
            turnCrank(-30)
            frames(1)
        end
        expect(TitleScene.selection == 1, "and cranking backwards goes up, stopping at the first")

        titleRow("daily")
        shot("title-daily-selected")
        titleRow("tumble")
        shot("title-tumble-selected")
        titleRow("slime")
        shot("title-slime-selected")
        titleRow("screensaver")
        shot("title-screensaver-selected")
        titleRow("size")
        expect(TitleScene.sizeIndex == Sizes.DEFAULT, "the size starts on medium")
        press(pd.kButtonRight)
        shot("title-size-large")
        expect(Sizes.ALL[TitleScene.sizeIndex].name == "Large", "right picks the next size up")
        press(pd.kButtonA)
        press(pd.kButtonA)
        expect(Sizes.ALL[TitleScene.sizeIndex].name == "Medium", "A cycles the size, wrapping round")
        press(pd.kButtonLeft)
        press(pd.kButtonLeft)
        expect(Sizes.ALL[TitleScene.sizeIndex].name == "Large", "left wraps from small to large")
        titleRow("explore")
        press(pd.kButtonA, 3)
        expect(
            FirstPersonScene.game.maze.columns == 12 and FirstPersonScene.game.maze.rows == 9,
            "Explore starts a maze of the chosen size"
        )
        shot("play-large")
        FirstPersonScene.game.player.x, FirstPersonScene.game.player.y = FirstPersonScene.game.maze:cellCenter(12, 9)
        frames(2)
        shot("play-large-far-corner-on-map")
        SceneManager.switch(TitleScene)
        TitleScene.sizeIndex = Sizes.DEFAULT
        frames(2)
        titleRow("explore")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(FirstPersonScene), "A on Explore starts the game")
        shot("play-start")
        expect(FirstPersonScene.game.visitedCount == 1, "the map starts with only the first cell revealed")
        expect(
            not FirstPersonScene.game:isRevealed(FirstPersonScene.game.maze.columns, FirstPersonScene.game.maze.rows),
            "the far corner starts hidden in fog"
        )

        local player = FirstPersonScene.game.player
        local startAngle = player.angle
        turnCrank(45)
        frames(2)
        shot("play-crank-45")
        expect(player.angle == (startAngle + 45) % 360, "the crank turns the view degree for degree")
        turnCrank(-45)
        frames(2)

        local startX, startY = player.x, player.y
        hold(pd.kButtonUp, 20)
        shot("play-walked-forward")
        expect(player.x ~= startX or player.y ~= startY, "holding up walks forward")
        expect(FirstPersonScene.game.visitedCount == 2, "walking into the next cell reveals it on the map")
        hold(pd.kButtonDown, 20)
        expect(math.abs(player.x - startX) < 0.001 and math.abs(player.y - startY) < 0.001, "holding down walks back")

        -- Head bob: the view rises and falls with each stride, and settles when standing
        hold(pd.kButtonUp, 6)
        shot("play-bob-mid-stride")
        hold(pd.kButtonUp, 7)
        shot("play-bob-later-in-the-stride")
        hold(pd.kButtonDown, 13)
        frames(40)
        player.x, player.y = startX, startY

        -- Ariadne's thread: walk away, then hold B and crank backwards to be reeled back
        hold(pd.kButtonUp, 25)
        local walkedX, walkedY = player.x, player.y
        expect(FirstPersonScene.game.thread:length() > 1.5, "walking lays the thread")
        shot("play-thread-laid")
        justPressed[pd.kButtonB], held[pd.kButtonB] = true, true
        coroutine.yield()
        justPressed[pd.kButtonB] = nil
        local angleBeforeReeling = player.angle
        for _ = 1, 12 do
            turnCrank(-30)
            frames(1)
        end
        shot("play-thread-reeled-in")
        release(pd.kButtonB)
        frames(2)
        local reeled = math.sqrt((player.x - walkedX) ^ 2 + (player.y - walkedY) ^ 2)
        expect(reeled > 1.5, "holding B and cranking backwards reels the player back along the thread")
        expect(player.angle == angleBeforeReeling, "and the crank does not turn the view meanwhile")
        expect(FirstPersonScene.game.message ~= "Nothing to put down", "letting go of B after reeling is not a drop")
        hold(pd.kButtonUp, 1)
        player.x, player.y = startX, startY

        hold(pd.kButtonRight, 5)
        shot("play-strafed-right")
        expect(player.angle == startAngle, "with the crank out, left and right sidestep")
        docked = true
        hold(pd.kButtonRight, 9)
        shot("play-docked-turned-right")
        expect(player.angle == (startAngle + 45) % 360, "with the crank docked, left and right turn")
        docked = false

        press(pd.kButtonA, 2)
        shot("play-nothing-to-pick-up")
        press(pd.kButtonB, 2)
        shot("play-nothing-to-put-down")

        -- Music off, as the system menu's Music item sets it: play carries on, silently
        Settings.setMusicOn(false)
        frames(40)
        expect(not Settings.isMusicOn(), "the music can be turned off")
        Settings.setMusicOn(true)
        frames(40)

        -- Dock to dream: put the crank away and leave it, and the autopilot takes over
        docked = true
        frames(DockTimer.DELAY_FRAMES - 10)
        expect(not FirstPersonScene.game:isAutopilotOn(), "the autopilot waits three seconds after the crank is docked")
        frames(15)
        shot("play-docked-autopilot")
        expect(FirstPersonScene.game:isAutopilotOn(), "then takes over")
        docked = false
        frames(2)
        shot("play-undocked-in-control")
        expect(not FirstPersonScene.game:isAutopilotOn(), "pulling the crank out takes control back")
        docked = true
        frames(DockTimer.DELAY_FRAMES + 5)
        expect(FirstPersonScene.game:isAutopilotOn(), "docking again hands over again")
        press(pd.kButtonA, 2)
        expect(
            not FirstPersonScene.game:isAutopilotOn(),
            "and any button takes control back with the crank still docked"
        )
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
            frames(1)
            shot(name)
            player.angle = (angle + 12) % 360
            frames(1)
            shot(name .. "-at-an-angle")
        end
        local seenKinds = {}
        for _, landmark in ipairs(FirstPersonScene.game.landmarks.all) do
            local x, y, angle = viewOf(FirstPersonScene.game, landmark)
            if x and not seenKinds[landmark.kind] then
                seenKinds[landmark.kind] = true
                lookAt(x, y, angle, "play-landmark-" .. landmark.kind)
            end
        end
        expect(
            seenKinds.picture and seenKinds.floor and seenKinds.ceiling,
            "a medium maze has every kind of landmark somewhere it can be seen from down a corridor"
        )

        -- The flipper: walk into it and the world turns over; walk away and back, and it turns back
        local flipper = FirstPersonScene.game.flippers.all[1]
        standFacing(flipper)
        frames(8)
        shot("play-flipper-ahead")
        frames(6)
        shot("play-flipper-spinning")
        hold(pd.kButtonUp, 12)
        shot("play-flipped")
        expect(FirstPersonScene.game.isFlipped, "walking into the flipper turns the world over")
        hold(pd.kButtonDown, 20)
        shot("play-flipped-looking-back")
        expect(FirstPersonScene.game.isFlipped, "and it stays over after walking away")
        hold(pd.kButtonUp, 20)
        expect(not FirstPersonScene.game.isFlipped, "until the flipper is touched again")
        hold(pd.kButtonDown, 20)

        -- The compass: north in the middle, and the letters carry on across 359 to 0 degrees
        player.angle = 270
        frames(1)
        shot("play-compass-north")
        player.angle = 352
        frames(1)
        shot("play-compass-across-the-join")

        -- Look around from the middle of the maze
        player.x, player.y = FirstPersonScene.game.maze:cellCenter(4, 3)
        for quarter = 0, 3 do
            player.angle = quarter * 90 + 20
            frames(1)
            shot("play-middle-" .. player.angle)
        end
    end

    -- Solve the puzzle and walk out
    scenarios.escape = function()
        frames(5)
        press(pd.kButtonA, 3)
        local game = FirstPersonScene.game
        local puzzle = game.puzzle

        for index, item in ipairs(puzzle.items) do
            local pedestal = puzzle.pedestals[index]
            standFacing(item)
            frames(2)
            shot(item.shape .. "-in-view")
            press(pd.kButtonA, 2)
            shot(item.shape .. "-picked-up")
            expect(puzzle.carried == item, "A picks up the " .. item.shape)

            if index == 1 then
                press(pd.kButtonB, 2)
                shot(item.shape .. "-dropped")
                expect(puzzle.carried == nil, "B puts the shape down")
                hold(pd.kButtonDown, 8)
                frames(1)
                shot(item.shape .. "-seen-after-drop")
                press(pd.kButtonA, 2)
                expect(puzzle.carried == item, "A picks it up again")
                standFacing(puzzle.pedestals[2])
                frames(2)
                shot("wrong-pedestal-in-view")
            end

            standFacing(pedestal)
            frames(2)
            shot(item.shape .. "-pedestal-in-view")
            press(pd.kButtonB, 2)
            shot(item.shape .. "-placed")
            expect(pedestal.isFilled, "B places the " .. item.shape .. " on its pedestal")
        end
        expect(puzzle:isSolved(), "all three shapes placed solves the puzzle")
        expect(game.isGateUnlocked, "which unlocks the gate")
        expect(not game.maze:hasPassage(game.maze.columns, game.maze.rows, "east"), "but does not raise it")

        -- Stand at the gate and winch it up with the crank
        game.player.x, game.player.y = game.maze:cellCenter(game.maze.columns, game.maze.rows)
        game.player.angle = 0
        frames(70)
        shot("gate-unlocked")
        for _ = 1, 12 do
            turnCrank(30)
            frames(1)
        end
        shot("gate-half-raised")
        expect(game.gateLift > 0.45 and game.gateLift < 0.55, "a full turn of the crank raises the gate half-way")
        expect(game.player.angle == 0, "and does not swing the view")
        frames(40)
        shot("gate-sagging")
        expect(game.gateLift < 0.45, "left alone, the gate sags back down")
        for _ = 1, 30 do
            if game.gateLift == 1 then break end
            turnCrank(30)
            frames(1)
        end
        expect(game.gateLift == 1, "cranking on raises it all the way")
        expect(game.maze:hasPassage(game.maze.columns, game.maze.rows, "east"), "which opens the exit")
        frames(2)
        shot("exit-open")
        hold(pd.kButtonUp, 40)
        expect(SceneManager.isCurrent(EscapedScene), "walking into the exit escapes")
        shot("escaped")
        press(pd.kButtonA, 3)
        shot("new-maze")
        expect(SceneManager.isCurrent(FirstPersonScene) and FirstPersonScene.game ~= game, "A starts a new maze")

        local exit = { gridX = FirstPersonScene.game.maze.exitGridX, gridY = FirstPersonScene.game.maze.exitGridY }
        standFacing(exit)
        frames(2)
        shot("exit-locked")
        hold(pd.kButtonDown, 12)
        frames(1)
        shot("exit-locked-from-further-back")
    end

    -- The daily maze is the same all day and different the next day
    scenarios.daily = function()
        frames(5)
        TitleScene.sizeIndex = 3
        titleRow("daily")
        press(pd.kButtonA, 3)
        expect(FirstPersonScene.submode == FirstPersonScene.SUBMODES.DAILY, "the daily row starts the daily maze")
        shot("daily-start")
        expect(FirstPersonScene.game.message == "Daily maze: 19 Sep", "the daily maze says which day it is for")
        expect(FirstPersonScene.game.maze.columns == 8, "the daily maze is medium whatever size is selected")
        expect(FirstPersonScene.game.puzzle ~= nil, "the daily maze has the puzzle")
        local blocks, firstItem = FirstPersonScene.game.maze.blocks, FirstPersonScene.game.puzzle.items[1]

        local function isSameMaze(other)
            for gridY, line in ipairs(blocks) do
                for gridX, block in ipairs(line) do
                    if other[gridY][gridX] ~= block then return false end
                end
            end
            return true
        end

        math.random(100)
        FirstPersonScene.restart()
        frames(2)
        expect(
            FirstPersonScene.game.maze.blocks ~= blocks and isSameMaze(FirstPersonScene.game.maze.blocks),
            "the same day gives the same maze"
        )
        local sameItem = FirstPersonScene.game.puzzle.items[1]
        expect(sameItem.gridX == firstItem.gridX and sameItem.gridY == firstItem.gridY, "and the same hiding places")

        today.day = 20
        FirstPersonScene.restart()
        frames(2)
        shot("daily-next-day")
        expect(not isSameMaze(FirstPersonScene.game.maze.blocks), "the next day gives a different maze")
    end

    -- The platformer: fall, walk, jump, turn the maze, collect the shapes, and leave
    scenarios.tumble = function()
        frames(5)
        titleRow("tumble")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(TumbleScene), "the Tumble row starts the platformer")
        local tumble = TumbleScene.tumble
        shot("start")
        frames(40)
        shot("landed")
        expect(tumble.isGrounded, "the player falls to the floor of the first cell")

        docked = true
        frames(2)
        shot("crank-docked")
        docked = false

        local x, y = tumble.player.x, tumble.player.y
        press(pd.kButtonA, 4)
        shot("jumping")
        expect(not tumble.isGrounded, "A jumps")
        frames(40)
        expect(tumble.isGrounded, "and comes back down")

        for step = 1, 9 do
            turnCrank(10)
            frames(1)
            if step == 3 or step == 6 then shot("turning-" .. step * 10) end
        end
        expect(tumble.angle == 90, "the crank turns the maze degree for degree")
        frames(60)
        shot("turned-90-settled")
        expect(tumble.isGrounded, "the player settles on what is now the floor")

        hold(pd.kButtonRight, 15)
        shot("walking-right")
        hold(pd.kButtonLeft, 15)
        shot("walking-left")
        expect(tumble.facing == -1, "the player faces the way it walks")
        expect(tumble.player.x ~= x or tumble.player.y ~= y, "and has moved")

        -- Collect the shapes by dropping the player next to each one
        for index, item in ipairs(tumble.puzzle.items) do
            tumble.player.x, tumble.player.y = tumble.maze:blockCenter(item.gridX, item.gridY)
            tumble.velocityX, tumble.velocityY = 0, 0
            frames(2)
            shot("collected-" .. item.shape)
            expect(item.state == Puzzle.STATES.PLACED, "touching the " .. item.shape .. " collects it")
            local isLast = index == #tumble.puzzle.items
            expect(
                tumble.maze:hasPassage(tumble.maze.columns, tumble.maze.rows, "east") == isLast,
                "the exit opens with the last shape"
            )
        end

        -- Stand in the last cell with the exit to the right of the screen and walk out
        turnCrank(-tumble.angle)
        frames(2)
        tumble.player.x, tumble.player.y = tumble.maze:cellCenter(tumble.maze.columns, tumble.maze.rows)
        tumble.velocityX, tumble.velocityY = 0, 0
        frames(30)
        shot("beside-the-open-exit")
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
        local function holdA()
            justPressed[pd.kButtonA], held[pd.kButtonA] = true, true
            coroutine.yield()
            justPressed[pd.kButtonA] = nil
        end
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
        waitUntilStuck(slime)
        frames(2)
        shot("resting")
        expect(slime.state == STATES.RESTING, "the slime drops to the floor of the first cell and rests")
        docked = true
        frames(2)
        shot("crank-docked")
        docked = false

        setCrank(40)
        frames(2)
        shot("pointer-before-aiming")
        holdA()
        frames(2)
        shot("aiming-up-right")
        expect(slime.isAiming, "holding A aims")
        setCrank(320)
        frames(2)
        shot("aiming-up-left")
        press(pd.kButtonB, 1)
        shot("aim-cancelled")
        expect(not slime.isAiming, "B calls off the aim")
        release(pd.kButtonA)
        frames(2)
        expect(slime.throws == 0 and slime.state == STATES.RESTING, "and letting go of A then throws nothing")

        hold(pd.kButtonRight, 10)
        expect(slime.player.x > 2.5, "right crawls along the floor")
        hold(pd.kButtonLeft, 10)

        -- Throw up and to the left, on to the first cell's outer wall
        setCrank(300)
        holdA()
        frames(1)
        release(pd.kButtonA)
        expect(slime.state == STATES.FLYING and slime.throws == 1, "letting go of A throws")
        frames(2)
        shot("flying")
        waitUntilStuck(slime)
        shot("clinging")
        expect(slime.state == STATES.CLINGING and slime.surface == "left", "it sticks to the wall it hits")
        frames(Slime.STICK_FRAMES // 2 - 3)
        shot("clinging-half-the-clock")
        holdA()
        setCrank(60)
        frames(3)
        shot("aiming-from-the-wall")
        release(pd.kButtonA)
        expect(slime.throws == 2, "and can throw itself off again")
        frames(6)
        setCrank(0)
        holdA()
        frames(1)
        expect(not slime.isAiming, "but there is no aiming in mid-air")
        release(pd.kButtonA)
        expect(slime.throws == 2, "and no throwing either")
        waitUntilStuck(slime)
        frames(2)

        -- B lets go of a wall
        slime.player.x, slime.player.y = slime.maze:cellCenter(1, 1)
        slime.state, slime.velocityX, slime.velocityY = STATES.FLYING, 0, 0
        waitUntilStuck(slime)
        setCrank(300)
        holdA()
        frames(1)
        release(pd.kButtonA)
        waitUntilStuck(slime)
        expect(slime.state == STATES.CLINGING, "it is on the wall again")
        press(pd.kButtonB, 1)
        shot("let-go-with-b")
        expect(slime.state == STATES.FLYING, "B lets go of the wall")
        waitUntilStuck(slime)
        expect(slime.state == STATES.RESTING, "and it drops to the floor")

        -- Let the clock run out on a wall
        slime.player.x, slime.player.y = slime.maze:cellCenter(1, 1)
        slime.state, slime.velocityX, slime.velocityY = STATES.FLYING, 0, 0
        waitUntilStuck(slime)
        setCrank(300)
        holdA()
        frames(1)
        release(pd.kButtonA)
        waitUntilStuck(slime)
        frames(Slime.STICK_FRAMES + 5)
        shot("sliding")
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
            frames(2)
            shot("collected-" .. item.shape)
            expect(item.state == Puzzle.STATES.PLACED, "touching the " .. item.shape .. " collects it")
            local isLast = index == #slime.puzzle.items
            expect(
                slime.maze:hasPassage(slime.maze.columns, slime.maze.rows, "east") == isLast,
                "the exit opens with the last shape"
            )
        end

        slime.player.x, slime.player.y = slime.maze:cellCenter(slime.maze.columns, slime.maze.rows)
        slime.state, slime.velocityX, slime.velocityY = STATES.FLYING, 0, 0
        waitUntilStuck(slime)
        frames(2)
        shot("beside-the-open-exit")
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
        local game = FirstPersonScene.game
        hold(pd.kButtonUp, 25)
        local item = game.puzzle.items[2]
        standFacing(item)
        frames(2)
        press(pd.kButtonA, 2)
        expect(game.puzzle.carried == item, "a shape is in hand")
        turnCrank(40)
        frames(2)
        local x, y, angle, played = game.player.x, game.player.y, game.player.angle, game.frames
        shot("before-leaving")

        SceneManager.switch(TitleScene)
        frames(3)
        shot("title-offers-continue")
        expect(
            TitleScene.rows[1].name == "continue" and TitleScene.selection == 1,
            "the title now offers Continue, first and selected"
        )
        press(pd.kButtonA, 3)
        expect(
            SceneManager.isCurrent(FirstPersonScene) and FirstPersonScene.game ~= game,
            "Continue loads the game from disk"
        )
        local resumed = FirstPersonScene.game
        shot("after-continuing")
        expect(math.abs(resumed.player.x - x) < 0.001 and math.abs(resumed.player.y - y) < 0.001, "in the same place")
        expect(math.abs(resumed.player.angle - angle) < 0.001, "looking the same way")
        expect(resumed.puzzle.carried and resumed.puzzle.carried.shape == item.shape, "holding the same shape")
        expect(resumed.frames >= played and resumed.frames < played + 10, "with the clock where it was")
        expect(resumed.visitedCount == game.visitedCount, "and the same map uncovered")
        expect(FirstPersonScene.submode == FirstPersonScene.SUBMODES.EXPLORE, "as the same kind of game")

        FirstPersonScene.restart()
        frames(2)
        expect(not SaveGame.exists(), "starting a new maze throws the old save away")
        SceneManager.switch(TitleScene)
        frames(3)
        expect(TitleScene.rows[1].name == "continue", "and leaving that one saves it in turn")
    end

    -- Not a test: draws the launcher card, its highlighted animation, and the list icon from the
    -- game's own renderer, as PNGs for `just launcher` to copy into source/launcher
    scenarios.launcher_art = function()
        local CARD_WIDTH <const>, CARD_HEIGHT <const> = 350, 155
        local ICON_SIZE <const> = 32
        local FRAMES <const> = 4
        frames(2)

        -- A maze of its own, the same every time, viewed down its longest straight corridor
        local game = Game.new({ columns = 8, rows = 6, hasPuzzle = false, random = SeededRandom.new(1995) })
        local best = { length = 0 }
        for row = 1, game.maze.rows do
            for column = 1, game.maze.columns do
                for _, direction in ipairs(Maze.DIRECTIONS) do
                    local offset, length = Maze.OFFSETS[direction], 0
                    local atColumn, atRow = column, row
                    while game.maze:hasPassage(atColumn, atRow, direction) and length < 8 do
                        atColumn, atRow, length = atColumn + offset[1], atRow + offset[2], length + 1
                    end
                    if length > best.length then
                        best = { length = length, column = column, row = row, direction = direction }
                    end
                end
            end
        end
        local ANGLES <const> = { east = 0, south = 90, west = 180, north = 270 }
        local startX, startY = game.maze:cellCenter(best.column, best.row)
        local offset = Maze.OFFSETS[best.direction]
        game.player.angle = ANGLES[best.direction]
        -- Nothing in the corridor but the maze itself
        game.flippers.all, game.landmarks.marks = {}, {}

        local titleWidth, titleHeight = gfx.getTextSize("MAZE")
        local title = gfx.image.new(titleWidth, titleHeight)
        gfx.pushContext(title)
        gfx.drawText("MAZE", 0, 0)
        gfx.popContext()

        local function drawCard(step)
            -- Each frame is a quarter of a stride further down the corridor, so the four loop smoothly
            local walked = (step - 1) * 2 / FRAMES
            game.player.x, game.player.y = startX + offset[1] * walked, startY + offset[2] * walked
            local scene = gfx.image.new(400, 240)
            gfx.pushContext(scene)
            MazeView.draw(game, 0)
            gfx.popContext()

            local card = gfx.image.new(CARD_WIDTH, CARD_HEIGHT, gfx.kColorBlack)
            gfx.pushContext(card)
            scene:draw((CARD_WIDTH - 400) / 2, (CARD_HEIGHT - 240) / 2)
            local plateWidth, plateHeight = titleWidth * 3 + 24, titleHeight * 3 + 8
            local plateLeft, plateTop = 14, (CARD_HEIGHT - plateHeight) / 2
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRoundRect(plateLeft, plateTop, plateWidth, plateHeight, 6)
            gfx.setColor(gfx.kColorBlack)
            gfx.setLineWidth(2)
            gfx.drawRoundRect(plateLeft, plateTop, plateWidth, plateHeight, 6)
            gfx.drawRect(1, 1, CARD_WIDTH - 2, CARD_HEIGHT - 2)
            gfx.setLineWidth(1)
            title:drawScaled(plateLeft + 12, plateTop + 5, 3)
            gfx.popContext()
            return card
        end

        pd.simulator.writeToFile(drawCard(1), OUT .. "/card.png")
        for step = 1, FRAMES do
            pd.simulator.writeToFile(drawCard(step), OUT .. "/card-highlighted-" .. step .. ".png")
        end

        -- The icon: a little maze, walls and all, with a dot in it
        local CELLS <const>, CELL <const> = 5, 6
        local maze = Maze.generate(CELLS, CELLS, SeededRandom.new(7))
        local icon = gfx.image.new(ICON_SIZE, ICON_SIZE, gfx.kColorWhite)
        gfx.pushContext(icon)
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        local margin = (ICON_SIZE - CELLS * CELL) / 2
        for row = 1, CELLS do
            for column = 1, CELLS do
                local left, top = margin + (column - 1) * CELL, margin + (row - 1) * CELL
                if not maze:hasPassage(column, row, "north") then gfx.drawLine(left, top, left + CELL, top) end
                if not maze:hasPassage(column, row, "west") then gfx.drawLine(left, top, left, top + CELL) end
                if not maze:hasPassage(column, row, "south") then
                    gfx.drawLine(left, top + CELL, left + CELL, top + CELL)
                end
                if not maze:hasPassage(column, row, "east") then
                    gfx.drawLine(left + CELL, top, left + CELL, top + CELL)
                end
            end
        end
        gfx.setLineWidth(1)
        gfx.fillCircleAtPoint(margin + CELL / 2, margin + CELL / 2, 2)
        gfx.popContext()
        pd.simulator.writeToFile(icon, OUT .. "/icon.png")
        frames(1)
    end

    -- Draw a map in the editor, play it, find it saved, edit it again, and throw it away
    scenarios.editor = function()
        local function holdDown(button)
            justPressed[button], held[button] = true, true
            coroutine.yield()
            justPressed[button] = nil
        end
        local function pickTool(name)
            for _ = 1, #MapEditor.TOOLS do
                if EditorScene.editor:tool().name == name then return end
                turnCrank(40)
                frames(1)
            end
            error("the crank never reached the " .. name .. " tool")
        end

        frames(5)
        titleRow("myMazes")
        shot("title-my-mazes")
        press(pd.kButtonA, 3)
        expect(SceneManager.isCurrent(MyMazesScene), "the My mazes row opens the list of maps")
        shot("my-mazes-all-empty")
        press(pd.kButtonA, 3)
        expect(
            SceneManager.isCurrent(EditorScene) and EditorScene.slot == "A",
            "A on an empty slot starts a new map in it"
        )
        local design = EditorScene.editor.design
        expect(design.columns == 8 and design.rows == 6, "at the size chosen on the title screen")
        shot("editor-blank")
        expect(EditorScene.editor:status() == "There is no exit", "a blank map says what it lacks")

        -- Carve along the top and down the right-hand side by moving with A held
        holdDown(pd.kButtonA)
        for _ = 1, 7 do
            press(pd.kButtonRight, 1)
        end
        for _ = 1, 5 do
            press(pd.kButtonDown, 1)
        end
        release(pd.kButtonA)
        shot("editor-carved")
        expect(
            design:hasPassage(1, 1, "east") and design:hasPassage(8, 5, "south"),
            "moving with A held carves passages"
        )
        expect(EditorScene.editor.cursorX == 16 and EditorScene.editor.cursorY == 12, "and carries the cursor along")

        -- Wall one back up by pushing at it with B held
        holdDown(pd.kButtonB)
        press(pd.kButtonUp, 1)
        release(pd.kButtonB)
        expect(not design:hasPassage(8, 5, "south"), "pushing with B held builds the wall back")
        holdDown(pd.kButtonA)
        press(pd.kButtonUp, 1)
        press(pd.kButtonDown, 1)
        release(pd.kButtonA)
        expect(design:hasPassage(8, 5, "south"), "and A carves it again")

        -- The crank picks the tool
        pickTool("exit")
        shot("editor-exit-tool")
        press(pd.kButtonA, 1)
        expect(design.exit == nil, "the exit cannot go in the middle of the map")
        shot("editor-exit-refused")
        press(pd.kButtonRight, 1)
        press(pd.kButtonA, 1)
        expect(
            design.exit and design.exit.gridX == 17 and design.exit.gridY == 12,
            "but goes in the outer wall beside an open block"
        )
        expect(EditorScene.editor:status() == "Ready to play", "and then the map is ready")

        -- The dial passes the cells tool on its way round, which puts the cursor back on a cell
        pickTool("blocks")
        expect(EditorScene.editor.cursorX == 16 and EditorScene.editor.cursorY == 12, "the cursor is on the last cell")
        press(pd.kButtonLeft, 1)
        expect(
            EditorScene.editor.cursorX == 15 and not design:isOpen(15, 12),
            "one step left is the wall between two cells"
        )
        press(pd.kButtonA, 1)
        expect(design:isOpen(15, 12), "the blocks tool opens a single block")
        pickTool("circle")
        press(pd.kButtonA, 1)
        expect(design.items.circle and design.items.circle.gridX == 15, "a shape can be stood on it")
        pickTool("triangle pedestal")
        press(pd.kButtonUp, 1)
        press(pd.kButtonRight, 1)
        press(pd.kButtonA, 1)
        shot("editor-finished")
        expect(design.pedestals.triangle ~= nil, "and a pedestal elsewhere")

        -- Play it, from the system menu's Play item
        EditorScene.play()
        frames(3)
        expect(
            SceneManager.isCurrent(FirstPersonScene) and FirstPersonScene.game.isHandMade,
            "Play starts the map in the 3D maze"
        )
        expect(MapSlots.exists("A"), "having saved it on the way out of the editor")
        local game = FirstPersonScene.game
        expect(
            game.puzzle.items[1].gridX == 15 and game.puzzle.items[1].gridY == 12,
            "with the circle where it was put"
        )
        expect(game.maze:blockValue(17, 12) == Maze.BLOCKS.DOOR, "and the gate where the exit was put")
        shot("playing-my-maze")
        hold(pd.kButtonUp, 30)
        shot("playing-my-maze-walked")
        docked = true
        frames(DockTimer.DELAY_FRAMES + 10)
        docked = false
        expect(not game:isAutopilotOn(), "a hand-made maze has no autopilot, even with the crank docked")

        SceneManager.switch(TitleScene)
        expect(SaveGame.exists(), "ordinary custom scene exit saves the unfinished run")
        expect(TitleScene.rows[1].name == "continue", "the title offers the saved custom run")
        TitleScene.continueSavedGame()
        expect(FirstPersonScene.design == nil, "resuming a custom run has no original design")
        FirstPersonScene.restart()
        expect(SceneManager.isCurrent(MyMazesScene), "restarting without a design returns to My mazes")
        expect(not SaveGame.exists(), "restart keeps the discarded custom save deleted after scene exit")
        SceneManager.switch(TitleScene)
        expect(TitleScene.rows[1].name == "explore", "the discarded custom run is not offered as Continue")

        -- It is in the list now, with a picture
        SceneManager.switch(MyMazesScene)
        frames(3)
        shot("my-mazes-with-a-map")
        expect(MyMazesScene.selectedDesign() ~= nil, "the list shows the saved map")
        press(pd.kButtonRight, 3)
        expect(SceneManager.isCurrent(EditorScene), "right opens it in the editor")
        expect(EditorScene.editor.design:hasPassage(1, 1, "east"), "as it was left")
        expect(EditorScene.editor.design.items.circle.gridX == 15, "with everything that was placed")
        EditorScene.randomMaze()
        frames(2)
        shot("editor-random-maze")
        expect(EditorScene.editor:status() == "Ready to play", "Random maze gives a finished maze to alter")

        -- Throw it away: left asks, left again does it
        SceneManager.switch(MyMazesScene)
        frames(3)
        press(pd.kButtonLeft, 2)
        shot("my-mazes-delete-asked")
        expect(MapSlots.exists("A"), "one press of left only asks")
        press(pd.kButtonLeft, 2)
        expect(not MapSlots.exists("A"), "the second deletes the map")
        press(pd.kButtonB, 3)
        expect(SceneManager.isCurrent(TitleScene), "B goes back to the title screen")
    end

    -- Let the screensaver wander, then take over
    scenarios.screensaver = function()
        frames(5)
        -- A small maze, so the wall-follower reaches the exit well inside run.sh's time limit
        TitleScene.sizeIndex = 1
        titleRow("screensaver")
        press(pd.kButtonA, 3)
        expect(FirstPersonScene.game:isAutopilotOn(), "the screensaver starts on autopilot")
        expect(
            FirstPersonScene.game:isRevealed(FirstPersonScene.game.maze.columns, FirstPersonScene.game.maze.rows),
            "the screensaver shows the whole map"
        )
        for index = 1, 8 do
            frames(40)
            shot("wandering-" .. index)
        end
        local game = FirstPersonScene.game
        for _ = 1, 6000 do
            if FirstPersonScene.game ~= game then break end
            frames(1)
        end
        expect(FirstPersonScene.game ~= game, "the screensaver finds the exit and starts a new maze")
        expect(
            FirstPersonScene.game:isAutopilotOn(),
            string.format(
                "and keeps wandering (mode %s, old maze escaped %s after %d frames, in play scene %s)",
                FirstPersonScene.submode,
                tostring(game.hasEscaped),
                game.frames,
                tostring(SceneManager.isCurrent(FirstPersonScene))
            )
        )
        shot("next-maze")

        press(pd.kButtonB, 2)
        shot("taken-over")
        expect(not FirstPersonScene.game:isAutopilotOn(), "any button takes over from the autopilot")
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
