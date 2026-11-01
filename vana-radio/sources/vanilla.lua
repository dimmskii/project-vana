-- Vanilla's programme for one station: a port of CAERadioTrackManager (US 1.0; see docs/radio.md),
-- with the story treated as complete. Plain Lua with no MTA calls, so tools can run it too.

---@class VanillaStation
---@field radio integer vanilla radio ID: 0 police scanner, 1 Playback FM .. 11 WCTR
---@field data table RadioData.stations entry
---@field excluded table<integer, true> adverts this station never plays
---@field random fun(lo: integer?, hi: integer?): number
---@field music integer[] recent song indices, newest first
---@field idents integer[]
---@field adverts integer[]
---@field banter integer[]
VanillaStation = {}
VanillaStation.__index = VanillaStation

local WCTR, SCANNER = 11, 0
local MUSIC_HISTORY, IDENT_HISTORY, ADVERT_HISTORY, BANTER_HISTORY = 20, 8, 40, 15

---@param radio integer
---@param random? fun(lo: integer?, hi: integer?): number defaults to math.random
---@return VanillaStation
function VanillaStation.new(radio, random)
    local data = RadioData.stations[radio + 1]
    assert(data, "no vanilla radio station " .. tostring(radio))
    local excluded = {}
    for _, id in ipairs(data.excludedAdverts) do excluded[id] = true end
    return setmetatable({ radio = radio, data = data, excluded = excluded, random = random or math.random,
                          music = {}, idents = {}, adverts = {}, banter = {} }, VanillaStation)
end

--- CAEAudioUtility::ResolveProbability.
---@param probability number
---@return boolean
function VanillaStation:chance(probability)
    return self.random() < probability
end

--- CAEAudioUtility::GetRandomNumberInRange (inclusive).
---@param lo integer
---@param hi integer
---@return integer
function VanillaStation:range(lo, hi)
    return self.random(lo, hi)
end

---@param history integer[]
---@param value integer
---@param depth integer
---@return boolean
local function isRecent(history, value, depth)
    for i = 1, depth do
        if history[i] == value then return true end
    end
    return false
end

--- Add*IndexToHistory: newest first, never the same twice in a row.
---@param history integer[]
---@param value integer?
---@param size integer
local function remember(history, value, size)
    if value == nil or history[1] == value then return end
    table.insert(history, 1, value)
    history[size + 1] = nil
end

--- ChooseMusicTrackIndex: any song but the last few. WCTR's talk shows (ChooseTalkRadioShow) all
--- count as available.
---@return integer songIndex 0-based
function VanillaStation:chooseSong()
    local count = #self.data.songs
    local depth = math.min(MUSIC_HISTORY, self.radio == WCTR and count - 1 or count - 2)
    local index
    repeat index = self:range(0, count - 1) until not isRecent(self.music, index, depth)
    return index
end

--- ChooseIdentIndex.
---@return integer? track
function VanillaStation:chooseIdent()
    local range = self.data.idents
    if not range then return end
    local depth = math.min(IDENT_HISTORY, range[2] - range[1] - 1)
    local id
    repeat id = self:range(range[1], range[2]) until not isRecent(self.idents, id, depth)
    return id
end

--- ChooseAdvertIndex: any advert but the excluded ones and the last 40.
---@return integer track
function VanillaStation:chooseAdvert()
    local lo, hi = RadioData.adverts[1], RadioData.adverts[2]
    local id
    repeat id = self:range(lo, hi) until not self.excluded[id] and not isRecent(self.adverts, id, ADVERT_HISTORY)
    return id
end

--- The first banter line of a list, from a random start, not played lately. Every list uses the
--- general list's history depth, as vanilla does.
---@param kind string "general", "rain", "fog", "morning", "evening" or "night"
---@return integer? track nil when every line was played lately
function VanillaStation:fromList(kind)
    local range = self.data.banter[kind]
    if not range then return end
    local general = self.data.banter.general
    local depth = general and math.min(BANTER_HISTORY, general[2] - general[1] - 1) or 0
    local count = range[2] - range[1] + 1
    local start = self:range(0, count - 1)
    for offset = 0, count - 1 do
        local id = range[1] + (start + offset) % count
        if not isRecent(self.banter, id, depth) then return id end
    end
end

--- ChooseDJBanterIndex: nothing 40% of the time (the caller plays an advert), else by the weather
--- due, then the time of day. Vanilla only talks outdoors and switches the scanner's lists during
--- the riots; neither applies to a server-wide station.
---@param context { hour: integer, weather: fun(id: integer): boolean }
---@return integer? track
function VanillaStation:chooseBanter(context)
    if self.radio == SCANNER then return self:fromList("general") end
    if not self:chance(0.6) then return end
    local id
    local weatherDue = context.weather
    if weatherDue(16) or weatherDue(8) then
        if self:chance(0.5) then id = self:fromList("rain") end
    elseif weatherDue(9) and self:chance(0.5) then
        -- The sunny list's condition (hour under 8 and at least 6) never holds, so it goes to fog.
        id = self:fromList("fog")
    end
    if id then return id end
    local hour = context.hour
    if hour >= 6 and hour < 9 then
        if self:chance(0.3) then id = self:fromList("morning") end
    elseif hour >= 18 and hour < 21 then
        if self:chance(0.3) then id = self:fromList("evening") end
    elseif (hour >= 22 or hour < 3) and self:chance(0.3) then
        id = self:fromList("night")
    end
    return id or self:fromList("general")
end

---@param range integer[]?
---@return integer?
function VanillaStation:pickIn(range)
    return range and self:range(range[1], range[2]) or nil
end

--- QueueUpTracksForStation: appends one piece. Music kinds: "intro" (intro, body, outro), "track"
--- (body, outro), "outro" (a new song's outro only).
---@param out table[] { track, kind } list to append to
---@param kind string "ident", "advert", "banter", "intro", "track" or "outro"
---@param context table
---@return boolean queued false when there was nothing to play (no ident or banter)
function VanillaStation:queue(out, kind, context)
    local function add(track, label)
        if track then out[#out + 1] = { track = track, kind = label } end
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
        local id = self:chooseBanter(context)
        remember(self.banter, id, BANTER_HISTORY)
        add(id, "banter")
        return id ~= nil
    end
    local index = self:chooseSong()
    local song = self.data.songs[index + 1]
    remember(self.music, index, MUSIC_HISTORY)
    if kind == "intro" then add(self:pickIn(song.intros), "intro") end
    if kind ~= "outro" then add(song.body, "body") end
    add(self:pickIn(song.outros), "outro")
    return true
end

--- ChooseTracksForStation: the next stretch of the programme.
---@param context table
---@return { track: integer, kind: string }[]
function VanillaStation:next(context)
    local out = {}
    local function queue(kind) return self:queue(out, kind, context) end
    local function talk()
        if self:chance(0.5) then queue("ident") end
        if not queue("banter") then queue("advert") end
    end
    if self:chance(0.95) then
        if self:chance(0.9) then
            queue("track")
        elseif self:chance(0.5) then
            if self:chance(0.5) then queue("ident") end
            queue("intro")
        else
            queue("outro")
            if self.radio == SCANNER then
                queue("banter")
            elseif self:chance(0.5) then
                if self:chance(0.5) then queue("ident") end
                queue("intro")
            else
                talk()
            end
        end
    else
        if self.radio == SCANNER then queue("banter") else talk() end
        queue("intro")
    end
    return out
end
