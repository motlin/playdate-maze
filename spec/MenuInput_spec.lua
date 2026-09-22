local function loadMenus()
    local state = { pressed = 0, crank = 0, reads = 0, crankReads = 0 }
    local environment = setmetatable({
        import = function() end,
        playdate = {
            kButtonLeft = 1,
            kButtonRight = 2,
            kButtonUp = 4,
            kButtonDown = 8,
            kButtonB = 16,
            kButtonA = 32,
            getButtonState = function()
                state.reads = state.reads + 1
                return state.pressed, state.pressed, 0
            end,
            getCrankChange = function()
                state.crankReads = state.crankReads + 1
                return state.crank
            end,
            getCrankPosition = function() return 0 end,
            isCrankDocked = function() return true end,
            graphics = {
                getTextSize = function() return 10, 10 end,
                image = { new = function() return {} end },
                pushContext = function() end,
                popContext = function() end,
                drawText = function() end,
            },
        },
        Bob = { new = function() return {} end },
        Game = {
            new = function()
                return { setAutopilot = function() end }
            end,
        },
        SaveGame = { exists = function() return false end },
        FirstPersonScene = {},
        TumbleScene = {},
        SlimeScene = {},
        MyMazesScene = {},
    }, { __index = _G })
    for _, name in ipairs({
        "PlayInput",
        "CrankSteps",
        "Sizes",
        "SceneManager",
        "scenes/TitleScene",
        "scenes/EscapedScene",
    }) do
        assert(loadfile("source/" .. name .. ".lua", "t", environment))()
    end
    environment.SceneManager.switch(environment.TitleScene)
    return environment, state
end

describe("menu input snapshots", function()
    it("accumulates crank steps and clamps navigation at both ends", function()
        local environment, state = loadMenus()
        local scene = environment.TitleScene
        local selections = {}
        for _, degrees in ipairs({ 20, 25, 90, 900, -900 }) do
            state.crank = degrees
            scene.handleInput()
            selections[#selections + 1] = scene.selection
        end
        assert.are.same({ 1, 2, 4, 7, 1 }, selections)
        assert.are.same({ 5, 5 }, { state.reads, state.crankReads })
    end)

    it("gives down precedence over up and crank, resetting partial turns", function()
        local environment, state = loadMenus()
        local scene = environment.TitleScene
        state.crank = 40
        scene.handleInput()
        state.crank, state.pressed = -90, 4 | 8
        scene.handleInput()
        local afterButtons = scene.selection
        state.crank, state.pressed = 5, 0
        scene.handleInput()
        assert.are.same({ 2, 2 }, { afterButtons, scene.selection })
    end)

    it("clears a partial crank turn when reentering the title", function()
        local environment, state = loadMenus()
        state.crank = 40
        environment.TitleScene.handleInput()
        environment.TitleScene.enter()
        state.crank = 5
        environment.TitleScene.handleInput()
        assert.are.equal(1, environment.TitleScene.selection)
    end)

    it("retains size changes from left, right, and confirmation", function()
        local environment, state = loadMenus()
        local scene = environment.TitleScene
        scene.selection = #scene.rows
        local sizes = {}
        for _, pressed in ipairs({ 2, 32, 1 }) do
            state.pressed = pressed
            scene.handleInput()
            sizes[#sizes + 1] = scene.sizeIndex
        end
        assert.are.same({ 3, 1, 3 }, sizes)
    end)

    it("confirms the original row during navigation and stops after switching", function()
        local environment, state = loadMenus()
        state.pressed = 8 | 32
        environment.TitleScene.update()
        assert.are.same({ true, 2, 1, 1 }, {
            environment.SceneManager.isCurrent(environment.FirstPersonScene),
            environment.TitleScene.selection,
            state.reads,
            state.crankReads,
        })
    end)

    it("gives replay precedence over title and stops input after replay", function()
        local environment, state = loadMenus()
        local replays = 0
        environment.EscapedScene.enter(30, function()
            replays = replays + 1
            environment.SceneManager.switch(environment.FirstPersonScene)
        end)
        state.pressed = 32 | 16
        environment.EscapedScene.update()
        assert.are.same({ 1, true, 1, 1 }, {
            replays,
            environment.SceneManager.isCurrent(environment.FirstPersonScene),
            state.reads,
            state.crankReads,
        })
    end)

    it("returns to the title on B without replaying", function()
        local environment, state = loadMenus()
        local replays = 0
        environment.EscapedScene.enter(30, function() replays = replays + 1 end)
        state.pressed = 16
        environment.EscapedScene.update()
        assert.are.same({ 0, true, 1, 1 }, {
            replays,
            environment.SceneManager.isCurrent(environment.TitleScene),
            state.reads,
            state.crankReads,
        })
    end)
end)
