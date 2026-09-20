-- The maze as a side-on throwing game. You are a slime: hold A and the crank handle points the
-- way you will throw yourself, along the arc shown; let go to fly, always at full power. You stick
-- to whatever you hit. A floor is safe, but a wall or ceiling only holds you for a couple of
-- seconds, and the clock runs while you aim. Then you slide down the wall, or drop from the
-- ceiling. One more throw is allowed in mid-air, the D-pad crawls along floors, and B calls off
-- an aim. Touch all three shapes to open the exit.
--
-- The maze stays upright, with corridors wide enough to throw in. Aim angles are the crank's:
-- 0 points up the screen and they grow clockwise. Speeds are in blocks a frame.

import "Maze"
import "Player"
import "Puzzle"
import "Run"

Slime = setmetatable({}, { __index = Run })
Slime.__index = Slime

Slime.STATES = { RESTING = "resting", CLINGING = "clinging", SLIDING = "sliding", FLYING = "flying" }
Slime.CORRIDOR_WIDTH = 3
Slime.RADIUS = Player.RADIUS
Slime.GRAVITY = 0.012
-- Enough to rise four blocks
Slime.THROW_SPEED = math.sqrt(2 * Slime.GRAVITY * 4)
-- Less than the body's width, so one frame's move can never step over a wall
Slime.MAX_SPEED = 0.35
Slime.STICK_FRAMES = 60
Slime.SLIDE_SPEED = 0.03
Slime.CRAWL_SPEED = 0.04

local RESTING <const> = Slime.STATES.RESTING
local CLINGING <const> = Slime.STATES.CLINGING
local SLIDING <const> = Slime.STATES.SLIDING
local FLYING <const> = Slime.STATES.FLYING
local GRAVITY <const> = Slime.GRAVITY
local MAX_SPEED <const> = Slime.MAX_SPEED
-- How far beyond the body to feel for the floor or wall it is on
local PROBE <const> = 0.05
-- A flight shorter than this that ends on the surface it left was a throw at that surface, which
-- must not win a fresh clock
local SHORTEST_REAL_FLIGHT <const> = 6
-- The arc is worked out this many frames ahead at most, with a point kept every few frames
local ARC_FRAMES <const> = 240
local ARC_POINT_EVERY <const> = 3

-- A Slime in a maze and puzzle made elsewhere, dropped into the first cell
function Slime.inMaze(maze, puzzle)
    local startX, startY = maze:cellCenter(1, 1)
    local slime = setmetatable(Run.new(maze, Player.new(startX, startY, 0)), Slime)
    slime.puzzle = puzzle
    slime.state = FLYING
    -- What it is stuck to: "floor", "ceiling", "left", or "right"
    slime.surface = nil
    slime.stickFrames = 0
    slime.flightFrames = 0
    slime.velocityX, slime.velocityY = 0, 0
    slime.hasAirThrow = true
    slime.aimAngle = 0
    slime.isAiming = false
    slime.isAimCancelled = false
    slime.throws = 0
    slime.scout = Player.new(startX, startY, 0)
    slime.arcPoints = {}
    slime.arcResult = { points = slime.arcPoints, landingX = startX, landingY = startY }
    return slime
end

-- options = { columns, rows, random }, where random(n) is like math.random
function Slime.new(options)
    local maze = Maze.generate(options.columns, options.rows, options.random, Slime.CORRIDOR_WIDTH)
    return Slime.inMaze(maze, Puzzle.scatterItems(maze, options.random))
end

function Slime:hint()
    if self.throws == 0 then return "Hold Ⓐ, aim with the crank, let go" end
    return nil
end

function Slime:canThrow()
    return self.state ~= FLYING or self.hasAirThrow
end

local function throwVelocity(angle)
    local radians = math.rad(angle)
    return math.sin(radians) * Slime.THROW_SPEED, -math.cos(radians) * Slime.THROW_SPEED
end

-- One frame of flight for a body: falls, moves, and says what it ran into, if anything.
-- Returns the new velocity and the surface hit. The slime and its arc both fly by this.
local function fly(maze, body, velocityX, velocityY)
    velocityY = velocityY + GRAVITY
    local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if speed > MAX_SPEED then
        velocityX, velocityY = velocityX * MAX_SPEED / speed, velocityY * MAX_SPEED / speed
    end
    local isBlockedX, isBlockedY = body:moveBy(maze, velocityX, velocityY)
    local surface
    if isBlockedY and velocityY > 0 then
        surface = "floor"
    elseif isBlockedX then
        surface = velocityX > 0 and "right" or "left"
    elseif isBlockedY then
        surface = "ceiling"
    end
    return velocityX, velocityY, surface
