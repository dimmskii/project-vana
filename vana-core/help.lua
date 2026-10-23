-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "vanadebug", usage = "/vanadebug [resource|all] [on|off|topic,topic]", right = "command.vanadebug",
      summary = "Turn resources' debug checks on or off",
      text = [[With nothing: every resource with debug checks, whether they're on, and their topics. With a resource (vana-peds, or just peds): its state; then on (all its topics), off, or a list of topics. all on / all off: every resource at once.

Debug output goes to the server log as [debug resource:topic] lines, from the server and from players' games. The switches are kept (vana-core's debug setting) across restarts.

Topics: vana-core stuck (peds that stop moving or hang in the air, with what their owner last told them), vana-peds orders (walk and encounter orders a client couldn't give), vana-controls targets (how each action found its target), vana-traffic telemetry (slow traffic units), vana-trains sync (trains made, removed, taken, out of step), vana-air sync (aircraft made, removed, taken, come down), vana-wildlife brains (what animals decide).]],
      see = { "traffic", "vanaset" } },
    { name = "vanaset", usage = "/vanaset [resource] [name value]", right = "command.vanaset",
      summary = "Change a resource's settings (density, caps...)",
      text = [[With nothing: the resources with settings. With a resource (vana-wildlife, or just wildlife): its settings and their values; then a name and a value to change one. Takes effect at once and is kept (the server's settings.xml) across restarts; the admin panel's resource settings are the same ones.

Settings so far: vana-wildlife (enabled, species, density, caps, aggression), vana-peds and vana-traffic (density, maxPerPlayer), vana-trains (freight, passenger, trams), vana-air (at400, andromada, shamal, nevada).]],
      see = { "vanadebug", "traffic" } },
}

function getHelpPages() return HelpPages end
