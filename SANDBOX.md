# TF2VR Campaign Sandbox

The campaign sandbox is an experimental developer layer added by the
**TF2VR Quality of life** Northstar mod. It lives in the real single-player
pause menu and provides a set of reversible tools: an NPC catalog, managed
NPC removal, a session bookmark, three saved positions, noclip fly and menu diagnostics.

It is **not** a map editor, a campaign-save editor, a multiplayer tool or a
general entity spawner. The available controls are deliberately small, and
unverified systems are left out rather than shown as dead buttons.

> **Runtime status:** the sandbox has been source-inspected, packaged and
> statically checked, but has **not been run in Titanfall 2 or in a VR
> headset** in the development environment. Treat it as experimental and use a
> disposable campaign mission for testing.

## Requirements and entry

- Titanfall 2 with CircuitLord's VR mod and Northstar installed.
- The **TF2VR Quality of life** package installed in `TF2VR\packages`.
- A loaded single-player campaign mission.

To open it:

1. Load a campaign mission.
2. Pause the game.
3. Press **Y** on **SANDBOX / DEV TOOLS**.
4. Use the sandbox pages; **B** leaves the sandbox.

The entry is appended to the campaign `InGameSPMenu`. Vanilla pause entries
such as Resume, Restart, Settings and Quit are not replaced. The main-menu
**TF2VR Quality of life** settings page is a separate feature and is unchanged.

## Pages

| Page | What it does |
|---|---|
| **Mission Control** | Shows the live map, session state, NPC counts and the most recent action result. Also the navigation hub. |
| **Maps & Environments** | Lists the 13 campaign map IDs, marks the current map and shows catalog details. Map travel is disabled. |
| **NPC Browser** | Searches and filters a 62-entry NPC catalog by category, opens details, and selects a spawn. |
| **NPC Details** | Shows the class, AI settings ID, support status, restrictions, dependencies, team and spawn action. |
| **Managed NPCs** | Lists tracked sandbox NPCs eight at a time, removes one by ID, and clears all tracked NPCs. |
| **Player Utilities** | Saves, returns to and clears a session bookmark, and toggles noclip fly. |
| **Position Presets** | Saves and loads three map-locked positions through the mod's Safe I/O folder. |
| **Developer Information** | Shows telemetry, dumps the current layout to `nslog`, changes overlay opacity and toggles debug logging. |

### Mission Control

Mission Control is the root page. Its rows open the top-level sandbox pages or
close the sandbox. The header shows the current campaign map and sandbox-managed NPC
count. The status line shows the last action result, including rejected actions.

### Maps & Environments

The catalog is read-only. It lists the campaign map IDs used by the game and
marks the current one with `>`. Selecting another entry only updates the details
panel; it does not call `ChangeLevel` or start a transition.

The page intentionally has no **TRAVEL** control. Campaign transitions have
side effects that have not been validated, so map switching remains outside this
build.

### NPC Browser, Details and Managed Roster

The old three-button page is now a catalog browser. The catalog contains **62
entries**, grouped into six categories: **Human Characters**, **Mechanical
Characters**, **Wildlife**, **Drones and Aircraft**, **Large NPCs** and **Other
Supported Entities**. The browser supports text search, category filtering,
six results per page, and a managed-NPC/status footer.

Source verification distinguishes an **AI settings identifier** from an entity
class. The spawn path is `CreateNPCFromAISettings(aiSettings, team, origin,
angles)` followed by `DispatchSpawn(npc)`. The server accepts only the 24
entries in its explicit allow-list; the other catalog entries are shown as
unavailable references with their restrictions.

