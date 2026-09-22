local mode = assert(playdate.argv[2], "Expected omitted, explicit, or fixed")
local seconds, milliseconds = playdate.getSecondsSinceEpoch()
if mode == "explicit" then
    math.randomseed(seconds, milliseconds)
elseif mode == "fixed" then
    math.randomseed(12345, 67890)
else
    assert(mode == "omitted", "Unknown seed mode")
end

local sequence = {}
for index = 1, 12 do
    sequence[index] = tostring(math.random(1, 1000000))
end
print("RNG_RESULT " .. mode .. " " .. seconds .. " " .. milliseconds .. " " .. table.concat(sequence, ","))
print("RNG_LUA " .. _VERSION)

local frames = 0
function playdate.update()
    frames = frames + 1
    if playdate.isSimulator and frames == 3 then playdate.simulator.exit() end
end
