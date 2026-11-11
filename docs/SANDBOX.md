# TF2VR Northstar Campaign Sandbox — Engineering Notes

For a practical walkthrough of the shipped sandbox, see
[`SANDBOX.md`](../SANDBOX.md).

This document records what the 1.7.0 sandbox actually implements, which
interfaces were verified before use, and what remains blocked on runtime
testing. It is a checklist, not a claim that every proposed PDF feature exists.

## Entry point

The entry is a footer option on `InGameSPMenu`, the campaign pause menu:

- **Y** — `SANDBOX / DEV TOOLS`
- **B** — back

`AddMenuFooterOption` appends the option; it does not replace an existing
button or resource. The UI VM registers eight sandbox pages:

| Menu ID | Resource |
|---|---|
| `TF2VRSBSandboxRoot` | `tf2vrsb_root.menu` |
| `TF2VRSBSandboxMaps` | `tf2vrsb_maps.menu` |
| `TF2VRSBSandboxNpcBrowser` | `tf2vrsb_npcs.menu` |
| `TF2VRSBSandboxNpcDetails` | `tf2vrsb_npc_details.menu` |
| `TF2VRSBSandboxNpcManaged` | `tf2vrsb_npc_managed.menu` |
| `TF2VRSBSandboxPlayer` | `tf2vrsb_player.menu` |
| `TF2VRSBSandboxPresets` | `tf2vrsb_presets.menu` |
| `TF2VRSBSandboxDeveloper` | `tf2vrsb_developer.menu` |

The main-menu **TF2VR Quality of life** page is separate; 1.7.0 adds the read-only VR diagnostics page there, not in the sandbox.

## PDF requirement mapping

The PDF's chapter order was used as the design checklist. Its technical
examples were treated as proposals, not APIs.

`Implemented` below means the packaged source contains the wired action. No row has
been run in Titanfall 2; the runtime test plan at the end is still outstanding.

| Requirement | State in 1.7.0 | Evidence / limitation |
|---|---|---|
| Campaign pause-menu entry | Implemented | `InGameSPMenu` is used by the installed TF2VR sources and the menu API is present in Northstar |
| Dashboard / category navigation | Implemented | Eight UI pages, explicit nav links, B footer, controller focus |
| Maps & Environments | Read-only catalog | 13 IDs cross-checked against the installed `tf2vr_memories.nut`; no map transition |
| Safe map switching | Not implemented | `ChangeLevel` exists but campaign transition side effects are not runtime-tested |
| World Editor | Not implemented | No verified `CreateProp` usage or object registry was found in the installed Northstar/campaign scripts; placement is withheld |
| NPC catalog browser | Implemented; runtime untested | 62 catalog entries, six categories, search, paging, details, support status and restrictions |
| NPC spawning / individual removal | Implemented; runtime untested | 24 server-accepted AI settings; stable managed IDs; two-click single removal and bulk clear |
| Player Utilities | Implemented slice | Session bookmark save/return/clear; noclip fly toggle with status |
| Gauntlet Builder | Not implemented | Requires tested scenario markers, ordering, timing and a verified server think/trigger path; no inert page is shipped |
| Save & Load | Implemented slice | Three map-locked position presets in mod-scoped Safe I/O |
| Rename / duplicate / browse / delete presets | Not implemented | Three fixed slots; no file browser |
| Developer Tools | Implemented readout + logs | Map, mode, coordinates, entity/NPC/managed counts, limits; layout dump, opacity control, debug switch and on-screen bounds toggle |
| Debug overlays / menu position | Implemented as logs + on-screen bounds | `[TF2VRSB][layout]` dumps geometry and text; **Y** tints the menu orange and focusable controls cyan using live HUD bounds |
| Visual design | Implemented resources | Original dark industrial layout, orange accents, technical labels |
| VR / WiVRn | Not physically tested | Native menu path is used; no separate OpenXR overlay was added |
| Packaging | Implemented | CMake package, version 1.7.0, verifier covers files, seven scripts, 93 ConVars and 15 menu resources; `scripts/verify-sandbox.py` cross-checks controls, bridge targets, commands, allow-list entries and ConVars |

## Verified interfaces

Checked against installed Northstar/Titanfall 2 scripts, the installed TF2VR
menu, and Northstar's public modding documentation before use:

- `AddMenu`, `GetMenu`, `AdvanceMenu`, `CloseActiveMenu`,
  `AddMenuFooterOption`, `AddMenuEventHandler`, `FocusDefaultMenuItem`
