-- The vehicle registry: every car a player gets into is remembered ("kept") and persisted exactly,
-- damage, fuel and radio included, until it falls off the end of each player's list of recent cars.
-- The last player to drive a car holds it; a car no player drove is held by its last player passengers.
-- Kept cars stay in the world (other resources must not clean them up: see isKept), and come back
-- after a restart, or straight away when something destroys one.
local C = VehicleConfig

local db
local records = {}  -- vid -> { vehicle, holders = { serial = true }, kind = "driver" | "passengers", saved }
local vids = {}     -- vehicle -> vid
local lists = {}    -- serial -> { vid, ... }, most recently used first
local dropped = {}  -- vehicles no longer kept, cleaned up once empty with nobody near
local stopping = false

local function serialOf(player) return getPlayerSerial(player) end

-- Vehicles whose lifetime another resource manages (mission cars, owned reward cars) aren't registered.
local function managed(vehicle)
    return getElementData(vehicle, "vana:managed") or getElementData(vehicle, "vana:owner")
end

function isKept(vehicle)
    return vids[vehicle] ~= nil
end

-- Snapshot: everything about a car the server knows, enough to rebuild it exactly.
local function snapshot(vehicle)
    local x, y, z = getElementPosition(vehicle)
    local rx, ry, rz = getElementRotation(vehicle)
    local v1, v2 = getVehicleVariant(vehicle)
    local s = {
        model = getElementModel(vehicle), pos = { x, y, z }, rot = { rx, ry, rz },
        interior = getElementInterior(vehicle), dimension = getElementDimension(vehicle),
        variant = { v1, v2 }, plate = getVehiclePlateText(vehicle),
        colors = { getVehicleColor(vehicle, true) }, paintjob = getVehiclePaintjob(vehicle),
        upgrades = getVehicleUpgrades(vehicle), headlights = { getVehicleHeadLightColor(vehicle) },
        health = getElementHealth(vehicle), blown = isVehicleBlown(vehicle),
        panels = {}, doors = {}, doorRatios = {}, lights = {}, wheels = { getVehicleWheelStates(vehicle) },
        engine = getVehicleEngineState(vehicle), overrideLights = getVehicleOverrideLights(vehicle),
        locked = isVehicleLocked(vehicle), sirens = getVehicleSirensOn(vehicle),
        taxiLight = isVehicleTaxiLightOn(vehicle), landingGear = getVehicleLandingGearDown(vehicle),
        damageProof = isVehicleDamageProof(vehicle), frozen = isElementFrozen(vehicle), alpha = getElementAlpha(vehicle),
        fuel = getElementData(vehicle, "vana:fuel"), radio = getElementData(vehicle, "vana:radio"),
        dashboard = getElementData(vehicle, "vana:dashboard"),
        handling = {},
    }
    for i = 0, 6 do s.panels[i + 1] = getVehiclePanelState(vehicle, i) end
    for i = 0, 5 do
        s.doors[i + 1] = getVehicleDoorState(vehicle, i)
        s.doorRatios[i + 1] = getVehicleDoorOpenRatio(vehicle, i)
    end
    for i = 0, 3 do s.lights[i + 1] = getVehicleLightState(vehicle, i) end
    -- Only handling that differs from the model's (tuning, scripts).
    local original = getOriginalHandling(s.model)
    for key, value in pairs(getVehicleHandling(vehicle)) do
        if type(value) ~= "table" and value ~= original[key] then s.handling[key] = value end
    end
    local trailer = getVehicleTowedByVehicle(vehicle)
    s.trailer = trailer and vids[trailer] or nil
    -- In a mod garage (vana-shops): kept as it will leave, in the doorway with what was bought, not
    -- in the garage's own dimension wearing whatever is being tried on.
    local garage = getElementData(vehicle, "vana:garage")
    if type(garage) == "table" then
        s.pos, s.rot, s.interior, s.dimension, s.frozen = garage.pos, { 0, 0, garage.heading }, 0, 0, false
        s.upgrades, s.paintjob, s.colors, s.locked = garage.upgrades, garage.paintjob, garage.colors, garage.locked
    end
    return s
end

