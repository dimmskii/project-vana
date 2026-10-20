-- Map point categories: the icon (vanilla's radar sprite by blip ID, or an image of ours: a file of the
-- owning resource), its name for legends, and whether it only shows nearby on the radar (short range,
-- as vanilla's shop icons do) or anywhere; the map (F11) shows every point. Both are ours
-- (draw_client.lua). Hand-written: edit freely.
MapCategories = {
    ammunation = { icon = 6, name = "Ammu-Nation", short = true },
    barber = { icon = 7, name = "Barber", short = true },
    tattoo = { icon = 39, name = "Tattoo parlour", short = true },
    clothes = { icon = 45, name = "Clothes shop", short = true },
    burger = { icon = 10, name = "Burger Shot", short = true },
    chicken = { icon = 14, name = "Cluckin' Bell", short = true },
    pizza = { icon = 29, name = "Well Stacked Pizza", short = true },
    restaurant = { icon = 50, name = "Restaurant", short = true },
    diner = { icon = 17, name = "Diner", short = true },
    bar = { icon = 49, name = "Bar", short = true },
    club = { icon = 48, name = "Club", short = true },
    gym = { icon = 54, name = "Gym", short = true },
    casino = { icon = 25, name = "Casino", short = true },
    casinoTriads = { icon = 44, name = "Casino", short = true },
    school = { icon = 36, name = "School", short = false },
    race = { icon = 33, name = "Races", short = true },
    stadium = { icon = 33, name = "Stadium event", short = true },
    trucking = { icon = 51, name = "Trucking", short = false },
    quarry = { icon = 11, name = "Quarry", short = false },
    courier = { icon = 53, name = "Courier", short = true },
    lowrider = { icon = 33, name = "Lowrider contest", short = true },
    modgarage = { icon = 27, name = "Mod garage", short = true },
    spray = { icon = 63, name = "Pay 'n' Spray", short = true },
    gasstation = { image = ":vana-vehicles/icons/radar_gasstn.png", name = "Gas station", short = true },
    bigfoot = { image = ":vana-encounters/icons/radar_bigfoot.png", name = "Bigfoot", short = false }, -- while he's out (vana-encounters)
}

-- Entrances (vana-interiors' enex names) and the category their street doors show as. Patterns are Lua
-- patterns matched against the whole name.
MapEntranceCategories = {
    { "^AMMUN%d$", "ammunation" }, { "^BARBER", "barber" }, { "^TATTO", "tattoo" },
    { "^CSCHP$", "clothes" }, { "^CSSPRT$", "clothes" }, { "^LACS1$", "clothes" }, { "^CLOTHGP$", "clothes" },
    { "^CSDESGN$", "clothes" }, { "^CSEXL$", "clothes" },
    { "^FDBURG$", "burger" }, { "^FDCHICK$", "chicken" }, { "^FDPIZA$", "pizza" }, { "^FDREST1$", "restaurant" },
    { "^FDDONUT$", "diner" }, { "^DINER%d$", "diner" }, { "^TSDINER$", "diner" }, { "^REST2$", "restaurant" },
    { "^BAR1$", "club" }, { "^BAR2$", "bar" }, { "^UFOBAR$", "bar" },
    { "^GYM%d$", "gym" }, { "^TRICAS$", "casinoTriads" }, { "^MAFCAS%d?$", "casino" }, { "^CASINO2$", "casino" },
    { "^DRIVES$", "school" },
}
-- How far short-range icons show (metres).
MapShortRange = 250
