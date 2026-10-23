-- Train crossings (vana-trains, docs/trains.md): which path links cross the rails, and which of them
-- are closed now (a train coming or passing). Import on the server; without vana-trains there are none.
--   TrainCrossings.refresh()            once a tick: fetches the closed set, returns it ({ [id] = true })
--   TrainCrossings.between(a, b, kind)  the crossings on the path link between nodes a and b (route
--                                       entries: area, id), kind "vehicle" or "ped"; nil when none
-- A crossing: { id, x, y, z, a, b, kind, track }.
TrainCrossings = {}

local index, triedAt, closed = nil, -math.huge, {}

local function running()
    local res = getResourceFromName("vana-trains")
    return res and getResourceState(res) == "running"
end

-- Every crossing by the link's ends ("area.id|area.id", both ways), fetched once vana-trains runs.
local function load()
    if index or getTickCount() - triedAt < 10000 then return index end
    triedAt = getTickCount()
    if not running() then return nil end
    local ok, list = pcall(function() return exports["vana-trains"]:getCrossings() end)
    if not ok or type(list) ~= "table" then return nil end
    index = {}
    for _, c in ipairs(list) do
        for _, key in ipairs({ c.a .. "|" .. c.b, c.b .. "|" .. c.a }) do
            index[key] = index[key] or {}
            table.insert(index[key], c)
        end
    end
    return index
end

function TrainCrossings.between(a, b, kind)
    local idx = load()
    local list = idx and idx[a.area .. "." .. a.id .. "|" .. b.area .. "." .. b.id]
    if not list then return nil end
    local out
    for _, c in ipairs(list) do
        if c.kind == kind then
            out = out or {}
            out[#out + 1] = c
        end
    end
    return out
end

function TrainCrossings.refresh()
    closed = {}
    if not running() then
        index = nil -- fetched again when it's back (a restart)
        return closed
    end
    local ok, set = pcall(function() return exports["vana-trains"]:getClosedCrossings() end)
    if ok and type(set) == "table" then closed = set end
    return closed
end
