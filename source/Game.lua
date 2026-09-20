-- One trip through one maze: the maze, the player, the puzzle that locks the exit, and
-- optionally an autopilot doing the walking. update() advances it by one frame of input.
-- Without a puzzle the exit starts open, which is what the screensaver wants.

import "Maze"
import "Player"
import "Puzzle"
import "Autopilot"

Game = {}
Game.__index = Game

Game.WALK_SPEED = 0.08
Game.MESSAGE_FRAMES = 60

local WALK_SPEED <const> = Game.WALK_SPEED
local ANGLES <const> = { east = 0, south = 90, west = 180, north = 270 }

-- options = { columns, rows, hasPuzzle, random }, where random(n) is like math.random
function Game.new(options)
    local maze = Maze.generate(options.columns, options.rows, options.random)
    local startX, startY = maze:cellCenter(1, 1)
    local startAngle = maze:hasPassage(1, 1, "east") and ANGLES.east or ANGLES.south
    local game = setmetatable({
        maze = maze,
        player = Player.new(startX, startY, startAngle),
        puzzle = nil,
        autopilot = nil,
        frames = 0,
        hasEscaped = false,
        message = nil,
        messageFrames = 0,
        visited = {},
        visitedCount = 0,
    }, Game)
    game:visit()
    if options.hasPuzzle then
        game.puzzle = Puzzle.scatter(maze, options.random)
    else
        maze:openExit()
    end
    return game
end

-- Remembers the cell the player is in, for the map's fog of war
function Game:visit()
    local column, row = self.maze:nearestCell(self.player.x, self.player.y)
    local key = (row - 1) * self.maze.columns + column
    if not self.visited[key] then
        self.visited[key] = true
        self.visitedCount = self.visitedCount + 1
    end
end

function Game:hasVisited(column, row)
    return self.visited[(row - 1) * self.maze.columns + column] == true
end

-- Whether the map shows this cell. Without a puzzle there is nothing to find, so nothing is hidden.
function Game:isRevealed(column, row)
    return self.puzzle == nil or self:hasVisited(column, row)
end

function Game:say(message)
    self.message = message
    self.messageFrames = Game.MESSAGE_FRAMES
end

function Game:isAutopilotOn()
    return self.autopilot ~= nil
end

function Game:setAutopilot(isOn)
    self.autopilot = isOn and Autopilot.new(self.maze, self.player) or nil
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
    self.frames = self.frames + 1
    if self.messageFrames > 0 then
        self.messageFrames = self.messageFrames - 1
        if self.messageFrames == 0 then self.message = nil end
    end

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
