-- What every event in the game sounds like, written as notes for a synth: which wave, what
-- frequency, how loud (0 to 1), how long in seconds, and how long after the event to start.
-- This is only the sheet music; Sounds plays it.

SoundBook = {}

-- The waves a note may ask for. Sounds gives each its own synths.
SoundBook.WAVES = { sine = true, square = true, triangle = true, noise = true }

local function note(wave, frequency, volume, seconds, delay)
    return { wave = wave, frequency = frequency, volume = volume, seconds = seconds, delay = delay or 0 }
end

-- A run of notes of one wave, each starting as the one before it ends
local function run(wave, frequencies, volume, seconds)
    local notes = {}
    for index, frequency in ipairs(frequencies) do
        notes[index] = note(wave, frequency, volume, seconds, (index - 1) * seconds)
    end
    return notes
end

local C4 <const>, E4 <const>, G4 <const> = 261.63, 329.63, 392.00
local C5 <const>, E5 <const>, G5 <const>, C6 <const> = 523.25, 659.25, 783.99, 1046.50

local BOOK <const> = {
    -- Walking the 3D maze
    step = { note("noise", 110, 0.18, 0.04) },
    bump = { note("square", 70, 0.4, 0.09) },
    pickUp = run("triangle", { G4, C5 }, 0.5, 0.06),
    drop = run("triangle", { C5, G4 }, 0.45, 0.06),
    blocked = run("square", { 180, 120 }, 0.3, 0.08),
    place = run("triangle", { C5, E5, G5 }, 0.55, 0.08),
    unlock = run("square", { C4, E4, G4, C5, E5 }, 0.4, 0.09),
    gateNotch = { note("noise", 900, 0.3, 0.025), note("square", 95, 0.25, 0.03) },
    gateOpen = run("triangle", { G4, C5, E5, G5, C6 }, 0.55, 0.1),
    reel = { note("triangle", 1200, 0.2, 0.02) },
    flip = run("sine", { 880, 660, 440, 330, 440, 660, 880 }, 0.45, 0.05),
    escape = run("triangle", { C5, E5, G5, C6, G5, C6 }, 0.6, 0.11),

    -- Tumble
    jump = run("square", { 300, 520 }, 0.3, 0.05),
    land = { note("noise", 140, 0.3, 0.05) },
    collect = run("triangle", { E5, G5, C6 }, 0.5, 0.06),
    exitOpen = run("triangle", { C5, G5, C6, G5, C6 }, 0.55, 0.09),

    -- Slime
    throw = run("sine", { 220, 330, 520 }, 0.4, 0.04),
    splat = { note("noise", 260, 0.4, 0.06), note("sine", 120, 0.35, 0.08) },
    slip = run("sine", { 420, 300, 210 }, 0.3, 0.07),
    letGo = run("sine", { 330, 240 }, 0.3, 0.05),
}

function SoundBook.notes(event) return BOOK[event] or error("no sound for the event '" .. tostring(event) .. "'") end
