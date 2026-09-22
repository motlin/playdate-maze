-- Finds what is visible from a point in a Maze.
-- cast() walks one ray through the block grid. scan() casts a ray per screen column and groups
-- neighbouring columns that hit the same face of the same block into runs. The top edge of a flat
-- wall is a straight line on screen, so a run can be drawn as one trapezoid from its two ends.
-- Angles are in degrees, 0 facing east (+x) and growing clockwise, since +y is south.

---@class RayScreen
---@field width integer
---@field columnWidth integer
---@field fieldOfView number
---@field refinements integer
---@class RayRun
---@field startX number
---@field endX number
---@field startDistance number
---@field endDistance number
---@field side integer
---@field gridX integer
---@field gridY integer
---@field block integer
---@field key integer
---@class RayScan
---@field runs RayRun[]
---@field depths number[]
---@field runPool? RayRun[]

---@class Raycaster
Raycaster = {}

Raycaster.SIDES = { X = 0, Y = 1 }

local OPEN <const> = 0

-- Returns distance, side, gridX, gridY, block. The distance is in multiples of the direction's
-- length, so a direction built from a camera plane gives the fisheye-free perpendicular distance.
---@param maze Maze
---@param x number
---@param y number
---@param directionX number
---@param directionY number
---@return number, integer, integer, integer, integer
function Raycaster.cast(maze, x, y, directionX, directionY)
    local blocks = maze.blocks
    local gridX, gridY = math.floor(x) + 1, math.floor(y) + 1
    local deltaX = directionX == 0 and math.huge or math.abs(1 / directionX)
    local deltaY = directionY == 0 and math.huge or math.abs(1 / directionY)
    local stepX, stepY, sideDistanceX, sideDistanceY
    if directionX < 0 then
        stepX, sideDistanceX = -1, (x - (gridX - 1)) * deltaX
    else
        stepX, sideDistanceX = 1, (gridX - x) * deltaX
    end
    if directionY < 0 then
        stepY, sideDistanceY = -1, (y - (gridY - 1)) * deltaY
    else
        stepY, sideDistanceY = 1, (gridY - y) * deltaY
    end

    -- The outer wall is solid, so a ray that starts inside always hits something
    while true do
        local side
        if sideDistanceX < sideDistanceY then
            sideDistanceX = sideDistanceX + deltaX
            gridX = gridX + stepX
            side = Raycaster.SIDES.X
        else
            sideDistanceY = sideDistanceY + deltaY
            gridY = gridY + stepY
            side = Raycaster.SIDES.Y
        end
        local block = blocks[gridY][gridX]
        if block ~= OPEN then
            local distance = side == Raycaster.SIDES.X and sideDistanceX - deltaX or sideDistanceY - deltaY
            return distance, side, gridX, gridY, block
        end
    end
end

local function faceKey(side, gridX, gridY) return (gridY * 256 + gridX) * 2 + side end

-- screen = { width, columnWidth, fieldOfView (degrees), refinements }
-- Each run has startX, endX, startDistance, endDistance, side, gridX, gridY, block.
-- refinements is how many times to halve the gap between two columns to pin down a run's edge.
---@param maze Maze
---@param x number
---@param y number
---@param angle number
---@param screen RayScreen
-- A fresh result unless the caller supplies a buffer, whose nested tables are overwritten.
---@param result? RayScan
---@return RayScan
function Raycaster.scan(maze, x, y, angle, screen, result)
    result = result or { runs = {}, depths = {} }
    result.runPool = result.runPool or {}
    local runs, depths, runPool = result.runs, result.depths, result.runPool
    local width, columnWidth = screen.width, screen.columnWidth
    local radians = math.rad(angle)
    local forwardX, forwardY = math.cos(radians), math.sin(radians)
    local planeScale = math.tan(math.rad(screen.fieldOfView / 2))
    local planeX, planeY = -forwardY * planeScale, forwardX * planeScale
    local cast = Raycaster.cast

    local function castAt(screenX)
        local cameraX = 2 * screenX / width - 1
        return cast(maze, x, y, forwardX + planeX * cameraX, forwardY + planeY * cameraX)
    end

    local runCount = 0
    local run
    local function startRun(outputRuns, startX, distance, side, gridX, gridY, block)
        runCount = runCount + 1
        run = runPool[runCount]
        if not run then
            run = outputRuns[runCount] or {}
            runPool[runCount] = run
        end
        outputRuns[runCount] = run
        run.startX, run.startDistance = startX, distance
        run.endX, run.endDistance = startX, distance
        run.side, run.gridX, run.gridY, run.block = side, gridX, gridY, block
        run.key = faceKey(side, gridX, gridY)
    end

    startRun(runs, 0, castAt(0))
    local previousX = 0
    local columnCount = width // columnWidth
    for column = 1, columnCount + 1 do
        -- One sample in the middle of each column, then a last one on the right-hand edge
        local sampleX = column <= columnCount and (column - 0.5) * columnWidth or width
        local distance, side, gridX, gridY, block = castAt(sampleX)
        if column <= columnCount then depths[column] = distance end
        if faceKey(side, gridX, gridY) == run.key then
            run.endX, run.endDistance = sampleX, distance
        else
            local low, high = previousX, sampleX
            local key = faceKey(side, gridX, gridY)
            local startDistance = distance
            for _ = 1, screen.refinements do
                local middle = (low + high) / 2
                local middleDistance, middleSide, middleGridX, middleGridY = castAt(middle)
                local middleKey = faceKey(middleSide, middleGridX, middleGridY)
                if middleKey == run.key then
                    low = middle
                    run.endDistance = middleDistance
                else
                    -- A sliver of some third face is treated as the edge of the new run
                    high = middle
                    if middleKey == key then startDistance = middleDistance end
                end
            end
            local edge = (low + high) / 2
            run.endX = edge
            startRun(runs, edge, startDistance, side, gridX, gridY, block)
            run.endX, run.endDistance = sampleX, distance
        end
        previousX = sampleX
    end

    for index = runCount + 1, #runs do
        runs[index] = nil
    end
    for index = columnCount + 1, #depths do
        depths[index] = nil
    end
    return result
end

-- Where a point in the world lands on screen. Returns screenX and the depth straight ahead,
-- which is the same measure scan() gives for walls, or nil when the point is behind the viewer.
---@param x number
---@param y number
---@param angle number
---@param screen RayScreen
---@param worldX number
---@param worldY number
---@return number?, number?
function Raycaster.project(x, y, angle, screen, worldX, worldY)
    local radians = math.rad(angle)
    local forwardX, forwardY = math.cos(radians), math.sin(radians)
    local offsetX, offsetY = worldX - x, worldY - y
    local depth = offsetX * forwardX + offsetY * forwardY
    if depth <= 0 then return nil end
    local sideways = -offsetX * forwardY + offsetY * forwardX
    local planeScale = math.tan(math.rad(screen.fieldOfView / 2))
    return screen.width / 2 * (1 + sideways / (depth * planeScale)), depth
end
