-- The client side of the stations: the server's clock, each station's schedule, and emitters, the
-- places a station is heard from (the car you're in, a car outside, a speaker). An emitter plays
-- whatever segment of its station is due, at the position it's due at, and loads the next one ahead
-- so they join without a gap.
local R = RadioConfig
Radio = { stations = {}, volume = 1 }
local emitters = {}

----------------------------------------------------------------------------------------------------
-- The server's clock: our offset from it, from the ping with the shortest round trip lately.

local samples = {} -- { rtt, offset }, newest last
local offset

function Radio.now() return offset and getTickCount() + offset end

local function ping() triggerServerEvent("vana-radio:ping", resourceRoot, getTickCount()) end

addEvent("vana-radio:pong", true)
addEventHandler("vana-radio:pong", resourceRoot, function(sent, serverNow)
    local now = getTickCount()
    local rtt = now - sent
    samples[#samples + 1] = { rtt, serverNow + rtt / 2 - now }
    if #samples > 8 then table.remove(samples, 1) end
    local best = samples[1]
    for _, s in ipairs(samples) do if s[1] < best[1] then best = s end end
    offset = best[2]
end)

----------------------------------------------------------------------------------------------------
-- Schedules

local byId = {}
for _, def in ipairs(R.stations) do byId[def.id] = def end
Radio.byId = byId

addEvent("vana-radio:schedule", true)
addEventHandler("vana-radio:schedule", resourceRoot, function(all)
    for id, st in pairs(all) do Radio.stations[id] = { segments = st.segments or {}, url = st.url } end
end)

addEvent("vana-radio:segments", true)
addEventHandler("vana-radio:segments", resourceRoot, function(id, added)
    local st = Radio.stations[id]
    if not st then return end
    for _, seg in ipairs(added) do st.segments[#st.segments + 1] = seg end
    local now = Radio.now()
    while now and st.segments[1] and st.segments[1].at + st.segments[1].length < now - 5000 do table.remove(st.segments, 1) end
end)

-- The segment due at `now` on a station, and the one after it.
function Radio.segmentAt(id, now)
    local st = Radio.stations[id]
    if not st or not now then return end
    for i, seg in ipairs(st.segments) do
        if now < seg.at + seg.length then
            if now >= seg.at then return seg, st.segments[i + 1] end
            return nil, seg
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Emitters. opts: station, volume; 3D ones: element (followed) or x, y, z, interior, dimension,
-- minDistance, maxDistance, muffle (parameq settings).

-- A vanilla track ID's archive (playSFX's name) and 1-based place in it.
local function archiveOf(track)
    for _, s in ipairs(RadioStreams) do
        if track < s[2] then return s[1], track + 1 end
        track = track - s[2]
    end
end

local streamsPlaying = 0

local function makeSound(e, seg, url)
    local sound
    if url then
        if streamsPlaying >= R.maxStreams then return end
        sound = e.is3D and playSound3D(url, e.x or 0, e.y or 0, e.z or 0) or playSound(url)
    else
        local archive, index = archiveOf(seg.track)
        if not archive then return end
        if e.is3D then
            local x, y, z = e.x or 0, e.y or 0, e.z or 0
            if e.element and isElement(e.element) then x, y, z = getElementPosition(e.element) end
            sound = playSFX3D("radio", archive, index, x, y, z, false)
        else
            sound = playSFX("radio", archive, index, false)
        end
    end
    if not sound then return end
    if url then streamsPlaying = streamsPlaying + 1 end
    setSoundVolume(sound, (e.volume or 1) * Radio.volume)
    if e.is3D then
        setSoundMinDistance(sound, e.minDistance or 3)
        setSoundMaxDistance(sound, e.maxDistance or 30)
        if e.muffle then
            setSoundEffectEnabled(sound, "parameq", true)
            for key, value in pairs(e.muffle) do setSoundEffectParameter(sound, "parameq", key, value) end
        end
        if e.element and isElement(e.element) then
            setElementInterior(sound, getElementInterior(e.element))
            setElementDimension(sound, getElementDimension(e.element))
            attachElements(sound, e.element)
        else
            setElementInterior(sound, e.interior or 0)
            setElementDimension(sound, e.dimension or 0)
        end
    end
    return sound
end

local function drop(e, which)
    local s = e[which]
    if s and isElement(s.sound) then
        destroyElement(s.sound)
        if s.url then streamsPlaying = streamsPlaying - 1 end
    end
    e[which] = nil
end

local function stopAll(e)
    drop(e, "playing")
    drop(e, "loaded")
end

function Radio.addEmitter(opts)
    local e = {}
    for k, v in pairs(opts) do e[k] = v end
    e.is3D = opts.element ~= nil or opts.x ~= nil
    emitters[e] = true
    return e
end

function Radio.removeEmitter(e)
    if not e or not emitters[e] then return end
    stopAll(e)
    emitters[e] = nil
end

function Radio.setEmitterStation(e, id)
    if e.station == id then return end
    stopAll(e)
    e.station = id
end

-- Volume changes reach the playing sounds.
function Radio.refreshVolume()
    for e in pairs(emitters) do
        if e.playing and isElement(e.playing.sound) then setSoundVolume(e.playing.sound, (e.volume or 1) * Radio.volume) end
    end
end

local function update(e, now)
    local st = Radio.stations[e.station]
    if not st then return stopAll(e) end
    if st.url then
        if not e.playing or e.playing.url ~= st.url then
            stopAll(e)
            local sound = makeSound(e, nil, st.url)
            if sound then e.playing = { sound = sound, url = st.url } end
        end
        return
    end
    local seg, nextSeg = Radio.segmentAt(e.station, now)
    -- The loaded next segment is due: start it.
    if e.loaded and seg == e.loaded.seg then
        drop(e, "playing")
        e.playing, e.loaded = e.loaded, nil
        setSoundPaused(e.playing.sound, false)
        setSoundVolume(e.playing.sound, (e.volume or 1) * Radio.volume)
        e.playing.checked = now
    end
    if not e.playing or e.playing.seg ~= seg then
        drop(e, "playing")
        if seg and seg.track then
            local sound = makeSound(e, seg)
            if sound then
                setSoundPosition(sound, (now - seg.at) / 1000)
                e.playing = { sound = sound, seg = seg, checked = now }
            else
                e.playing = { seg = seg } -- no audio for it: don't retry every frame
            end
        elseif seg then
            e.playing = { seg = seg }
        end
    end
    -- Keep it in place: a sound drifts (loading, frame hitches).
    local p = e.playing
    if p and p.sound and isElement(p.sound) and now - p.checked > 2000 then
        p.checked = now
        local want = now - seg.at
        if math.abs(getSoundPosition(p.sound) * 1000 - want) > R.resyncMs then setSoundPosition(p.sound, want / 1000) end
    end
    -- Load the next one shortly before it's due, paused.
    if nextSeg and nextSeg.track and nextSeg.at - now < R.preloadMs and (not e.loaded or e.loaded.seg ~= nextSeg) then
        drop(e, "loaded")
        local sound = makeSound(e, nextSeg)
        if sound then
            setSoundPaused(sound, true)
            setSoundVolume(sound, 0)
            e.loaded = { sound = sound, seg = nextSeg }
        end
    end
end

-- Every frame, so a segment starts within a frame of when it's due.
addEventHandler("onClientRender", root, function()
    local now = Radio.now()
    if not now then return end
    for e in pairs(emitters) do update(e, now) end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("vana-radio:hello", resourceRoot)
    -- A few quick pings for a first offset, then one every 30 s.
    for i = 0, 4 do setTimer(ping, 50 + i * 400, 1) end
    setTimer(ping, 30000, 0)
end)
