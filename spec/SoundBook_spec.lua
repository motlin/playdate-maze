require("spec.support.playdate_stub")
import "SoundBook"

-- Every event name that any source file reports with emit("...")
local function emittedEvents()
    local events, seen = {}, {}
    local listing = assert(io.popen("find source -name '*.lua'"))
    for path in listing:lines() do
        local file = assert(io.open(path))
        for event in file:read("a"):gmatch("emit%(\"(%w+)\"%)") do
            if not seen[event] then
                seen[event] = true
                events[#events + 1] = event
            end
        end
        file:close()
    end
    listing:close()
    return events
end

describe("SoundBook", function()
    it("finds the events the game reports", function() assert.is_true(#emittedEvents() >= 15) end)

    it("has a sound for every event any mode reports", function()
        for _, event in ipairs(emittedEvents()) do
            assert.is_not_nil(SoundBook.notes(event), "no sound for the event '" .. event .. "'")
        end
    end)

    it("refuses an event it has never heard of, rather than staying silent", function()
        assert.has_error(function() SoundBook.notes("kazoo") end)
    end)

    it("writes every note so that a synth can play it", function()
        for _, event in ipairs(emittedEvents()) do
            local notes = SoundBook.notes(event)
            assert.is_true(#notes >= 1)
            for _, note in ipairs(notes) do
                assert.is_not_nil(SoundBook.WAVES[note.wave], event .. " uses an unknown wave")
                assert.is_true(note.frequency >= 40 and note.frequency <= 4000)
                assert.is_true(note.volume > 0 and note.volume <= 1)
                assert.is_true(note.seconds > 0 and note.seconds <= 1)
                assert.is_true(note.delay >= 0 and note.delay <= 1)
            end
        end
    end)

    it("keeps the sounds that repeat all the time quiet and short", function()
        for _, event in ipairs({ "step", "reel", "gateNotch" }) do
            for _, note in ipairs(SoundBook.notes(event)) do
                assert.is_true(note.volume <= 0.35)
                assert.is_true(note.seconds <= 0.08)
            end
        end
    end)

    it("makes good news rise and bad news fall", function()
        local function direction(event)
            local notes = SoundBook.notes(event)
            return notes[#notes].frequency - notes[1].frequency
        end
        assert.is_true(direction("place") > 0)
        assert.is_true(direction("unlock") > 0)
        assert.is_true(direction("escape") > 0)
        assert.is_true(direction("blocked") < 0)
        assert.is_true(direction("slip") < 0)
    end)
end)