local function build(s)
    local vehicle = createVehicle(s.model, s.pos[1], s.pos[2], s.pos[3], s.rot[1], s.rot[2], s.rot[3], s.plate, false,
        s.variant[1], s.variant[2])
    if not vehicle then return false end
    setElementInterior(vehicle, s.interior)
    setElementDimension(vehicle, s.dimension)
    setVehicleColor(vehicle, unpack(s.colors))
    if s.paintjob and s.paintjob ~= 3 then setVehiclePaintjob(vehicle, s.paintjob) end
    for _, upgrade in ipairs(s.upgrades or {}) do addVehicleUpgrade(vehicle, upgrade) end
    setVehicleHeadLightColor(vehicle, unpack(s.headlights))
    for key, value in pairs(s.handling or {}) do setVehicleHandling(vehicle, key, value) end
    setElementHealth(vehicle, s.health)
    for i, state in ipairs(s.panels) do setVehiclePanelState(vehicle, i - 1, state) end
    for i, state in ipairs(s.doors) do setVehicleDoorState(vehicle, i - 1, state) end
    for i, ratio in ipairs(s.doorRatios) do setVehicleDoorOpenRatio(vehicle, i - 1, ratio) end
    for i, state in ipairs(s.lights) do setVehicleLightState(vehicle, i - 1, state) end
    setVehicleWheelStates(vehicle, unpack(s.wheels))
    setVehicleEngineState(vehicle, s.engine)
    setVehicleOverrideLights(vehicle, s.overrideLights)
    setVehicleLocked(vehicle, s.locked)
    setVehicleSirensOn(vehicle, s.sirens)
    setVehicleTaxiLightOn(vehicle, s.taxiLight)
    setVehicleLandingGearDown(vehicle, s.landingGear)
    setVehicleDamageProof(vehicle, s.damageProof)
    setElementFrozen(vehicle, s.frozen)
    setElementAlpha(vehicle, s.alpha)
    if s.fuel then setElementData(vehicle, "vana:fuel", s.fuel) end
    if s.radio then setElementData(vehicle, "vana:radio", s.radio) end
    if s.dashboard then setElementData(vehicle, "vana:dashboard", s.dashboard) end
    if s.blown then blowVehicle(vehicle, false) end
    return vehicle
end

local function attach(vid, vehicle)
    local rec = records[vid]
    rec.vehicle = vehicle
    vids[vehicle] = vid
    dropped[vehicle] = nil
    setElementData(vehicle, "vana:kept", vid, false)
end

