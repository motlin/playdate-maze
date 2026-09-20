-- Plays the game's sounds on the Playdate's synths, from the notes SoundBook writes for each
-- event. Each wave has a few synths, used in turn, so notes that overlap do not cut each other off.

import "SoundBook"

local snd <const> = playdate.sound

Sounds = {}

local VOICES_PER_WAVE <const> = 4
local WAVES <const> = {
    sine = snd.kWaveSine,
    square = snd.kWaveSquare,
    triangle = snd.kWaveTriangle,
    noise = snd.kWaveNoise,
}

-- 1 is full volume. The screenshot harness plays at 0, which still exercises all of this.
local masterVolume = 1
local voices, nextVoice = {}, {}
for wave, waveform in pairs(WAVES) do
    voices[wave], nextVoice[wave] = {}, 1
    for index = 1, VOICES_PER_WAVE do
        local synth = snd.synth.new(waveform)
        synth:setADSR(0.003, 0.03, 0.6, 0.04)
        voices[wave][index] = synth
    end
end

function Sounds.setVolume(volume)
    masterVolume = volume
end

-- events is a list of event names, such as a Run's events for the frame
function Sounds.play(events)
    if #events == 0 then return end
    local now = snd.getCurrentTime()
    for _, event in ipairs(events) do
        for _, note in ipairs(SoundBook.notes(event)) do
            local wave = note.wave
            local synth = voices[wave][nextVoice[wave]]
            nextVoice[wave] = nextVoice[wave] % VOICES_PER_WAVE + 1
            synth:playNote(note.frequency, note.volume * masterVolume, note.seconds, now + note.delay)
        end
    end
end
