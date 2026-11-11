# TF2VR Northstar Campaign Sandbox

This document records what the 1.4.0 sandbox actually implements, which
interfaces were verified before use, and what remains blocked on runtime
testing. It is a checklist, not a claim that every proposed PDF feature exists.

## Entry point

The entry is a footer option on `InGameSPMenu`, the campaign pause menu:

- **Y** — `SANDBOX / DEV TOOLS`
- **B** — back

`AddMenuFooterOption` appends the option; it does not replace an existing
button or resource. The same UI VM registers six sandbox pages:

| Menu ID | Resource |
|---|---|
| `TF2VRSBSandboxRoot` | `tf2vrsb_root.menu` |
| `TF2VRSBSandboxMaps` | `tf2vrsb_maps.menu` |
| `TF2VRSBSandboxNpcs` | `tf2vrsb_npcs.menu` |
| `TF2VRSBSandboxPlayer` | `tf2vrsb_player.menu` |
| `TF2VRSBSandboxPresets` | `tf2vrsb_presets.menu` |
| `TF2VRSBSandboxDeveloper` | `tf2vrsb_developer.menu` |

The existing main-menu **TF2VR Better Bindings** page is unchanged.

## PDF requirement mapping

The PDF's chapter order was used as the design checklist. Its technical
examples were treated as proposals, not APIs.

`Implemented` below means the packaged source contains the wired action. No row has
been run in Titanfall 2; the runtime test plan at the end is still outstanding.

| Requirement | State in 1.4.0 | Evidence / limitation |
|---|---|---|
| Campaign pause-menu entry | Implemented | `InGameSPMenu` is used by the installed TF2VR sources and the menu API is present in Northstar |
| Dashboard / category navigation | Implemented | Six UI pages, explicit nav links, B footer, controller focus |
| Maps & Environments | Read-only catalog | 13 IDs cross-checked against the installed `tf2vr_memories.nut`; no map transition |
| Safe map switching | Not implemented | `ChangeLevel` exists but campaign transition side effects are not runtime-tested |
| World Editor | Not implemented | No verified `CreateProp` usage or object registry was found in the installed Northstar/campaign scripts; placement is withheld |
| NPC Sandbox | Implemented slice | Hostile soldier, hostile spectre, friendly soldier, cap, clear managed |
| NPC browser / individual removal | Not implemented | Only three server-validated NPC classes and bulk cleanup are exposed |
| Player Utilities | Implemented slice | Session bookmark save/return/clear |
| Gauntlet Builder | Not implemented | Requires tested scenario markers, ordering, timing and a verified server think/trigger path; no inert page is shipped |
| Save & Load | Implemented slice | Three map-locked position presets in mod-scoped Safe I/O |
| Rename / duplicate / browse / delete presets | Not implemented | Three fixed slots; no file browser |
| Developer Tools | Implemented readout | Map, mode, coordinates, entity/NPC/managed counts, limits |
| Debug overlays | Not implemented | No unverified overlay API is used |
| Visual design | Implemented resources | Original dark industrial layout, orange accents, technical labels |
| VR / WiVRn | Not physically tested | Native menu path is used; no separate OpenXR overlay was added |
| Packaging | Implemented | CMake package, version 1.4.0, verifier covers files, scripts, ConVars and menus; `scripts/verify-sandbox.py` cross-checks controls, bridge targets, commands and ConVars |

## Verified interfaces

Checked against installed Northstar/Titanfall 2 scripts, the installed TF2VR
menu, and Northstar's public modding documentation before use:

- `AddMenu`, `GetMenu`, `AdvanceMenu`, `CloseActiveMenu`,
  `AddMenuFooterOption`, `AddMenuEventHandler`, `FocusDefaultMenuItem`
- `Hud_GetChild`, `Hud_SetText`, `Hud_AddEventHandler`, `Hud_SetNavUp`,
  `Hud_SetNavDown`, `SetButtonRuiText`
- `RunClientScript` from the UI VM
- `player.ClientCommand` from the CLIENT VM
- `AddClientCommandCallback(string, bool functionref(entity, array<string>))`
- `GetConVarString`, `GetConVarInt`, `GetConVarFloat`, `SetConVarString`,
  `SetConVarInt`
- `IsSingleplayer`, `GetMapName`, `IsValid`, `IsAlive`, `GetNPCArray`
- `CreateNPC`, `DispatchSpawn`, `npc.Destroy`
- `player.GetOrigin`, `GetAngles`, `GetTeam`, `EyePosition`, `SetOrigin`,
  `SetAngles`, `SetVelocity`, `IsOnGround`
- `AnglesToForward`, `TraceLine`
- `Entities_First`, `Entities_Next`
- `NSSaveFile`, `NSLoadFile`, `NSDoesFileExist`, `split`

`NSSaveFile`/`NSLoadFile` are used only from the UI VM and resolve to the mod's
own save directory. They are not pointed at campaign saves. `TraceLine` uses
the documented five-argument form and rejects both a start-solid trace and a
blocked forward trace before creating an NPC.

## Execution contexts

| Script | Context | Responsibility |
|---|---|---|
| `ui/tf2vrsb_menu.nut` | UI | Menus, labels, controller navigation, Safe I/O preset text, status display |
| `tf2vrsb_client.nut` | CLIENT | Forwards an allow-listed UI command through `ClientCommand` |
| `tf2vrsb_server.nut` | SERVER | Campaign validation, NPC creation/cleanup, teleport, counts |

The UI never creates or destroys entities and does not call the server VM
directly. It calls `RunClientScript("TF2VRSB_SendCommand", ...)`; the CLIENT VM
checks a fixed allow-list and forwards one of these narrow commands:

- `tf2vrsb_status`
- `tf2vrsb_spawn_imc_soldier`
- `tf2vrsb_spawn_imc_spectre`
- `tf2vrsb_spawn_friendly_soldier`
- `tf2vrsb_clear_managed`
- `tf2vrsb_save_bookmark`
- `tf2vrsb_return_bookmark`
- `tf2vrsb_clear_bookmark`
- `tf2vrsb_load_preset`

The SERVER VM checks all of the following before acting:

1. `IsSingleplayer()` is true.
2. A map is active.
3. The player entity is valid and alive.
4. The player is on the ground.
5. The NPC cap and spawn distance are clamped to safe limits.
6. The forward spawn point has a clear trace.
7. Only recorded handles are destroyed.
8. A preset's map ID matches the current map and its coordinates are bounded.

## Data and safety

- Sandbox NPC handles are kept in a separate array and capped at 20 even if a
  ConVar is edited externally.
- Map changes discard handles without touching the old level.
- Bookmarks disappear when the map changes.
- Presets are stored as `sandbox_position_<slot>.txt` in the mod's Safe I/O
  directory. They contain `map x y z yaw` and no user or campaign data.
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
3. Spawn one of each NPC type, observe team behavior, press clear twice, and
   verify only sandbox NPCs disappear.
4. Set the cap to 2 and confirm a third spawn is rejected.
5. Save a bookmark, move, return, and clear it. Change map and confirm the
   bookmark is gone.
6. Save a position preset, restart the game, load it on the same map, and
   confirm a different map rejects it.
7. Check `tf2vrsb_*` ConVars and the server log for rejected actions.
8. Repeat the menu and gameplay checks in the Quest 3S through WiVRn, looking
   for readability, focus, input handoff, and frame-time regressions.

Only after those tests should the map/world/Gauntlet features be considered for
implementation. They are intentionally absent rather than shipped as unverified
controls.
