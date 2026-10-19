-- Game text for a resource that doesn't load american.gxt itself: Gxt functions answered by
-- vana-text (which owns the file, see sa_gxt.lua there), so every resource asks one copy.
Gxt = Gxt or {}

local function call(fn, ...)
    local res = getResourceFromName("vana-text")
    if not res or getResourceState(res) ~= "running" then return nil end
    return exports["vana-text"][fn](exports["vana-text"], ...)
end

-- Whether the text is available (vana-text running, with its american.gxt).
function Gxt.load() return call("isReady") == true end

-- The text for a key as stored (formatting tokens kept), from tableName first, then MAIN; nil if missing.
function Gxt.raw(key, tableName) return call("rawText", key, tableName) or nil end

-- The text without its colour tokens.
function Gxt.get(key, tableName) return call("plainText", key, tableName) or nil end

-- Fills ~1~ placeholders in order with the given values.
function Gxt.format(s, ...)
    local args, i = { ... }, 0
    return (s:gsub("~1~", function()
        i = i + 1
        return tostring(args[i] or "")
    end))
end