| Status | Meaning in this build |
|---|---|
| `VERIFIED_SPAWNABLE` | AI settings and the needed BaseClass were found in the game scripts, and the generic NPC creation path is documented. **Not yet exercised in game.** |
| `NOT_TESTED` | Known AI settings, but the exact campaign-map behaviour has not been checked. Spawn is enabled only for the four elite-pilot entries. |
| `VERIFIED_BUT_MAP_DEPENDENT` | The class exists but needs map geometry or a flight path. Spawn is disabled. |
| `REQUIRES_SPECIAL_SPAWNER` | Needs a campaign spawner, Titan loadout, turret owner/model or scripted setup. Spawn is disabled. |
| `AI_SETTING_ONLY` | Reference entry; not exposed for independent creation. |
| `DEPRECATED` | Present in deprecated data; not exposed. |
| `UNSUPPORTED` | No safe creation path is currently claimed. |

The 24 server-accepted AI settings are:

- **Human:** `npc_soldier`, `npc_soldier_specialist`,
  `npc_soldier_specialist_militia`, `npc_soldier_sidearm`,
  `npc_soldier_shield_captain`, `npc_soldier_hero_bear`,
  `npc_soldier_hero_sarah`, `npc_pilot_elite`,
  `npc_pilot_elite_assassin`, `npc_pilot_elite_assassin_cqb`,
  `npc_pilot_elite_assassin_sniper`.
- **Mechanical:** `npc_spectre`, `npc_stalker`, `npc_marvin`,
  `npc_super_spectre`, `npc_stalker_zombie`,
  `npc_stalker_zombie_mossy`.
- **Wildlife:** `npc_prowler`.
- **Drones:** `npc_drone`, `npc_drone_beam`, `npc_drone_plasma`,
  `npc_drone_worker`, `npc_frag_drone`, `npc_frag_drone_throwable`.

Titans, dropships, gunships, turrets and the deprecated hero/story variants
remain visible in the browser as **unavailable** entries. They are not sent to
`CreateNPCFromAISettings`; their specialized spawner requirements are shown in
Details. The large-entry category can therefore be inspected without offering
a button that is known to be incomplete.

#### NPC Details

Selecting a browser row stores its catalog ID and opens a details page with:

- display name, category and catalog status;
- AI settings identifier and verified entity BaseClass;
- creation path and the **runtime not tested** label;
- current count for that type, total managed count, cap and spawn distance;
- restrictions and dependencies;
- a friendly/hostile team switch;
- **SPAWN** only when the catalog entry is server-accepted;
- **MANAGED NPCs** and **BACK**.

The server clamps the cap to 1-20 and the spawn distance to 64-512 units. It
also requires a living, grounded player, a campaign map and a clear forward
trace. The spawn is placed along the player's view direction.

#### Managed NPCs

Every accepted spawn receives a stable sandbox ID and is stored in parallel
arrays with its entity handle, AI settings ID and team. The managed page shows
eight entries per page. Press a row twice to remove that specific ID; press
**CLEAR ALL SANDBOX-MANAGED NPCs** twice to remove every tracked handle.

Removal validates the requested ID against the tracked roster. The server never
scans and destroys unrelated campaign NPCs. A destroyed or invalidated handle is
pruned during the next status update. Changing maps discards the old handle list
without touching the old level.

### Player Utilities

**SAVE POSITION BOOKMARK** stores the player's current origin and angles in the
server VM for the current session. Returning restores the origin and yaw and
clears velocity. The bookmark is not written to disk and disappears when the
map changes. Saving requires solid ground; returning and clearing do not.

**FLY (NOCLIP)** toggles the local player between `MOVETYPE_NOCLIP` and
`MOVETYPE_WALK` and clears velocity on each toggle. It is campaign-only and
requires a living player, but not ground contact. Noclip ignores collision, so
it can pass through geometry and leave campaign bounds. It is not god mode,
a teleport or a progression tool.

### Position Presets

There are three fixed slots. A save writes the current map ID, coordinates and
yaw into a mod-scoped Safe I/O text file. A load is accepted only if:

- the file exists and contains the expected fields;
- the saved map ID matches the current map;
- the coordinates and yaw are within the server's accepted range.

Preset storage is separate from campaign saves. The files are named
`sandbox_position_1.txt`, `sandbox_position_2.txt` and
`sandbox_position_3.txt`. The slot summary reports **SAVED POSITION** or
**EMPTY**; renaming, duplicating, browsing and deleting presets are not
implemented.

