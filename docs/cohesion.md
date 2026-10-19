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
- **Everything a player does is a command.** Keys are binds to commands (`bindKey(key, state,
  command)`), never `onClientKey` hooks on a game control, so every one shows in MTA's binds menu and
  can be rebound. What a player does *to* something (a car, a player, a shopkeeper) is an action
  (vana-lib's `actions`, see [controls.md](controls.md)): typed, bound, or picked in `/interact`, with
  the target named, clicked or looked at, through one gate (dimension, interior, reach, sight).
  Only things that make no sense as a command (a held minigame key) stay key handlers.
- **Consistent naming:** lowercase full names (`/vehicle`, `/weapon`). Short aliases are
  optional and must be registered through the same handler.
- **One help registry.** Each resource describes its commands and topics in its `help.lua`
  (`HelpPages`: name, aliases, usage, required right, summary, page text, see also) and exports
  `getHelpPages`. `vana-help` collects them from every running resource and prints the manual to the
  chat (and the console): `/?` or `/man <name>` in game (MTA's client keeps `/help` for its own console list, so it never reaches
  scripts), `?`, `man` or `helptest` at the server console. A player only sees the pages they may
  use (the page's `right` in the ACL); self-tests show at the console only. A new command gets its
  page in the same change.
- **Feedback:** one shared helper for success and error messages, so wording and colours match
  everywhere: vana-controls' status box (top middle, in the game's own font, copied to the console), from the
  server `exports["vana-controls"]:status(player, text)` (or `Actions.status`).

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
| F, Enter | `/use` | What the help box offers where you stand; otherwise GTA's enter/exit (cars). |
| F1 | `/interact` | The cursor and the command box: click a car, a ped or a player for what you can do to it, or type a command. Player-facing game functions (stats, progress, properties, the future cell phone) come in through here. |
| F2 (proposed) | Meta and social | Friends, social features, settings, help, server info. Nothing that affects the game world. |
| F3 (proposed) | Admin | The admin toolset. The panel only opens for players whose rights the server confirms, and every action is still checked on the server. |

- **Leave MTA and player-expected keys alone:** F8 (console), F9 (help), F11 (map), F12
  (screenshot), T and Y (chat), Tab (scoreboard).
- **One visual style.** Shared colours, fonts and window chrome come from one place. Prefer
  diegetic, vanilla-style presentation (HUD-style text, the phone, in-world markers) over
  generic windows for gameplay. Messages and help use the status box, top middle, in the game's own font (Neon's native text); subtitles the game's own subtitle line.
- **Menus take every input:** arrows, the pad and the mouse (vana-lib's `menu_input`); picking
  something in the world with `/interact` is the one thing that needs the mouse.
- **Screen edges stay clear** for a possible column of desktop icons (help and the like) later.
- **Walk-in where vanilla is.** Shop counters (food, Ammu-Nation, 24/7, clothes, barbers, tattoos,
  gym trainers) open as you walk onto them, running the shop's action, and `/use` reopens them there.
  Machines, tables and activity markers show "Press F to ..." and wait for `/use` (vana-lib's
  `prompts`), as vanilla's do; while one is offered, GTA's enter/exit is off, so the press never also
  sends you to the nearest car. Driving activities (mod garages, the lowrider contest, courier,
  stunts, Chiliad) stay drive-in, entrances (doors) walk-through, as vanilla's.
- **In-world interactions stay in-world.** Shops, food, gyms, clothes and similar use vanilla
  markers and menus, not F1 buttons.
