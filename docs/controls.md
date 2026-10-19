# Controls: /use, /interact and actions (`vana-controls`)

Everything a player does to the world outside driving and fighting is a command, so it can be typed,
bound to a key or picked from a menu, and the three always do the same thing. Two commands carry
the keys:

| Command | Default keys | What it does |
| --- | --- | --- |
| `/use` | F, Enter (vanilla's enter/exit keys) | What the help box offers where you stand: a shop counter, a machine, loot, getting off gym equipment. With nothing offered, the key is GTA's enter/exit again (cars). |
| `/interact` | F1 | The cursor and a command box: click a vehicle, ped or player for its menu, or type any command, with suggestions. |

Both are bound with `bindKey(key, "down", command)`, so they're listed under **vana-controls** in
MTA's Settings > Binds, where players rebind them (MTA remembers a player's change over our default).
`/use` takes F and Enter; the other two slots there are free for a third key or a pad button.

## /use and offers

Scripts *offer* what `/use` does (client: `exports["vana-controls"]:offer(id, text [, silent])`,
`withdraw(id)`); the latest offer wins and pressing raises `onClientVanaUse(id)` on the root
element. Ids start with the resource's name (`vana-shops:vendor`), so a stopping resource's offers go
with it. When vana-controls (re)starts it raises `onClientVanaUseReset` and scripts offer again.

- **The prompt** ("Press F to order food") shows as the status text, top middle with no box: GTA's
  own font with its drop shadow, drawn by the game (Neon's positioned `drawText`), clear of the chat
  in the top left. Not GTA's help box: that one is pinned top left and its slot can stay busy with
  nothing showing.
- **Where it lands:** GTA places script text from the bottom of the screen, with a vertical scale
  that MTA's HUD aspect setting (Settings > Video) multiplies by aspect ratio / 4:3, while script
  rectangles are placed from the top. A box and its text therefore drift apart on any screen but
  4:3, and a y near the top can land off-screen. The script y is worked out from the setting
  (`dxGetStatus`) so the text sits 3.5% down the screen whatever it is. Our own DX drawing doesn't
  follow that setting at all (MTA's `dxSetAspectRatioAdjustmentEnabled` would), which is why it can
  sit a little off GTA's HUD. `text` is a verb phrase, or a GXT string with `~k~~VEHICLE_ENTER_EXIT~` where the key
  name goes (the `/use` key, whatever it's bound to). `silent` offers show nothing (the script has
  its own help, like the gym's bar). The prompt waits while a menu has the controls off.
- **The key is ours alone:** while there's an offer (on foot), GTA's `enter_exit` control is off, so
  the same press never also sends CJ to a car nearby. With no offer, it's turned back on.
- **Who offers:** vana-lib's `prompts` (every "Press F" marker: gym machines, the shooting range,
  quarry, the Blood Ring, dancing, shop counters), vending machines and food carts, minigame spots,
  burglary loot and the van, gym equipment while working out (getting off).

## Actions

An action is something a player does to something: `/engine`, `/lights`, `/givemoney`, `/buyfood`.
Each resource adds its own with vana-lib's `actions` module (`Actions.add{...}`, server; the fields
are at the top of `vana-lib/lib/actions.lua`) and exports `getActions`, `checkActionTarget`,
`getTargetActions` and `runAction`. vana-controls collects them from every running resource and
registers each one, aliases too, as a **client** command (MTA also sends any typed command to the
server, so the server never registers them itself: they would run twice).

Running one (typed, bound or picked) sends the server the words typed after it, what was clicked, and
what the player can see: vehicles, players, peds and markers within 12 m with nothing solid in
between (`isLineOfSightClear` from the player), those within 30 degrees of the middle of the view
first by angle, then the rest by distance. The server picks the target:

1. a `#id` anywhere in the words (the number /interact shows next to a name), or a player's name for
   an action whose params take a `target`;
2. for `inside` actions, the vehicle the player sits in;
3. what was clicked, then the seen list in order: the first element the action takes.

An action's `accepts` can depend on the player: the vehicle actions take only the player's own
vehicle while they sit in one, so a car alongside is never the target from inside yours.

**The gate**, the same for every action: the target is in the player's dimension and interior,
within the action's `reach`, in the seen list (or the player's own vehicle), and alive. Then the
action's `run` decides the rest (who may, money, cooldowns) and returns the message to show.
Line of sight is the client's word: the server has no collision to check it against.

