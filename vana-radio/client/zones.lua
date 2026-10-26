-- Music zones: speakers ([data]/vana-data-radio) play their station in 3D on the shared clock. Only
-- the nearest few in range, in the player's interior, play.

local config = RadioConfig

---@type table<table, Emitter> speaker record -> its emitter
local playing = {}

---@param px number
---@param py number
---@param pz number
---@return table<table, true> speakers that should play
local function nearestSpeakers(px, py, pz)
    local interior, dimension = getElementInterior(localPlayer), getElementDimension(localPlayer)
    local inRange = {}
    for _, speaker in ipairs(Radio.speakers) do
        local distance = getDistanceBetweenPoints3D(speaker.x, speaker.y, speaker.z, px, py, pz)
        if speaker.interior == interior and dimension == 0 and distance < speaker.range and Radio.byId[speaker.station] then
            inRange[#inRange + 1] = { speaker = speaker, distance = distance }
        end
    end
    table.sort(inRange, function(a, b) return a.distance < b.distance end)
    local nearest = {}
    for i = 1, math.min(#inRange, config.speakers.nearest) do nearest[inRange[i].speaker] = true end
    return nearest
end

setTimer(function()
    if not Radio.speakers then return end
    local nearest = nearestSpeakers(getElementPosition(localPlayer))
    for speaker, emitter in pairs(playing) do
        if not nearest[speaker] then
            Radio.removeEmitter(emitter)
            playing[speaker] = nil
        end
    end
    for speaker in pairs(nearest) do
        playing[speaker] = playing[speaker] or Radio.addEmitter({
            station = speaker.station, x = speaker.x, y = speaker.y, z = speaker.z, interior = speaker.interior,
            dimension = 0, volume = speaker.volume, minDistance = config.speakers.minDistance, maxDistance = speaker.range,
        })
    end
end, 500, 0)
