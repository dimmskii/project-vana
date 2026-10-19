-- Map data (vana-lib's map_data): the speakers music zones are heard from, in vana-data-radio. Placed
-- by hand in the Map Editor (no seed).
MapDatasets.radio = {
    resource = "vana-data-radio", file = "radio.map", definition = "vana-radio",
    types = {
        { element = "speaker", friendly = "Speaker (plays a station)", position = true, interior = "interior",
          fields = {
              { "station", "int", 101, "the station it plays (an id in vana-radio's config/radio.lua)" },
              { "range", "number", 30, "heard this far away (m)" },
              { "volume", "number", 1, "0 to 1" },
              { "note", "string", nil, "free-form note" },
          },
          rep = '<marker type="corona" size="1" color="#FF40C080" />' },
    },
    toRecords = function(g) return { speaker = g.Speakers } end,
    fromRecords = function(t) return { Speakers = t.speaker } end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    Speakers = MapData.load(MapDatasets.radio).Speakers
end
