require("spec.support.playdate_stub")
import "DockTimer"

local HAND_OVER <const> = DockTimer.ACTIONS.HAND_OVER
local TAKE_BACK <const> = DockTimer.ACTIONS.TAKE_BACK

-- Runs the same frame a number of times and returns every action that came out
local function run(timer, frames, isDocked, isAnyInput)
    local actions = {}
    for _ = 1, frames do
        actions[#actions + 1] = timer:update(isDocked, isAnyInput)
    end
    return actions
end

-- A timer whose player has already shown they are there, by pressing something
local function armedTimer()
    local timer = DockTimer.new()
    timer:update(true, true)
    return timer
end

describe("DockTimer", function()
    it("hands over to the autopilot once the crank has been docked and nothing touched for three seconds", function()
        local timer = armedTimer()
        assert.are.same({}, run(timer, DockTimer.DELAY_FRAMES - 1, true, false))
        assert.are.equal(HAND_OVER, timer:update(true, false))
    end)

    it("hands over only once", function()
        local timer = armedTimer()
        run(timer, DockTimer.DELAY_FRAMES, true, false)
        assert.are.same({}, run(timer, 500, true, false))
    end)

    it("starts counting again whenever something is pressed, so docked play is never interrupted", function()
        local timer = armedTimer()
        run(timer, DockTimer.DELAY_FRAMES - 1, true, false)
        timer:update(true, true)
        assert.are.same({}, run(timer, DockTimer.DELAY_FRAMES - 1, true, false))
        assert.are.equal(HAND_OVER, timer:update(true, false))
    end)

    it("never hands over while the crank is out", function()
        local timer = armedTimer()
        assert.are.same({}, run(timer, 500, false, false))
    end)

    it("takes control back the moment the crank is pulled out", function()
        local timer = armedTimer()
        run(timer, DockTimer.DELAY_FRAMES, true, false)
        assert.are.equal(TAKE_BACK, timer:update(false, false))
        assert.are.same({}, run(timer, 10, false, false))
    end)

    it("hands over again after the crank is put away again", function()
        local timer = armedTimer()
        run(timer, DockTimer.DELAY_FRAMES, true, false)
        timer:update(false, false)
        assert.are.same({}, run(timer, DockTimer.DELAY_FRAMES - 1, true, false))
        assert.are.equal(HAND_OVER, timer:update(true, false))
    end)

    it("does not hand over at the start of a game before the player has touched anything", function()
        local timer = DockTimer.new()
        assert.are.same({}, run(timer, 500, true, false))
    end)

    it("counts pulling the crank out as the player having touched something", function()
        local timer = DockTimer.new()
        timer:update(true, false)
        timer:update(false, false)
        run(timer, DockTimer.DELAY_FRAMES - 1, true, false)
        assert.are.equal(HAND_OVER, timer:update(true, false))
    end)

    it("does not say take back when the crank comes out and the autopilot was never handed to", function()
        local timer = armedTimer()
        run(timer, 10, true, false)
        assert.is_nil(timer:update(false, false))
    end)
end)
