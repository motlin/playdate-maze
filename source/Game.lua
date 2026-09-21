-- Walking the 3D maze: a Run with the puzzle that locks the exit and, optionally, an autopilot
-- doing the walking. update() advances it by one frame of input.
-- Without a puzzle the exit starts open, which is what the screensaver wants.

import "Maze"
import "Player"
import "Puzzle"
import "Autopilot"
import "Flippers"
import "Landmarks"
import "Run"
import "Thread"

Game = setmetatable({}, { __index = Run })
Game.__index = Game

Game.WALK_SPEED = 0.08
Game.MESSAGE_FRAMES = Run.MESSAGE_FRAMES
-- Reeling in the thread: how far the crank turns for each block, and how fast the view may turn
-- to follow the thread round a corner, in degrees a frame
Game.REEL_DEGREES_PER_BLOCK = 180
Game.REEL_TURN_SPEED = 12
-- The gate: degrees of cranking to raise it all the way, how much it sags each frame it is left
-- alone, and how near and how squarely the player must stand to work it
Game.GATE_DEGREES = 720
Game.GATE_SAG_DEGREES = 3
Game.GATE_REACH = 1.5
Game.GATE_FACING = 45
-- For the sounds: a footstep every so many blocks, a bump no more often than every so many
-- frames, a ratchet click every so many degrees of gate, and a tick every so many blocks reeled
Game.STEP_BLOCKS = 0.7
Game.BUMP_FRAMES_APART = 12
Game.GATE_NOTCH_DEGREES = 60
Game.REEL_TICK_BLOCKS = 0.5

local WALK_SPEED <const> = Game.WALK_SPEED
local ANGLES <const> = { east = 0, south = 90, west = 180, north = 270 }

