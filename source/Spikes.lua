import "Maze"
import "Player"

---@class Spike
---@field x number
---@field y number
Spikes = {}
Spikes.HALF_WIDTH = 0.3
Spikes.HEIGHT = 0.35

-- Short floor patches leave room to land on either side and keep cell connections clear.
---@param maze Maze
---@param puzzle Puzzle
---@return Spike[]
function Spikes.place(maze, puzzle)
    local spikes = {}
    local startX, startY = maze:cellCenter(1, 1)
    local spawnGridX, landingGridY = maze:blockAt(startX, startY)
    -- Slime cannot steer or throw during this fall; its first landing must be safe.
    while not maze:isWall(spawnGridX, landingGridY + 1) do
        landingGridY = landingGridY + 1
    end
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            local x = maze:cellCenter(column, row)
            local floorY = row * (maze.corridorWidth + 1)
            local gridX = math.floor(x) + 1
            local protected = (column == 1 and (row == 1 or floorY == landingGridY))
                or (column == maze.columns and row == maze.rows)
            for _, item in ipairs(puzzle.items) do
                local itemX, itemY = maze:blockCenter(item.gridX, item.gridY)
                local itemColumn, itemRow = maze:nearestCell(itemX, itemY)
                if itemColumn == column and itemRow == row then protected = true end
            end
            if not protected and maze:isWall(gridX, floorY + 1) and not maze:isWall(gridX, floorY) then
                spikes[#spikes + 1] = { x = x, y = floorY }
            end
        end
    end
    return spikes
end

---@param spikes Spike[]
---@param x number
---@param y number
---@return boolean
function Spikes.touches(spikes, x, y)
    for _, spike in ipairs(spikes) do
        if
            math.abs(x - spike.x) < Spikes.HALF_WIDTH + Player.RADIUS
            and y + Player.RADIUS > spike.y - Spikes.HEIGHT
            and y - Player.RADIUS < spike.y
        then
            return true
        end
    end
    return false
end
