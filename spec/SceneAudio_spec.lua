local function loadScene(name)
    local log = {}
    local function constructor() return {} end
    local environment = setmetatable({
        import = function() end,
        PlayInput = { new = constructor },
        WalkingActions = { new = constructor },
        SlimeActions = { new = constructor },
        TumbleActions = { new = constructor },
        DockTimer = { new = constructor },
        Bob = { new = constructor },
        Sizes = { DEFAULT = 1 },
        Music = { stop = function() log[#log + 1] = "music off" end },
        Sounds = { stopHum = function() log[#log + 1] = "hum off" end },
        SaveGame = { write = function() log[#log + 1] = "save" end },
    }, { __index = _G })
    assert(loadfile("source/SceneManager.lua", "t", environment))()
    assert(loadfile("source/scenes/" .. name .. ".lua", "t", environment))()
    local scene = environment[name]
    scene.enter = nil
    scene.game = { puzzle = {} }
    environment.SceneManager.switch(scene)
    return scene, environment.SceneManager, log
end

describe("scene audio lifecycle", function()
    it("saves and stops first-person held audio on pause and when leaving", function()
        local scene, manager, log = loadScene("FirstPersonScene")
        manager.pause()
        assert.are.same({ "save", "hum off", "music off" }, log)
        assert.is_true(manager.isCurrent(scene))

        manager.switch({})
        manager.pause()
        assert.are.same({ "save", "hum off", "music off", "save", "hum off", "music off" }, log)
    end)

    for _, mode in ipairs({ "SlimeScene", "TumbleScene" }) do
        it("stops " .. mode .. " music on pause and when leaving", function()
            local scene, manager, log = loadScene(mode)
            manager.pause()
            assert.are.same({ "music off" }, log)
            assert.is_true(manager.isCurrent(scene))

            manager.switch({})
            manager.pause()
            assert.are.same({ "music off", "music off" }, log)
        end)
    end
end)
