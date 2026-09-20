-- One button with two jobs: tap it, or hold it and turn the crank backwards to reel something in.
-- Letting go counts as a tap only if nothing was reeled while it was held.

TapOrReel = {}
TapOrReel.__index = TapOrReel

-- A resting crank trembles by a degree or so, which must not turn a tap into a reel. Backwards
-- travel is added up while the button is held, and forwards travel taken off again, so trembling
-- never gets anywhere while even the slowest steady cranking soon does.
local TREMBLE <const> = 3

function TapOrReel.new()
    return setmetatable({ isDown = false, hasReeled = false, isIgnored = false, pending = 0 }, TapOrReel)
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
        self.isDown, self.hasReeled, self.isIgnored, self.pending = true, false, false, 0
    end
    if isJustReleased then
        local isTap = self.isDown and not self.hasReeled and not self.isIgnored
        self.isDown = false
        return 0, isTap
    end
    if not (isPressed and self.isDown) or self.isIgnored then return 0, false end

    self.pending = math.max(0, self.pending - crankChange)
    if not self.hasReeled and self.pending <= TREMBLE then return 0, false end
    -- Nothing cranked while making sure is lost: it all comes out now
    local degrees = self.pending
    self.hasReeled, self.pending = true, 0
    return degrees, false
end