**Messages** go to the status line (`exports["vana-controls"]:status(player, text)` on the server,
`Actions.status` from the module, or `status(text)` from another resource's client): the status
text (top middle) for 4 s, copied to the player's console. Activity help (vana-activities'
`Hud.help`) shares it: a message first, then help, then the prompt. **Subtitles** (objectives, spoken lines, "You cannot mod
this vehicle.") go to the game's own subtitle line, bottom middle (`subtitle(text, ms)` on the
client; vana-activities' subtitles use it). A text longer than the game takes (160 bytes) is drawn by
us in the same place instead.

### The actions

| Action | Target | Who | Does |
| --- | --- | --- | --- |
| `/givemoney <amount> [player]` (`/pay`) | a player, 4 m | anyone | Moves the cash, saves both, tells both |
| `/engine` | your vehicle | its driver | Engine off or on (not with an empty tank) |
| `/lights` | your vehicle | its driver | On, off, automatic (the game's: night, tunnels), in turn |
| `/lock` | a vehicle, 6 m | its driver, or a holder beside it | Locks or unlocks the doors |
| `/hood`, `/trunk`, `/doorfrontleft`, `/doorfrontright`, `/doorrearleft`, `/doorrearright` | your vehicle, or on foot one within 6 m | inside: the driver for the hood and trunk, each seat its own door; on foot: anyone, when unlocked | Opens or closes it (rear doors on 4+ seaters; a missing door is gone) |
| `/buyfood`, `/buyweapons`, `/buyclothes`, `/buyitems`, `/haircut`, `/tattoo`, `/learnstyle` | the shop's keeper or counter marker, 8 m | anyone | Opens that shop's menu (the keeper seats you; shops without one need you at the counter) |

A shop point's action is its kind's unless its map element names another (`action` on `shoppoint`
in `[data]/vana-data-shops/shops.map`, editable in the Map Editor); the target is that shop's keeper.
Walking onto a shop counter runs its action at once, as vanilla's counters open their menu.

## /interact

The cursor comes up and a command box opens at the bottom of the screen (an invisible MTA edit box
takes the keys, with binds off while it has them; we draw it).

- **Picking:** what the cursor points at (a ray from the camera through it, `processLineOfSight`)
  glows: a tint shader on its textures (`highlight.fx`) and a green arrow above it. Its name and `#id`
  show by the cursor. Clicking it asks the server for its menu (`getTargetActions`, past the gate).
- **The menu:** next to the click. Click, or arrows and Enter. An entry that needs more (an amount)
  fills the box with its command for that target, so typing the rest and Enter runs it.
- **Typing:** suggestions from the actions and every documented command the player may use
  (vana-help's pages, as `/?` lists them). Enter takes the highlighted one, Tab completes it. Anything
  that isn't an action runs as the command it is: client handlers here, server handlers through
  `executeCommandHandler` (a right vana-controls asks for in its meta), which checks the player's ACL
  rights as typing it would.
- Escape closes the menu, then the box; the `/interact` key closes it too. Running anything closes it.
- Picking needs the mouse; the menus themselves don't.

## Preferences (`/preferences`, `/prefs`, F9)

One panel for each player's own settings, a vana-lib `menu_list`: the sections and settings are
`vana-controls/config/preferences.lua` (key, label, choices, default), headings the selection passes
over. Values change at once and are kept in `@prefs.json`, a private file of vana-controls on the
player's machine. Any client script reads one with `exports["vana-controls"]:getPreference(key)` and
hears about changes from `onClientPreferenceChange` (key, value) on the root element.

| Key | Setting | Read by |
| --- | --- | --- |
| `map.blipSize` | HUD > Map > Blip size (60%-175%) | the map (F11) |
| `minimap.rotation` | HUD > Minimap > Rotation: turns with the camera (vanilla), or north up | the radar |
| `minimap.blipSize` | HUD > Minimap > Blip size | the radar |
| `minimap.blipRange` | HUD > Minimap > Nearby icons' range (x0.5-x3 of the short range) | the radar |

## Menus

Every menu takes the keyboard, the pad and the mouse (vana-lib's `menu_input`): arrows, D-pad or
wheel move; Enter, the pad's sprint button (else joy1) or a left click take; Backspace, Escape, the
pad's enter/exit button (else joy2) or a right click go back. The cursor shows while a menu is open.
A long menu scrolls two ways: moved by the keys or the pad, the view follows the selection as it
always has (a margin of half the rows); picked by the mouse, it stays where it is (hovering only
selects), and the wheel over the menu scrolls it a row at a time, selecting the row then under the
cursor. Away from the menu, the wheel moves the selection like the arrow keys.
Menus with the controls off swallow their keys, so binds (`/use` on Enter) don't fire under them.
Done for the shop, garage, activity pick and driving school menus; the casino, pool and side games
still take the arrow keys only.

`controlstest` (console) checks that the actions load and parse, `#id`s and the reach.

## Not yet

- **In game:** the native help box (font, sound, how it sits with other HUD), the highlight shader,
  the command box's focus after clicking the world, and pad buttons are untested.
- **Desktop:** a column of icons at a screen edge may come later; the command box and menus keep
  clear of the sides. vana-help's old window (`desktop_client.lua`) waits for its "?" icon.
- **Vehicles:** which car GTA will pick to enter isn't known to scripts; /interact uses what you click.
