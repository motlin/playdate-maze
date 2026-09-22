local function loadSounds()
    local clock, synths, played = 0, {}, {}
    local sound = { kWaveSine = "sine", kWaveSquare = "square", kWaveTriangle = "triangle", kWaveNoise = "noise" }
    sound.getCurrentTime = function() return clock end
    sound.synth = {
        new = function(wave)
            local synth = {}
            function synth:setADSR(_, _, _, release) self.release = release end
            function synth:playNote(frequency, volume, seconds, when)
                -- The SDK replaces a pending note, even if isPlaying() is false.
                self.pending = { wave, frequency, volume, seconds, when }
                return true
            end
            function synth:isPlaying() return self.endsAt ~= nil and clock < self.endsAt end
            synths[#synths + 1] = synth
            return synth
        end,
    }
    local environment = setmetatable({ playdate = { sound = sound }, import = function() end }, { __index = _G })
    assert(loadfile("source/SoundBook.lua", "t", environment))()
    assert(loadfile("source/Sounds.lua", "t", environment))()
    local function advance(time)
        clock = time
        for _, synth in ipairs(synths) do
            local pending = synth.pending
            if pending and pending[5] <= clock then
                played[#played + 1] = pending
                synth.endsAt = pending[5] + pending[4] + synth.release
                synth.pending = nil
            end
        end
        table.sort(played, function(left, right)
            if left[5] ~= right[5] then return left[5] < right[5] end
            if left[1] ~= right[1] then return left[1] < right[1] end
            return left[2] < right[2]
        end)
        return played
    end
    return environment.Sounds, environment.SoundBook, advance, synths
end

describe("sound scheduling", function()
    for _, event in ipairs({ "flip", "unlock", "gateOpen", "escape", "exitOpen" }) do
        it("preserves every note and its timing for " .. event, function()
            local sounds, book, advance = loadSounds()
            sounds.play({ event })
            local expected = {}
            for _, note in ipairs(book.notes(event)) do
                expected[#expected + 1] = { note.wave, note.frequency, note.volume, note.seconds, note.delay }
                assert.are.same(expected, advance(note.delay))
            end
            assert.are.same(expected, advance(1))
        end)
    end

    it("preserves overlapping effects between calls and during paused scene updates", function()
        local sounds, book, advance = loadSounds()
        sounds.setVolume(0.5)
        sounds.play({ "gateOpen", "escape" })
        advance(0.05)
        sounds.play({ "gateOpen", "escape" })
        sounds.stopHum()
        local expected = {}
        for _, start in ipairs({ 0, 0.05 }) do
            for _, event in ipairs({ "gateOpen", "escape" }) do
                for _, note in ipairs(book.notes(event)) do
                    expected[#expected + 1] = {
                        note.wave,
                        note.frequency,
                        note.volume * 0.5,
                        note.seconds,
                        start + note.delay,
                    }
                end
            end
        end
        table.sort(expected, function(left, right)
            if left[5] ~= right[5] then return left[5] < right[5] end
            return left[2] < right[2]
        end)
        assert.are.same(expected, advance(1))
    end)

    it("reserves playing release tails and reuses voices after they finish", function()
        local sounds, _, advance, synths = loadSounds()
        sounds.play({ "flip" })
        advance(0.06)
        sounds.play({ "flip" })
        assert.are.equal(14, #synths)
        advance(1)
        sounds.play({ "flip", "flip" })
        assert.are.equal(14, #synths)
    end)
end)
