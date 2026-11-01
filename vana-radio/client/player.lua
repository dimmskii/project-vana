-- The client side of the stations: the server clock, each station's schedule, and emitters (the car
-- you're in, a car outside, a speaker). An emitter plays the segment due on its station at the
-- position due, and preloads the next one so they join without a gap.

local config = RadioConfig

---@class Emitter
---@field station integer
---@field volume number?
---@field is3D boolean
---@field element element? followed by a 3D sound
---@field x number?
---@field y number?
---@field z number?
---@field interior integer?
---@field dimension integer?
---@field minDistance number?
---@field maxDistance number?
---@field muffle table? parametric EQ settings
---@field playing table? { sound, segment, checkedAt } or { sound, url }
---@field preloaded table? { sound, segment }

Radio = { stations = {}, volume = 1, byId = {} }
for _, def in ipairs(config.stations) do Radio.byId[def.id] = def end

---@type table<Emitter, true>
local emitters = {}
---@type { roundTrip: integer, offset: number }[] newest last
local clockSamples = {}
---@type number?
local clockOffset
local streamsPlaying = 0
local debugOverlay = false

--- The server clock, or nil before the first sync.
---@return number?
function Radio.now()
    return clockOffset and getTickCount() + clockOffset
end

--- Export: the server clock (its getTickCount) on this client, or false before the first sync.
---@return number|false
function getServerTime()
    return Radio.now() or false
end

local function ping()
    triggerServerEvent("vana-radio:ping", resourceRoot, getTickCount())
end

--- The segment due at `now` on a station, and the one after it.
---@param id integer
---@param now number?
---@return table? current
---@return table? following
function Radio.segmentAt(id, now)
    local station = Radio.stations[id]
    if not station or not now then return end
    for i, segment in ipairs(station.segments) do
        if now < segment.at + segment.length then
            if now >= segment.at then return segment, station.segments[i + 1] end
            return nil, segment
        end
    end
end

--- A vanilla track ID's audio archive (playSFX's name) and 1-based index in it.
---@param track integer
---@return string? archive
---@return integer? index
local function archiveOf(track)
    for _, stream in ipairs(RadioStreams) do
        local name, count = stream[1], stream[2]
        if track < count then return name, track + 1 end
        track = track - count
    end
end

---@param emitter Emitter
---@return number
local function emitterVolume(emitter)
    return (emitter.volume or 1) * Radio.volume
end

---@param emitter Emitter
---@param segment table?
---@param url string? a stream to play instead of a segment
---@return sound?
local function createSound(emitter, segment, url)
    local sound
    if url then
        if streamsPlaying >= config.maxStreams then return end
        sound = emitter.is3D and playSound3D(url, emitter.x or 0, emitter.y or 0, emitter.z or 0) or playSound(url)
    else
        local archive, index = archiveOf(segment.track)
        if not archive then return end
        if emitter.is3D then
            local x, y, z = emitter.x or 0, emitter.y or 0, emitter.z or 0
            if isElement(emitter.element) then x, y, z = getElementPosition(emitter.element) end
            sound = playSFX3D("radio", archive, index, x, y, z, false)
        else
            sound = playSFX("radio", archive, index, false)
        end
    end
    if not sound then return end
    if url then streamsPlaying = streamsPlaying + 1 end
    setSoundVolume(sound, emitterVolume(emitter))
    if emitter.is3D then
        setSoundMinDistance(sound, emitter.minDistance or 3)
        setSoundMaxDistance(sound, emitter.maxDistance or 30)
        if emitter.muffle then
            setSoundEffectEnabled(sound, "parameq", true)
            for key, value in pairs(emitter.muffle) do setSoundEffectParameter(sound, "parameq", key, value) end
        end
        if isElement(emitter.element) then
            setElementInterior(sound, getElementInterior(emitter.element))
            setElementDimension(sound, getElementDimension(emitter.element))
            attachElements(sound, emitter.element)
        else
            setElementInterior(sound, emitter.interior or 0)
            setElementDimension(sound, emitter.dimension or 0)
        end
    end
    return sound
