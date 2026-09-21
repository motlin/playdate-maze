PlayInput = {}
PlayInput.__index = PlayInput

local pd <const> = playdate

function PlayInput.new()
    return setmetatable({ current = 0, pressed = 0, released = 0, crankChange = 0, crankPosition = 0, isCrankDocked = true }, PlayInput)
end

function PlayInput:read()
    self.current, self.pressed, self.released = pd.getButtonState()
    self.crankChange = pd.getCrankChange()
    self.crankPosition = pd.getCrankPosition()
    self.isCrankDocked = pd.isCrankDocked()
    return self
end

function PlayInput:isDown(button)
    return self.current & button ~= 0
end

function PlayInput:isPressed(button)
    return self.pressed & button ~= 0
end

function PlayInput:isReleased(button)
    return self.released & button ~= 0
end

function PlayInput:axis(negativeButton, positiveButton)
    return (self:isDown(positiveButton) and 1 or 0) - (self:isDown(negativeButton) and 1 or 0)
end
