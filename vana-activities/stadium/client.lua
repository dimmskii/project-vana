-- Stadium events, this client's side: Kickstart's coronas (collected by riding through them) and the
-- Blood Ring rivals' ramming (native drive-to, straight at you).
local coronas, rivals, target

addEvent("vana-stadium:coronas", true)
addEventHandler("vana-stadium:coronas", resourceRoot, function(list, dim, interior)
    for _, c in ipairs(coronas or {}) do if isElement(c.marker) then destroyElement(c.marker) end end
    coronas = nil
    if not list then return end
    coronas = {}
    local colours = { { 60, 220, 60 }, { 240, 180, 30 }, { 230, 40, 40 } }
    for i, p in ipairs(list) do
        local col = colours[p[4]]
        local m = createMarker(p[1], p[2], p[3], "corona", 1.6, col[1], col[2], col[3], 200)
        setElementDimension(m, dim)
        setElementInterior(m, interior)
        coronas[i] = { p = p, marker = m }
    end
end)

addEvent("vana-stadium:rivals", true)
addEventHandler("vana-stadium:rivals", resourceRoot, function(list, car) rivals, target = list, car end)

setTimer(function()
    if coronas then
        local x, y, z = getElementPosition(localPlayer)
        for i, c in ipairs(coronas) do
            if isElement(c.marker) and getDistanceBetweenPoints3D(x, y, z, c.p[1], c.p[2], c.p[3]) < 2.5 then
                destroyElement(c.marker)
                triggerServerEvent("vana-stadium:corona", resourceRoot, i)
            end
        end
    end
    if rivals and isElement(target) then
        local tx, ty, tz = getElementPosition(target)
        for _, r in ipairs(rivals) do
            if isElement(r.ped) and isElement(r.car) and not isVehicleBlown(r.car) and isElementStreamedIn(r.car) then
                setPedDriveTo(r.ped, r.car, Vector3(tx, ty, tz), 60, "straight_line", "plough_through")
            end
        end
    end
end, 400, 0)
