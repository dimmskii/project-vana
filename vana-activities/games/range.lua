-- Ammu-Nation shooting range (vanilla SHRANGE): walk into the range at any of the four Ammu-Nations
-- with a range and take the next weapon challenge (pistol, micro SMG, shotgun, AK47): three rounds against
-- two rivals, judged on your client (games/range_client.lua). Passing raises that weapon's skill; all
-- four earn vanilla's fast reload (recorded: MTA has no control for it).
local G = Games.range

local function nextWeapon(player)
    for i in ipairs(G.weapons) do
        if not Activity.progress(player, "range." .. i) then return i end
    end
end

Activity.perk("fastreload", function() end)

Activity.register("range", {
    title = "Shooting Range",
    start = function(session, rangeIndex, weaponIndex)
        local r = G.ranges[rangeIndex]
        local w = G.weapons[weaponIndex]
        local d = session.data
        local player = session.player
        d.range, d.weapon = rangeIndex, weaponIndex
        d.dim = Activity.dimension(player)
        setElementInterior(player, r.interior)
        setElementDimension(player, d.dim)
        setElementPosition(player, r.booth[1], r.booth[2], r.booth[3] + 1)
        setElementRotation(player, 0, 0, r.heading, "default", true)
        setElementFrozen(player, true)
        d.hadWeapon = getPedWeapon(player, getSlotFromWeapon(w.weapon))
        giveWeapon(player, w.weapon, 9999, true)
        session:help(Activity.text("ANR_7"))
        triggerClientEvent(player, "vana-range:run", resourceRoot, rangeIndex, weaponIndex, d.dim)
    end,
    stop = function(session)
        local player = session.player
        local d = session.data
        if not isElement(player) then return end
        triggerClientEvent(player, "vana-range:run", resourceRoot, nil)
        setElementFrozen(player, false)
        local r = G.ranges[d.range]
        setElementDimension(player, 0)
        setElementPosition(player, r.entry[1], r.entry[2], r.entry[3] + 1)
    end,
})

addEvent("vana-range:round", true)
addEventHandler("vana-range:round", resourceRoot, function(round, won)
    local session = Activity.of(client)
    if not session or session.name ~= "range" or type(round) ~= "number" then return end
    local d = session.data
    if not won then return session:fail("ANR_16") end
    if round < 3 then
        session:big(Activity.text(({ "ANR_41", "ANR_42" })[round]), 3000, "small")
        return
    end
    local w = G.weapons[d.weapon]
    local player = session.player
    local first = not Activity.progress(player, "range." .. d.weapon)
    Activity.setProgress(player, "range." .. d.weapon, true)
    setPedStat(player, w.stat, math.min(1000, getPedStat(player, w.stat) + G.skillGain + (first and G.skillBonus or 0)))
    session:big(Activity.text(w.passed), 4000, "passed")
    if nextWeapon(player) then
        session:after(4000, function(s) s:help(Activity.text("ANR_44")) end)
    elseif Activity.grantPerk(player, "fastreload") then
        session:after(4000, function(s) s:help(Activity.text("ANR_45") .. "~n~" .. Activity.text("ANR_54")) end)
    end
    session:after(4500, function(s) s:stop("passed") end)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for i, r in ipairs(G.ranges) do
        local m = createMarker(r.entry[1], r.entry[2], r.entry[3] - 0.1, "cylinder", 1.2, 255, 200, 0, 120)
        setElementInterior(m, r.interior)
        addEventHandler("onMarkerHit", m, function(player, matching)
            if not matching or getElementType(player) ~= "player" or Activity.of(player) then return end
            local items = {}
            for wi, w in ipairs(G.weapons) do
                local done = Activity.progress(player, "range." .. wi)
                local open = wi == 1 or Activity.progress(player, "range." .. (wi - 1))
                items[wi] = { label = Activity.text(w.rounds[1]):gsub("~n~.*", ""), right = done and "passed" or (open and "" or "locked"), enabled = open and true or false }
            end
            Activity.menu(player, Activity.text("ANR_1"), items, function(p, wi)
                if not Activity.of(p) then Activity.start(p, "range", i, wi) end
            end)
        end)
    end
end)

Activity.test("range", function()
    return Gxt.raw("ANR_7") ~= nil and #G.ranges == 4, "4 ranges, 4 weapons"
end)
