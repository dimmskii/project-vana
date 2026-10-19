-- BMX and NRG-500 stunt challenges (vanilla STUNT): ride the course's bike onto its marker and press enter/exit, then collect
-- every corona before the clock runs out: 11 s to start, +10 s for each corona. First completion pays
-- $1000; best times are saved ("stunt.<course>.time").
local S = Racing.stunts

Activity.register("stunt", {
    title = "Stunt",
    gxt = "STUNT",
    start = function(session, key)
        local course = S[key]
        local d = session.data
        d.key, d.coronas, d.left = key, {}, #course.coronas
        for i, c in ipairs(course.coronas) do d.coronas[i] = { c[1], c[2], c[3], 1 } end
        d.deadline, d.started = getTickCount() + S.startMs, getTickCount()
        session:say(session:text("STUNT_6"), 5000)
        session:counter("time", session:text("STUNT_2"), S.startMs, "timer")
        triggerClientEvent(session.player, "vana-stadium:coronas", resourceRoot, d.coronas, 0, 0)
        session:every(250, function(s)
            local dd = s.data
            local v = getPedOccupiedVehicle(s.player)
            if not v or getElementModel(v) ~= course.bike then return s:fail("STUNT_7") end
            if getTickCount() > dd.deadline then return s:fail("STUNT_7") end
        end)
    end,
    onCorona = function(session, c)
        local d = session.data
        d.left = d.left - 1
        d.deadline = d.deadline + S.perCoronaMs
        session:counter("time", session:text("STUNT_2"), d.deadline - getTickCount(), "timer")
        session:big(session:text("STUNT_3", S.perCoronaMs / 1000), 1500, "small")
        if d.left <= 0 then
            local player = session.player
            local elapsed = getTickCount() - d.started
            local key = "stunt." .. d.key
            local best = Activity.progress(player, key .. ".time")
            if not best or elapsed < best then Activity.setProgress(player, key .. ".time", elapsed) end
            local first = not Activity.progress(player, key .. ".done")
            Activity.setProgress(player, key .. ".done", true)
            session:pass(nil, first and S.prize or 0)
        end
    end,
    stop = function(session)
        if isElement(session.player) then triggerClientEvent(session.player, "vana-stadium:coronas", resourceRoot, nil) end
    end,
})

addEventHandler("onResourceStart", resourceRoot, function()
    for key, p in pairs(S.entries) do
        local m = createMarker(p[1], p[2], p[3] - 0.5, "cylinder", 4, 255, 200, 0, 110)
        Prompts.add(m, { text = "start the stunt challenge", vehicle = true, use = function(player)
            local v = getPedOccupiedVehicle(player)
            if v and getElementModel(v) == S[key].bike and not Activity.of(player) then Activity.start(player, "stunt", key) end
        end })
    end
end)

Activity.test("stunts", function()
    return #S.bmx.coronas == 19 and #S.nrg.coronas >= 18 and Gxt.raw("STUNT_6", "STUNT") ~= nil,
        ("BMX %d, NRG %d coronas"):format(#S.bmx.coronas, #S.nrg.coronas)
end)
