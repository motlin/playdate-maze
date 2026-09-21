PlayInput = {}
PlayInput.__index = PlayInput

function PlayInput.new()
    return setmetatable(
        { current = 0, pressed = 0, released = 0, crankChange = 0, crankPosition = 0, isCrankDocked = true },
        PlayInput
    )
end

function PlayInput:read()
    self.current, self.pressed, self.released = playdate.getButtonState()
    self.crankChange = playdate.getCrankChange()
    self.crankPosition = playdate.getCrankPosition()
    self.isCrankDocked = playdate.isCrankDocked()
    return self
end

function PlayInput:isDown(button) return self.current & button ~= 0 end

function PlayInput:isPressed(button) return self.pressed & button ~= 0 end

function PlayInput:isReleased(button) return self.released & button ~= 0 end

function PlayInput:axis(negativeButton, positiveButton)
    return (self:isDown(positiveButton) and 1 or 0) - (self:isDown(negativeButton) and 1 or 0)
end
