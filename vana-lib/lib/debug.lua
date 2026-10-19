-- Debug switches (docs/debug.md): /vanadebug turns a resource's debug checks on, all of them or by
-- topic. vana-core keeps the switches and puts them on each resource's root element ("vana:debug":
-- "all" or "topic,topic"), so both its sides see them (a script that doesn't import this can read the
-- element data itself). Import on either side.
--   Debug.on(topic)         this resource's topic is on
--   Debug.log(topic, text)  a line in the server log ("[debug vana-peds:orders] ..."), from either side
Debug = {}
local name = getResourceName(getThisResource())

function Debug.on(topic)
    local v = getElementData(resourceRoot, "vana:debug")
    return v == "all" or (type(v) == "string" and ("," .. v .. ","):find("," .. topic .. ",", 1, true) ~= nil)
end

function Debug.log(topic, text)
    if not localPlayer then
        outputServerLog(("[debug %s:%s] %s"):format(name, topic, text))
    else
        triggerServerEvent("vana-core:debug", localPlayer, name, topic, text)
    end
end
