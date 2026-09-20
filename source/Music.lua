-- Plays the ambient music: a slow wandering tune with long tails, which rises in pitch and
-- quickens as the player nears the exit, as the music in Osmos follows your speed. MusicScore
-- writes the tune and how it answers to the maze; ExitDistance says how near the exit is.

import "ExitDistance"
import "MusicScore"

local snd <const> = playdate.sound

Music = {}

local VOICES <const> = 3
local NOTE_VOLUME <const> = 0.16
local NOTE_SECONDS <const> = 0.9
-- Every so many notes, a low note sounds under the tune, this many semitones down
local BASS_EVERY <const> = 4
local BASS_DROP <const> = 12
local BASS_VOLUME <const> = 0.2
local BASS_SECONDS <const> = 1.6

-- 1 is full volume. The screenshot harness plays at 0, which still exercises all of this.
local masterVolume = 1
local voices = {}
for index = 1, VOICES do
    local synth = snd.synth.new(index == VOICES and snd.kWaveTriangle or snd.kWaveSine)
    -- A soft start and a long tail, so the notes run into each other
    synth:setADSR(0.12, 0.5, 0.4, 1.6)
    voices[index] = synth
end
local bass = snd.synth.new(snd.kWaveSine)
bass:setADSR(0.3, 0.8, 0.5, 2)

local distances, heard, step, framesUntilNote = nil, 0, 0, 0

function Music.setVolume(volume)
    masterVolume = volume
end

-- Call every frame of play. fixedProximity, from 0 to 1, overrides the maze: the screensaver
-- uses it to keep the music calm and level.
function Music.update(run, fixedProximity)
    if not distances or distances.maze ~= run.maze then
        distances = ExitDistance.new(run.maze)
        heard = fixedProximity or distances:proximity(run.player.x, run.player.y)
    end
    heard = MusicScore.glide(heard, fixedProximity or distances:proximity(run.player.x, run.player.y))

    framesUntilNote = framesUntilNote - 1
    if framesUntilNote > 0 then return end
    framesUntilNote = MusicScore.framesBetweenNotes(heard)
    step = step + 1
    local semitones = MusicScore.transposition(heard)
    local midiNote = MusicScore.noteAt(step)
    voices[step % VOICES + 1]:playNote(MusicScore.frequency(midiNote, semitones), NOTE_VOLUME * masterVolume, NOTE_SECONDS)
    if step % BASS_EVERY == 0 then
        bass:playNote(MusicScore.frequency(midiNote - BASS_DROP, semitones), BASS_VOLUME * masterVolume, BASS_SECONDS)
    end
end

function Music.stop()
    for _, synth in ipairs(voices) do synth:noteOff() end
    bass:noteOff()
    framesUntilNote = 0
end