-- options = { columns, rows, hasPuzzle, random }, where random(n) is like math.random
function Game.new(options)
    local maze = Maze.generate(options.columns, options.rows, options.random)
    local startX, startY = maze:cellCenter(1, 1)
    local startAngle = maze:hasPassage(1, 1, "east") and ANGLES.east or ANGLES.south
    local game = setmetatable(Run.new(maze, Player.new(startX, startY, startAngle)), Game)
    game.autopilot = nil
    game.thread = Thread.new(maze, startX, startY)
    -- The gate over the exit unlocks when the puzzle is solved and is then cranked up by hand.
    -- gateLift runs from 0, fully down, to 1, where the exit opens for good.
    -- It is counted in degrees of cranking, because adding up fractions never quite reaches 1.
    -- How far the player walked in the latest frame, for the view's head bob
    game.distanceWalked = 0
    game.blocksSinceStep = 0
    game.blocksSinceReelTick = 0
    game.lastBumpFrame = -Game.BUMP_FRAMES_APART
    game.isGateUnlocked = false
    game.gateDegrees = 0
    game.gateLift = 0
    if options.hasPuzzle then
        game.puzzle = Puzzle.scatter(maze, options.random)
    else
        maze:openExit()
    end
    game.landmarks = Landmarks.scatter(maze, options.random)

    -- Touching a flipper turns the world upside down, or the right way up again
    local taken = {}
    for _, mark in ipairs(game.landmarks.marks) do taken[#taken + 1] = mark end
    if game.puzzle then
        for _, item in ipairs(game.puzzle.items) do taken[#taken + 1] = item end
        for _, pedestal in ipairs(game.puzzle.pedestals) do taken[#taken + 1] = pedestal end
    end
    game.flippers = Flippers.scatter(maze, options.random, taken)
    game.isFlipped = false
    return game
end

-- The compass bearing of the view, which a mode only has if looking around means something in it
function Game:heading()
    return self.player.angle
end

function Game:isAutopilotOn()
    return self.autopilot ~= nil
end

function Game:setAutopilot(isOn)
    self.autopilot = isOn and Autopilot.new(self.maze, self.player) or nil
end

-- Whether the player is standing at the unlocked gate, looking at it, with it still to be raised
function Game:canCrankGate()
    if not self.isGateUnlocked or self.gateLift == 1 then return false end
    local gateX, gateY = self.maze:blockCenter(self.maze.exitGridX, self.maze.exitGridY)
    local offsetX, offsetY = gateX - self.player.x, gateY - self.player.y
    if math.sqrt(offsetX * offsetX + offsetY * offsetY) > Game.GATE_REACH then return false end
    local bearing = math.deg(math.atan(offsetY, offsetX))
    return math.abs((bearing - self.player.angle + 180) % 360 - 180) <= Game.GATE_FACING
end

-- One line for the bottom of the screen about what the player could do here, or nil
function Game:hint()
    if self.autopilot then return "Autopilot: press any button to take over" end
    if self:canCrankGate() then return "Crank forwards to raise the gate" end
    local puzzle, player = self.puzzle, self.player
    if not puzzle then return nil end
    local item = puzzle:itemInReach(player.x, player.y)
    if item then return "Ⓐ Pick up the " .. item.shape end
    if puzzle:pedestalInReach(player.x, player.y) then return "Ⓑ Place the " .. puzzle.carried.shape end
    return nil
end

function Game:pickUp()
    local item = self.puzzle:pickUp(self.player.x, self.player.y)
    if item then
        self:emit("pickUp")
        self:say("Picked up the " .. item.shape)
    elseif self.puzzle.carried then
        self:emit("blocked")
        self:say("Your hands are full")
    else
        self:emit("blocked")
        self:say("Nothing here to pick up")
    end
end

function Game:drop()
    local item = self.puzzle.carried
    local result = self.puzzle:drop(self.player.x, self.player.y)
    if result == Puzzle.RESULTS.DROPPED then
        self:emit("drop")
        self:say("Dropped the " .. item.shape)
    elseif result == Puzzle.RESULTS.BLOCKED then
        self:emit("blocked")
        self:say("No room to put it down here")
    elseif result == Puzzle.RESULTS.PLACED then
        self:emit("place")
        if self.puzzle:isSolved() then
            self.isGateUnlocked = true
            self:emit("unlock")
            self:say("The gate is unlocked! Crank it open")
        else
            self:say("The " .. item.shape .. " fits!")
        end
    else
        self:emit("blocked")
        self:say("Nothing to put down")
    end
end

-- Pulls the player back along the thread, looking the way they were walking when it was laid,
-- like a film run backwards
function Game:reelIn(degrees)
    local player = self.player
    local x, y, heading, blocked = self.thread:rewindFrom(player.x, player.y, degrees / Game.REEL_DEGREES_PER_BLOCK)
    if not x then
        self:say(blocked and "The thread is blocked here" or "The thread begins here")
        return
    end
    self.blocksSinceReelTick = self.blocksSinceReelTick + degrees / Game.REEL_DEGREES_PER_BLOCK
    if self.blocksSinceReelTick >= Game.REEL_TICK_BLOCKS then
        self.blocksSinceReelTick = self.blocksSinceReelTick - Game.REEL_TICK_BLOCKS
        self:emit("reel")
    end
    player.x, player.y = x, y
    local turn = (heading - player.angle + 180) % 360 - 180
    player:turn(math.max(-Game.REEL_TURN_SPEED, math.min(Game.REEL_TURN_SPEED, turn)))
end

-- Raises the gate by a forward crank, or lets it sag. Returns whether the crank was used on it.
function Game:workGate(crank)
    if self.gateLift == 1 then return false end
    local isCranking = crank > 0 and self:canCrankGate()
    if isCranking then
        local notchesBefore = self.gateDegrees // Game.GATE_NOTCH_DEGREES
        self.gateDegrees = math.min(Game.GATE_DEGREES, self.gateDegrees + crank)
        if self.gateDegrees < Game.GATE_DEGREES and self.gateDegrees // Game.GATE_NOTCH_DEGREES > notchesBefore then
            self:emit("gateNotch")
        end
    else
        self.gateDegrees = math.max(0, self.gateDegrees - Game.GATE_SAG_DEGREES)
    end
    self.gateLift = self.gateDegrees / Game.GATE_DEGREES
    if self.gateLift == 1 then
        self.maze:openExit()
        self:emit("gateOpen")
        self:say("The exit is open!")
    end
    return isCranking
end

-- input = { turn (degrees to turn the view, from the crank or the D-pad), crank (degrees the crank
-- itself moved), forward and strafe (-1 to 1), reel (degrees of thread to wind in), pickUp, drop },
-- all optional
function Game:update(input)
    if self.hasEscaped then
        self:clearEvents()
        return
    end
    self:tick()

    local reel = input.reel or 0
    local isCrankingGate = self:workGate(input.crank or 0)
    local fromX, fromY = self.player.x, self.player.y
    if self.autopilot then
        self.autopilot:update()
        self.thread:record(self.player.x, fromY)
        self.thread:record(self.player.x, self.player.y)
    elseif reel > 0 then
        self:reelIn(reel)
        fromX, fromY = self.player.x, self.player.y
    else
        -- While the crank is lifting the gate it does not also swing the view
        if not isCrankingGate then self.player:turn(input.turn or 0) end
        self.player:move(self.maze, (input.forward or 0) * WALK_SPEED, (input.strafe or 0) * WALK_SPEED)
        self.thread:record(self.player.x, fromY)
        self.thread:record(self.player.x, self.player.y)
    end
    local walkedX, walkedY = self.player.x - fromX, self.player.y - fromY
    self.distanceWalked = math.sqrt(walkedX * walkedX + walkedY * walkedY)
    self.blocksSinceStep = self.blocksSinceStep + self.distanceWalked
    if self.blocksSinceStep >= Game.STEP_BLOCKS then
        self.blocksSinceStep = self.blocksSinceStep - Game.STEP_BLOCKS
        self:emit("step")
    end
    local isPushing = not self.autopilot and reel == 0 and ((input.forward or 0) ~= 0 or (input.strafe or 0) ~= 0)
    if isPushing and self.distanceWalked == 0 and self.frames - self.lastBumpFrame >= Game.BUMP_FRAMES_APART then
        self.lastBumpFrame = self.frames
        self:emit("bump")
    end
    self:visit()
    if self.flippers:touch(self.player.x, self.player.y) then
        self.isFlipped = not self.isFlipped
        self:emit("flip")
        self:say("The world turns over!")
    end
    if self.puzzle and input.pickUp then self:pickUp() end
    if self.puzzle and input.drop then self:drop() end

    self.hasEscaped = self.maze:isExit(self.player.x, self.player.y)
    if self.hasEscaped then self:emit("escape") end
end

Game.SAVE_VERSION = 1

-- Everything needed to carry on later, as lists and named entries only, so it can be written as
-- JSON. The autopilot is not kept: a resumed game is in the player's hands.
function Game:toSave()
    assert(self.puzzle, "only a maze with a puzzle is worth saving")
    local visited = {}
    for key in pairs(self.visited) do visited[#visited + 1] = key end
    table.sort(visited)
    return {
        version = Game.SAVE_VERSION,
        maze = self.maze:toSave(),
        player = { x = self.player.x, y = self.player.y, angle = self.player.angle },
        puzzle = self.puzzle:toSave(),
        landmarks = self.landmarks.all,
        flippers = self.flippers.all,
        thread = self.thread.points,
        visited = visited,
        frames = self.frames,
        isFlipped = self.isFlipped,
        isGateUnlocked = self.isGateUnlocked,
        gateDegrees = self.gateDegrees,
    }
end

function Game.fromSave(save)
    assert(save.version == Game.SAVE_VERSION, "this save is version " .. tostring(save.version) .. ", which this game cannot load")
    local maze = Maze.fromSave(save.maze)
    local game = setmetatable(Run.new(maze, Player.new(save.player.x, save.player.y, save.player.angle)), Game)
    game.autopilot = nil
    game.puzzle = Puzzle.fromSave(save.puzzle)
    game.landmarks = Landmarks.fromSave(save.landmarks)
    game.flippers = Flippers.fromSave(save.flippers)
    game.thread = Thread.fromSave(maze, save.thread, save.player.x, save.player.y)
    game.frames = save.frames
    game.visited, game.visitedCount = {}, #save.visited
    for _, key in ipairs(save.visited) do game.visited[key] = true end
    game.isFlipped = save.isFlipped
    game.isGateUnlocked = save.isGateUnlocked
    game.gateDegrees = save.gateDegrees
    game.gateLift = save.gateDegrees / Game.GATE_DEGREES
    game.distanceWalked, game.blocksSinceStep, game.blocksSinceReelTick = 0, 0, 0
    game.lastBumpFrame = save.frames - Game.BUMP_FRAMES_APART
    return game
end
