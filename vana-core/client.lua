-- Players' script errors and warnings, sent to the server log (server.lua): client errors otherwise
-- only show in that player's own debug view, so nobody running the server sees them.
local sent, windowStart = 0, 0
local last = {} -- message -> tick it was last sent

addEventHandler("onClientDebugMessage", root, function(message, level, file, line)
    if level ~= 1 and level ~= 2 then return end
    local now = getTickCount()
    if now - windowStart > 10000 then sent, windowStart = 0, now end
    local text = ("%s%s: %s"):format(file or "?", line and (":" .. line) or "", message)
    if sent >= 20 or (last[text] and now - last[text] < 5000) then return end
    sent, last[text] = sent + 1, now
    triggerServerEvent("vana-core:clientError", resourceRoot, level == 1 and "ERROR" or "WARNING", text:sub(1, 300))
end)
