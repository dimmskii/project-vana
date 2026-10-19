-- "WASTED" / "BUSTED", in the vanilla style.
local text, shownAt

addEvent("vana-player:restartText", true)
addEventHandler("vana-player:restartText", resourceRoot, function(kind)
    text, shownAt = kind == "busted" and "busted" or "wasted", getTickCount()
end)

addEventHandler("onClientRender", root, function()
    if not text then return end
    local age = getTickCount() - shownAt
    if age > 5500 then text = nil return end
    local alpha = math.min(255, age / 4)
    local sw, sh = guiGetScreenSize()
    local scale = sh / 360
    dxDrawText(text, 3, 3, sw + 3, sh + 3, tocolor(0, 0, 0, alpha), scale, "pricedown", "center", "center")
    dxDrawText(text, 0, 0, sw, sh, tocolor(text == "wasted" and 180 or 200, text == "wasted" and 25 or 200, 29, alpha), scale, "pricedown", "center", "center")
end)

-- Ground under a place the server put us (or our car) at: places from vanilla's data are points on the
-- ground, MTA positions are a model's centre. Once the collision there has loaded (up to 4 s), the
-- floor below and the model's centre-to-base height go back to the server, which settles it there.
addEvent("vana-player:measureGround", true)
addEventHandler("vana-player:measureGround", resourceRoot, function(token, element, x, y, z)
    local tries = 0
    local timer
    timer = setTimer(function()
        tries = tries + 1
        if not isElement(element) then return killTimer(timer) end
        local hit, _, _, hz = processLineOfSight(x, y, z + 1.5, x, y, z - 3, true, false, false, true, false, false, false, false, element)
        if hit then
            killTimer(timer)
            local base = getElementDistanceFromCentreOfMassToBaseOfModel(element)
            if not base or base <= 0 then base = 1 end
            triggerServerEvent("vana-player:ground", resourceRoot, token, hz, base)
        elseif tries >= 40 then
            killTimer(timer)
        end
    end, 100, 0)
end)
