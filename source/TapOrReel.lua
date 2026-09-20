-- One button with two jobs: tap it, or hold it and turn the crank backwards to reel something in.
-- Letting go counts as a tap only if nothing was reeled while it was held.

TapOrReel = {}
TapOrReel.__index = TapOrReel

-- A resting crank trembles by a degree or so, which must not turn a tap into a reel
local TREMBLE <const> = 2

function TapOrReel.new()
    return setmetatable({ isDown = false, hasReeled = false, isIgnored = false }, TapOrReel)
end

function TapOrReel:isHeld()
    return self.isDown
end

-- For a press that has already done something else, such as taking over from the autopilot
function TapOrReel:ignoreThisPress()
    self.isIgnored = true
end

-- Call every frame. Returns the degrees to reel in this frame, and whether the button was tapped.
function TapOrReel:update(isJustPressed, isPressed, isJustReleased, crankChange)
    if isJustPressed then
        self.isDown, self.hasReeled, self.isIgnored = true, false, false
    end
    if isJustReleased then
        local isTap = self.isDown and not self.hasReeled and not self.isIgnored
        self.isDown = false
        return 0, isTap
    end
    if isPressed and self.isDown and not self.isIgnored and crankChange < -TREMBLE then
        self.hasReeled = true
        return -crankChange, false
    end
    return 0, false
end
