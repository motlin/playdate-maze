require("spec.support.playdate_stub")
import "Tumble"
import "Slime"
import "SeededRandom"

describe("platforming spikes", function()
    it("widens Tumble corridors and gives both modes safe spawns and hazards", function()
        for _, mode in ipairs({ Tumble, Slime }) do
            local run = mode.new({ columns = 6, rows = 4, random = SeededRandom.new(100) })
            assert.is_true(run.maze.corridorWidth >= 2)
            assert.is_true(#run.spikes > 0)
            assert.is_false(Spikes.touches(run.spikes, run.player.x, run.player.y))
        end
    end)

    it("returns Tumble to the start on contact without losing collected shapes", function()
        local run = Tumble.new({ columns = 6, rows = 4, random = SeededRandom.new(100) })
        run:collect(run.puzzle.items[1])
        local spike = run.spikes[1]
        run.player.x, run.player.y = spike.x, spike.y - 0.2
        run:update({})
        local x, y = run.maze:cellCenter(1, 1)
        assert.are.same({ x, y, 0, 0, 0, false, Puzzle.STATES.PLACED, "Spikes! Back to the start" }, {
            run.player.x,
            run.player.y,
            run.velocityX,
            run.velocityY,
            run.angle,
            run.isGrounded,
            run.puzzle.items[1].state,
            run.message,
        })
    end)

    it("resets Slime flight and aiming on contact", function()
        local run = Slime.new({ columns = 6, rows = 4, random = SeededRandom.new(100) })
        local spike = run.spikes[1]
        run.player.x, run.player.y = spike.x, spike.y - 0.2
        run:update({ aim = 90, isAimHeld = true })
        local x, y = run.maze:cellCenter(1, 1)
        assert.are.same({ x, y, 0, 0, Slime.STATES.FLYING, false, 0, 0 }, {
            run.player.x,
            run.player.y,
            run.velocityX,
            run.velocityY,
            run.state,
            run.isAiming,
            run.stickFrames,
            run.flightFrames,
        })
    end)

    it("allows a body above the tips and detects touching from either side", function()
        local spikes = { { x = 3, y = 4 } }
        assert.are.same({ false, true, true, false }, {
            Spikes.touches(spikes, 3, 3.4),
            Spikes.touches(spikes, 2.7, 3.8),
            Spikes.touches(spikes, 3.3, 3.8),
            Spikes.touches(spikes, 4, 3.8),
        })
    end)
    it("lets Tumble jump across a patch instead of walking into it", function()
        local run = Tumble.new({ columns = 6, rows = 4, random = SeededRandom.new(100) })
        local spike = run.spikes[1]
        run.player.x, run.player.y = spike.x - 0.75, spike.y - Player.RADIUS - 0.000001
        run:update({})
        run:update({ move = 1, jump = true })
        for _ = 1, 23 do
            run:update({ move = 1 })
        end
        assert.are.same({ true, nil }, { run.player.x > spike.x + 0.5, run.message })
    end)
end)
