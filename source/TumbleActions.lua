TumbleActions = {}
TumbleActions.__index = TumbleActions

function TumbleActions.new(controls) return setmetatable({ controls = controls, actions = {} }, TumbleActions) end

function TumbleActions:read()
    local input = self.controls
    local actions = self.actions
    actions.turn = input.crankChange
    actions.move = input:axis(playdate.kButtonLeft, playdate.kButtonRight)
    actions.jump = input:isPressed(playdate.kButtonA)
        or input:isPressed(playdate.kButtonB)
        or input:isPressed(playdate.kButtonUp)
    return actions
end
