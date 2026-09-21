-- Detached snapshots of acyclic save data: scalar values and plain tables with scalar keys.
SaveData = {}

---@generic T
---@param value T
---@return T
function SaveData.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do
        result[key] = SaveData.copy(item)
    end
    return result
end
