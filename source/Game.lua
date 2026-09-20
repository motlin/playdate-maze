-- Walking the 3D maze: a Run with the puzzle that locks the exit and, optionally, an autopilot
-- doing the walking. update() advances it by one frame of input.
-- Without a puzzle the exit starts open, which is what the screensaver wants.

import "Maze"
import "Player"
import "Puzzle"
import "Autopilot"
import "Run"

Game = setmetatable({}, { __index = Run })
Game.__index = Game

Game.WALK_SPEED = 0.08
Game.MESSAGE_FRAMES = Run.MESSAGE_FRAMES

local WALK_SPEED <const> = Game.WALK_SPEED
local ANGLES <const> = { east = 0, south = 90, west = 180, north = 270 }

-- options = { columns, rows, hasPuzzle, random }, where random(n) is like math.random
function Game.new(options)
    local maze = Maze.generate(options.columns, options.rows, options.random)
    local startX, startY = maze:cellCenter(1, 1)
    local startAngle = maze:hasPassage(1, 1, "east") and ANGLES.east or ANGLES.south
    local game = setmetatable(Run.new(maze, Player.new(startX, startY, startAngle)), Game)
    game.autopilot = nil
    if options.hasPuzzle then
        game.puzzle = Puzzle.scatter(maze, options.random)
    else
        maze:openExit()
    end
    return game
end

function Game:isAutopilotOn()
    return self.autopilot ~= nil
end

function Game:setAutopilot(isOn)
    self.autopilot = isOn and Autopilot.new(self.maze, self.player) or nil
end

-- One line for the bottom of the screen about what A or B would do here, or nil
function Game:hint()
    if self.autopilot then return "Autopilot: press any button to take over" end
    local puzzle, player = self.puzzle, self.player
    if not puzzle then return nil end
    local item = puzzle:itemInReach(player.x, player.y)
    if item then return "Ⓐ Pick up the " .. item.shape end
    if puzzle:pedestalInReach(player.x, player.y) then return "Ⓑ Place the " .. puzzle.carried.shape end
    return nil
end

local function pickUp(self)
    local item = self.puzzle:pickUp(self.player.x, self.player.y)
    if item then
        self:say("Picked up the " .. item.shape)
    elseif self.puzzle.carried then
        self:say("Your hands are full")
    else
        self:say("Nothing here to pick up")
    end
end

local function drop(self)
    local item = self.puzzle.carried
    local result = self.puzzle:drop(self.player.x, self.player.y)
    if result == Puzzle.RESULTS.DROPPED then
        self:say("Dropped the " .. item.shape)
    elseif result == Puzzle.RESULTS.BLOCKED then
        self:say("No room to put it down here")
    elseif result == Puzzle.RESULTS.PLACED then
        if self.puzzle:isSolved() then
            self.maze:openExit()
            self:say("The exit is open!")
        else
            self:say("The " .. item.shape .. " fits!")
        end
    else
        self:say("Nothing to put down")
    end
end

-- input = { turn (degrees), forward and strafe (-1 to 1), pickUp, drop }, all optional
function Game:update(input)
    if self.hasEscaped then return end
    self:tick()

    if self.autopilot then
        self.autopilot:update()
    else
        self.player:turn(input.turn or 0)
        self.player:move(self.maze, (input.forward or 0) * WALK_SPEED, (input.strafe or 0) * WALK_SPEED)
    end
    self:visit()
    if self.puzzle and input.pickUp then pickUp(self) end
    if self.puzzle and input.drop then drop(self) end

    self.hasEscaped = self.maze:isExit(self.player.x, self.player.y)
end
