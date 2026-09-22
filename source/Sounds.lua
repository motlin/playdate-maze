-- Plays the game's sounds on the Playdate's synths, from the notes SoundBook writes for each
-- event. Each pending or playing note reserves a synth until its release finishes.

import "Hum"
import "SoundBook"

Sounds = {}
local humLevels = {}

local RELEASE_SECONDS <const> = 0.04
local WAVES <const> = {
    sine = playdate.sound.kWaveSine,
    square = playdate.sound.kWaveSquare,
    triangle = playdate.sound.kWaveTriangle,
    noise = playdate.sound.kWaveNoise,
}

-- 1 is full volume. The screenshot harness plays at 0, which still exercises all of this.
local masterVolume = 1
local voices = { sine = {}, square = {}, triangle = {}, noise = {} }

local function reserveVoice(wave, now, finishesAt)
    for _, voice in ipairs(voices[wave]) do
        if voice.finishesAt <= now and not voice.synth:isPlaying() then
            voice.finishesAt = finishesAt
            return voice.synth
        end
    end
    local synth = playdate.sound.synth.new(WAVES[wave])
    synth:setADSR(0.003, 0.03, 0.6, RELEASE_SECONDS)
    table.insert(voices[wave], { synth = synth, finishesAt = finishesAt })
    return synth
end

function Sounds.setVolume(volume) masterVolume = volume end

-- Finite effects finish on the sound clock, including across scene switches or paused updates.
-- events is a list of event names, such as a Run's events for the frame
function Sounds.play(events)
    if #events == 0 then return end
    local now = playdate.sound.getCurrentTime()
    for _, event in ipairs(events) do
        for _, note in ipairs(SoundBook.notes(event)) do
            local finishesAt = now + note.delay + note.seconds + RELEASE_SECONDS
            local synth = reserveVoice(note.wave, now, finishesAt)
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
