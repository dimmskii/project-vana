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
    -- Ours: a misc counter's own stock and menu title in place of the 24/7's, by shop point name.
    stocks = {
        SEXSHOP = { title = "Sex Shop", items = {
            { name = "Dildo", weapon = 10, ammo = 1, price = 50 },
            { name = "Flowers", weapon = 14, ammo = 1, price = 20 },
        } },
    },
    -- Our prices, overriding shopping.dat by item name (e.g. vest = 15, pistol = 250). Names are the
    -- first column of shopping.dat's price sections (clothes: the texture name).
    prices = {
    },
    -- Clothes menus are grouped by apparel category (shopping.dat's clothes type), in this order.
    clothesCategories = {
        { type = 0, name = "Torso" }, { type = 2, name = "Legs" }, { type = 3, name = "Shoes" },
        { type = 16, name = "Hats" }, { type = 15, name = "Glasses" }, { type = 13, name = "Necklaces" },
        { type = 14, name = "Watches" }, { type = 17, name = "Special" },
    },
    -- Sex appeal (0-1000) per shopping.dat "sexy" point worn. Ours: a good outfit (~120 points) reaches
    -- vanilla's girlfriend thresholds (45-70%).
    sexAppealPerPoint = 5,
    -- Special costumes (clothes slot 17) that aren't sold: rewards such as girlfriends' gifts, owned as
    -- "special" items and worn from the closet. Names are ours.
    specialClothes = {
        pimp = { texture = "pimptr", model = "pimptr", name = "Pimp Suit" },
        mechanic = { texture = "garageleg", model = "garagetr", name = "Mechanic Overalls" },
        country = { texture = "countrytr", model = "countrytr", name = "Rural Clothes" },
        police = { texture = "policetr", model = "policetr", name = "Police Uniform" },
        medic = { texture = "medictr", model = "medictr", name = "Medic Uniform" },
        gimp = { texture = "gimpleg", model = "gimpleg", name = "Gimp Suit" },
        valet = { texture = "valet", model = "valet", name = "Valet Uniform" },
        croupier = { texture = "croupier", model = "valet", name = "Croupier Uniform" },
    },
    -- Fighting styles taught at the gym mats (setPedFightingStyle IDs). Each gym's mat point says which
    -- style it teaches; learned styles are owned for good and can be picked at any mat.
    fightingStyles = {
        { style = 4, name = "Default", default = true },
        { style = 5, name = "Boxing" }, { style = 6, name = "Kung Fu" }, { style = 7, name = "Kickboxing" },
    },
    fightingMinMuscle = 350, -- muscle stat (0-1000) needed to learn a style
    -- Tattoo menus are grouped by body part (shopping.dat's tattoo type = clothes slot).
    tattooCategories = {
        { type = 4, name = "Left upper arm" }, { type = 5, name = "Left lower arm" },
        { type = 6, name = "Right upper arm" }, { type = 7, name = "Right lower arm" },
        { type = 8, name = "Back" }, { type = 9, name = "Left chest" }, { type = 10, name = "Right chest" },
        { type = 11, name = "Stomach" }, { type = 12, name = "Lower back" },
    },
    -- How close to a shop point you need to be.
    radius = 1.5,

    -- Robbing a staffed shop: aiming at the keeper (or shooting, or hurting them) closes the shop, as
    -- in vanilla: the Ammu-Nation clerk draws a pistol and shoots from behind the counter, the others
    -- put their hands up (BARB, TATTO, CLOTH, and the food shops' SKBRAIN). Ours: keep the aim on a
    -- hands-up keeper for cashSeconds and they hand over the till (a holdup crime), once per shop per
    -- cooldownMs. The shop reopens once no player has been within resetRadius for resetMs.
    robbery = {
        cashSeconds = 3, aimTimeoutMs = 1500,
        cash = { food = { 80, 300 }, hair = { 60, 250 }, tattoo = { 100, 400 }, clothes = { 150, 600 }, convenience = { 100, 450 } },
        cooldownMs = 600000, resetRadius = 25, resetMs = 8000,
        clerkWeapon = 22, clerkAmmo = 30000,
    },
}