end

-- Where a throw from here at the present aim would go: { points = { { x, y }, ... }, landingX,
-- landingY }. The tables are reused by the next call.
function Slime:arc()
    local scout, points = self.scout, self.arcPoints
    scout.x, scout.y = self.player.x, self.player.y
    local velocityX, velocityY = throwVelocity(self.aimAngle)
    local count = 0
    for frame = 1, ARC_FRAMES do
        local surface
        velocityX, velocityY, surface = fly(self.maze, scout, velocityX, velocityY)
        if surface then break end
        if frame % ARC_POINT_EVERY == 0 then
            count = count + 1
            local point = points[count]
            if not point then
                point = {}
                points[count] = point
            end
            point.x, point.y = scout.x, scout.y
        end
    end
    for index = count + 1, #points do points[index] = nil end
    self.arcResult.landingX, self.arcResult.landingY = scout.x, scout.y
    return self.arcResult
end

local function stick(self, surface)
    if self.state == FLYING then self:emit("splat") end
    local isSameSurfaceAgain = surface == self.surface and self.flightFrames < SHORTEST_REAL_FLIGHT
    self.velocityX, self.velocityY = 0, 0
    self.hasAirThrow = true
    self.surface = surface
    if surface == "floor" then
        self.state = RESTING
        return
    end
    if not isSameSurfaceAgain then self.stickFrames = Slime.STICK_FRAMES end
    self.state = self.stickFrames > 0 and CLINGING or SLIDING
end

local function launch(self)
    if self.state == FLYING then self.hasAirThrow = false end
    self:emit("throw")
    self.velocityX, self.velocityY = throwVelocity(self.aimAngle)
    self.state = FLYING
    self.flightFrames = 0
    self.throws = self.throws + 1
end

-- Holding A aims, B calls it off, and letting go of A throws
local function aim(self, input)
    if input.cancel and self.isAiming then
        self.isAiming, self.isAimCancelled = false, true
    end
    if not input.isAimHeld then
        if self.isAiming then launch(self) end
        self.isAiming, self.isAimCancelled = false, false
    elseif not self.isAimCancelled then
        self.isAiming = self:canThrow()
    end
end

local function fall(self)
    self.state = FLYING
    self.velocityX, self.velocityY = 0, 0
    self.flightFrames = SHORTEST_REAL_FLIGHT
end

local function move(self, input)
    local maze, player = self.maze, self.player
    if self.state == FLYING then
        local surface
        self.velocityX, self.velocityY, surface = fly(maze, player, self.velocityX, self.velocityY)
        self.flightFrames = self.flightFrames + 1
        if surface then stick(self, surface) end
    elseif self.state == RESTING then
        player:moveBy(maze, (input.move or 0) * Slime.CRAWL_SPEED, 0)
        if not player:wouldHit(maze, 0, PROBE) then fall(self) end
    elseif self.state == CLINGING then
        self.stickFrames = self.stickFrames - 1
        if self.stickFrames == 0 then
            self:emit("slip")
            if self.surface == "ceiling" then fall(self) else self.state = SLIDING end
        end
    else
        local _, hasReachedFloor = player:moveBy(maze, 0, Slime.SLIDE_SPEED)
        local towardsWall = self.surface == "right" and PROBE or -PROBE
        if hasReachedFloor then
            stick(self, "floor")
        elseif not player:wouldHit(maze, towardsWall, 0) then
            fall(self)
        end
    end
end

local function collect(self, item)
    self.puzzle:collect(item)
    self:emit("collect")
    local remaining = 0
    for _, other in ipairs(self.puzzle.items) do
        if other.state ~= Puzzle.STATES.PLACED then remaining = remaining + 1 end
    end
    if remaining == 0 then
        self.maze:openExit()
        self:emit("exitOpen")
        self:say("Got the " .. item.shape .. "! The exit is open")
    else
        self:say("Got the " .. item.shape .. "! " .. remaining .. " to go")
    end
end

-- input = { aim (the crank's position in degrees), isAimHeld (A is down), cancel (B was pressed),
-- move (-1 to 1, crawling) }; all but aim are optional
function Slime:update(input)
    if self.hasEscaped then
        self:clearEvents()
        return
    end
    self:tick()
    self.aimAngle = input.aim
    aim(self, input)
    move(self, input)

    self:visit()
    local item = self.puzzle:itemTouching(self.player.x, self.player.y)
    if item then collect(self, item) end
    self.hasEscaped = self.maze:isExit(self.player.x, self.player.y)
    if self.hasEscaped then self:emit("escape") end
end
