-- Plays the game's sounds on the Playdate's synths, from the notes SoundBook writes for each
-- event. Each wave has a few synths, used in turn, so notes that overlap do not cut each other off.

import "Hum"
import "SoundBook"

Sounds = {}
local humLevels = {}

local VOICES_PER_WAVE <const> = 4
local WAVES <const> = {
    sine = playdate.sound.kWaveSine,
    square = playdate.sound.kWaveSquare,
    triangle = playdate.sound.kWaveTriangle,
    noise = playdate.sound.kWaveNoise,
}

-- 1 is full volume. The screenshot harness plays at 0, which still exercises all of this.
local masterVolume = 1
local voices, nextVoice = {}, {}
for wave, waveform in pairs(WAVES) do
    voices[wave], nextVoice[wave] = {}, 1
    for index = 1, VOICES_PER_WAVE do
        local synth = playdate.sound.synth.new(waveform)
        synth:setADSR(0.003, 0.03, 0.6, 0.04)
        voices[wave][index] = synth
    end
end

function Sounds.setVolume(volume) masterVolume = volume end

-- events is a list of event names, such as a Run's events for the frame
function Sounds.play(events)
    if #events == 0 then return end
    local now = playdate.sound.getCurrentTime()
    for _, event in ipairs(events) do
        for _, note in ipairs(SoundBook.notes(event)) do
            local wave = note.wave
            local synth = voices[wave][nextVoice[wave]]
            nextVoice[wave] = nextVoice[wave] % VOICES_PER_WAVE + 1
            synth:playNote(note.frequency, note.volume * masterVolume, note.seconds, now + note.delay)
        end
    end
end

-- One held note for each shape, made the first time it is needed
local hums = {}

local function humFor(shape)
    local synth = hums[shape]
    if not synth then
        synth = playdate.sound.synth.new(playdate.sound.kWaveSine)
        -- A slow swell, so a hum never clicks in or out
        synth:setADSR(0.4, 0, 1, 0.4)
        hums[shape] = synth
    end
    return synth
end

-- Call every frame of the 3D maze: sets how loudly each shape hums in each ear
function Sounds.hum(game)
    if not game.puzzle then return end
    local player, items = game.player, game.puzzle.items
    for index, level in ipairs(Hum.levels(player.x, player.y, player.angle, items, humLevels)) do
        local shape = items[index].shape
        local synth = humFor(shape)
        if level.left + level.right > 0 then
            if not synth:isPlaying() then synth:playNote(Hum.FREQUENCIES[shape], 1) end
            synth:setVolume(level.left * masterVolume, level.right * masterVolume)
        elseif synth:isPlaying() then
            synth:noteOff()
        end
    end
end

function Sounds.stopHum()
    for _, synth in pairs(hums) do
        synth:noteOff()
    end
end
