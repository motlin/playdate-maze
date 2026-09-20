-- Small movements that make the 3D view feel walked through: the head bobbing with each stride,
-- and the shapes hovering gently.

Bob = {}
Bob.__index = Bob

-- The most the view rises or falls, in pixels, and the blocks walked for one full bob
Bob.HEAD_PIXELS = 3
Bob.STRIDE_BLOCKS = 1.4
-- The most a hovering shape drifts, in blocks
Bob.HOVER_BLOCKS = 0.03

-- How quickly the bob builds when walking and dies away when standing: the share of the
-- difference made up each frame
local EASE_IN <const> = 0.25
local EASE_OUT <const> = 0.2
local HOVER_SPEED <const> = 0.09
-- Far enough apart that three shapes are never in step
local HOVER_PHASE_APART <const> = 2.1

function Bob.new()
    return setmetatable({ phase = 0, strength = 0 }, Bob)
end

-- Call every frame with how far the player walked in it
function Bob:walk(distance)
    if distance > 0 then
        self.phase = self.phase + distance / Bob.STRIDE_BLOCKS * 2 * math.pi
        self.strength = self.strength + (1 - self.strength) * EASE_IN
    else
        self.strength = self.strength * (1 - EASE_OUT)
    end
end

-- Pixels to shift the horizon by; positive is down
function Bob:headOffset()
    return math.sin(self.phase) * Bob.HEAD_PIXELS * self.strength
end

-- Blocks to shift hovering shape number `index` by on this frame; positive is down
function Bob.hoverOffset(frame, index)
    return math.sin(frame * HOVER_SPEED + index * HOVER_PHASE_APART) * Bob.HOVER_BLOCKS
end