end

---@param emitter Emitter
---@param slot "playing"|"preloaded"
local function dropSound(emitter, slot)
    local held = emitter[slot]
    if held and isElement(held.sound) then
        destroyElement(held.sound)
        if held.url then streamsPlaying = streamsPlaying - 1 end
    end
    emitter[slot] = nil
end

---@param emitter Emitter
local function stopEmitter(emitter)
    dropSound(emitter, "playing")
    dropSound(emitter, "preloaded")
end

---@param options table station, volume; for 3D: element or x/y/z/interior/dimension, minDistance, maxDistance, muffle
---@return Emitter
function Radio.addEmitter(options)
    local emitter = {}
    for key, value in pairs(options) do emitter[key] = value end
    emitter.is3D = options.element ~= nil or options.x ~= nil
    emitters[emitter] = true
    return emitter
end

---@param emitter Emitter?
function Radio.removeEmitter(emitter)
    if not emitter or not emitters[emitter] then return end
    stopEmitter(emitter)
    emitters[emitter] = nil
end

---@param emitter Emitter
---@param id integer
function Radio.setEmitterStation(emitter, id)
    if emitter.station == id then return end
    stopEmitter(emitter)
    emitter.station = id
end

--- Applies a changed Radio.volume to every playing sound.
function Radio.refreshVolume()
    for emitter in pairs(emitters) do
        if emitter.playing and isElement(emitter.playing.sound) then
            setSoundVolume(emitter.playing.sound, emitterVolume(emitter))
        end
    end
end

---@param emitter Emitter
---@param url string
local function updateStream(emitter, url)
    if emitter.playing and emitter.playing.url == url then return end
    stopEmitter(emitter)
    local sound = createSound(emitter, nil, url)
    if sound then emitter.playing = { sound = sound, url = url } end
end

---@param emitter Emitter
---@param now number
local function updateEmitter(emitter, now)
    local station = Radio.stations[emitter.station]
    if not station then return stopEmitter(emitter) end
    if station.url then return updateStream(emitter, station.url) end

    local segment, following = Radio.segmentAt(emitter.station, now)
    if emitter.preloaded and segment == emitter.preloaded.segment then
        dropSound(emitter, "playing")
        emitter.playing, emitter.preloaded = emitter.preloaded, nil
        setSoundPaused(emitter.playing.sound, false)
        setSoundVolume(emitter.playing.sound, emitterVolume(emitter))
        emitter.playing.checkedAt = now
    end
    if not emitter.playing or emitter.playing.segment ~= segment then
        dropSound(emitter, "playing")
        local sound = segment and segment.track and createSound(emitter, segment)
        if sound then
            setSoundPosition(sound, (now - segment.at) / 1000)
            emitter.playing = { sound = sound, segment = segment, checkedAt = now }
        elseif segment then
            -- No audio for this segment: remember it so it isn't retried every frame.
            emitter.playing = { segment = segment }
        end
    end

    local playing = emitter.playing
    local sound = playing and playing.sound
    if sound and isElement(sound) then
        if segment.fade then
            local left = segment.at + segment.length - now
            local share = left < segment.fade and math.max(0, left / segment.fade) or 1
            setSoundVolume(sound, emitterVolume(emitter) * share)
        end
        -- Sounds drift (loading, frame hitches): put them back in place every 2 s.
        if now - playing.checkedAt > 2000 then
            playing.checkedAt = now
            local due = now - segment.at
            if math.abs(getSoundPosition(sound) * 1000 - due) > config.resyncMs then setSoundPosition(sound, due / 1000) end
        end
    end

    local preloadDue = following and following.track and following.at - now < config.preloadMs
    if preloadDue and (not emitter.preloaded or emitter.preloaded.segment ~= following) then
        dropSound(emitter, "preloaded")
        local next = createSound(emitter, following)
        if next then
            setSoundPaused(next, true)
            setSoundVolume(next, 0)
            emitter.preloaded = { sound = next, segment = following }
        end
    end
