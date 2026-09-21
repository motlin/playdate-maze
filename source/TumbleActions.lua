TumbleActions = {}
TumbleActions.__index = TumbleActions

function TumbleActions.new(controls) return setmetatable({ controls = controls }, TumbleActions) end

-- Returns fresh actions unless the caller supplies the table to overwrite.
function TumbleActions:read(actions)
    actions = actions or {}
    local input = self.controls
    actions.turn = input.crankChange
    actions.move = input:axis(playdate.kButtonLeft, playdate.kButtonRight)
    actions.jump = input:isPressed(playdate.kButtonA)
        or input:isPressed(playdate.kButtonB)
        or input:isPressed(playdate.kButtonUp)
    return actions
end
