-- Server-side player persistence, keyed by MTA serial (no accounts yet): money, body stats,
-- clothes and weapons (ammo and clip per slot, and the weapon in hand), plus the last position.
-- Also owns spawning, and coming back from being wasted (hospital) or busted (police station).
local STATS = { 21, 22, 23, 24 } -- fat, stamina, muscle, max health

local db
local data = {}    -- player -> saved state
local serials = {} -- player -> serial

local function serialOf(player)
    serials[player] = serials[player] or getPlayerSerial(player)
    return serials[player]
end

local function fresh()
    local s = PlayerConfig.start
    local stats = {}
    for _, stat in ipairs(STATS) do stats[stat] = s.stats[stat] end
    return { money = s.money, stats = stats, clothes = {}, weapons = {}, slot = 0 }
end

-- JSON turns numeric keys into strings; turn them back.
local function numericKeys(t)
    local out = {}
    for k, v in pairs(t or {}) do out[tonumber(k) or k] = v end
    return out
end

local function load(player)
    local serial = serialOf(player)
    local rows = dbPoll(dbQuery(db, "SELECT data FROM players WHERE serial = ?", serial), -1)
    local d = rows and rows[1] and fromJSON(rows[1].data)
    if type(d) ~= "table" then
        d = fresh()
    else
        d.stats, d.clothes, d.weapons = numericKeys(d.stats), numericKeys(d.clothes), numericKeys(d.weapons)
    end
    data[player] = d
    return d
end

-- Reads the authoritative server state of a player into its saved record.
local function snapshot(player)
    local d = data[player]
    if not d then return end
    d.money = getPlayerMoney(player)
    for _, stat in ipairs(STATS) do d.stats[stat] = getPedStat(player, stat) end
    d.clothes = {}
    for clothesType = 0, 17 do
        local texture, model = getPedClothes(player, clothesType)
        if texture then d.clothes[clothesType] = { texture = texture, model = model } end
    end
    if not isPedDead(player) then
        d.weapons = {}
        for slot = 0, 12 do
            local weapon = getPedWeapon(player, slot)
            if weapon and weapon > 0 then
                d.weapons[slot] = { id = weapon, total = getPedTotalAmmo(player, slot), clip = getPedAmmoInClip(player, slot) }
            end
        end
        d.slot = getPedWeaponSlot(player)
        d.fightingStyle = getPedFightingStyle(player)
        local x, y, z = getElementPosition(player)
        local _, _, rz = getElementRotation(player)
        d.position = { x = x, y = y, z = z, heading = rz, interior = getElementInterior(player), dimension = getElementDimension(player) }
    end
end

function savePlayer(player)
    if not data[player] then return false end
    snapshot(player)
    dbExec(db, "INSERT OR REPLACE INTO players (serial, name, data, updated) VALUES (?, ?, ?, ?)",
        serialOf(player), getPlayerName(player), toJSON(data[player], true), getRealTime().timestamp)
    return true
end

-- Things a player owns for good, by kind (e.g. "clothes" -> "texture/model"): bought once, kept
-- across sessions. The closet (still to come) will offer every owned item.
function isOwned(player, kind, key)
    local d = data[player]
    return d and d.owned and d.owned[kind] and d.owned[kind][key] == true or false
end

function grantOwned(player, kind, key)
    local d = data[player]
    if not d then return false end
    d.owned = d.owned or {}
    d.owned[kind] = d.owned[kind] or {}
    d.owned[kind][key] = true
    savePlayer(player)
    return true
end

