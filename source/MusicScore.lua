-- The tune and how it answers to the maze. Like the music in Osmos, which speeds up and rises
-- with your speed, this rises in pitch and quickens as you get nearer the exit: `proximity` runs
-- from 0, as far away as the maze allows, to 1 beside the exit. Music plays what this writes.

MusicScore = {}

-- An octave up by the time the exit is reached
local OCTAVE <const> = 12
MusicScore.SLOWEST_FRAMES = 26
MusicScore.FASTEST_FRAMES = 12
-- How far the music's idea of proximity may move in a frame, so that walking into the next cell
-- is heard as a glide and not a jump
MusicScore.GLIDE_PER_FRAME = 0.002

-- A minor pentatonic from the A below middle C: any of these notes sound well together
local SCALE <const> = { 57, 60, 62, 64, 67, 69, 72, 74, 76 }
-- Steps up and down the scale, of different lengths, so that the tune takes a long time to repeat
local WALK <const> = { 2, 1, -2, 3, -1, -2, 2, -3, 1, 2, -1, -2, 1 }
local SWAY <const> = { 0, 1, 0, -1, 1, 0, -1 }

local WALK_PREFIX <const> = { [0] = 0 }
for index, offset in ipairs(WALK) do WALK_PREFIX[index] = WALK_PREFIX[index - 1] + offset end

function MusicScore.transposition(proximity)
    return OCTAVE * proximity
end

function MusicScore.frequency(midiNote, semitones)
    return 440 * 2 ^ ((midiNote - 69 + semitones) / 12)
end

function MusicScore.framesBetweenNotes(proximity)
    local frames = MusicScore.SLOWEST_FRAMES + (MusicScore.FASTEST_FRAMES - MusicScore.SLOWEST_FRAMES) * proximity
    return math.floor(frames + 0.5)
end

function MusicScore.glide(current, target)
    local step = MusicScore.GLIDE_PER_FRAME
    if math.abs(target - current) <= step then return target end
    return current + (target > current and step or -step)
end

-- The MIDI note of the tune's step-th note, counting from 1
function MusicScore.noteAt(step)
    local position = (step // #WALK) * WALK_PREFIX[#WALK] + WALK_PREFIX[step % #WALK]
    position = position + SWAY[(step - 1) % #SWAY + 1]
    -- Fold the walk back and forth across the scale rather than letting it run off either end
    local span = #SCALE - 1
    local folded = position % (2 * span)
    if folded > span then folded = 2 * span - folded end
    return SCALE[folded + 1]
end
