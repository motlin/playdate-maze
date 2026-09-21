-- Turns crank movement into whole steps, for moving a highlight through a menu. Travel adds up
-- until it amounts to a step and what is left over is kept, so that slow cranking works as well as
-- fast, and a trembling crank gets nowhere. (After mnemonica-playdate's CrankSelector.)

CrankSteps = {}
CrankSteps.__index = CrankSteps

-- Absorbs floating point drift, so that a full turn one way and back lands where it started
local EPSILON <const> = 1e-9

function CrankSteps.new(degreesPerStep)
    return setmetatable({ degreesPerStep = degreesPerStep, pendingDegrees = 0 }, CrankSteps)
end

-- Feed one frame of crank change, in degrees. Returns how many steps to move, signed.
function CrankSteps:turn(degrees)
    self.pendingDegrees = self.pendingDegrees + degrees
    local magnitude = math.floor((math.abs(self.pendingDegrees) + EPSILON) / self.degreesPerStep)
    if magnitude == 0 then return 0 end
    local steps = self.pendingDegrees > 0 and magnitude or -magnitude
    self.pendingDegrees = self.pendingDegrees - steps * self.degreesPerStep
    return steps
end

function CrankSteps:reset() self.pendingDegrees = 0 end
