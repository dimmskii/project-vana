-- Dancing and the lowrider contest on this client: run the rhythm game on the server's clock (the
-- routine's beats are times on it, as vana-radio's speakers play it), report each dance beat (for the
-- moves everyone sees) and the score.

-- The server's clock, from vana-radio's sync, refreshed each second.
local function serverClock()
    local offset, refreshed = 0, nil
    return function()
        local now = getTickCount()
        if not refreshed or now - refreshed > 1000 then
            refreshed = now
            local ok, t = pcall(function() return exports["vana-radio"]:getServerTime() end)
            if ok and t then offset = t - now end
        end
        return now + offset
    end
end

addEvent("vana-dance:start", true)
addEventHandler("vana-dance:start", resourceRoot, function(kind, opts)
    if not kind then return Rhythm.stop() end
    if opts.serverClock then opts.clock = serverClock() end
    if kind == "dance" then
        opts.onJudge = function(grade) triggerServerEvent("vana-dance:beat", resourceRoot, grade) end
    end
    Rhythm.start(opts, function(share, points) triggerServerEvent("vana-dance:done", resourceRoot, share, points) end)
end)
