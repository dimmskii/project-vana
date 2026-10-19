-- Minigame objects: walk up to a slot machine, table, arcade machine, hoop or pool table and /use
-- (F) to play it (vanilla's prompts where it has them).
local texts = {}
local OURS = {
    roulette = "~k~~VEHICLE_ENTER_EXIT~ Play Roulette", blackjack = "~k~~VEHICLE_ENTER_EXIT~ Play Blackjack",
    arcade = "~k~~VEHICLE_ENTER_EXIT~ Play the arcade machine", console = "~k~~VEHICLE_ENTER_EXIT~ Play the games console",
    pool = "~k~~VEHICLE_ENTER_EXIT~ Play Pool", betting = "~k~~VEHICLE_ENTER_EXIT~ Bet on the horses",
}
local near, shown
local busy = false

addEvent("vana-minigame:texts", true)
addEventHandler("vana-minigame:texts", resourceRoot, function(t) texts = t or {} end)
addEventHandler("onClientResourceStart", resourceRoot, function() triggerServerEvent("vana-minigame:hello", resourceRoot) end)

addEvent("vana-activities:session", true)
addEventHandler("vana-activities:session", resourceRoot, function(name) busy = name ~= nil end)

-- The spot in reach is an offer to vana-controls' /use, which shows its prompt.
local ID = "vana-activities:minigame"
local function offer(text)
    local res = getResourceFromName("vana-controls")
    if not res or getResourceState(res) ~= "running" then return end
    if text then exports["vana-controls"]:offer(ID, text) else exports["vana-controls"]:withdraw(ID) end
end

local function spotText(i)
    local s = i and MinigameSpots[i]
    return s and (texts[s.kind] or OURS[s.kind]) or nil
end

setTimer(function()
    near = nil
    if busy or getPedOccupiedVehicle(localPlayer) or isPedDead(localPlayer) then
        if shown then offer(nil) shown = nil end
        return
    end
    local x, y, z = getElementPosition(localPlayer)
    local interior = getElementInterior(localPlayer)
    local best
    for i, s in ipairs(MinigameSpots) do
        if s.interior == interior and math.abs(s.z - z) < 3 then
            local d = getDistanceBetweenPoints2D(x, y, s.x, s.y)
            local reach = (s.kind == "roulette" or s.kind == "blackjack" or s.kind == "pool" or s.kind == "wheel") and 3.2 or Games.reach
            if d < reach and (not best or d < best) then near, best = i, d end
        end
    end
    if near ~= shown then
        shown = near
        offer(spotText(near))
    end
end, 300, 0)

addEvent("onClientVanaUse", false)
addEventHandler("onClientVanaUse", root, function(id)
    if id ~= ID or not near or busy then return end
    triggerServerEvent("vana-minigame:use", resourceRoot, near)
    offer(nil)
    shown = nil
end)
addEvent("onClientVanaUseReset", false)
addEventHandler("onClientVanaUseReset", root, function() offer(spotText(shown)) end)
