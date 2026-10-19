-- Map data (tools/lib/map_data.lua): hospital and police restart points, in vana-data-player.
MapDatasets.restarts = {
    resource = "vana-data-player", file = "restarts.map", definition = "vana-player",
    types = {
        { element = "restart", friendly = "Restart point", position = true, rotation = "heading",
          fields = { { "kind", "string", "hospital", "hospital (wasted) or police (busted)" } },
          rep = '<marker type="cylinder" size="1.5" color="#FF404080" /><ped model="274" rotation="!rotation!" />' },
    },
    toRecords = function(g)
        local list = {}
        for _, kind in ipairs({ "hospital", "police" }) do
            for _, r in ipairs(g.Restarts[kind]) do
                list[#list + 1] = { kind = kind, x = r.x, y = r.y, z = r.z, heading = r.heading }
            end
        end
        return { restart = list }
    end,
    fromRecords = function(t)
        local out = { hospital = {}, police = {} }
        for _, r in ipairs(t.restart) do
            table.insert(out[r.kind], { x = r.x, y = r.y, z = r.z, heading = r.heading })
        end
        return { Restarts = out }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.restarts)
    Restarts = data.Restarts
end
