SlimeActions = {}
SlimeActions.__index = SlimeActions

function SlimeActions.new(controls) return setmetatable({ controls = controls }, SlimeActions) end

-- Returns fresh actions unless the caller supplies the table to overwrite.
function SlimeActions:read(actions)
    actions = actions or {}
    local input = self.controls
    actions.aim = input.crankPosition
    actions.isAimHeld = input:isDown(playdate.kButtonA)
    actions.cancel = input:isPressed(playdate.kButtonB)
    actions.move = input:axis(playdate.kButtonLeft, playdate.kButtonRight)
    return actions
end
