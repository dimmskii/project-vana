-- Prompts: a marker you stand on, on foot, that starts something only when you press the enter/exit
-- key (F / Enter), as the pool tables, arcade machines and vending machines do, instead of the moment
-- you walk into it. (Driving activities stay drive-in.) Import on both sides (lib.lua).
-- Server: Prompts.add(marker, { text, use })
--   text     what pressing does, shown as "Press F to <text>"
--   use      function(player): pressed while on the marker, on foot (checked again here)
-- The press is the prompt's alone: the key's down and up are both swallowed, so nothing else bound
-- to enter/exit (getting into a car nearby) happens with it. The marker's interior counts: MTA's
-- marker hits don't check it.
Prompts = {}
local CONTROL = "enter_exit"

if not localPlayer then
    local prompts = {} -- marker -> opts

    local function fits(player, marker)
        if not isElement(player) or isPedDead(player) or getElementInterior(player) ~= getElementInterior(marker) then return false end
        return not getPedOccupiedVehicle(player) and isElementWithinMarker(player, marker)
    end

    function Prompts.add(marker, opts)
        prompts[marker] = opts
        addEventHandler("onMarkerHit", marker, function(player, matching)
            if matching and getElementType(player) == "player" and fits(player, marker) then
                triggerClientEvent(player, "vana-prompt:show", resourceRoot, marker, opts.text)
            end
        end)
        addEventHandler("onMarkerLeave", marker, function(player)
            if getElementType(player) == "player" then triggerClientEvent(player, "vana-prompt:hide", resourceRoot, marker) end
        end)
        addEventHandler("onElementDestroy", marker, function() prompts[marker] = nil end)
        return marker
    end

    addEvent("vana-prompt:use", true)
    addEventHandler("vana-prompt:use", resourceRoot, function(marker)
        local opts = isElement(marker) and prompts[marker]
        if opts and fits(client, marker) then opts.use(client) end
    end)
else
    local current  -- { marker, text }
    local swallow  -- the key whose press started something: its release is swallowed too

    addEvent("vana-prompt:show", true)
    addEventHandler("vana-prompt:show", resourceRoot, function(marker, text) current = { marker = marker, text = text } end)
    addEvent("vana-prompt:hide", true)
    addEventHandler("vana-prompt:hide", resourceRoot, function(marker)
        if current and current.marker == marker then current = nil end
    end)

    addEventHandler("onClientKey", root, function(key, pressed)
        if not pressed then
            if key == swallow then swallow = nil cancelEvent() end
            return
        end
        if not current or isCursorShowing() or getPedOccupiedVehicle(localPlayer) then return end
        for bound in pairs(getBoundKeys(CONTROL) or {}) do
            if bound == key then
                -- Cancelling the key stops every GTA and MTA bind on it: no running off to the nearest car.
                cancelEvent()
                swallow = key
                triggerServerEvent("vana-prompt:use", resourceRoot, current.marker)
                current = nil
                return
            end
        end
    end)

    addEventHandler("onClientRender", root, function()
        if not current then return end
        if not isElement(current.marker) or isPedDead(localPlayer) then current = nil return end
        if getPedOccupiedVehicle(localPlayer) then return end
        local key = next(getBoundKeys(CONTROL) or {}) or "f"
        local _, sh = guiGetScreenSize()
        local s = sh / 720
        local text = ("Press %s to %s"):format(key:upper(), current.text)
        dxDrawRectangle(40 * s, 70 * s, 380 * s, 34 * s, tocolor(0, 0, 0, 170))
        dxDrawText(text, 52 * s, 70 * s, 410 * s, 104 * s, tocolor(255, 255, 255), 1.15 * s, "default-bold", "left", "center", true)
    end)
end