- `Hud_GetChild`, `Hud_SetText`, `Hud_SetEnabled`, `Hud_GetUTF8Text`,
  `Hud_AddEventHandler`, `Hud_SetNavUp`, `Hud_SetNavDown`, `SetButtonRuiText`
- `Hud_GetX`, `Hud_GetY`, `Hud_GetAbsX`, `Hud_GetAbsY`, `Hud_GetWidth`,
  `Hud_GetHeight`, `Hud_GetParent`, `Hud_IsVisible`, `Hud_IsEnabled`,
  `Hud_GetScriptID`, `Hud_GetUTF8Text`, `GetScreenSize`, `WaitFrame`
- `Hud_SetPos`, `Hud_SetSize`, `Hud_SetAlpha`, `Hud_Show`, `Hud_Hide` for the overlay's own labels
- `RunClientScript` from the UI VM
- `player.ClientCommand` from the CLIENT VM
- `AddClientCommandCallback(string, bool functionref(entity, array<string>))`
- `GetConVarString`, `GetConVarInt`, `GetConVarFloat`, `SetConVarString`,
  `SetConVarInt`
- `IsSingleplayer`, `GetMapName`, `IsValid`, `IsAlive`, `GetNPCArray`
- `CreateNPCFromAISettings`, `CreateNPC`, `DispatchSpawn`, `npc.Destroy`
- `player.GetOrigin`, `GetAngles`, `GetTeam`, `EyePosition`, `SetOrigin`,
  `SetAngles`, `SetVelocity`, `IsOnGround`
- `player.IsNoclipping`, `player.SetPhysics`, `MOVETYPE_NOCLIP`, `MOVETYPE_WALK`
- `AnglesToForward`, `TraceLine`
- `Entities_First`, `Entities_Next`
- `NSSaveFile`, `NSLoadFile`, `NSDoesFileExist`, `split`

`NSSaveFile`/`NSLoadFile` are used only from the UI VM and resolve to the mod's
own save directory. They are not pointed at campaign saves. `TraceLine` uses
the documented five-argument form and rejects both a start-solid trace and a
blocked forward trace before creating an NPC. The HUD geometry getters are the
same ones already used by the settings debug logger in `ui/tf2vrbb_menu.nut`;
the measured controls are never resized or moved, only the overlay's own labels.
`IsNoclipping`/`SetPhysics` and the two movement-type constants match the
installed Northstar `_northstar_cheatcommands.nut`.

## Execution contexts

| Script | Context | Responsibility |
|---|---|---|
| `ui/tf2vrsb_menu.nut` | UI | Menus, labels, controller navigation, Safe I/O preset text, status display |
| `ui/tf2vrsb_npc_browser.nut` | UI | Catalog search/filter, details, team selection, managed roster and layout logs; no world access |
| `ui/tf2vrsb_debug.nut` | UI | Layout/state/event logging and the on-screen bounds overlay; no world access |
| `tf2vrsb_client.nut` | CLIENT | Forwards an allow-listed UI command through `ClientCommand` |
| `tf2vrsb_server.nut` | SERVER | Campaign validation, NPC creation/cleanup, teleport, fly, counts |

The UI never creates or destroys entities and does not call the server VM
directly. It calls `RunClientScript("TF2VRSB_SendCommand", ...)`; the CLIENT VM
checks a fixed allow-list and forwards one of these narrow commands:

- `tf2vrsb_status`
- `tf2vrsb_spawn_npc`
- `tf2vrsb_remove_managed`
- `tf2vrsb_clear_managed`
- `tf2vrsb_save_bookmark`
- `tf2vrsb_return_bookmark`
- `tf2vrsb_clear_bookmark`
- `tf2vrsb_toggle_fly`
- `tf2vrsb_load_preset`

The SERVER VM checks all of the following before acting:

1. `IsSingleplayer()` is true.
2. A map is active.
3. The player entity is valid and alive.
4. The player is on the ground for spawning.
5. The requested AI settings ID is in the 24-entry server allow-list.
6. The NPC cap and spawn distance are clamped to safe limits.
7. The forward spawn point has a clear trace.
8. Individual removal names a stable sandbox ID, not a world-space entity reference.
9. Only recorded handles are destroyed.
10. A preset's map ID matches the current map and its coordinates are bounded.

The fly command uses a narrower check than NPC spawning: the player must be in
a single-player campaign, on a map, valid and alive. It does not require ground
contact.

## Diagnostics

`ui/tf2vrsb_debug.nut` is a separate UI module registered with the same mod. It
writes these prefixes to Northstar's `nslog`:

