-- Shared code from vana-lib (docs/libraries.md), run in this resource: listed first in meta.xml.
local modules = localPlayer and { "map_data", "prompts", "sa_reader", "sa_txd", "menu_input", "menu_list" } or { "sa_reader", "sa_dat", "map_data", "map_points", "text", "prompts", "actions" }
for _, name in ipairs(modules) do
    local source = exports["vana-lib"]:import(name)
    if not source then error("vana-shops: can't import " .. name .. " (is vana-lib running? see docs/libraries.md)", 0) end
    assert(loadstring(source, "@vana-lib/lib/" .. name .. ".lua"))()
end
