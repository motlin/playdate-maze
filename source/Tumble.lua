-- The maze as a platformer, seen from the side. Left and right walk, a button jumps, and gravity
-- always pulls down the screen. The crank turns the whole maze around the player, which inside
-- the maze means turning which way is down: a shaft too tall to climb becomes a corridor to walk
-- along. Touch all three shapes to open the exit.
--
-- `angle` is how far the maze is turned clockwise on screen, in degrees, so a point in the maze
-- appears at the player's position plus its offset turned by `angle`. Velocity is kept in maze
-- coordinates, in blocks a frame. The body is the same square as Player's.

import "Maze"
import "Player"
import "Puzzle"
import "Run"

---@class TumbleInput
---@field turn? number
---@field move? number
---@field jump? boolean

---@class Tumble: Run
---@field puzzle Puzzle
---@field angle number
---@field velocityX number
---@field velocityY number
---@field isGrounded boolean
---@field facing number
Tumble = setmetatable({}, { __index = Run })
Tumble.__index = Tumble

Tumble.RADIUS = Player.RADIUS
Tumble.GRAVITY = 0.012
Tumble.WALK_SPEED = 0.06
Tumble.JUMP_SPEED = 0.17
-- Less than the body's width, so one frame's move can never step over a wall
Tumble.MAX_SPEED = 0.35

-- How quickly walking reaches full speed, and how quickly the player stops: the share of the
-- difference made up each frame
local WALK_GRIP <const> = 0.5
local GROUND_FRICTION <const> = 0.2
local AIR_FRICTION <const> = 0.02
-- How far below the body to feel for the ground
local GROUND_PROBE <const> = 0.05

-- A Tumble in a maze and puzzle made elsewhere, starting in the first cell
---@param maze Maze
---@param puzzle Puzzle
---@return Tumble
function Tumble.inMaze(maze, puzzle)
    local startX, startY = maze:cellCenter(1, 1)
    local tumble = setmetatable(Run.new(maze, Player.new(startX, startY, 90)), Tumble)
    ---@cast tumble Tumble
    tumble.puzzle = puzzle
    tumble.angle = 0
    tumble.velocityX, tumble.velocityY = 0, 0
    tumble.isGrounded = false
    -- 1 when the player last walked to the right of the screen, -1 to the left
    tumble.facing = 1
    return tumble
end

-- options = { columns, rows, random }, where random(n) is like math.random
---@param options RunOptions
---@return Tumble
function Tumble.new(options)
    local maze = Maze.generate(options.columns, options.rows, options.random)
    return Tumble.inMaze(maze, Puzzle.scatterItems(maze, options.random))
end

---@return nil
function Tumble:hint() return nil end -- luacheck: ignore 212/self

---@param item PuzzleItem
---@return nil
function Tumble:collect(item)
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

-- input = { turn (degrees), move (-1 to 1, along the screen), jump }, all optional
---@param input TumbleInput
---@return nil
function Tumble:update(input)
    if self.hasEscaped then
        self:clearEvents()
        return
    end
    self:tick()

    self.angle = (self.angle + (input.turn or 0)) % 360
    -- Which way down and right on the screen point inside the maze
    local radians = math.rad(self.angle)
    local sine, cosine = math.sin(radians), math.cos(radians)
    local downX, downY = sine, cosine
    local rightX, rightY = cosine, -sine
    self.player.angle = (90 - self.angle) % 360

    local velocityX, velocityY = self.velocityX + downX * Tumble.GRAVITY, self.velocityY + downY * Tumble.GRAVITY

    local move = input.move or 0
    local along = velocityX * rightX + velocityY * rightY
    local wanted
    if move ~= 0 then
        wanted = along + (move * Tumble.WALK_SPEED - along) * WALK_GRIP
        self.facing = move > 0 and 1 or -1
    else
        wanted = along * (1 - (self.isGrounded and GROUND_FRICTION or AIR_FRICTION))
    end
    velocityX, velocityY = velocityX + rightX * (wanted - along), velocityY + rightY * (wanted - along)

    if input.jump and self.isGrounded then
        self:emit("jump")
        local falling = velocityX * downX + velocityY * downY
        velocityX, velocityY =
            velocityX - downX * (falling + Tumble.JUMP_SPEED), velocityY - downY * (falling + Tumble.JUMP_SPEED)
    end

    local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if speed > Tumble.MAX_SPEED then
        velocityX, velocityY = velocityX * Tumble.MAX_SPEED / speed, velocityY * Tumble.MAX_SPEED / speed
    end

    local isBlockedX, isBlockedY = self.player:moveBy(self.maze, velocityX, velocityY)
    self.velocityX = isBlockedX and 0 or velocityX
    self.velocityY = isBlockedY and 0 or velocityY
    local wasGrounded = self.isGrounded
    self.isGrounded = self.player:wouldHit(self.maze, downX * GROUND_PROBE, downY * GROUND_PROBE)
    if self.isGrounded and not wasGrounded then self:emit("land") end

    self:visit()
    local item = self.puzzle:itemTouching(self.player.x, self.player.y)
    if item then self:collect(item) end
    self.hasEscaped = self.maze:isExit(self.player.x, self.player.y)
    if self.hasEscaped then self:emit("escape") end
end
