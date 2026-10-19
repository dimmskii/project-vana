-- Actions on vehicles (vana-lib's actions, docs/controls.md), open to everyone: the engine and lights
-- from the driver's seat, the locks from the driver's seat or, for the car's holders, from beside it.
-- Doors: sitting in a car, only that car's, and only your own seat's door (the driver also has the hood
-- and trunk); on foot, any car you're beside and looking at, when it's unlocked.
local DOORS = {
    { name = "hood", aliases = { "bonnet" }, door = 0, part = "hood", summary = "Open or close the hood" },
    { name = "trunk", aliases = { "boot" }, door = 1, part = "trunk", summary = "Open or close the trunk" },
    { name = "doorfrontleft", aliases = { "doorfl" }, door = 2, part = "front left door", summary = "Open or close the front left door" },
    { name = "doorfrontright", aliases = { "doorfr" }, door = 3, part = "front right door", summary = "Open or close the front right door" },
    { name = "doorrearleft", aliases = { "doorrl" }, door = 4, part = "rear left door", summary = "Open or close the rear left door", rear = true },
    { name = "doorrearright", aliases = { "doorrr" }, door = 5, part = "rear right door", summary = "Open or close the rear right door", rear = true },
}
local DOORED = { Automobile = true, ["Monster Truck"] = true }
local SEAT_DOOR = { [0] = 2, [1] = 3, [2] = 4, [3] = 5 } -- seat -> its door
local NO_ENGINE = { BMX = true, Trailer = true }

local function driving(player, vehicle)
    return getPedOccupiedVehicle(player) == vehicle and getPedOccupiedVehicleSeat(player) == 0
end

-- Sitting in a car, nothing but that car is in reach.
local function ownOrOnFoot(v, player)
    local own = getPedOccupiedVehicle(player)
    return not own or own == v
end

local function capital(s) return (s:gsub("^%l", string.upper)) end

Actions.add{
    name = "engine", label = function(_, v) return getVehicleEngineState(v) and "Turn the engine off" or "Turn the engine on" end,
    usage = "", summary = "Turn your engine on or off (driver)",
    targets = { "vehicle" }, inside = true,
    accepts = function(v) return not NO_ENGINE[getVehicleType(v)] end,
    available = driving,
    run = function(player, v)
        if not driving(player, v) then return false, "Only the driver can do that." end
        local on = not getVehicleEngineState(v)
        if on and getVehicleFuel(v) and getVehicleFuel(v) <= 0 then return false, "The tank is empty." end
        setVehicleEngineState(v, on)
        return on and "Engine turned on" or "Engine turned off"
    end,
}

-- The lights cycle on, off and back to the game's own (on at night and in tunnels).
local LIGHTS = { [0] = { 2, "Lights turned on" }, [2] = { 1, "Lights turned off" }, [1] = { 0, "Lights on automatic" } }
local LIGHT_LABELS = { [0] = "Turn the lights on", [2] = "Turn the lights off", [1] = "Lights on automatic" }

Actions.add{
    name = "lights", label = function(_, v) return LIGHT_LABELS[getVehicleOverrideLights(v)] or LIGHT_LABELS[0] end,
    usage = "", summary = "Lights on, off or automatic, in turn (driver)",
    targets = { "vehicle" }, inside = true,
    accepts = function(v) return not NO_ENGINE[getVehicleType(v)] end,
    available = driving,
    run = function(player, v)
        if not driving(player, v) then return false, "Only the driver can do that." end
        local nextState = LIGHTS[getVehicleOverrideLights(v)] or LIGHTS[0]
        setVehicleOverrideLights(v, nextState[1])
        return nextState[2]
    end,
}

local function mayLock(player, v) return driving(player, v) or (not getPedOccupiedVehicle(player) and holdsVehicle(player, v)) end

Actions.add{
    name = "lock", label = function(_, v) return isVehicleLocked(v) and "Unlock the doors" or "Lock the doors" end,
    usage = "", summary = "Lock or unlock the doors (driver, or beside a car you hold)",
    targets = { "vehicle" }, inside = true, reach = 6,
    accepts = function(v, player) return DOORED[getVehicleType(v)] == true and ownOrOnFoot(v, player) end,
    available = mayLock,
    run = function(player, v)
        if getPedOccupiedVehicle(player) and not driving(player, v) then return false, "Only the driver can do that." end
        if not mayLock(player, v) then return false, "You don't have the keys to this one." end
        local locked = not isVehicleLocked(v)
        setVehicleLocked(v, locked)
        return locked and "Doors locked" or "Doors unlocked"
    end,
}

for _, d in ipairs(DOORS) do
    local function has(v)
        if not DOORED[getVehicleType(v)] or getVehicleDoorState(v, d.door) == 4 then return false end
        return not d.rear or getVehicleMaxPassengers(v) >= 3
    end
    -- Inside: the hood and trunk are the driver's, each door its own seat's. Outside: unlocked.
    local function allowed(player, v)
        if getPedOccupiedVehicle(player) == v then
            local seat = getPedOccupiedVehicleSeat(player)
            if d.door <= 1 then return seat == 0, "Only the driver can do that." end
            return SEAT_DOOR[seat] == d.door, "You can only open your own door."
        end
        return not isVehicleLocked(v), "It's locked."
    end
    local summary = d.door <= 1 and " (the driver, or beside it unlocked)" or " (from its seat, or beside it unlocked)"
    Actions.add{
        name = d.name, aliases = d.aliases, usage = "", summary = d.summary .. summary,
        label = function(_, v) return ((getVehicleDoorOpenRatio(v, d.door) or 0) > 0.5 and "Close the " or "Open the ") .. d.part end,
        targets = { "vehicle" }, inside = true, reach = 6,
        accepts = function(v, player) return has(v) and ownOrOnFoot(v, player) end,
        available = function(player, v) return (allowed(player, v)) end,
        run = function(player, v)
            local ok, why = allowed(player, v)
            if not ok then return false, why end
            local open = (getVehicleDoorOpenRatio(v, d.door) or 0) <= 0.5
            setVehicleDoorOpenRatio(v, d.door, open and 1 or 0, 400)
            return capital(d.part) .. (open and " opened" or " closed")
        end,
    }
end
