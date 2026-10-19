-- Prompts: a marker that starts something only when you press the enter/exit key (F / Enter) in it,
-- as the pool tables, arcade machines and vending machines do, instead of the moment you walk or
-- drive into it. Import on both sides (lib.lua).
-- Server: Prompts.add(marker, { text, vehicle, use })
--   text     what pressing does, shown as "Press F to <text>"
--   vehicle  nil: on foot only; true: driving only; "any": either
--   use      function(player): pressed while in the marker (checked again here)
-- The marker's interior counts: MTA's marker hits don't check it.
Prompts = {}
local CONTROL = "enter_exit"

if not localPlayer then
    local prompts = {} -- marker -> opts

    local function fits(player, marker, opts)
        if not isElement(player) or isPedDead(player) or getElementInterior(player) ~= getElementInterior(marker) then return false end
        local vehicle = getPedOccupiedVehicle(player)
        if opts.vehicle == true then
            return vehicle ~= false and getVehicleOccupant(vehicle, 0) == player and isElementWithinMarker(vehicle, marker)
        elseif opts.vehicle == "any" then
            return isElementWithinMarker(vehicle and vehicle or player, marker)
        end
        return not vehicle and isElementWithinMarker(player, marker)
    end

    function Prompts.add(marker, opts)
        prompts[marker] = opts
        addEventHandler("onMarkerHit", marker, function(element, matching)
            local player = getElementType(element) == "vehicle" and getVehicleOccupant(element, 0) or element
            if not matching or not isElement(player) or getElementType(player) ~= "player" then return end
            -- A car entering hits as the car; its driver is the one asked.
            setTimer(function()
                if prompts[marker] and fits(player, marker, opts) then
                    triggerClientEvent(player, "vana-prompt:show", resourceRoot, marker, opts.text)
                end
            end, 50, 1)
        end)
        addEventHandler("onMarkerLeave", marker, function(element)
            local player = getElementType(element) == "vehicle" and getVehicleOccupant(element, 0) or element
            if isElement(player) and getElementType(player) == "player" then
                triggerClientEvent(player, "vana-prompt:hide", resourceRoot, marker)
            end
        end)
        addEventHandler("onElementDestroy", marker, function() prompts[marker] = nil end)
        return marker
    end

    addEvent("vana-prompt:use", true)
    addEventHandler("vana-prompt:use", resourceRoot, function(marker)
        local opts = isElement(marker) and prompts[marker]
        if opts and fits(client, marker, opts) then opts.use(client) end
    end)
else
    local current -- { marker, text }

    addEvent("vana-prompt:show", true)
    addEventHandler("vana-prompt:show", resourceRoot, function(marker, text) current = { marker = marker, text = text } end)
    addEvent("vana-prompt:hide", true)
    addEventHandler("vana-prompt:hide", resourceRoot, function(marker)
        if current and current.marker == marker then current = nil end
    end)

    addEventHandler("onClientKey", root, function(key, pressed)
        if not current or not pressed or isCursorShowing() then return end
        for bound in pairs(getBoundKeys(CONTROL) or {}) do
            if bound == key then
                triggerServerEvent("vana-prompt:use", resourceRoot, current.marker)
                current = nil
                cancelEvent()
                return
            end
        end
    end)

    addEventHandler("onClientRender", root, function()
        if not current then return end
        if not isElement(current.marker) or isPedDead(localPlayer) then current = nil return end
        local key = next(getBoundKeys(CONTROL) or {}) or "f"
        local _, sh = guiGetScreenSize()
        local s = sh / 720
        local text = ("Press %s to %s"):format(key:upper(), current.text)
        dxDrawRectangle(40 * s, 70 * s, 380 * s, 34 * s, tocolor(0, 0, 0, 170))
        dxDrawText(text, 52 * s, 70 * s, 410 * s, 104 * s, tocolor(255, 255, 255), 1.15 * s, "default-bold", "left", "center", true)
    end)
end
