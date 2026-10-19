-- Prompts: a marker you stand on, on foot, that starts something when you press /use (F / Enter), as
-- the pool tables, arcade machines and vending machines do. (Driving activities stay drive-in.)
-- Import on both sides (lib.lua).
-- Server: Prompts.add(marker, { text, use, walkIn })
--   text     what pressing does, shown as "Press F to <text>"
--   use      function(player): pressed while on the marker, on foot (checked again here)
--   walkIn   also run use the moment the player walks onto it, as vanilla's shop counters do
-- The prompt is an offer to vana-controls' /use, which keeps the game's enter/exit off meanwhile, so
-- the key never also sends you to a car nearby. The marker's interior counts: MTA's marker hits don't
-- check it.
Prompts = {}

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
                if opts.walkIn then opts.use(player) end
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
    -- The prompt is an offer to /use (vana-controls): it shows the help box and owns the key.
    local current -- { marker, text }
    local id = getResourceName(getThisResource()) .. ":prompt"

    local function offer(text)
        local res = getResourceFromName("vana-controls")
        if res and getResourceState(res) == "running" then
            if text then exports["vana-controls"]:offer(id, text) else exports["vana-controls"]:withdraw(id) end
        end
    end

    addEvent("vana-prompt:show", true)
    addEventHandler("vana-prompt:show", resourceRoot, function(marker, text)
        current = { marker = marker, text = text }
        offer(text)
    end)
    addEvent("vana-prompt:hide", true)
    addEventHandler("vana-prompt:hide", resourceRoot, function(marker)
        if current and current.marker == marker then
            current = nil
            offer(nil)
        end
    end)

    addEvent("onClientVanaUse", false)
    addEventHandler("onClientVanaUse", root, function(used)
        if used ~= id or not current then return end
        if not isElement(current.marker) then current = nil offer(nil) return end
        triggerServerEvent("vana-prompt:use", resourceRoot, current.marker)
    end)
    addEvent("onClientVanaUseReset", false)
    addEventHandler("onClientVanaUseReset", root, function() if current then offer(current.text) end end)
end