end

---@return string[]
local function debugLines()
    local now = Radio.now()
    local best
    for _, sample in ipairs(clockSamples) do
        if not best or sample.roundTrip < best.roundTrip then best = sample end
    end
    local native = getRadioPlaybackState()
    local lines = {
        ("native: channel %s, mode %s, station %s, track %s"):format(tostring(getRadioChannel()), tostring(native and native.mode),
            tostring(native and native.station), tostring(native and native.trackId)),
        ("clock: offset %s ms, best round trip %s ms"):format(clockOffset and math.floor(clockOffset) or "-", best and best.roundTrip or "-"),
    }
    for emitter in pairs(emitters) do
        local playing = emitter.playing
        local segment = playing and playing.segment
        local line = ("%s station %s: "):format(emitter.is3D and "3D" or "2D", tostring(emitter.station))
        if segment and now then
            local archive, index = archiveOf(segment.track or 0)
            line = line .. ("%s %s (%s #%s) due %.1fs / %.1fs"):format(segment.kind or "?", tostring(segment.track or segment.label),
                tostring(archive), tostring(index), (now - segment.at) / 1000, segment.length / 1000)
            if playing.sound and isElement(playing.sound) then
                line = line .. (", sound at %.1fs"):format(getSoundPosition(playing.sound))
            else
                line = line .. ", no sound"
            end
        else
            line = line .. (playing and playing.url or "nothing")
        end
        if emitter.preloaded then line = line .. (" | next %s loaded"):format(tostring(emitter.preloaded.segment.track)) end
        lines[#lines + 1] = line
    end
    return lines
end

addEvent("vana-radio:pong", true)
addEventHandler("vana-radio:pong", resourceRoot, function(sentAt, serverNow)
    local now = getTickCount()
    local roundTrip = now - sentAt
    clockSamples[#clockSamples + 1] = { roundTrip = roundTrip, offset = serverNow + roundTrip / 2 - now }
    if #clockSamples > 8 then table.remove(clockSamples, 1) end
    local best = clockSamples[1]
    for _, sample in ipairs(clockSamples) do
        if sample.roundTrip < best.roundTrip then best = sample end
    end
    clockOffset = best.offset
end)

addEvent("vana-radio:schedule", true)
addEventHandler("vana-radio:schedule", resourceRoot, function(schedule, speakers)
    for id, station in pairs(schedule) do Radio.stations[id] = { segments = station.segments or {}, url = station.url } end
    Radio.speakers = speakers or {}
end)

addEvent("vana-radio:segments", true)
addEventHandler("vana-radio:segments", resourceRoot, function(id, added)
    local station = Radio.stations[id]
    if not station then return end
    for _, segment in ipairs(added) do station.segments[#station.segments + 1] = segment end
    local now = Radio.now()
    while now and station.segments[1] and station.segments[1].at + station.segments[1].length < now - 5000 do
        table.remove(station.segments, 1)
    end
end)

-- Every frame, so a segment starts within a frame of when it's due.
addEventHandler("onClientRender", root, function()
    local now = Radio.now()
    if now then
        for emitter in pairs(emitters) do updateEmitter(emitter, now) end
    end
    if debugOverlay then
        local text = table.concat(debugLines(), "\n")
        dxDrawText(text, 21, 301, 0, 0, tocolor(0, 0, 0, 220), 1, "default-bold")
        dxDrawText(text, 20, 300, 0, 0, tocolor(255, 255, 255, 230), 1, "default-bold")
    end
end)

addCommandHandler("radiodebug", function() debugOverlay = not debugOverlay end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("vana-radio:hello", resourceRoot)
    for i = 0, 4 do setTimer(ping, 50 + i * 400, 1) end
    setTimer(ping, 30000, 0)
end)
