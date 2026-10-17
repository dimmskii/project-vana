-- Vending machines and food carts: what each kind sells. Prices and effects are ours (vanilla's live
-- in the compiled vending_machine/food_vendor scripts); edit freely. Shared with the client for prompts.
VendorKinds = {
    soda = { name = "Sprunk", price = 1, health = 20, fat = 0, anim = { "VENDING", "VEND_Drink_P" } },
    candy = { name = "a candy bar", price = 1, health = 10, fat = 5, anim = { "VENDING", "VEND_Eat_P" } },
    hotdog = { name = "a hot dog", price = 3, health = 35, fat = 20, anim = { "VENDING", "VEND_Eat_P" } },
    noodles = { name = "noodles", price = 3, health = 35, fat = 15, anim = { "VENDING", "VEND_Eat_P" } },
    icecream = { name = "an ice cream", price = 2, health = 25, fat = 10, anim = { "VENDING", "VEND_Eat_P" } },
}
VendorReach = 1.6 -- metres from the machine or cart to use it
