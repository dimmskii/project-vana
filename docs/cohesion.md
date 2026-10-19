# Cohesion

Rules that keep the gamemode feeling like one product instead of a pile of scripts.

## Permissions

- **The server decides.** Every privileged action is checked on the server against the ACL.
  Never trust the client for permissions. Element data such as `"Admin"`, client-side
  `isPlayerAdmin` checks and hidden buttons are presentation only. The old mod gated its admin
  window on client-readable element data; don't repeat that.
- **Use MTA's own mechanisms:**
  - Commands use `addCommandHandler(name, fn, true)` (restricted), which checks
    `command.<name>` in the ACL automatically.
  - Feature rights that aren't commands use custom rights named
    `resource.<resource>.<right>`, checked with
    `hasObjectPermissionTo(player, "resource.vana-admin.vehicles", false)`.
  - Resources that need privileged MTA functions declare them with `<aclrequest>` in
    `meta.xml`, not by editing `acl.xml` by hand.
- **Groups:** the stock ACL groups (`Everyone`, `Moderator`, `SuperModerator`, `Admin`,
  `Console`) are the vocabulary. Docs and setup list exactly which rights each group needs.
- **Validate every remote event.** Treat client-triggered events as untrusted input: check
  `client` against the expected player, the rights, distances and cooldowns before acting.

## Commands

- **One implementation per action.** A command and its UI button call the same server-side
  function. There's never a UI-only or a command-only version of a privileged action.
- **Consistent naming:** lowercase full names (`/vehicle`, `/weapon`). Short aliases are
  optional and must be registered through the same handler.
- **One help registry.** Each resource describes its commands and topics in its `help.lua`
  (`HelpPages`: name, aliases, usage, required right, summary, page text, see also) and exports
  `getHelpPages`. `vana-help` collects them from every running resource and shows the manual: `/?`
  or `/man <name>` in game (MTA's client keeps `/help` for its own console list, so it never reaches
  scripts), `?`, `man` or `helptest` at the server console. A player only sees the pages they may
  use (the page's `right` in the ACL); self-tests show at the console only. A new command gets its
  page in the same change.
- **Feedback:** one shared helper for success and error messages, so wording and colours match
  everywhere.

## Freeroam tools are admin tools

- **Ordinary players get the game, not a trainer.** Spawning vehicles, giving weapons, setting
  time or weather, warping, jetpacks, gravity and so on are not available to them. They get
  vehicles, weapons, money and so on the way single player provides them.
- **Admins get the full freeroam toolset.** Vehicle spawning and tuning, weapons, skins and
  clothes, warp and teleport, time, weather, game speed, and spawning or controlling ambient
  peds and traffic. All of it sits behind ACL rights, so it can be handed out per group.

## UI layout

Each layer has one home; don't scatter windows.

| Key | Layer | Contents |
| --- | --- | --- |
| F1 | Gameplay | Player-facing game functions: stats, map and progress, owned properties and vehicles, activities. Long-term this becomes an immersive in-world cell phone. |
| F2 (proposed) | Meta and social | Friends, social features, settings, help, server info. Nothing that affects the game world. |
| F3 (proposed) | Admin | The admin toolset. The panel only opens for players whose rights the server confirms, and every action is still checked on the server. |

- **Leave MTA and player-expected keys alone:** F8 (console), F9 (help), F11 (map), F12
  (screenshot), T and Y (chat), Tab (scoreboard).
- **One visual style.** Shared colours, fonts and window chrome come from one place. Prefer
  diegetic, vanilla-style presentation (HUD-style text, the phone, in-world markers) over
  generic windows for gameplay.
- **Nothing starts by walking into it.** On-foot markers that start an activity or open a shop show
  "Press F to ..." and wait for the enter/exit key (vana-lib's `prompts`), as vanilla's tables and
  machines do; that press is swallowed whole, so it never also sends you to the nearest car.
  Driving activities (mod garages, the lowrider contest, courier, stunts, Chiliad) stay drive-in,
  as vanilla's. Entrances (doors) stay walk-through, as vanilla's.
- **In-world interactions stay in-world.** Shops, food, gyms, clothes and similar use vanilla
  markers and menus, not F1 buttons.
