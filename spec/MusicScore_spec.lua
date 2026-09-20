require("spec.support.playdate_stub")
import "MusicScore"

describe("MusicScore", function()
    describe("pitch", function()
        it("is untransposed far from the exit and an octave up right beside it", function()
            assert.are.equal(0, MusicScore.transposition(0))
            assert.are.equal(12, MusicScore.transposition(1))
        end)

        it("rises steadily in between, by fractions of a semitone, so it glides rather than steps", function()
            local previous = -1
            for step = 0, 20 do
                local semitones = MusicScore.transposition(step / 20)
                assert.is_true(semitones > previous)
                previous = semitones
            end
            assert.is_near(6, MusicScore.transposition(0.5), 0.0001)
        end)

        it("turns a note and a transposition into hertz", function()
            assert.is_near(440, MusicScore.frequency(69, 0), 0.001)
            assert.is_near(880, MusicScore.frequency(69, 12), 0.001)
            assert.is_near(261.63, MusicScore.frequency(60, 0), 0.01)
        end)
    end)

    describe("tempo", function()
        it("plays a note less often far from the exit than near it", function()
            assert.is_true(MusicScore.framesBetweenNotes(0) > MusicScore.framesBetweenNotes(1))
            assert.are.equal(MusicScore.SLOWEST_FRAMES, MusicScore.framesBetweenNotes(0))
            assert.are.equal(MusicScore.FASTEST_FRAMES, MusicScore.framesBetweenNotes(1))
        end)
    end)

    describe("glide", function()
        it("moves towards where it is going by a little each frame, and arrives", function()
            local value = 0
            value = MusicScore.glide(value, 1)
            assert.is_near(MusicScore.GLIDE_PER_FRAME, value, 0.0001)
            for _ = 1, 1000 do value = MusicScore.glide(value, 1) end
            assert.are.equal(1, value)
        end)

        it("glides downwards too", function()
            assert.is_near(1 - MusicScore.GLIDE_PER_FRAME, MusicScore.glide(1, 0), 0.0001)
        end)

        it("takes about a second to cross the gap between neighbouring cells of a medium maze", function()
            local frames = (1 / 20) / MusicScore.GLIDE_PER_FRAME
            assert.is_true(frames >= 15 and frames <= 60)
        end)
    end)

    describe("the tune", function()
        it("only ever uses the notes of a pentatonic scale, which cannot clash", function()
            local PENTATONIC <const> = { [0] = true, [3] = true, [5] = true, [7] = true, [10] = true }
            for step = 1, 200 do
                local midiNote = MusicScore.noteAt(step)
                assert.is_true(PENTATONIC[(midiNote - 57) % 12], "step " .. step .. " is outside A minor pentatonic")
                assert.is_true(midiNote >= 45 and midiNote <= 81)
            end
        end)

        it("wanders rather than repeating a short loop", function()
            local seen = {}
            for step = 1, 64 do seen[MusicScore.noteAt(step)] = true end
            local count = 0
            for _ in pairs(seen) do count = count + 1 end
            assert.is_true(count >= 6)
        end)

        it("is the same tune every time", function()
            assert.are.equal(MusicScore.noteAt(17), MusicScore.noteAt(17))
        end)
    end)
end)
