addEventHandler("onResourceStart", resourceRoot, function()
    outputServerLog("[vana-core] started on " .. getServerName() .. " (MTA " .. getVersion().sortable .. ")")
end)

-- Players' script errors and warnings (client.lua), at most 30 a minute from each.
local counts = {} -- player -> { n, since }
addEvent("vana-core:clientError", true)
addEventHandler("vana-core:clientError", resourceRoot, function(kind, text)
    if type(kind) ~= "string" or type(text) ~= "string" then return end
    local now = getTickCount()
    local c = counts[client]
    if not c or now - c.since > 60000 then c = { n = 0, since = now } counts[client] = c end
    c.n = c.n + 1
    if c.n > 30 then return end
    outputServerLog(("[client %s] %s: %s"):format(getPlayerName(client):gsub("#%x%x%x%x%x%x", ""), kind == "ERROR" and "ERROR" or "WARNING", text:sub(1, 300)))
end)
addEventHandler("onPlayerQuit", root, function() counts[source] = nil end)
