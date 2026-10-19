-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "setmoney", usage = "/setmoney <amount> [player]", right = "command.setmoney", summary = "Set a player's money",
      text = [[Sets your money, or the named player's. Saved at once.]],
      see = { "addmoney" },
    },
    { name = "addmoney", usage = "/addmoney <amount> [player]", right = "command.addmoney", summary = "Give (or take) money",
      text = [[Adds to your money, or the named player's; a negative amount takes money. Saved at once.]],
      see = { "setmoney" },
    },
    { name = "setstat", usage = "/setstat <fat|stamina|muscle|maxhealth|stat ID> <0-1000> [player]", right = "command.setstat", summary = "Set a body stat",
      text = [[Sets a ped stat on you or the named player. Setting max health also fills health to it. Any stat ID can be set, but only fat, stamina, muscle and max health are saved; others last until you leave.]],
    },
    { name = "warp", usage = "/warp <place|player|x y z [interior]> [player]", right = "command.warp", summary = "Go to a place, a player or coordinates",
      text = [[Warps you, or the player named last, to a place, a player, or coordinates. A driver takes the car and its passengers along. To a player: beside them, in their interior and dimension.

Place names (case doesn't matter; a unique start is enough):
  start, spawn, cj / home (CJ's door), carls.in (inside), sweet, ryder, ogloc
  hospital.1-8, police.1-7, by zone (hospital.jefferson), or hospital / police alone: the nearest
  ls, sf, lv: that city's police station
  interiors by vanilla's names (ammun1, gym1 ...), .in for inside
  transfender, transfender.sf, transfender.lv, locolow, waa: the mod garages
  any spot id (games.dance.floors.1, jobs.trucking.start ...)

/warps <word> lists them.]],
      see = { "warps", "warphere" },
    },
    { name = "warphere", usage = "/warphere <player>", right = "command.warphere", summary = "Bring a player to you",
      text = [[Brings the player to you (beside you; a driver brings their car).]],
      see = { "warp" },
    },
    { name = "warps", usage = "/warps [part of a name]", right = "command.warps", summary = "List the place names /warp knows",
      text = [[Lists the place names containing the word (chat shows 30, the console all). Try hospital, police, carls, games., jobs.]],
      see = { "warp" },
    },
    { name = "playertest", usage = "playertest", console = true, summary = "Self-test: persistence and restarts",
      text = [[Checks player persistence and the wasted/busted restart rules.]],
    },
    { name = "warptest", usage = "warptest", console = true, summary = "Self-test: warp places",
      text = [[Builds the place list and checks every extra name in config/player.lua points at a place.]],
    },
}

function getHelpPages() return HelpPages end
