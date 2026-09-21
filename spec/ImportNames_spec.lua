-- The Playdate compiler looks for an import next to the importing file before it looks in the
-- source root. So scenes/Foo.lua saying `import "Foo"` imports itself, the real Foo never loads,
-- and the game crashes on the console and in the Simulator while every spec here still passes.

local function sourceFiles()
    local files = {}
    local listing = assert(io.popen("find source -name '*.lua'"))
    for path in listing:lines() do
        files[#files + 1] = path
    end
    listing:close()
    return files
end

describe("source file names", function()
    it("finds the source files", function() assert.is_true(#sourceFiles() > 10) end)

    it("are unique across folders, so an import can never resolve to the wrong file", function()
        local pathsByName, clashes = {}, {}
        for _, path in ipairs(sourceFiles()) do
            local name = path:match("([^/]+)%.lua$")
            if pathsByName[name] then clashes[#clashes + 1] = pathsByName[name] .. " and " .. path end
            pathsByName[name] = path
        end
        assert.are.same({}, clashes)
    end)
end)
