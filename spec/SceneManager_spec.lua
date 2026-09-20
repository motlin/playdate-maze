require("spec.support.playdate_stub")
import "SceneManager"

describe("SceneManager", function()
    local function recordingScene(name, log)
        return {
            enter = function(...) log[#log + 1] = { name, "enter", ... } end,
            update = function() log[#log + 1] = { name, "update" } end,
            exit = function() log[#log + 1] = { name, "exit" } end,
        }
    end

    it("enters a scene with the arguments given to switch", function()
        local log = {}
        SceneManager.switch(recordingScene("quiz", log), "mode", 7)
        assert.are.same({ "quiz", "enter", "mode", 7 }, log[#log])
    end)

    it("updates only the current scene", function()
        local log = {}
        SceneManager.switch(recordingScene("menu", log))
        SceneManager.switch(recordingScene("quiz", log))
        SceneManager.update()
        assert.are.same({ "quiz", "update" }, log[#log])
        assert.are.equal(4, #log)
    end)

    it("delegates update to the current scene", function()
        local log = {}
        SceneManager.switch(recordingScene("menu", log))
        SceneManager.update()
        assert.are.same({ "menu", "update" }, log[#log])
    end)

    it("exits the previous scene before entering the next", function()
        local log = {}
        SceneManager.switch(recordingScene("menu", log))
        SceneManager.switch(recordingScene("quiz", log))
        assert.are.same({ { "menu", "enter" }, { "menu", "exit" }, { "quiz", "enter" } }, log)
    end)

    it("allows scenes without enter or exit", function()
        local updates = 0
        SceneManager.switch({ update = function() updates = updates + 1 end })
        SceneManager.switch({ update = function() updates = updates + 10 end })
        SceneManager.update()
        assert.are.equal(10, updates)
    end)

    it("reports which scene is current", function()
        local menu, quiz = recordingScene("menu", {}), recordingScene("quiz", {})
        SceneManager.switch(menu)
        SceneManager.switch(quiz)
        assert.is_true(SceneManager.isCurrent(quiz))
        assert.is_false(SceneManager.isCurrent(menu))
    end)

    it("tells its listener about the new scene after entering it", function()
        local log = {}
        local quiz = recordingScene("quiz", log)
        SceneManager.onSwitch = function(scene) log[#log + 1] = { "listener", scene == quiz } end

        SceneManager.switch(quiz)

        assert.are.same({ { "quiz", "enter" }, { "listener", true } }, log)
        SceneManager.onSwitch = nil
    end)
end)
