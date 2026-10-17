# References

## APIs

- **Neon wiki:** <https://mtasa-neon-wiki.vercel.app/neon/>. Covers Neon-only functionality on
  top of upstream MTA, such as native ped and vehicle AI, the story runtime and synchronized AI
  (<https://mtasa-neon-wiki.vercel.app/neon/synchronized-ai>).
- **Upstream MTA wiki:** <https://wiki.multitheftauto.com/wiki/Main_Page>. Everything not
  Neon-specific.
- **Neon source:** <https://github.com/Dryxio/mtasa-neon>, pinned to tag `neon-2026.10.09.188`.
  The `official-resources/` folder has worked examples of the native APIs (`native-ped-traffic`,
  `native-vehicle-traffic`, `native-task-runtime`, `story-world-runtime`), and the top-level docs
  (`STORY_RUNTIME.md`, `NATIVE_WORLD_HANDOFF.md`) are worth reading.

## Vanilla behavior

- **Decompiled `main.scm`:** the reference for missions, side activities, timings and world
  state.
- **gta-reversed:** <https://github.com/gta-reversed/gta-reversed>. Reverse-engineered SA engine
  code, for engine-side rules that `main.scm` doesn't contain (for example
  `CTrafficLights::ShouldCarStopForLight`).
- **Path file format:** <https://gtamods.com/wiki/Paths_(GTA_SA)> and
  <https://www.grandtheftwiki.com/Paths_(GTA_SA)>. These are inaccurate in places; see
  [paths-and-lights.md](paths-and-lights.md) for what we verified against the files.

## Prior work

- **The old `[dima]` resources** (`riot`, `riot-npc`, `project-trains` and more) for upstream MTA.
  They're reference only, not code to port wholesale. `riot-npc` holds the earlier ped and traffic
  work, which used pre-dumped Lua tables of the path data.
