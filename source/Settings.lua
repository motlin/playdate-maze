-- The player's choices that outlast a game, kept on the Playdate's disk. So far: whether the
-- music plays.

Settings = {}

Settings.FILE = "settings"

local isMusicOn = true

-- Call once when the game starts
function Settings.load()
    local saved = playdate.datastore.read(Settings.FILE)
    isMusicOn = saved == nil or saved.isMusicOn
end

function Settings.isMusicOn() return isMusicOn end

function Settings.setMusicOn(isOn)
    if isOn == isMusicOn then return end
    isMusicOn = isOn
    playdate.datastore.write({ isMusicOn = isOn }, Settings.FILE)
end
