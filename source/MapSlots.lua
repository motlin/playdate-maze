-- The four places on the Playdate's disk where hand-made maps are kept, lettered A to D.

import "MapDesign"


---@class MapSlots
MapSlots = {}

MapSlots.NAMES = { "A", "B", "C", "D" }

local isSlot <const> = { A = true, B = true, C = true, D = true }

---@param name string
---@return string
function MapSlots.fileFor(name)
    assert(isSlot[name], "there is no map slot " .. tostring(name))
    return "map-" .. name
end

-- A map from a version of the game that cannot read it is thrown away, so that the slot reads as
-- empty instead of crashing the list of maps
---@param name string
---@return MapDesign?
function MapSlots.read(name)
    local save = playdate.datastore.read(MapSlots.fileFor(name))
    if not save then return nil end
    if save.version ~= MapDesign.SAVE_VERSION then
        MapSlots.delete(name)
        return nil
    end
    return MapDesign.fromSave(save)
end

---@param name string
---@return boolean
function MapSlots.exists(name)
    return MapSlots.read(name) ~= nil
end

---@param name string
---@param design MapDesign
---@return nil
function MapSlots.write(name, design)
    playdate.datastore.write(design:toSave(), MapSlots.fileFor(name))
end

---@param name string
---@return nil
function MapSlots.delete(name)
    playdate.datastore.delete(MapSlots.fileFor(name))
end
