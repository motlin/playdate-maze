-- What every way of playing a maze has in common: the maze and the player in it, how long it has
-- taken, the latest message for the screen, and which cells have been seen, for the map's fog of
-- war. Game and Tumble build on this.

Run = {}
Run.__index = Run

Run.MESSAGE_FRAMES = 60

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
function Run:visit()
    local column, row = self.maze:nearestCell(self.player.x, self.player.y)
    local key = (row - 1) * self.maze.columns + column
    if not self.visited[key] then
        self.visited[key] = true
        self.visitedCount = self.visitedCount + 1
    end
end

function Run:hasVisited(column, row)
    return self.visited[(row - 1) * self.maze.columns + column] == true
end

-- Whether the map shows this cell. Without a puzzle there is nothing to find, so nothing is hidden.
function Run:isRevealed(column, row)
    return self.puzzle == nil or self:hasVisited(column, row)
end

function Run:say(message)
    self.message = message
    self.messageFrames = Run.MESSAGE_FRAMES
end

function Run:emit(event)
    self.events[#self.events + 1] = event
end

function Run:clearEvents()
    for index = #self.events, 1, -1 do self.events[index] = nil end
end

-- Call once at the start of every frame that is played
function Run:tick()
    self:clearEvents()
    self.frames = self.frames + 1
    if self.messageFrames > 0 then
        self.messageFrames = self.messageFrames - 1
        if self.messageFrames == 0 then self.message = nil end
    end
end

function Run:isAutopilotOn()
    return false
end
