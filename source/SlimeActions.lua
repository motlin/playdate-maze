SlimeActions = {}
SlimeActions.__index = SlimeActions

local pd <const> = playdate

function SlimeActions.new(controls)
    return setmetatable({ controls = controls, actions = {} }, SlimeActions)
end

function SlimeActions:read()
    local input = self.controls
    local actions = self.actions
    actions.aim = input.crankPosition
    actions.isAimHeld = input:isDown(pd.kButtonA)
    actions.cancel = input:isPressed(pd.kButtonB)
    actions.move = input:axis(pd.kButtonLeft, pd.kButtonRight)
    return actions
end
