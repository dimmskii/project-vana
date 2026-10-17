-- Dating, the player's side: talking to girls you meet, getting her into the car, the cruise report
-- (jumps, radio), the venue fade, the dance minigame (ours until DANCE is ported) and the coffee scene.
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
        radio = getRadioChannel(),
    })
end, 1000, 0)

addEvent("vana-dating:leave", true)
addEventHandler("vana-dating:leave", resourceRoot, function(ped)
    setTimer(function() if isElement(ped) then setPedWander(ped, "walk") end end, 1500, 1)
end)

-- Dancing: hit the shown direction before the next beat.
local dance -- { beats, index, shown, hits, deadline }
local ARROWS = { { "forwards", "UP" }, { "backwards", "DOWN" }, { "left", "LEFT" }, { "right", "RIGHT" } }

local function nextBeat()
    dance.index = dance.index + 1
    if dance.index > Dating.dance.beats then
        local share = dance.hits / Dating.dance.beats
        dance = nil
        fadeCamera(false, 0.5)
        setTimer(function() fadeCamera(true, 1) setCameraTarget(localPlayer) end, 800, 1)
        triggerServerEvent("vana-dating:danced", resourceRoot, share)
        return
    end
    dance.shown, dance.answered = ARROWS[math.random(#ARROWS)], false
    dance.deadline = getTickCount() + Dating.dance.beatMs
end

addEvent("vana-dating:venue", true)
addEventHandler("vana-dating:venue", resourceRoot, function(kind)
    fadeCamera(false, 1)
    setTimer(function()
        fadeCamera(true, 1)
        if kind == "dance" then
            dance = { index = 0, hits = 0 }
            nextBeat()
        end
    end, 2500, 1)
end)

addEventHandler("onClientKey", root, function(key, pressed)
    if not dance or not pressed or dance.answered then return end
    for _, a in ipairs(ARROWS) do
        for k in pairs(getBoundKeys(a[1]) or {}) do
            if k == key then
                dance.answered = true
                if a == dance.shown then dance.hits = dance.hits + 1 end
                cancelEvent()
                return
            end
        end
    end
end)

addEventHandler("onClientRender", root, function()
    if not dance then return end
    if getTickCount() > dance.deadline then return nextBeat() end
    local w, h = guiGetScreenSize()
    local colour = dance.answered and tocolor(120, 255, 120) or tocolor(255, 255, 255)
    dxDrawText(dance.shown[2], 0, h * 0.4, w, h * 0.5, colour, 3, "pricedown", "center", "center")
    dxDrawText(("%d / %d"):format(dance.hits, Dating.dance.beats), 0, h * 0.5, w, h * 0.56, tocolor(225, 196, 130), 1.5, "bankgothic", "center", "center")
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
