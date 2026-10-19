-- Vanilla's programme for one station: a port of CAERadioTrackManager (US 1.0; addresses and the
-- tables in docs/radio.md), playing the story as complete. Plain Lua, no MTA calls: tools can run it.
-- VanillaStation.new(radio) for vanilla's radio ID (0 the police scanner, 1 Playback FM .. 11 WCTR);
-- :next(ctx) gives the next stretch, as ChooseTracksForStation does: a list of { track, kind },
-- kind "ident", "advert", "banter", "intro", "body" or "outro". ctx: { hour, weather(id) -> bool }
-- (weather(id): that weather is due, as CWeather::ForecastWeather(id, 3)).
VanillaStation = {}
VanillaStation.__index = VanillaStation

local WCTR, SCANNER = 11, 0
local MUSIC_HISTORY, IDENT_HISTORY, ADVERT_HISTORY, BANTER_HISTORY = 20, 8, 40, 15

function VanillaStation.new(radio, random)
    local data = RadioData.stations[radio + 1]
    assert(data, "no vanilla radio station " .. tostring(radio))
    local excluded = {}
    for _, id in ipairs(data.excludedAdverts) do excluded[id] = true end
    return setmetatable({ radio = radio, data = data, excluded = excluded, random = random or math.random,
                          music = {}, idents = {}, adverts = {}, banter = {} }, VanillaStation)
end

-- CAEAudioUtility: ResolveProbability, and GetRandomNumberInRange (inclusive).
function VanillaStation:chance(p) return self.random() < p end
function VanillaStation:range(lo, hi) return self.random(lo, hi) end

local function recent(history, value, depth)
    for i = 1, depth do
        if history[i] == value then return true end
    end
    return false
end

-- Add*IndexToHistory: newest first, not twice in a row.
local function remember(history, value, size)
    if value == nil or history[1] == value then return end
    table.insert(history, 1, value)
    history[size + 1] = nil
end

-- ChooseMusicTrackIndex: any song but the station's last few. WCTR's talk shows (ChooseTalkRadioShow)
-- depend on story progress: all count as available, drawn the same way.
function VanillaStation:chooseSong()
    local n = #self.data.songs
    local depth = math.min(MUSIC_HISTORY, self.radio == WCTR and n - 1 or n - 2)
    local index
    repeat index = self:range(0, n - 1) until not recent(self.music, index, depth)
    return index
end

-- ChooseIdentIndex.
function VanillaStation:chooseIdent()
    local range = self.data.idents
    if not range then return end
    local depth = math.min(IDENT_HISTORY, range[2] - range[1] - 1)
    local id
    repeat id = self:range(range[1], range[2]) until not recent(self.idents, id, depth)
    return id
end

-- ChooseAdvertIndex: any advert but the station's excluded ones and its last 40.
function VanillaStation:chooseAdvert()
    local lo, hi = RadioData.adverts[1], RadioData.adverts[2]
    local id
    repeat id = self:range(lo, hi) until not self.excluded[id] and not recent(self.adverts, id, ADVERT_HISTORY)
    return id
end

-- Picks from one of the station's banter lists, from a random place onwards, the first one not
-- played lately; nil if every one was. The history depth comes from the general list's size, for
-- every list (as vanilla).
function VanillaStation:fromList(kind)
    local range = self.data.banter[kind]
    if not range then return end
    local general = self.data.banter.general
    local depth = general and math.min(BANTER_HISTORY, general[2] - general[1] - 1) or 0
    local n = range[2] - range[1] + 1
    local start = self:range(0, n - 1)
    for k = 0, n - 1 do
        local id = range[1] + (start + k) % n
        if not recent(self.banter, id, depth) then return id end
    end
end

-- ChooseDJBanterIndex: nil (the caller plays an advert instead) 40% of the time; otherwise by the
-- weather due, then the time of day. Vanilla only talks outdoors (area 0) and the scanner switches
-- lists during the riots: neither applies to a server-wide station.
function VanillaStation:chooseBanter(ctx)
    if self.radio == SCANNER then return self:fromList("general") end
    if not self:chance(0.6) then return end
    local id
    local w = ctx.weather
    if w(16) or w(8) then
        if self:chance(0.5) then id = self:fromList("rain") end
    elseif w(9) and self:chance(0.5) then
        -- The sunny list's own condition (hour under 8 and at least 6) never holds: on to fog.
        id = self:fromList("fog")
    end
    if id then return id end
    local h = ctx.hour
    if h >= 6 and h < 9 then
        if self:chance(0.3) then id = self:fromList("morning") end
    elseif h >= 18 and h < 21 then
        if self:chance(0.3) then id = self:fromList("evening") end
    elseif (h >= 22 or h < 3) and self:chance(0.3) then
        id = self:fromList("night")
    end
    return id or self:fromList("general")
end

local function pick(range, self)
    return range and self:range(range[1], range[2]) or nil
end

-- QueueUpTracksForStation: adds one kind of piece; false when there was none (no banter).
function VanillaStation:queue(out, kind, ctx)
    local function add(track, what)
        if track then out[#out + 1] = { track = track, kind = what } end
    end
    if kind == "ident" then
        local id = self:chooseIdent()
        remember(self.idents, id, IDENT_HISTORY)
        add(id, "ident")
        return id ~= nil
    elseif kind == "advert" then
        local id = self:chooseAdvert()
        remember(self.adverts, id, ADVERT_HISTORY)
        add(id, "advert")
        return true
    elseif kind == "banter" then
        local id = self:chooseBanter(ctx)
        remember(self.banter, id, BANTER_HISTORY)
        add(id, "banter")
        return id ~= nil
    end
    -- Music: "intro" is intro + body + outro, "track" body + outro, "outro" a newly picked song's outro.
    local index = self:chooseSong()
    local song = self.data.songs[index + 1]
    remember(self.music, index, MUSIC_HISTORY)
    if kind == "intro" then add(pick(song.intros, self), "intro") end
    if kind ~= "outro" then add(song.body, "body") end
    add(pick(song.outros, self), "outro")
    return true
end

-- ChooseTracksForStation.
function VanillaStation:next(ctx)
    local out = {}
    local function q(kind) return self:queue(out, kind, ctx) end
    local function talk() -- maybe an ident, then banter or else an advert
        if self:chance(0.5) then q("ident") end
        if not q("banter") then q("advert") end
    end
    if self:chance(0.95) then
        if self:chance(0.9) then
            q("track")
        elseif self:chance(0.5) then
            if self:chance(0.5) then q("ident") end
            q("intro")
        else
            q("outro")
            if self.radio == SCANNER then
                q("banter")
            elseif self:chance(0.5) then
                if self:chance(0.5) then q("ident") end
                q("intro")
            else
                talk()
            end
        end
    else
        if self.radio == SCANNER then q("banter") else talk() end
        q("intro")
    end
    return out
end
