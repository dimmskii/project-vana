-- The game's text (data/american.gxt, copied from your GTA:SA install, see docs/setup.md), read
-- once here with sa_gxt.lua and answered to every other resource (their Gxt, vana-lib's text.lua).
local ready = Gxt.load("data/american.gxt")
if not ready then outputDebugString("[vana-text] data/american.gxt is missing or not a GXT file (see docs/setup.md)", 1) end

function isReady() return ready end
function rawText(key, tableName) return ready and Gxt.raw(key, tableName) or false end
function plainText(key, tableName) return ready and Gxt.get(key, tableName) or false end
