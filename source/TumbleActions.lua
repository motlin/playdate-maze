TumbleActions = {}
TumbleActions.__index = TumbleActions

local pd <const> = playdate

function TumbleActions.new(controls)
    return setmetatable({ controls = controls, actions = {} }, TumbleActions)
end

function TumbleActions:read()
    local input = self.controls
    local actions = self.actions
    actions.turn = input.crankChange
    actions.move = input:axis(pd.kButtonLeft, pd.kButtonRight)
    actions.jump = input:isPressed(pd.kButtonA) or input:isPressed(pd.kButtonB) or input:isPressed(pd.kButtonUp)
    return actions
end
