-- What every way of playing a maze has in common: the maze and the player in it, how long it has
-- taken, the latest message for the screen, and which cells have been seen, for the map's fog of
-- war. Game and Tumble build on this.

---@class RunOptions
---@field columns integer
---@field rows integer
---@field random Random
---@field hasPuzzle? boolean

---@class Run
---@field maze Maze
---@field player Player
---@field puzzle Puzzle?
---@field frames integer
---@field hasEscaped boolean
---@field message string?
---@field messageFrames integer
---@field visited table<integer, boolean>
---@field visitedCount integer
---@field events string[]
Run = {}
Run.__index = Run

Run.MESSAGE_FRAMES = 60

---@param maze Maze
---@param player Player
---@return Run
function Run.new(maze, player)
    local run = setmetatable({
        maze = maze,
        player = player,
        puzzle = nil,
        frames = 0,
        hasEscaped = false,
        message = nil,
        messageFrames = 0,
        visited = {},
        visitedCount = 0,
        -- What happened this frame, by name, for whoever makes the sounds
        events = {},
    }, Run)
    run:visit()
    return run
end

-- Remembers the cell the player is in
---@return nil
function Run:visit()
    local column, row = self.maze:nearestCell(self.player.x, self.player.y)
    local key = (row - 1) * self.maze.columns + column
    if not self.visited[key] then
        self.visited[key] = true
        self.visitedCount = self.visitedCount + 1
    end
end

---@param column integer
---@param row integer
---@return boolean
function Run:hasVisited(column, row) return self.visited[(row - 1) * self.maze.columns + column] == true end

-- Whether the map shows this cell. Without a puzzle there is nothing to find, so nothing is hidden.
---@param column integer
---@param row integer
---@return boolean
function Run:isRevealed(column, row) return self.puzzle == nil or self:hasVisited(column, row) end

---@param message string
---@return nil
function Run:say(message)
    self.message = message
    self.messageFrames = Run.MESSAGE_FRAMES
end

---@param event string
---@return nil
function Run:emit(event) self.events[#self.events + 1] = event end

---@return nil
function Run:clearEvents()
    for index = #self.events, 1, -1 do
        self.events[index] = nil
    end
end

-- Call once at the start of every frame that is played
---@return nil
function Run:tick()
    self:clearEvents()
    self.frames = self.frames + 1
    if self.messageFrames > 0 then
        self.messageFrames = self.messageFrames - 1
        if self.messageFrames == 0 then self.message = nil end
    end
end

---@return boolean
function Run:isAutopilotOn() return false end -- luacheck: ignore 212/self
