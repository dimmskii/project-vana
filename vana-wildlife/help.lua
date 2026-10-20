-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "animal", usage = "/animal <species>", right = "command.animal", summary = "Spawn an animal ahead of you",
      text = [[One animal of that species 8 m in front of you (hare, deer, boar, cat, dog, wolf, brownbear, blackbear, puma, leopard), with its usual behaviour: prey runs, predators may go for you. Gone once you're far away. How many spawn on their own, and how aggressive they are: /vanaset wildlife.]],
      see = { "vanaset" } },
    { name = "wildlifetest", usage = "wildlifetest", console = true, summary = "Self-test: wildlife",
      text = [[Every spawner names a known species, and every species' model, animation and sound files are here; the species spawning and the settings in force.]],
    },
}

function getHelpPages() return HelpPages end
