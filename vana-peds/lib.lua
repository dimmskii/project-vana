-- Shared code from vana-lib (docs/libraries.md), run in this resource: listed first in meta.xml.
local modules = localPlayer and { "debug" } or { "settings", "train_crossings" }
for _, name in ipairs(modules) do
    local source = exports["vana-lib"]:import(name)
    if not source then error("vana-peds: can't import " .. name .. " (is vana-lib running? see docs/libraries.md)", 0) end
    assert(loadstring(source, "@vana-lib/lib/" .. name .. ".lua"))()
end
