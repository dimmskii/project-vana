# Mission

## Goal

Build a freeroam gamemode that is true to vanilla San Andreas (`main.scm`) in everything except
the linear story.

- **In:** the open world as single player has it: ambient peds and traffic, side activities,
  burglary, dating with its cutscenes, shops, gyms, vehicle sub-missions, collectibles and
  everything else that lives in the world rather than in the story.
- **Out:** linear mission progression. There are no story missions, and nothing is locked behind
  the chapter the save is on. Content that vanilla unlocks or hides depending on story progress is
  always available here.
- **Multiplayer first:** it all has to work for several players at once, synchronized and
  server-authoritative.

## Fidelity

- **Vanilla is the reference.** When in doubt, do what the game does. The decompiled `main.scm`
  and the retail data files (`data/*.dat`, `data/Paths/`) are the source of truth for behavior,
  timings, locations and content. Prefer reading retail data at runtime over hand-copied tables.
- **Go beyond vanilla where Neon makes it better.** MTA Neon exposes native engine features
  (native ped and vehicle AI, story runtime, extended radar and more) on top of upstream MTA.
  Where one of those gives a more faithful or better result than a vanilla limitation or a
  script-side imitation, use it.
- **Story-locked state has one fixed choice.** For world state that vanilla changes as the story
  advances (gang territories, open islands, shop stock and so on), pick one fixed, sensible state
  and record the decision in the relevant resource's README.

## Shape of the code

- **Pure Lua resources** live under `mods/deathmatch/resources/[vana]/`. Server and engine
  changes are out of scope.
- **The resources folder starts clean:** no stock MTA resources are assumed. Anything we depend
  on is either ours or an explicit, documented dependency.
- **Server-side testable:** each resource should be testable on the Linux dedicated server
  without a client where possible, for example with a console self-test command.
