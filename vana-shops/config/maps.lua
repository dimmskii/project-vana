-- Map data (tools/lib/map_data.lua): shop customer spots and vending machines / food carts, in
-- vana-data-shops.
MapDatasets.shops = {
    resource = "vana-data-shops", file = "shops.map", definition = "vana-shops",
    types = {
        { element = "shoppoint", friendly = "Shop point", position = true, interior = "interior", id = "name",
          fields = {
              { "kind", "string", "food", "shop kind (weapons, food, clothes, hair, tattoo, 247...)" },
              { "style", "int", nil, "fighting style taught (gym mats only)" },
              { "action", "string", nil, "the command walking in runs (default: the kind's, e.g. buyfood); its target is this shop's keeper" },
              { "note", "string", nil, "free-form note" },
          },
          rep = '<marker type="cylinder" size="1" color="#FF780060" />' },
        { element = "vendor", friendly = "Vending machine / food cart", position = true, interior = "interior",
          fields = { { "kind", "string", "soda", "what it sells (config/vendorkinds.lua)" } },
          rep = '<marker type="corona" size="0.6" color="#FFFF0080" />' },
    },
    toRecords = function(g)
        local points, vendors = {}, {}
        local names = {}
        for name in pairs(g.ShopPoints) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local p = g.ShopPoints[name]
            points[#points + 1] = { name = name, kind = p.kind, style = p.style, action = p.action, note = p.note, interior = p.interior, x = p.x, y = p.y, z = p.z }
        end
        for _, v in ipairs(g.Vendors) do
            vendors[#vendors + 1] = { kind = v.kind, interior = v.interior, x = v.x, y = v.y, z = v.z }
        end
        return { shoppoint = points, vendor = vendors }
    end,
    fromRecords = function(t)
        local points, vendors = {}, {}
        for _, r in ipairs(t.shoppoint) do
            points[r.name] = { kind = r.kind, style = r.style, action = r.action, note = r.note, interior = r.interior, x = r.x, y = r.y, z = r.z }
        end
        for _, r in ipairs(t.vendor) do
            vendors[#vendors + 1] = { kind = r.kind, interior = r.interior, x = r.x, y = r.y, z = r.z }
        end
        return { ShopPoints = points, Vendors = vendors }
    end,
}

-- In the game (not the converter): the tables the code uses.
if MapData.load then
    local data = MapData.load(MapDatasets.shops)
    ShopPoints = data.ShopPoints
    Vendors = data.Vendors
end