function getOwned(player, kind)
    local d = data[player]
    local list = {}
    for key in pairs(d and d.owned and d.owned[kind] or {}) do list[#list + 1] = key end
    return list
end

-- Activity progress by key (e.g. "taxi.fares", "perk.fireproof"): numbers, strings or booleans,
-- saved with the player. vana-activities keeps levels, records and earned perks here.
function getProgress(player, key)
    local d = data[player]
    return d and d.progress and d.progress[key]
end

function setProgress(player, key, value)
    local d = data[player]
    if not d then return false end
    d.progress = d.progress or {}
    d.progress[key] = value
    savePlayer(player)
    return true
end

local function maxHealth(player)
    return 100 + (getPedStat(player, 24) - 569) * 76 / 431
end

-- Puts a saved record onto a (freshly spawned) player.
local function apply(player, d)
    setPlayerMoney(player, d.money, true)
    for stat, value in pairs(d.stats) do setPedStat(player, stat, value) end
    setElementHealth(player, maxHealth(player))
    for clothesType, c in pairs(d.clothes) do addPedClothes(player, c.texture, c.model, clothesType) end
    takeAllWeapons(player)
    for _, w in pairs(d.weapons) do
        giveWeapon(player, w.id, w.total, false)
        setWeaponAmmo(player, w.id, w.total, w.clip)
    end
    setPedWeaponSlot(player, d.slot or 0)
    if d.fightingStyle then setPedFightingStyle(player, d.fightingStyle) end
end

local function spawnAt(player, place, interior, dimension)
    spawnPlayer(player, place.x, place.y, place.z, place.heading or 0, 0, interior or 0, dimension or 0)
    apply(player, data[player])
    fadeCamera(player, true)
    setCameraTarget(player, player)
end

-- Every player is logged in to an account named after their serial (nothing to remember), so ACL
-- rights can be granted per player with <object name="user.SERIAL" /> in acl.xml. The password is
-- derived from a random secret that never leaves the server.
local secret

local function accountSecret()
    if secret then return secret end
    local rows = dbPoll(dbQuery(db, "SELECT value FROM meta WHERE key = 'accountSecret'"), -1)
    secret = rows and rows[1] and rows[1].value
    if not secret then
        local bytes = {}
        for i = 1, 32 do bytes[i] = string.format("%02x", math.random(0, 255)) end
        secret = table.concat(bytes)
        dbExec(db, "INSERT INTO meta (key, value) VALUES ('accountSecret', ?)", secret)
    end
    return secret
end

local function autoLogin(player)
    if not isGuestAccount(getPlayerAccount(player)) then return end
    local serial = serialOf(player)
    local password = hash("sha256", serial .. accountSecret())
    local account = getAccount(serial) or addAccount(serial, password)
    if not account or not logIn(player, account, password) then
        outputServerLog(("[vana-player] could not log %s in to account %s (see docs/player.md)"):format(getPlayerName(player), serial))
    end
end

-- Puts the configured serials' accounts into their ACL groups.
local function applyGroups()
    local changed = false
    for groupName, serials in pairs(PlayerConfig.groups) do
        local group = aclGetGroup(groupName)
        if group then
            for _, serial in ipairs(serials) do
                if not isObjectInACLGroup("user." .. serial, group) then
                    changed = aclGroupAddObject(group, "user." .. serial) or changed
                end
            end
        else
            outputServerLog("[vana-player] ACL group " .. groupName .. " does not exist")
        end
    end
    -- Our restricted commands, on the Admin ACL (the Console group inherits it).
    local acl = aclGet("Admin")
    for _, right in ipairs(PlayerConfig.adminRights or {}) do
        if acl and not aclGetRight(acl, right) then
            aclSetRight(acl, right, true)
            changed = true
        end
    end
    if changed then aclSave() end
end

addEventHandler("onPlayerJoin", root, function()
    autoLogin(source)
    local d = load(source)
    local p = d.position
    if PlayerConfig.spawnAtLastPosition and p then
        spawnAt(source, p, p.interior, p.dimension)
    else
        spawnAt(source, PlayerConfig.start.spawn)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    savePlayer(source)
    data[source], serials[source] = nil, nil
end)

local function nearest(points, x, y, z)
    local best, bestDist = points[1], math.huge
    for _, p in ipairs(points) do
        local d = getDistanceBetweenPoints3D(x, y, z, p.x, p.y, p.z)
        if d < bestDist then best, bestDist = p, d end
    end
    return best
end

-- Wasted or busted: the vanilla penalties, then back at the nearest hospital or police station.
local function restart(player, kind)
    local rules, points = PlayerConfig[kind], Restarts[kind == "busted" and "police" or "hospital"]
    local d = data[player]
    if not d then return end
    -- Earned perks (vanilla girlfriends: Barbara gets you out of jail, Katie out of hospital, for free
    -- and with your weapons): progress "perk.free_busted" / "perk.free_wasted".
    local free = d.progress and d.progress["perk.free_" .. kind] == true
    -- The penalty goes on the live player, not just the record: any save before the respawn snapshots
    -- the live state and would otherwise undo it.
    if not free then
        setPlayerMoney(player, math.max(0, getPlayerMoney(player) - rules.fee), true)
        if rules.loseWeapons then takeAllWeapons(player) end
    end
    snapshot(player)
    if not free and rules.loseWeapons then d.weapons, d.slot = {}, 0 end
    triggerClientEvent(player, "vana-player:restartText", resourceRoot, kind)
    setTimer(function()
        if not isElement(player) then return end
        fadeCamera(player, false, 1)
        setTimer(function()
            if not isElement(player) then return end
            local x, y, z = getElementPosition(player)
            spawnAt(player, nearest(points, x, y, z))
            savePlayer(player)
        end, 1000, 1)
    end, rules.delayMs, 1)
end

addEventHandler("onPlayerWasted", root, function()
    if not data[source] or data[source].busting then return end
    restart(source, "wasted")
end)

-- Called by the police (vana-services) when a cop arrests the player.
function bustPlayer(player)
    local d = data[player]
    if not d or d.busting or isPedDead(player) then return false end
    d.busting = true
    setElementFrozen(player, true)
    toggleAllControls(player, false, true, false)
    restart(player, "busted")
    setTimer(function()
        if not isElement(player) then return end
        setElementFrozen(player, false)
        toggleAllControls(player, true, true, false)
        if data[player] then data[player].busting = nil end
    end, PlayerConfig.busted.delayMs + 1500, 1)
    return true
end

addEventHandler("onResourceStart", resourceRoot, function()
    db = dbConnect("sqlite", "players.db")
    dbExec(db, "CREATE TABLE IF NOT EXISTS players (serial TEXT PRIMARY KEY, name TEXT, data TEXT, updated INTEGER)")
    dbExec(db, "CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
    applyGroups()
    -- Players already on the server (resource restart) carry on from their current state.
    for _, player in ipairs(getElementsByType("player")) do
        autoLogin(player)
        load(player)
        snapshot(player)
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(data) do savePlayer(player) end
end)

setTimer(function()
    for player in pairs(data) do
        if isElement(player) then savePlayer(player) end
    end
end, PlayerConfig.saveIntervalMs, 0)

-- Console-only: round-trips a record through the database and checks the restart data.
addCommandHandler("playertest", function(source)
    if getElementType(source) ~= "console" then return end
    local ok = true
    local record = fresh()
    record.money, record.weapons[2], record.clothes[0] = 1234, { id = 22, total = 68, clip = 17 }, { texture = "vest", model = "vest" }
    local json = toJSON(record, true)
    dbExec(db, "INSERT OR REPLACE INTO players (serial, name, data, updated) VALUES (?, ?, ?, ?)", "TEST", "test", json, 0)
    local rows = dbPoll(dbQuery(db, "SELECT data FROM players WHERE serial = ?", "TEST"), -1)
    local back = rows and rows[1] and fromJSON(rows[1].data)
    local weapons = back and numericKeys(back.weapons)
    ok = back and back.money == 1234 and weapons[2] and weapons[2].clip == 17 and numericKeys(back.clothes)[0].texture == "vest"
    dbExec(db, "DELETE FROM players WHERE serial = ?", "TEST")
    ok = ok and #Restarts.hospital > 0 and #Restarts.police > 0
    local h = nearest(Restarts.hospital, 2495, -1687, 13)
    outputServerLog(("[playertest] database round trip %s; nearest hospital to Grove Street: %.0f, %.0f"):format(ok and "ok" or "FAILED", h.x, h.y))
    outputServerLog("[playertest] " .. (ok and "PASS" or "FAIL"))
end)
