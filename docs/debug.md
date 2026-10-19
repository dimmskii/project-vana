# Debugging

## Players' errors in the server log (`vana-core`)

A client's script errors and warnings normally show only in that player's own debug view. vana-core
forwards them: `[client <name>] ERROR: file:line: message` (warnings likewise) in the server log, at
most 20 per 10 s from a client (repeats within 5 s dropped) and 30 a minute per player. Always on.

## Debug switches: `/vanadebug`

MTA's own tools only filter what's shown (`debugscript 0-3`, the levels of `outputDebugString`);
they can't turn a check off. So resources keep their debug checks behind switches, by topic, and
leave them off unless asked:

```text
/vanadebug                          every resource with checks: on or off, and its topics
/vanadebug peds                     one resource's state ("vana-" can be left out)
/vanadebug peds on | off            all its topics, or none
/vanadebug core stuck               just these topics (comma-separated)
/vanadebug all on | off             every resource at once
```

Restricted (`command.vanadebug`; vana-player grants it to `Admin`). Works at the server console.

- **Where they live:** vana-core's `debug` setting (`settings.xml`, e.g. `vana-core:stuck vana-peds`),
  so they survive restarts. vana-core puts each resource's switch on its root element as element data
  `vana:debug` (`"all"` or `"topic,topic"`) whenever that resource starts, so its server and its
  clients both see it.
- **Reading one:** vana-lib's `debug` module (`Debug.on(topic)`, either side), or the element data
  directly where a resource imports nothing on that side (vana-traffic's server).
- **Output:** `Debug.log(topic, text)` writes `[debug <resource>:<topic>] ...` to the server log; on
  a client it goes through vana-core (60 lines a minute per player, only while that switch is on).
- **A new check:** add the topic to `TOPICS` in `vana-core/server.lua` (it lists them and refuses
  unknown ones), guard it with `Debug.on`, and say what it does here.

## Topics

| Resource:topic | Checks |
| --- | --- |
| `vana-core:stuck` | Every 2 s, each client looks at the peds within 80 m on foot: one that hasn't moved 0.3 m in 6 s, or hangs in the air without falling for 2 s, is reported once (until it moves again). The client says whether it simulates the ped (`mine`), frozen, on the ground, how far above the ground (or "not loaded": no collision), speed, its primary and simplest task, animation, health and our tags (`ambient`, `service`, `keeper`). The server adds the ped's syncer and what vana-peds and vana-services last told it (their `describePed`: the walk target and when it was sent, the encounter, the crew's state, the owner). |
| `vana-peds:orders` | A walk or encounter order the client couldn't give: why it might be (target not streamed, the task the ped is in, mission actor, frozen, how full GTA's route pools are). Off, these are silent (they used to be a warning each time). Also every recovery ([traffic.md](traffic.md), "Keeping them walking"): a lost syncer pinned back, a walk given again, a fresh route after a stuck walk or a long wait at a kerb, a follower sent back to its slot, a hanging ped put back down or removed. |
| `vana-controls:targets` | For each action run: the target named, or every candidate it tried (clicked, the car you sit in, what you can see) and why each was taken or passed over. |
| `vana-traffic:telemetry` | Slow traffic units and their native autopilot state; `/traffic debug on|off` sets the same switch. |

Reading a stuck ped's line: `mine false` with `syncer none` means nobody simulates it (it freezes in
its pose); `ground not loaded` with `HANGING` means no collision under it; `mine true` with an idle task
and an old "sent" means its last order didn't take.