- `[TF2VRSB][layout] page=... screen=...` on each page open
- `[TF2VRSB][layout] menu ... rel=... abs=... size=... visible=...`
- `[TF2VRSB][layout] <control> ... text="..."` for each page control
- `[TF2VRSB][state] source=... map=... mode=... pos=... fly=...`
- `[TF2VRSB][event] <kind> <detail>` for navigation, commands and preset loads
- `[TF2VRSB][server] ...` for accepted server actions

Press **Y** on any sandbox page to toggle the on-screen bounds overlay.
`DebugMenu` follows the page's `Panel`; `Debug0`-`Debug14` follow its focusable
controls. The overlay is off by default, independent of `tf2vrsb_debug`, and
stores its state in the archived `tf2vrsb_overlay` ConVar so a UI reload or game
restart restores it. The **LAYOUT OPACITY** button in Developer Information
cycles 10%, 20%, 35%, 50%, 75% and 100%, starting at 20%. That choice uses the archived
`tf2vrsb_overlay_opacity` ConVar and is restored after a reload or restart. The
boxes are fully opaque in the menu resources; their HUD alpha is set on every
overlay draw. It only resizes and displays its own HUD labels.

`tf2vrsb_debug` defaults to `1`. Setting it to `0` suppresses every diagnostic
line; setting it back to `1` restores them. It does not affect the on-screen
overlay. Developer Information's **LOG CURRENT LAYOUT TO NSLOG** writes a fresh
page dump only while logging is on. The module reads geometry and ConVars; it
only moves and shows its own overlay labels, never the measured controls, and
does not change menu resources at runtime or call a server API.

## Data and safety

- Sandbox NPC handles are kept in separate arrays with stable IDs and capped at
  20 even if a ConVar is edited externally. Individual removal matches the ID
  recorded at spawn; it never searches the world for a matching class.
- Map changes discard handles without touching the old level.
- Bookmarks disappear when the map changes.
- Presets are stored as `sandbox_position_<slot>.txt` in the mod's Safe I/O
  directory. They contain `map x y z yaw` and no user or campaign data.
- Fly changes only the local player's movement type. Noclip ignores collision
  and can leave campaign bounds; it must be toggled off to land.
- Diagnostics are read-only for the measured controls and contain menu geometry,
  ConVar state and action names. The optional overlay only resizes its own HUD
  labels. Neither path modifies campaign data.
- The map catalog cannot change levels.
- No campaign map file, campaign save, Northstar core file, Proton prefix,
  launch option or XR runtime configuration is modified by this mod.

## Runtime test plan

These tests require a disposable campaign mission and were not available in
the development environment:

1. Pause in campaign; confirm **Y SANDBOX / DEV TOOLS** is visible and vanilla
   pause entries still work.
2. Open/close each page with controller and keyboard; confirm focus returns to
   gameplay.
3. Search and filter the catalog; inspect disabled Titan, dropship and turret
   entries; spawn one entry from each enabled category.
4. Remove one managed NPC by pressing its row twice; verify only that ID is
   destroyed. Set the cap to 2 and confirm a third spawn is rejected; clear twice
   and verify only sandbox NPCs disappear.
5. Save a bookmark, move, return, and clear it. Change map and confirm the
   bookmark is gone.
6. Save a position preset, restart the game, load it on the same map, and
   confirm a different map rejects it.
7. Toggle **FLY (NOCLIP)** and confirm the label/status switches to ON, the
   player ignores collision, and a second press returns to walking with velocity
   cleared. Check `tf2vrsb_fly` follows the actual state.
8. Open Developer Information and confirm the `[TF2VRSB][layout]` block contains
   the page and control positions; use **LOG CURRENT LAYOUT TO NSLOG**. Press
   **Y** and confirm the orange menu box and cyan control boxes align with the
   page while logging is on, then turn **DEBUG LOGGING** off and confirm new
   page opens stop logging while the overlay still toggles. Open **LAYOUT
   OPACITY** and cycle it; confirm the boxes change opacity immediately. Restart
   the game and confirm the overlay state and opacity are restored.
9. Check `tf2vrsb_*` ConVars and the server log for rejected actions.
10. Repeat the menu and gameplay checks in the Quest 3S through WiVRn, looking
    for readability, focus, input handoff, fly comfort, and frame-time regressions.

Only after those tests should the map/world/Gauntlet features be considered for
implementation. They are intentionally absent rather than shipped as unverified
controls.
