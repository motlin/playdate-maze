require("spec.support.playdate_stub")
import "Maze"
import "ExitDistance"

local function seededRandom(seed)
    local state = seed
    return function(n)
        state = (state * 1103515245 + 12345) % 2147483648
        return state % n + 1
    end
end

describe("ExitDistance", function()
    it("counts the cells to walk through to reach the exit's cell", function()
        local distances = ExitDistance.new(Maze.generate(3, 1, seededRandom(1)))
        assert.are.equal(0, distances:cells(3, 1))
        assert.are.equal(1, distances:cells(2, 1))
        assert.are.equal(2, distances:cells(1, 1))
        assert.are.equal(2, distances.farthest)
    end)

    it("follows the corridors, not the crow", function()
        -- A U-shaped maze: the first cell is next door to the exit's cell, but five cells' walk away
        local maze = Maze.new(2, 3)
        maze:carve(1, 3, "north")
        maze:carve(1, 2, "north")
        maze:carve(1, 1, "east")
        maze:carve(2, 1, "south")
        maze:carve(2, 2, "south")
        maze.exitGridX, maze.exitGridY = maze.gridWidth, 6
        local distances = ExitDistance.new(maze)
        assert.are.equal(0, distances:cells(2, 3))
        assert.are.equal(5, distances:cells(1, 3))
    end)

    it("gives every cell of a generated maze a distance one different from each cell it opens on to", function()
        local maze = Maze.generate(8, 6, seededRandom(5))
        local distances = ExitDistance.new(maze)
        for row = 1, 6 do
            for column = 1, 8 do
                for _, direction in ipairs(Maze.DIRECTIONS) do
                    local offset = Maze.OFFSETS[direction]
                    local nextColumn, nextRow = column + offset[1], row + offset[2]
                    local isInside = nextColumn >= 1 and nextColumn <= 8 and nextRow >= 1 and nextRow <= 6
                    if isInside and maze:hasPassage(column, row, direction) then
                        assert.are.equal(
                            1,
                            math.abs(distances:cells(column, row) - distances:cells(nextColumn, nextRow))
                        )
                    end
                end
            end
        end
    end)

    it("works in a maze with wide corridors", function()
        local distances = ExitDistance.new(Maze.generate(4, 3, seededRandom(5), 3))
        assert.are.equal(0, distances:cells(4, 3))
        assert.is_true(distances.farthest >= 5)
    end)

    describe("proximity", function()
        it("is 1 at the exit's cell and 0 at the farthest cell from it", function()
            local maze = Maze.generate(3, 1, seededRandom(1))
            local distances = ExitDistance.new(maze)
            assert.are.equal(1, distances:proximity(maze:cellCenter(3, 1)))
            assert.are.equal(0.5, distances:proximity(maze:cellCenter(2, 1)))
            assert.are.equal(0, distances:proximity(maze:cellCenter(1, 1)))
        end)
    end)
end)

describe("custom-map block distances", function()
    local function corridor()
        import "MapDesign"
        local design = MapDesign.new(4, 2)
        for gridX = 2, 8 do
            design:setBlock(gridX, 3, true)
        end
        design:place("start", nil, 3, 3)
        design:place("exit", nil, 9, 3)
        assert.are.same({}, design:problems())
        return Maze.fromDesign(design)
    end

    it("reaches off-center starts and progresses along row three to the closed gate", function()
        local maze = corridor()
        local distances = ExitDistance.new(maze, true)
        local proximity = {}
        for gridX = 2, 9 do
            proximity[#proximity + 1] = distances:proximity(maze:blockCenter(gridX, 3))
        end
        assert.are.same({ 1 / 8, 2 / 8, 3 / 8, 4 / 8, 5 / 8, 6 / 8, 7 / 8, 1 }, proximity)
        assert.are.equal(0, distances:proximity(0.5, 0.5))
        maze:openExit()
        assert.are.equal(1, ExitDistance.new(maze, true):proximity(maze:blockCenter(9, 3)))
    end)

    it("feeds custom block proximity through Music into the played pitch", function()
        import "MusicScore"
        import "Settings"
        local originalSound = playdate.sound
        local notes = {}
        playdate.sound = {
            synth = {
                new = function()
                    return {
                        setADSR = function() end,
                        noteOff = function() end,
                        playNote = function(_, frequency) notes[#notes + 1] = frequency end,
                    }
                end,
            },
        }
        local environment = setmetatable({}, { __index = _G })
        assert(loadfile("source/Music.lua", "t", environment))()
        Settings.setMusicOn(true)
        local maze = corridor()
        environment.Music.update({ maze = maze, isHandMade = true, player = { x = 2.5, y = 2.5 } })
        assert.are.same({ MusicScore.frequency(MusicScore.noteAt(1), 3) }, notes)
        playdate.sound = originalSound
    end)
end)
