-- Dating, the player's side: talking to girls you meet, getting her into the car, the cruise report
-- (jumps, radio), the venue fade, the dance (the club rhythm game) and the coffee scene.
local state, talkText = {}, nil
local date -- { kind, radio }
local hurtSent = false

addEvent("vana-dating:state", true)
addEventHandler("vana-dating:state", resourceRoot, function(s, talk) state, talkText = s or {}, talk end)

local function nearGirl()
    if getPedOccupiedVehicle(localPlayer) then return nil end
    local x, y, z = getElementPosition(localPlayer)
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        local key = getElementData(ped, "vana:girl")
        local s = key and state[key]
        if key and not (s and (s.likes or s.dumped)) then
            local px, py, pz = getElementPosition(ped)
            if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < 2.5 then return key end
        end
    end
end

local prompted
setTimer(function()
    local key = nearGirl()
    if key ~= prompted then
        prompted = key
        Hud.help(key and talkText or nil, key ~= nil)
    end
end, 300, 0)

for control, yes in pairs({ conversation_yes = true, conversation_no = false }) do
    bindKey(control, "down", function()
        if prompted then
            triggerServerEvent("vana-dating:answer", resourceRoot, prompted, yes)
            Hud.help(nil)
            prompted = nil
        end
    end)
end

addEvent("vana-dating:pickup", true)
addEventHandler("vana-dating:pickup", resourceRoot, function(ped, vehicle)
    setTimer(function()
        if isElement(ped) and isElement(vehicle) then setPedEnterVehicle(ped, vehicle, 1) end
    end, 1200, 1)
    hurtSent = false
end)

addEvent("vana-dating:date", true)
addEventHandler("vana-dating:date", resourceRoot, function(kind, radio) date = { kind = kind, radio = radio } end)

addEvent("vana-dating:over", true)
addEventHandler("vana-dating:over", resourceRoot, function() date = nil end)

-- The cruise: report each second what only this client knows.
setTimer(function()
    if not date or date.kind ~= "cruise" then return end
    local vehicle = getPedOccupiedVehicle(localPlayer)
    triggerServerEvent("vana-dating:report", resourceRoot, {
        airborne = vehicle and not isVehicleOnGround(vehicle) or false,
        radio = vehicle and getElementData(vehicle, "vana:radio") or 0, -- vana-radio's station (1..11 vanilla's)
    })
end, 1000, 0)

addEvent("vana-dating:leave", true)
addEventHandler("vana-dating:leave", resourceRoot, function(ped)
    setTimer(function() if isElement(ped) then setPedWander(ped, "walk") end end, 1500, 1)
end)

addEvent("vana-dating:venue", true)
addEventHandler("vana-dating:venue", resourceRoot, function(kind)
    fadeCamera(false, 1)
    setTimer(function()
        fadeCamera(true, 1)
        if kind == "dance" then
            -- The dance date uses the club rhythm game (games/rhythm_client.lua).
            Rhythm.start({ count = Dating.dance.beats, beatMs = Dating.dance.beatMs, title = "Dance" }, function(share)
                triggerServerEvent("vana-dating:danced", resourceRoot, share)
            end)
        end
    end, 2500, 1)
end)

-- Coffee (censored, as vanilla's release): the camera waits outside her door.
addEvent("vana-dating:coffee", true)
addEventHandler("vana-dating:coffee", resourceRoot, function(home, ms)
    fadeCamera(false, 1)
    setTimer(function()
        local x, y, z = home[1], home[2], home[3]
        local hr = math.rad(home[4] or 0)
        setCameraMatrix(x + math.sin(hr) * 8, y - math.cos(hr) * 8, z + 3, x, y, z + 1)
        fadeCamera(true, 1)
    end, 1200, 1)
    setTimer(function() fadeCamera(false, 1) end, ms - 1200, 1)
    setTimer(function() setCameraTarget(localPlayer) fadeCamera(true, 1) end, ms, 1)
end)

-- Hurting her ends the date (vanilla GF_H018).
addEventHandler("onClientPedDamage", root, function(attacker)
    if date and not hurtSent and attacker == localPlayer and getElementData(source, "vana:date") then
        hurtSent = true
        triggerServerEvent("vana-dating:hurt", resourceRoot)
    end
end)
