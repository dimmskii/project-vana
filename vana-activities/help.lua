-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "activities", topic = true, summary = "Starting activities, jobs and minigames",
      text = [[Markers you walk to (shops, the gym, dancing, races, schools, trucking...) show "Press F to ...": stand on them and press enter/exit; nothing starts by walking into them. Driving ones (the mod garages, the lowrider contest, courier, stunts, Chiliad) start when you drive into them.

Vehicle jobs (taxi, paramedic, firefighter, vigilante, pimping) start with the sub-mission key (2) in the right vehicle.

Dancing and the lowrider contest play the music at the club or contest spot; arrows for dancing, the hydraulics keys (numpad, two at once for diagonals) for the lowrider contest, which any car with hydraulics can enter.]],
      see = { "garages" },
    },
    { name = "activitytest", usage = "activitytest", console = true, summary = "Self-test: activities",
      text = [[Checks every activity's data: burglary, dating, jobs, schools, races, stadium, games.]],
    },
}

function getHelpPages() return HelpPages end
