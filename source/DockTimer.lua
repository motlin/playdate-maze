-- "Dock to dream": put the crank away, leave the game alone for a few seconds, and the autopilot
-- takes over; pull the crank out and it hands back. Playing with the crank docked is fine, since
-- any press starts the wait again. update() says what to do, if anything, each frame.

DockTimer = {}
DockTimer.__index = DockTimer

DockTimer.ACTIONS = { HAND_OVER = "handOver", TAKE_BACK = "takeBack" }
DockTimer.DELAY_FRAMES = 90

function DockTimer.new()
    return setmetatable({
        -- Not until the player has touched something: a game often starts with the crank docked
        isArmed = false,
        wasDocked = false,
        idleFrames = 0,
        hasHandedOver = false,
    }, DockTimer)
end

function DockTimer:update(isDocked, isAnyInput)
    local hasJustUndocked = self.wasDocked and not isDocked
    self.wasDocked = isDocked
    if isAnyInput or hasJustUndocked then self.isArmed = true end

    if not isDocked or isAnyInput then
        local wasHandedOver = self.hasHandedOver
        self.idleFrames, self.hasHandedOver = 0, false
        if hasJustUndocked and wasHandedOver then return DockTimer.ACTIONS.TAKE_BACK end
        return nil
    end

    if not self.isArmed or self.hasHandedOver then return nil end
    self.idleFrames = self.idleFrames + 1
    if self.idleFrames < DockTimer.DELAY_FRAMES then return nil end
    self.hasHandedOver = true
    return DockTimer.ACTIONS.HAND_OVER
end
