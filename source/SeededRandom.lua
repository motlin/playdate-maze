-- A random number generator that gives the same numbers on the Playdate as on a computer, so a
-- seed means the same maze everywhere. The Playdate's integers are 32 bits, so this is the
-- Park-Miller minimal standard generator worked with Schrage's method, which never overflows them.

SeededRandom = {}

local MODULUS <const> = 2147483647
local MULTIPLIER <const> = 16807
local QUOTIENT <const> = MODULUS // MULTIPLIER
local REMAINDER <const> = MODULUS % MULTIPLIER
-- Neighbouring seeds start out giving similar numbers, so the first few are thrown away
local WARM_UP <const> = 20

function SeededRandom.advance(state)
    local next = MULTIPLIER * (state % QUOTIENT) - REMAINDER * (state // QUOTIENT)
    if next <= 0 then next = next + MODULUS end
    return next
end

-- Returns random(n), which gives a whole number from 1 to n like math.random
function SeededRandom.new(seed)
    assert(math.type(seed) == "integer" and seed >= 1 and seed < MODULUS, "the seed must be a whole number from 1 to 2147483646")
    local state = seed
    for _ = 1, WARM_UP do state = SeededRandom.advance(state) end
    return function(n)
        state = SeededRandom.advance(state)
        -- The high bits are the most random ones
        return (state // 65536) % n + 1
    end
end

function SeededRandom.seedForDate(year, month, day)
    return year * 10000 + month * 100 + day
end
