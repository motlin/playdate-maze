SlimeActions = {}
SlimeActions.__index = SlimeActions

function SlimeActions.new(controls) return setmetatable({ controls = controls, actions = {} }, SlimeActions) end

function SlimeActions:read()
    local input = self.controls
    local actions = self.actions
    actions.aim = input.crankPosition
    actions.isAimHeld = input:isDown(playdate.kButtonA)
    actions.cancel = input:isPressed(playdate.kButtonB)
    actions.move = input:axis(playdate.kButtonLeft, playdate.kButtonRight)
    return actions
end
