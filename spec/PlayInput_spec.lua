local device = require("spec.support.playdate_stub")
import "PlayInput"
import "WalkingActions"
import "TumbleActions"
import "SlimeActions"

local pd <const> = playdate
local controls

local function frame(current, pressed, released, crankChange, docked)
    device.current, device.pressed, device.released = current, pressed, released
    device.crankChange, device.isCrankDocked = crankChange, docked
    return controls:read()
end

local function walkingFrame(mapper, current, pressed, released, crankChange, docked, suppressItemActions)
    frame(current, pressed, released, crankChange, docked)
    return mapper:read(suppressItemActions)
end

describe("input and actions", function()
    before_each(function() device.reset(); controls = PlayInput.new() end)

    it("keeps one hardware snapshot until the next read", function()
        local input = frame(pd.kButtonLeft | pd.kButtonA, pd.kButtonA, pd.kButtonB, 10, false)
        device.current, device.pressed, device.released, device.crankChange = 0, 0, 0, 0
        assert.are.same({ true, true, true, -1, 10 }, {
            input:isDown(pd.kButtonLeft), input:isPressed(pd.kButtonA), input:isReleased(pd.kButtonB),
            input:axis(pd.kButtonLeft, pd.kButtonRight), input.crankChange,
        })
        input:read()
        assert.are.same({ false, false, false, 0, 0 }, {
            input:isDown(pd.kButtonLeft), input:isPressed(pd.kButtonA), input:isReleased(pd.kButtonB),
            input:axis(pd.kButtonLeft, pd.kButtonRight), input.crankChange,
        })
    end)

    it("maps the same hardware to different game actions", function()
        device.crankPosition = 90
        frame(pd.kButtonRight | pd.kButtonUp | pd.kButtonA, pd.kButtonA, 0, 10, false)
        assert.are.same({
            walking = { forward = 1, turn = 10, crank = 10, reel = 0, strafe = 1, pickUp = true, drop = false },
            tumble = { turn = 10, move = 1, jump = true },
            slime = { aim = 90, isAimHeld = true, cancel = false, move = 1 },
        }, {
            walking = WalkingActions.new(controls):read(false),
            tumble = TumbleActions.new(controls):read(),
            slime = SlimeActions.new(controls):read(),
        })
    end)

    it("turns with docked buttons without turning the gate crank", function()
        assert.are.same({ forward = 0, turn = -5, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = false }, walkingFrame(WalkingActions.new(controls), pd.kButtonLeft, 0, 0, 0, true, false))
    end)

    it("cancels opposing directions and clears actions on the next frame", function()
        local walking = WalkingActions.new(controls)
        walkingFrame(walking, pd.kButtonUp, pd.kButtonA, 0, 10, false, false)
        assert.are.same({ forward = 0, turn = 0, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = false }, walkingFrame(walking, pd.kButtonLeft | pd.kButtonRight | pd.kButtonUp | pd.kButtonDown, 0, 0, 0, false, false))
    end)

    it("suppresses takeover items through release but allows the next tap", function()
        local walking = WalkingActions.new(controls)
        assert.are.same({ forward = 0, turn = 0, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = false }, walkingFrame(walking, pd.kButtonB, pd.kButtonA | pd.kButtonB, 0, -10, false, true))
        assert.are.same({ forward = 0, turn = 0, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = false }, walkingFrame(walking, pd.kButtonB, 0, 0, -10, false, false))
        assert.are.same({ forward = 0, turn = 0, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = false }, walkingFrame(walking, 0, 0, pd.kButtonB, 0, false, false))
        walkingFrame(walking, pd.kButtonB, pd.kButtonB, 0, 0, false, false)
        assert.are.same({ forward = 0, turn = 0, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = true }, walkingFrame(walking, 0, 0, pd.kButtonB, 0, false, false))
    end)

    it("keeps button history separate for different walking readers", function()
        local first, second = WalkingActions.new(controls), WalkingActions.new(controls)
        walkingFrame(first, pd.kButtonB, pd.kButtonB, 0, 0, false, true)
        walkingFrame(second, pd.kButtonB, pd.kButtonB, 0, 0, false, false)
        assert.are.same({ forward = 0, turn = 0, crank = 0, reel = 0, strafe = 0, pickUp = false, drop = true }, walkingFrame(second, 0, 0, pd.kButtonB, 0, false, false))
    end)
end)
