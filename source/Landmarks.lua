-- Things to recognise a place by: pictures hung on walls, and marks on floors and ceilings.
-- About one cell in five gets one. They belong to the maze's random numbers, so everyone playing
-- the same daily maze sees the same ones.

import "Maze"

Landmarks = {}
Landmarks.__index = Landmarks

-- The faces of a wall block, named for the side of the block they are on
Landmarks.FACES = { WEST = 1, EAST = 2, NORTH = 3, SOUTH = 4 }
-- How many different motifs the view knows how to draw
Landmarks.MOTIFS = 8

local CELLS_PER_LANDMARK <const> = 5
local KINDS <const> = { "picture", "floor", "picture", "ceiling" }
-- A wall to the east of a cell shows that cell its west face, and so on
local FACE_SEEN_FROM <const> = {
    east = Landmarks.FACES.WEST,
    west = Landmarks.FACES.EAST,
    north = Landmarks.FACES.SOUTH,
    south = Landmarks.FACES.NORTH,
}

local function faceKey(gridX, gridY, face) return (gridY * 256 + gridX) * 4 + face end

-- The solid walls around a cell, as directions; the exit gate does not count
local function solidWalls(maze, column, row)
    local directions = {}
    for _, direction in ipairs(Maze.DIRECTIONS) do
        local offset = Maze.OFFSETS[direction]
        local gridX, gridY = maze:cellBlock(column, row)
        if maze:blockValue(gridX + offset[1], gridY + offset[2]) == Maze.BLOCKS.WALL then
            directions[#directions + 1] = direction
        end
    end
    return directions
end

-- For a maze with corridors one block wide. random(n) is like math.random.
function Landmarks.scatter(maze, random)
    assert(maze.corridorWidth == 1, "landmarks are placed for corridors one block wide")
    local cells = {}
    for row = 1, maze.rows do
        for column = 1, maze.columns do
            -- A map drawn by hand may have cells that have been filled in
            local isOpen = not maze:isWall(maze:cellBlock(column, row))
            if isOpen and not (column == 1 and row == 1) then cells[#cells + 1] = { column, row } end
        end
    end
    for index = #cells, 2, -1 do
        local other = random(index)
        cells[index], cells[other] = cells[other], cells[index]
    end

    local landmarks = setmetatable({ all = {}, marks = {}, pictures = {} }, Landmarks)
    for index = 1, math.min(#cells, maze.columns * maze.rows // CELLS_PER_LANDMARK) do
        local column, row = cells[index][1], cells[index][2]
        local gridX, gridY = maze:cellBlock(column, row)
        local landmark = {
            kind = KINDS[(index - 1) % #KINDS + 1],
            column = column,
            row = row,
            motif = (index - 1) % Landmarks.MOTIFS + 1,
            gridX = gridX,
            gridY = gridY,
        }
        if landmark.kind == "picture" then
            local walls = solidWalls(maze, column, row)
            if #walls == 0 then
                landmark.kind = "floor"
                landmarks.marks[#landmarks.marks + 1] = landmark
            else
                landmark.direction = walls[random(#walls)]
                local offset = Maze.OFFSETS[landmark.direction]
                landmark.gridX, landmark.gridY = gridX + offset[1], gridY + offset[2]
                landmark.face = FACE_SEEN_FROM[landmark.direction]
                landmarks.pictures[faceKey(landmark.gridX, landmark.gridY, landmark.face)] = landmark.motif
            end
        else
            landmarks.marks[#landmarks.marks + 1] = landmark
        end
        landmarks.all[index] = landmark
    end
    return landmarks
end

-- The motif of the picture on a face of a wall block, or nil
function Landmarks:pictureOn(gridX, gridY, face) return self.pictures[faceKey(gridX, gridY, face)] end

-- Landmarks again from their saved list, which is `all`
function Landmarks.fromSave(all)
    local landmarks = setmetatable({ all = all, marks = {}, pictures = {} }, Landmarks)
    for _, landmark in ipairs(all) do
        if landmark.kind == "picture" then
            landmarks.pictures[faceKey(landmark.gridX, landmark.gridY, landmark.face)] = landmark.motif
        else
            landmarks.marks[#landmarks.marks + 1] = landmark
        end
    end
    return landmarks
end
