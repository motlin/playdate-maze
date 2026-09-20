require("spec.support.playdate_stub")
import "Maze"
import "Landmarks"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

local function scatter(seed)
    local maze = Maze.generate(8, 6, seededRandom(seed or 3))
    return Landmarks.scatter(maze, seededRandom(40)), maze
end

describe("Landmarks", function()
    it("marks about one cell in five", function()
        local landmarks = scatter()
        assert.are.equal(48 // 5, #landmarks.all)
    end)

    it("gives every landmark a cell of its own, never the one the player starts in", function()
        local landmarks = scatter()
        local seen = {}
        for _, landmark in ipairs(landmarks.all) do
            local key = landmark.column .. "," .. landmark.row
            assert.is_nil(seen[key])
            seen[key] = true
            assert.are_not.equal("1,1", key)
        end
    end)

    it("is a mix of pictures on walls and marks on floors and ceilings", function()
        local kinds = {}
        for _, landmark in ipairs(scatter().all) do kinds[landmark.kind] = (kinds[landmark.kind] or 0) + 1 end
        assert.is_true((kinds.picture or 0) >= 2)
        assert.is_true((kinds.floor or 0) + (kinds.ceiling or 0) >= 2)
    end)

    it("hangs pictures only on solid wall, never across a passage or on the exit gate", function()
        for seed = 1, 10 do
            local landmarks, maze = scatter(seed)
            for _, landmark in ipairs(landmarks.all) do
                if landmark.kind == "picture" then
                    assert.are.equal(Maze.BLOCKS.WALL, maze:blockValue(landmark.gridX, landmark.gridY))
                    assert.is_false(maze:hasPassage(landmark.column, landmark.row, landmark.direction))
                end
            end
        end
    end)

    it("can be asked whether a wall face has a picture, by the face the viewer sees", function()
        local landmarks = scatter()
        local picture
        for _, landmark in ipairs(landmarks.all) do
            if landmark.kind == "picture" then picture = landmark end
        end
        assert.are.equal(picture.motif, landmarks:pictureOn(picture.gridX, picture.gridY, picture.face))
        local otherFace = picture.face % 4 + 1
        assert.is_nil(landmarks:pictureOn(picture.gridX, picture.gridY, otherFace))
    end)

    it("puts a picture on the face of the wall that looks into its cell", function()
        local FACES <const> = Landmarks.FACES
        local expected = { east = FACES.WEST, west = FACES.EAST, north = FACES.SOUTH, south = FACES.NORTH }
        for _, landmark in ipairs(scatter().all) do
            if landmark.kind == "picture" then assert.are.equal(expected[landmark.direction], landmark.face) end
        end
    end)

    it("gives neighbouring landmarks different motifs, by using each in turn", function()
        local landmarks = scatter()
        for index = 2, #landmarks.all do
            assert.are_not.equal(landmarks.all[index - 1].motif, landmarks.all[index].motif)
        end
        for _, landmark in ipairs(landmarks.all) do
            assert.is_true(landmark.motif >= 1 and landmark.motif <= Landmarks.MOTIFS)
        end
    end)

    it("is the same for the same random numbers, so a daily maze has the same landmarks for everyone", function()
        assert.are.same(scatter().all, scatter().all)
    end)

    it("lists the marks on floors and ceilings with the block they are in", function()
        local landmarks, maze = scatter()
        assert.is_true(#landmarks.marks >= 2)
        for _, mark in ipairs(landmarks.marks) do
            assert.are.same({ maze:cellBlock(mark.column, mark.row) }, { mark.gridX, mark.gridY })
        end
    end)
end)
