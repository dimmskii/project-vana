-- Shops: how shopping.dat's items map onto the game, and our own stock. Hand-written: edit freely.
ShopConfig = {
    -- shopping.dat weapon names -> MTA weapon IDs ("armour" is body armour, not a weapon).
    weapons = {
        pistol = 22, pistol_silenced = 23, desert_eagle = 24, grenade = 16, shotgun = 25, spas12 = 27,
        sawnoff = 26, micro_uzi = 28, tec9 = 32, mp5 = 29, ak47 = 30, m4 = 31, countryrifle = 33,
        sniperrifle = 34, rlauncher = 35, rlauncher_hs = 36, fthrower = 37, satchel_charge = 39, minigun = 38,
    },
    -- Eating: "calories N" restores N health and adds fat (fatPerCalorie per point); "health N"
    -- restores N health only.
    fatPerCalorie = 2,
    -- Fallback names for food items (menus use vanilla GXT names from data/american.gxt when present).
    foodNames = {
        clucklow = "Cluckin' Little Meal", cluckmed = "Cluckin' Big Meal", cluckhigh = "Cluckin' Huge Meal", cluck_healthy = "Salad Meal",
        pizzalow = "Buster", pizzamed = "Double D-Luxe", pizzahigh = "Full Rack", pizza_healthy = "Salad Meal",
        burgerlow = "Moo Kids Meal", burgermed = "Beef Tower", burgerhigh = "Meat Stack", burger_healthy = "Salad Meal",
    },
    -- 24/7 counters: not a vanilla shop. Our misc stock (weapon ID, ammo, price).
    misc = {
        { name = "Camera", weapon = 43, ammo = 36, price = 100 },
        { name = "Flowers", weapon = 14, ammo = 1, price = 20 },
        { name = "Cane", weapon = 15, ammo = 1, price = 50 },
        { name = "Brass Knuckles", weapon = 1, ammo = 1, price = 100 },
        { name = "Spraycan", weapon = 41, ammo = 500, price = 100 },
        { name = "Fire Extinguisher", weapon = 42, ammo = 500, price = 200 },
        { name = "Parachute", weapon = 46, ammo = 1, price = 500 },
    },
    -- Our prices, overriding shopping.dat by item name (e.g. vest = 15, pistol = 250). Names are the
    -- first column of shopping.dat's price sections (clothes: the texture name).
    prices = {
    },
    -- Clothes menus are grouped by apparel category (shopping.dat's clothes type), in this order.
    clothesCategories = {
        { type = 0, name = "Torso" }, { type = 2, name = "Legs" }, { type = 3, name = "Shoes" },
        { type = 16, name = "Hats" }, { type = 15, name = "Glasses" }, { type = 13, name = "Necklaces" },
        { type = 14, name = "Watches" },
    },
    -- How close to a shop point you need to be.
    radius = 1.5,
}