### Developer Information

Developer Information shows the current map ID, session mode, coordinates,
entity/NPC/managed counts, cap and spawn distance. The controls are:

- **LOG CURRENT LAYOUT TO NSLOG** — dumps the page again while debug logging is on.
- **REFRESH SESSION TELEMETRY** — asks the server for new status values.
- **LAYOUT OPACITY** — cycles 10%, 20%, 35%, 50%, 75% and 100%.
- **DEBUG LOGGING** — enables or disables the diagnostic lines.
- **BACK TO MISSION CONTROL** — leaves the page.

Press **Y** on any sandbox page to toggle the on-screen layout overlay. It draws
the page panel in orange and the focusable controls and footer in cyan using
live HUD bounds. The overlay is independent of debug logging. Its visibility is
stored in the archived `tf2vrsb_overlay` ConVar, and its opacity is stored in
the archived `tf2vrsb_overlay_opacity` ConVar, so both survive a UI reload or
game restart.

## How a control reaches the game

The sandbox is split across three Squirrel VMs:

```text
UI menu
  -> RunClientScript("TF2VRSB_SendCommand", command)
CLIENT VM
  -> allow-list check
  -> GetLocalClientPlayer().ClientCommand(command)
SERVER VM
  -> AddClientCommandCallback validation
  -> world action or status update
  -> tf2vrsb_* status ConVars
UI menu
  -> labels refresh from the ConVars
```

The UI never creates or destroys entities and never calls the server directly.
The client forwards only these commands:

- `tf2vrsb_status`
- `tf2vrsb_spawn_npc`
- `tf2vrsb_remove_managed`
- `tf2vrsb_clear_managed`
- `tf2vrsb_save_bookmark`
- `tf2vrsb_return_bookmark`
- `tf2vrsb_clear_bookmark`
- `tf2vrsb_toggle_fly`
- `tf2vrsb_load_preset`

The server checks the campaign session, the player, the map, the NPC cap, the
spawn trace and the preset map/range before acting. This is the boundary that
keeps a menu click from becoming an arbitrary game command.

## Key settings and runtime state

| ConVar | Default | Purpose |
|---|---|---|
| `tf2vrsb_cap` | `6` | NPC cap; the UI offers 2-10, the server hard-caps at 20 |
| `tf2vrsb_npc_category` | `0` | Browser category filter, 0 = all |
| `tf2vrsb_spawn_team` | `1` | Details team selection, 0 = player team, 1 = hostile |
| `tf2vrsb_managed_page` | `0` | Managed-roster page index |
| `tf2vrsb_spawn_distance` | `150` | Spawn distance; the UI offers 100-300, the server clamps to 64-512 |
| `tf2vrsb_debug` | `1` | Writes `[TF2VRSB]` diagnostic lines to `nslog` |
| `tf2vrsb_overlay` | `0` | Archived layout-overlay visibility |
| `tf2vrsb_overlay_opacity` | `20` | Archived layout-overlay opacity percentage |

The remaining `tf2vrsb_*` ConVars are status values written by the server:
map, mode, ready state, coordinates, yaw, entity/NPC/managed counts, bookmark,
fly state and the last result. They are not campaign data.

Diagnostics are written to `TF2VR\logs\nslog*.txt`:

- `[TF2VRSB][layout]` — page and control geometry.
- `[TF2VRSB][state]` — session and status values.
- `[TF2VRSB][event]` — navigation, commands and preset loads.
- `[TF2VRSB][server]` — accepted server actions.

Debug logging defaults to on. Turning it off suppresses layout/state/event
lines and accepted-action server lines; a rejected action still prints its
reason. The **Y** bounds overlay continues to work independently.

## Safety boundaries

- Single-player campaign only; multiplayer is rejected.
- NPC cleanup only touches handles created by this sandbox.
- The map catalog cannot change levels.
- Presets are plain text in the mod's Safe I/O folder, not campaign saves.
- No campaign map file, campaign save, checkpoint, Northstar core file,
  Proton prefix or XR runtime configuration is edited.
