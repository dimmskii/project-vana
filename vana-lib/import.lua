-- Shared code for the other resources (docs/libraries.md): import(name) returns the source of
-- lib/<name>.lua, which the importing resource runs in its own Lua state:
--   loadstring(exports["vana-lib"]:import("sa_gxt"), "@vana-lib/lib/sa_gxt.lua")()
-- Each resource does that in its lib.lua, listed first in its meta.xml. vana-lib must start before
-- them (top of the startup list); restarting it reaches importers only when they restart.
local cache = {}

function import(name)
    if type(name) ~= "string" or not name:match("^[%w_]+$") then return false end
    if cache[name] == nil then
        local path = "lib/" .. name .. ".lua"
        local source = false
        if fileExists(path) then
            local f = fileOpen(path, true)
            if f then
                source = fileRead(f, fileGetSize(f))
                fileClose(f)
            end
        end
        cache[name] = source
    end
    return cache[name]
end
