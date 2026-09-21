import "TapOrReel"

WalkingActions = {}
WalkingActions.__index = WalkingActions

local DPAD_TURN_SPEED <const> = 5

function WalkingActions.new(controls)
    return setmetatable({ controls = controls, actions = {}, bButton = TapOrReel.new() }, WalkingActions)
end

function WalkingActions:read(suppressItemActions)
    local input = self.controls
    local actions, button = self.actions, self.bButton
    local sideways = input:axis(playdate.kButtonLeft, playdate.kButtonRight)
    local reel, isBTapped = button:update(
        input:isPressed(playdate.kButtonB), input:isDown(playdate.kButtonB), input:isReleased(playdate.kButtonB), input.crankChange
    )
    actions.forward = input:axis(playdate.kButtonDown, playdate.kButtonUp)
    actions.turn = button:isHeld() and 0 or input.crankChange
    actions.crank = actions.turn
    actions.reel = reel
    actions.strafe = 0
    if input.isCrankDocked then
        actions.turn = sideways * DPAD_TURN_SPEED
    else
        actions.strafe = sideways
    end
    actions.pickUp = input:isPressed(playdate.kButtonA)
    actions.drop = isBTapped
    if suppressItemActions then
        button:ignoreThisPress()
        actions.pickUp, actions.drop, actions.reel = false, false, 0
    end
    return actions
end
