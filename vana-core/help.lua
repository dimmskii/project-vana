-- This resource's pages in /help (vana-help; the fields are explained in vana-help/help.lua).
HelpPages = {
    { name = "vanadebug", usage = "/vanadebug [resource|all] [on|off|topic,topic]", right = "command.vanadebug",
      summary = "Turn resources' debug checks on or off",
      text = [[With nothing: every resource with debug checks, whether they're on, and their topics. With a resource (vana-peds, or just peds): its state; then on (all its topics), off, or a list of topics. all on / all off: every resource at once.

Debug output goes to the server log as [debug resource:topic] lines, from the server and from players' games. The switches are kept (vana-core's debug setting) across restarts.

Topics: vana-core stuck (peds that stop moving or hang in the air, with what their owner last told them), vana-peds orders (walk and encounter orders a client couldn't give), vana-controls targets (how each action found its target), vana-traffic telemetry (slow traffic units).]],
      see = { "traffic" } },
}

function getHelpPages() return HelpPages end
