local Adapter = {}
function Adapter.new(settings)
    local studio = game:GetService("RunService"):IsStudio()
    if studio and (not settings.studioEnabled or settings.studioUniverseId <= 0 or game.GameId ~= settings.studioUniverseId) then
        return {mode = "DisabledStudio", update = function() error("Studio persistence is disabled; use the isolated test fixture") end}
    end
    local name = if studio then settings.studioStoreName else settings.storeName
    assert(not studio or name ~= settings.storeName, "Studio must use a separate namespace")
    local store = game:GetService("DataStoreService"):GetDataStore(name)
    return {mode = if studio then "IsolatedDataStore" else "DataStore", update = function(_, key, transform)
        return store:UpdateAsync(key, transform)
    end}
end
return Adapter