local function save(vid, force)
    local rec = records[vid]
    if not rec or not isElement(rec.vehicle) then return end
    local s = snapshot(rec.vehicle)
    local holders = {}
    for serial in pairs(rec.holders) do holders[#holders + 1] = serial end
    local json = toJSON({ state = s, holders = holders, kind = rec.kind }, true)
    if json == rec.saved and not force then return end
    rec.saved = json
    dbExec(db, "UPDATE vehicles SET data = ?, updated = ? WHERE id = ?", json, getRealTime().timestamp, vid)
end

local function saveList(serial)
    dbExec(db, "DELETE FROM registry WHERE serial = ?", serial)
    for i, vid in ipairs(lists[serial] or {}) do
        dbExec(db, "INSERT INTO registry (serial, vid, rank) VALUES (?, ?, ?)", serial, vid, i)
    end
end

-- A car on nobody's list stops being kept and goes back to ordinary cleanup.
local function release(vid)
    local rec = records[vid]
    records[vid] = nil
    dbExec(db, "DELETE FROM vehicles WHERE id = ?", vid)
    if rec and isElement(rec.vehicle) then
        vids[rec.vehicle] = nil
        removeElementData(rec.vehicle, "vana:kept")
        dropped[rec.vehicle] = true
    end
end

local function unlist(serial, vid)
    local list = lists[serial] or {}
    for i = #list, 1, -1 do
        if list[i] == vid then table.remove(list, i) end
    end
end

-- Most recently used first; the least recently used falls off past the list size, and is released
-- once no other player holds it.
local function touch(serial, vid)
    unlist(serial, vid)
    lists[serial] = lists[serial] or {}
    table.insert(lists[serial], 1, vid)
    while #lists[serial] > C.registrySize do
        local old = table.remove(lists[serial])
        local rec = records[old]
        if rec then
            rec.holders[serial] = nil
            if not next(rec.holders) then release(old) end
        end
    end
    saveList(serial)
end

local function setHolders(vid, serials, kind)
    local rec = records[vid]
    local old, new = rec.holders, {}
    for _, serial in ipairs(serials) do new[serial] = true end
    rec.holders, rec.kind = new, kind
    for serial in pairs(old) do
        if not new[serial] then
            unlist(serial, vid)
            saveList(serial)
        end
    end
    for _, serial in ipairs(serials) do touch(serial, vid) end
    save(vid, true)
end

local function register(vehicle)
    local vid = vids[vehicle]
    if vid then return vid end
    local _, _, id = dbPoll(dbQuery(db, "INSERT INTO vehicles (data, updated) VALUES ('{}', ?)", getRealTime().timestamp), -1)
    vid = tonumber(id)
    if not vid then return false end
    records[vid] = { holders = {} }
    attach(vid, vehicle)
    return vid
end

local function humanPassengers(vehicle)
    local list = {}
    for seat, occupant in pairs(getVehicleOccupants(vehicle) or {}) do
        if seat > 0 and getElementType(occupant) == "player" then list[#list + 1] = serialOf(occupant) end
    end
    return list
end

addEventHandler("onVehicleEnter", root, function(player, seat)
    if getElementType(player) ~= "player" or managed(source) then return end
    local vid = register(source)
    if not vid then return end
    local rec = records[vid]
    if seat == 0 then
        setHolders(vid, { serialOf(player) }, "driver")
    else
        local driver = getVehicleOccupant(source, 0)
        -- A player who drove it has the last say; otherwise its last player passengers hold it.
        if (driver and getElementType(driver) == "player") or rec.kind == "driver" then return end
        setHolders(vid, humanPassengers(source), "passengers")
    end
end)

addEventHandler("onVehicleExit", root, function(player)
    if vids[source] and getElementType(player) == "player" then save(vids[source]) end
end)

-- Quitting in a kept car puts you back in your seat when you rejoin (vana-player spawns you where
-- you left, next to it).
local spawned = {} -- players spawned at least once since joining

addEventHandler("onPlayerQuit", root, function()
    local vehicle = getPedOccupiedVehicle(source)
    local serial = serialOf(source)
    if vehicle and vids[vehicle] then
        save(vids[vehicle])
        dbExec(db, "INSERT OR REPLACE INTO seats (serial, vid, seat) VALUES (?, ?, ?)", serial, vids[vehicle], getPedOccupiedVehicleSeat(source))
    else
        dbExec(db, "DELETE FROM seats WHERE serial = ?", serial)
    end
    spawned[source] = nil
end)

-- The first spawn after joining (whichever order the join handlers ran in).
addEventHandler("onPlayerSpawn", root, function()
    if spawned[source] then return end
    spawned[source] = true
    local player, serial = source, serialOf(source)
    local rows = dbPoll(dbQuery(db, "SELECT vid, seat FROM seats WHERE serial = ?", serial), -1)
    dbExec(db, "DELETE FROM seats WHERE serial = ?", serial)
    local row = rows and rows[1]
    local vehicle = row and records[row.vid] and records[row.vid].vehicle
    if not vehicle or not isElement(vehicle) or isVehicleBlown(vehicle) or getVehicleOccupant(vehicle, row.seat) then return end
    local x, y, z = getElementPosition(vehicle)
    local px, py, pz = getElementPosition(player)
    if getDistanceBetweenPoints3D(x, y, z, px, py, pz) > 30 then return end
    setTimer(function()
        if isElement(player) and isElement(vehicle) and not getVehicleOccupant(vehicle, row.seat) then
            warpPedIntoVehicle(player, vehicle, row.seat)
        end
    end, 100, 1)
end)

-- Something destroyed a kept car (a resource stopping, a cleanup that missed isKept): put it back.
addEventHandler("onElementDestroy", root, function()
    if stopping or getElementType(source) ~= "vehicle" or not vids[source] then return end
    local vid = vids[source]
    local s = snapshot(source)
    vids[source] = nil
    setTimer(function()
        local rec = records[vid]
        if not rec or isElement(rec.vehicle) then return end
        local vehicle = build(s)
        if vehicle then attach(vid, vehicle) end
    end, 50, 1)
end)

setTimer(function()
    for vid in pairs(records) do save(vid) end
end, C.saveIntervalMs, 0)

setTimer(function()
    local players = getElementsByType("player")
    for vehicle in pairs(dropped) do
        if not isElement(vehicle) or vids[vehicle] then
            dropped[vehicle] = nil
        elseif not next(getVehicleOccupants(vehicle) or {}) and not getElementData(vehicle, "vana:trafficCar") then
            local x, y, z = getElementPosition(vehicle)
            local near = false
            for _, player in ipairs(players) do
                local px, py, pz = getElementPosition(player)
                if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < C.dropRadius then near = true break end
            end
            if not near then
                dropped[vehicle] = nil
                destroyElement(vehicle)
            end
        end
    end
end, 5000, 0)

addEventHandler("onResourceStart", resourceRoot, function()
    db = dbConnect("sqlite", "vehicles.db")
    dbExec(db, "CREATE TABLE IF NOT EXISTS vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, data TEXT, updated INTEGER)")
    dbExec(db, "CREATE TABLE IF NOT EXISTS registry (serial TEXT, vid INTEGER, rank INTEGER)")
    dbExec(db, "CREATE TABLE IF NOT EXISTS seats (serial TEXT PRIMARY KEY, vid INTEGER, seat INTEGER)")
    for _, player in ipairs(getElementsByType("player")) do spawned[player] = true end
    -- Kept cars still in the world (only this resource restarted) are picked up again, not rebuilt.
    local existing = {}
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        local vid = getElementData(vehicle, "vana:kept")
        if vid then existing[vid] = vehicle end
    end
    local built, found = 0, 0
    local trailers = {}
    for _, row in ipairs(dbPoll(dbQuery(db, "SELECT id, data FROM vehicles"), -1) or {}) do
        local d = fromJSON(row.data)
        if type(d) == "table" and d.state and d.state.model then
            local holders = {}
            for _, serial in ipairs(d.holders or {}) do holders[serial] = true end
            records[row.id] = { holders = holders, kind = d.kind, saved = row.data }
            local vehicle = existing[row.id]
            if vehicle then found = found + 1 else vehicle = build(d.state) built = built + (vehicle and 1 or 0) end
            if vehicle then
                attach(row.id, vehicle)
                if d.state.trailer then trailers[vehicle] = d.state.trailer end
            else
                records[row.id] = nil
            end
        else
            dbExec(db, "DELETE FROM vehicles WHERE id = ?", row.id)
        end
    end
    for vehicle, vid in pairs(trailers) do
        local trailer = records[vid] and records[vid].vehicle
        if trailer and not getVehicleTowedByVehicle(vehicle) then attachTrailerToVehicle(vehicle, trailer) end
    end
    for _, row in ipairs(dbPoll(dbQuery(db, "SELECT serial, vid FROM registry ORDER BY serial, rank"), -1) or {}) do
        if records[row.vid] then
            lists[row.serial] = lists[row.serial] or {}
            table.insert(lists[row.serial], row.vid)
        end
    end
    outputServerLog(("[vana-vehicles] %d kept vehicles: %d rebuilt, %d still in the world"):format(built + found, built, found))
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for vid in pairs(records) do save(vid) end
    stopping = true
end)

-- Console-only: snapshot -> rebuild round trip, the list rules, and a persisted record.
-- vehicletest keep / check: one kept car across a restart of this resource (keep, restart, check).
local function persistenceTest(mode)
    local serial = "vehicletest-persist"
    if mode == "keep" then
        local car = createVehicle(560, 2480, -1670, 13.3)
        setVehiclePanelState(car, 4, 2)
        setElementData(car, "vana:fuel", 4242)
        setElementData(car, "vana:radio", 7)
        setHolders(register(car), { serial }, "driver")
        save(vids[car], true)
        outputServerLog("[vehicletest] kept a Sultan for " .. serial .. "; now restart vana-vehicles and run: vehicletest check")
        return
    end
    local vid = lists[serial] and lists[serial][1]
    local rec = vid and records[vid]
    local car = rec and rec.vehicle
    local ok = car and isElement(car) and getElementModel(car) == 560 and getVehiclePanelState(car, 4) == 2
        and getElementData(car, "vana:fuel") == 4242 and getElementData(car, "vana:radio") == 7 and rec.holders[serial]
    if vid then
        release(vid)
        if isElement(car) then destroyElement(car) end
    end
    lists[serial] = nil
    saveList(serial)
    outputServerLog("[vehicletest] persistence " .. (ok and "PASS" or "FAIL"))
end

addCommandHandler("vehicletest", function(source, _, mode)
    if getElementType(source) ~= "console" then return end
    if mode == "keep" or mode == "check" then return persistenceTest(mode) end
    local ok = true
    local function check(cond, what)
        if not cond then ok = false outputServerLog("[vehicletest] FAILED: " .. what) end
    end
    -- Fuel bands (gasoline.cs at 25 fps) and radio picks (peds.ide favourites, model defaults).
    check(fuelRate(0, false) == 0 and fuelRate(0.5, false) == 0 and fuelRate(20, false) == 25 and fuelRate(60, false) == 50
        and fuelRate(150, false) == 125 and fuelRate(20, true) == 25, "fuel bands")
    local radioCar = createVehicle(411, 2495, -1700, 13.3)
    assignRadio(radioCar, 7) -- male01: K-Rose or SF-UR (peds.ide 1, 4)
    local station = getElementData(radioCar, "vana:radio")
    check(station == 2 or station == 5, "male01's favourite station, got " .. tostring(station))
    local cop = createVehicle(596, 2495, -1710, 13.3)
    check(not assignRadio(cop, 7) and not getElementData(cop, "vana:radio"), "no station for a police car (scanner)")
    destroyElement(radioCar)
    destroyElement(cop)
    local a = createVehicle(411, 2495, -1680, 13.3)
    setVehiclePanelState(a, 0, 3)
    setVehicleDoorState(a, 1, 4)
    setVehicleLightState(a, 2, 1)
    setVehicleWheelStates(a, 1, 0, 2, 0)
    setElementHealth(a, 437)
    setVehicleColor(a, 10, 20, 30, 40, 50, 60)
    addVehicleUpgrade(a, 1010)
    setElementData(a, "vana:fuel", 12345)
    setElementData(a, "vana:radio", 4)
    local s = snapshot(a)
    local b = build(fromJSON(toJSON(s)))
    local t = snapshot(b)
    check(toJSON(s.panels) == toJSON(t.panels) and toJSON(s.doors) == toJSON(t.doors) and toJSON(s.lights) == toJSON(t.lights)
        and toJSON(s.wheels) == toJSON(t.wheels), "damage states round trip")
    check(math.abs(s.health - t.health) < 0.5, "health round trip")
    check(toJSON(s.colors) == toJSON(t.colors) and toJSON(s.upgrades) == toJSON(t.upgrades), "colours and upgrades round trip")
    check(t.fuel == 12345 and t.radio == 4, "fuel and radio round trip")
    destroyElement(b)

    -- Lists: 12 cars through one (fake) serial keep the last C.registrySize, most recent first.
    local serial = "vehicletest"
    local cars = {}
    for i = 1, C.registrySize + 2 do
        cars[i] = createVehicle(411, 2495 + i * 6, -1660, 13.3)
        setHolders(register(cars[i]), { serial }, "driver")
    end
    local list = lists[serial]
    check(#list == C.registrySize, "list size " .. #list)
    check(list[1] == vids[cars[#cars]], "most recent first")
    check(not vids[cars[1]] and not vids[cars[2]] and dropped[cars[1]], "oldest released")
    -- Touching an older car moves it to the front instead of dropping anything.
    setHolders(vids[cars[3]], { serial }, "driver")
    check(lists[serial][1] == vids[cars[3]] and #lists[serial] == C.registrySize, "re-entering moves to front")
    local rows = dbPoll(dbQuery(db, "SELECT data FROM vehicles WHERE id = ?", vids[cars[3]]), -1)
    check(rows and rows[1] and fromJSON(rows[1].data).state.model == 411, "record persisted")
    -- A destroyed kept car comes back.
    local vid = vids[cars[5]]
    destroyElement(cars[5])
    setTimer(function()
        check(records[vid] and isElement(records[vid].vehicle), "destroyed kept car rebuilt")
        for _, v in ipairs(lists[serial]) do
            local rec = records[v]
            local vehicle = rec and rec.vehicle
            release(v)
            if isElement(vehicle) then destroyElement(vehicle) end
        end
        lists[serial] = nil
        saveList(serial)
        for _, car in ipairs(cars) do if isElement(car) then destroyElement(car) end end
        destroyElement(a)
        outputServerLog("[vehicletest] " .. (ok and "PASS" or "FAIL"))
    end, 300, 1)
end)