- Noclip can leave campaign bounds; the player must toggle it off to land.
- The sandbox does not add a separate OpenXR overlay; it uses the game's native
  menu path.

## What is not implemented

The following controls are deliberately absent:

- Map travel or campaign transitions.
- World-object placement or editing.
- A general world-entity browser (the NPC catalog is deliberately NPC-only).
- A Gauntlet builder.
- Preset rename, duplicate, browse or delete beyond the three fixed slots.

These depend on level-transition, spawn-model, navigation or scenario behavior
that has not been validated in a running campaign. They are not hidden behind
inert buttons.

## Troubleshooting

| Message or symptom | Meaning |
|---|---|
| No **SANDBOX / DEV TOOLS** footer | You are not in a campaign pause menu, or the package/scripts are not loaded. Confirm Northstar and the installed package, then restart the game. |
| `CONTACTING CAMPAIGN SESSION` | The UI is waiting for the server VM to answer. Wait a moment and open the page again. |
| `STAND ON SOLID GROUND FIRST` | NPC spawning or bookmark saving needs a valid, living, grounded player. |
| `NO CLEAR SPAWN POSITION AHEAD` | The forward trace is blocked or starts inside geometry. Move or aim into open space. |
| `NPC CAP REACHED (N)` | Clear managed NPCs or raise the cap. |
| `NO POSITION BOOKMARK IN THIS SESSION` | No bookmark has been saved on this map. |
| `PRESET BELONGS TO ANOTHER MAP` | Presets are map-locked; load it on the map where it was saved. |
| `SAVE FAILED - SAFE I/O UNAVAILABLE` | The mod could not write its preset file. |
| `DEBUG LOGGING IS OFF` | Turn the Developer Information switch back on before requesting a layout dump. |
| Overlay is hard to see | Open Developer Information and raise **LAYOUT OPACITY**; 10% is intentionally faint. |

## Runtime test plan

These checks still need a disposable campaign mission and a VR session:

1. Confirm the pause footer appears and vanilla pause rows still work.
2. Open and close every page with controller and keyboard; check focus and input
   handoff.
3. Search the catalog, switch every category, inspect a disabled Titan/turret
   entry, then spawn a sample from each enabled category and observe team behavior.
4. Spawn at least two different types, remove one by its managed row, and verify
   only that entity disappears. Set the cap to 2, confirm a third spawn is
   rejected, then clear twice and verify the remaining sandbox NPCs disappear.
5. Save, return to and clear a bookmark; change maps and confirm it is gone.
6. Save a preset, restart the game, load it on the same map, and confirm a
   different map rejects it.
7. Toggle fly and confirm the movement mode, status label, landing behavior and
   cleared velocity.
8. Check layout logging, the Developer Information dump, debug on/off and the
   **Y** overlay.
9. Cycle opacity, restart and confirm both overlay state and opacity return.
10. Repeat the menu and comfort checks through WiVRn on the Quest 3S.

Only after those checks should map, world-object or Gauntlet work be considered.

## Where the code lives

| Path | Role |
|---|---|
| `package/.../mod/scripts/vscripts/ui/tf2vrsb_menu.nut` | Menus, labels, navigation and Safe I/O preset calls |
| `package/.../mod/scripts/vscripts/ui/tf2vrsb_debug.nut` | Layout/state/event logs and bounds overlay |
| `package/.../mod/scripts/vscripts/tf2vrsb_client.nut` | Allow-list command bridge |
| `package/.../mod/scripts/vscripts/tf2vrsb_server.nut` | Campaign validation, NPCs, teleport, fly and status |
| `package/.../mod/resource/ui/menus/tf2vrsb_*.menu` | Eight sandbox page resources |

For the implementation checklist, verified interfaces, execution-context
details and the original PDF mapping, see
[`docs/SANDBOX.md`](docs/SANDBOX.md). For planned work, see
[`ROADMAP.md`](ROADMAP.md). Installation and the rest of the add-on are covered
in [`README.md`](README.md).
