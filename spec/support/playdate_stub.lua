-- Minimal host-side stand-in for the Playdate runtime so pure game logic runs under plain Lua.

package.path = "source/?.lua;" .. package.path

local stub = { clockMilliseconds = 0, datastore = {}, writeCounts = {} }

-- Playdate's import runs a file once and returns nothing on later imports; mimic that so
-- specs fail the same way the device does when a module is imported twice.
local imported = {}
function import(name)
    if imported[name] then return nil end
    imported[name] = true
    return require(name)
end

playdate = {
    getCurrentTimeMilliseconds = function() return stub.clockMilliseconds end,
    getSecondsSinceEpoch = function() return 0 end,
    datastore = {
        write = function(value, name)
            stub.datastore[name] = value
            stub.writeCounts[name] = (stub.writeCounts[name] or 0) + 1
        end,
        read = function(name) return stub.datastore[name] end,
        delete = function(name) stub.datastore[name] = nil end,
    },
}

function stub.reset()
    stub.clockMilliseconds = 0
    stub.datastore = {}
    stub.writeCounts = {}
end

function stub.advanceSeconds(seconds)
    stub.clockMilliseconds = stub.clockMilliseconds + seconds * 1000
end

return stub
