-- Music zones: speakers ([data]/vana-data-radio) play their station in 3D, on the same clock as
-- everyone else's, so a club or the lowrider contest sounds the same to all who are there. Only the
-- nearest few in range, in your interior, play.
local R = RadioConfig
local playing = {} -- speaker record -> emitter

setTimer(function()
    local speakers = Radio.speakers
    if not speakers then return end
    local px, py, pz = getElementPosition(localPlayer)
    local interior, dimension = getElementInterior(localPlayer), getElementDimension(localPlayer)
    local near = {}
    for _, s in ipairs(speakers) do
        local d = getDistanceBetweenPoints3D(s.x, s.y, s.z, px, py, pz)
        if s.interior == interior and dimension == 0 and d < s.range and Radio.byId[s.station] then
            near[#near + 1] = { s, d }
        end
    end
    table.sort(near, function(a, b) return a[2] < b[2] end)
    local keep = {}
    for i = 1, math.min(#near, R.speakers.nearest) do keep[near[i][1]] = true end
    for s, e in pairs(playing) do
        if not keep[s] then
            Radio.removeEmitter(e)
            playing[s] = nil
        end
    end
    for s in pairs(keep) do
        if not playing[s] then
            playing[s] = Radio.addEmitter({ station = s.station, x = s.x, y = s.y, z = s.z, interior = s.interior,
                dimension = 0, volume = s.volume, minDistance = R.speakers.minDistance, maxDistance = s.range })
        end
    end
end, 500, 0)
