# TF2VR-QOL Comprehensive Development Roadmap

**Status:** planning document plus the source-verified 1.7.0 VR diagnostics/input-tester and searchable map-favorites slices, and the 1.6.0 NPC browser/managed-roster slice. Every other item remains proposed and requires separate approval and runtime testing.

**Source baseline:** TF2VR Quality of Life 1.7.0.

**Reviewed:** 2026-11-11.

> **Scope gate.** Except for the explicitly listed 1.7.0 diagnostics/input-tester slice and 1.6.0 NPC slice, this document does not add Squirrel scripts, menu pages, ConVars, configuration settings, C++ code, manifest entries, package files, or gameplay behaviour. Each remaining feature requires a separate implementation task, source review, runtime test plan and user approval.

> **1.6.0 implementation note.** The NPC catalog, browser, details page and managed roster were implemented before live VR diagnostics because they could be validated against extracted game scripts, while OpenXR/controller diagnostics require a running headset and runtime that are unavailable here. This is a dependency-driven ordering change, not a claim that the NPC slice has passed runtime testing.

> **1.7.0 implementation note.** The settings menu now has a read-only VR diagnostics page and text action tester fed by layer-published ConVars. It reports runtime class/version, app API version, current interaction profiles, pose validity, configured actions and live trigger/grip/stick/button action states. It has not been run in Titanfall 2 or a headset. The sandbox map catalog also gained search by name/ID and persistent favorites in 1.7.0. Report export, setup-health checks, calibration compatibility and graphical controller visualization remain planned.

## 1. Project vision

TF2VR-QOL should become a complete, runtime-independent quality-of-life and campaign sandbox toolkit for Titanfall 2 VR:

- Better controller behaviour without requiring SteamVR.
- Clear diagnostics for OpenXR, Proton, WiVRn, Monado and controller profiles.
- Editable VR calibration and comfort settings.
- A safe campaign sandbox for spawning, positions, maps and scenarios.
- Developer tools that make failures explainable rather than guesswork.

The project should remain:

- **OpenXR-first.** Do not introduce a SteamVR dependency where an OpenXR path exists.
- **Campaign-safe.** Never edit campaign saves, checkpoints or game-owned files.
- **Server-authoritative.** World changes stay behind narrow, validated commands.
- **Controller-first.** Every menu must work with a controller in the headset.
- **Evidence-led.** No dead buttons for unverified APIs.

### Non-goals

- Multiplayer cheating, progression unlocks or campaign-save editing.
- Arbitrary code execution, downloaded scripts or unvalidated map packages.
- A general-purpose game engine or asset importer.
- Replacing CircuitLord's VR mod rather than extending it.
- Shipping the world editor or Gauntlet builder before their engine APIs are proven.

## 2. Roadmap at a glance

| Phase | Outcome | Exit gate |
|---|---|---|
| **0. Reliability** | Prove the existing 1.7.0 build in Titanfall 2 and a headset | Every shipped control tested or explicitly marked unsupported |
| **1. VR diagnostics** | Runtime identity, setup check, input diagnostics and reports | A user can diagnose a missing layer, binding, setting or controller |
| **2. Personalization** | Calibration profiles, sprint wizard, preset manager, comfort options | Profiles survive restart and can be recovered |
| **3. Sandbox** | Map browser, managed NPC tools, player utilities, save/load v1 | Existing sandbox actions are safe and pleasant on a disposable save |
| **4. Environment tools** | World-object placement and layout persistence | One object class can be created, undone and restored safely |
| **5. Scenario tools** | Gauntlet-style courses and timing | A complete short course survives restart and reset |
| **6. Advanced tools** | Performance, script/config diagnostics and export | Reports are useful without a debugger |

The requested phase order is kept, with two adjustments:

1. **A minimal Setup Check and diagnostic bridge belong in Phase 1**, not Phase 6, because later features need runtime identity and state visibility.
2. **Performance profiling and exportable reports remain in Phase 6**; they should not delay basic diagnostics.

## 3. Status and feasibility vocabulary

### 3.1 Implementation status

| Status | Meaning |
|---|---|
| **Implemented** | Code exists and is packaged; no claim is made that every path has been exercised in game |
| **Implemented, untested** | Code exists but the project has no recorded runtime test in Titanfall 2 or a headset |
| **Partial** | A narrow slice exists; major expected pieces are absent |
| **Planned** | Proposed here; no production code exists |
| **Uncertain** | Feasible only if a named engine, UI or OpenXR capability is verified |
| **Unsupported** | No safe or verified path is currently known; do not expose a control |

### 3.2 Feasibility

| Class | Meaning |
|---|---|
| **HIGH** | Supported by existing code paths or already-verified APIs |
| **MEDIUM** | Possible with new implementation and runtime testing |
| **LOW** | Significant API, engine or UX uncertainty remains |
| **UNKNOWN** | Insufficient evidence; requires a focused technical spike first |

### 3.3 Complexity

**S** = small UI/documentation work; **M** = a focused feature across one or two VMs; **L** = C++/OpenXR/UI integration; **XL** = new subsystem with persistence, editing and runtime risk.

### 3.4 Priority

**P0** = must happen before feature expansion; **P1** = next after the Phase 0 gate; **P2** = valuable follow-up; **P3** = long-term or research-gated.

## 4. Current implementation status

### 4.1 Architecture discovered in source

| Component | Current role | Important limits |
|---|---|---|
| `src/layer` | Windows OpenXR API layer loaded in the game process; intercepts actions, bindings, action states, aim/head poses and config reloads | No runtime-name query, current interaction-profile query, grip-pose tracking or direct bridge to the Squirrel UI |
| `src/plugin` | Northstar plugin: settings mirror, registration and calibration persistence | Only a small set of ConVars and files are bridged; run-frame work is CPU-side |
| `tf2vrbb_menu` | Main-menu settings pages, including read-only diagnostics | Fixed RUI resources; text-only live input, no graphical controller visualization |
| `tf2vrsb_menu` | Campaign pause sandbox navigation and shared helpers | Three fixed preset slots; map catalog is read-only |
| `tf2vrsb_npc_browser` | NPC browser, details and managed roster | Catalog data is UI-side; spawning and removal remain server-authoritative |
| `tf2vrsb_client` | Nine-command allow-list bridge | UI cannot call the server directly |
| `tf2vrsb_server` | Campaign validation, 24-entry NPC allow-list, managed IDs, bookmark, fly, preset load and status | No props, transitions or scenario engine |
| `tf2vrsb_debug` | Layout, state, event logs and bounds overlay | Logs depend on `tf2vrsb_debug`; layer log is a separate optional file |
| `config/TF2VRBetterBindings.ini` | Single settings source for the layer | Action on/off changes require restart; behaviour values reload |
| `scripts/verify-sandbox.py` | Static menu/ConVar/bridge checks | Not a Squirrel compiler or runtime test |

### 4.2 Feature status

| Area | Status | Evidence / limitation |
|---|---|---|
| OpenXR actions for **Reload Grab**, **Crouch** and **Tactical Ability** | Implemented; no formal runtime test report | Layer creates and intercepts the actions; SteamVR manual binding or Wine-suggested bindings |
| In-game settings menu | Implemented | Seven pages, nine action rows, three general rows and a diagnostics page |
| Settings synchronization | Implemented | Twelve menu ConVars mirrored to the layer INI; action toggles restart-only |
| Calibration persistence | Implemented | Single profile, file version 1, native image-size match, hard-coded Titanfall2VR offsets |
| Campaign pause entry and eight sandbox pages | Implemented; runtime untested | `InGameSPMenu` footer and native RUI pages, including the NPC browser/details/managed pages |
| NPC catalog and managed roster | Implemented; runtime untested | 62 catalog entries, six categories, search, details, 24 server-accepted AI settings, stable IDs, individual removal and bulk clear |
| Player bookmark and fly/noclip | Implemented; runtime untested | Session bookmark; movement-type toggle |
| Three position presets | Implemented; runtime untested | Fixed slots in mod-safe I/O, map-locked load |
| Campaign map catalog | Implemented; runtime untested | 13 known campaign IDs, search by name/ID and persistent favorites; no transitions |
| Developer telemetry, layout logs and overlay | Implemented; runtime untested | Read-only UI diagnostics; fixed overlay boxes |
| Build and package verification | Implemented | 93 ConVars, seven scripts, 15 menus, static package cross-checks only |
| Automated tests / CI | Not implemented | No test project is present and no CI workflow exists |
| Runtime VR diagnostics dashboard | Implemented text v1; runtime untested | Layer publishes runtime class/version, profiles, tracking and action state through ConVars; no report export or setup-health checks |
| Live controller tester | Implemented text v1; runtime untested | Trigger, grip, stick, stick click, primary, crouch, tactical and reload are sampled; no graphical silhouette, battery or face-button data |
| Multi-profile calibration | Planned | Single profile only |
| Sprint calibration wizard | Planned | Numerical thresholds exist; no live threshold view |
| Advanced preset manager | Planned | No rename, duplicate, delete or import/export |
| Advanced map browser | Partial | Catalog only; no categories, search, images or custom maps |
| World editor | Planned / uncertain | No verified prop-creation path |
| Individual NPC management | Implemented; runtime untested | Stable managed IDs and two-click removal |
| Gauntlet / scenario builder | Planned / uncertain | No marker, timer or scoring implementation |
| Generic save/load system | Partial | Presets only; no schema manager, backups or scenario storage |
| Advanced developer dashboard | Partial | Current telemetry and logs only |
| Comfort and interface customization | Partial | Overlay opacity only; menus are fixed resources |
| Automated self-diagnostics | Not implemented in game | Static verifier and logs exist; no user-facing self-test |

### 4.3 Constraints that shape the roadmap

- The UI, CLIENT and SERVER VMs are separate. World actions must continue through the allow-listed command bridge.
- The layer has no direct Squirrel/UI object channel. Settings use ConVars plus an INI file; diagnostics use a throttled, read-only set of integer ConVars. A richer status/report bridge is still prerequisite work for report export and setup checks.
- Layer logging is compiled out in normal release builds. Diagnostics cannot depend only on `TF2VRBetterBindings.log`.
- Calibration uses fixed RVAs and matches the native module by image size, not content hash. A game or Titanfall2VR update can invalidate it.
- Console commands use a verified engine signature, but a hard-coded RVA. It must remain guarded by a prologue check.
- The static verifier deliberately rejects `ChangeLevel` and `CreateProp` because their campaign behaviour is unverified.
- The sandbox has no general entity registry. Its NPC catalog is limited to 24 source-accepted AI settings; unavailable entries never reach the spawn call.
- The RUI menu system supports text, buttons, panels and limited image controls. Arbitrary live drawing or controller silhouettes are not currently proven.
- No `tests/` sources are present; CMake's conditional test targets do not run. There is no CI.
- WiVRn has no per-app OpenXR binding editor; xrizer binds OpenVR actions and cannot see this OpenXR action set.

## 5. Development phases

### Phase 0 — Reliability and runtime proof

**Goal:** establish what actually works before expanding the feature surface.

- Execute the runtime test plan in [`SANDBOX.md`](../SANDBOX.md) on a disposable campaign save.
- Test the settings menu, all three added actions, configuration sync and calibration persistence.
- Search/filter/view the NPC catalog, spawn a sample from each enabled category, remove one managed ID, and verify campaign NPCs survive.
- Test with Quest 3S through WiVRn and, where available, a SteamVR/OpenXR path.
- Record game version, TF2VR DLL version, runtime, headset, controller profile and pass/fail results.
- Confirm overlay opacity and saved state survive a clean restart.
- Turn every failure into a small fix before starting Phase 1.

**Exit criteria:** every shipped feature has a pass, a documented failure, or an explicit **not supported** label. No new feature work begins while a core action is unverified.

### Phase 1 — VR diagnostics and observability

**Goal:** make failures visible and shorten support cycles.

- Runtime identity and setup check.
- Layer registration, settings bridge, action availability and calibration status.
- Text-based controller input tester.
- Diagnostic report export.
- Small baseline self-diagnostics.

**Why first:** runtime identity, bridge state and action availability are reused by personalization, calibration and the sandbox UI.

### Phase 2 — VR personalization

**Goal:** make existing tuning comfortable and recoverable.

- Multiple calibration profiles.
- Sprint calibration wizard.
- Advanced preset manager.
- Menu readability and comfort options.

**Why here:** these features need the Phase 1 state bridge and should not depend on world-editing research.

### Phase 3 — Campaign sandbox expansion

**Goal:** make the existing sandbox a dependable campaign tool.

- Map catalog metadata and richer discovery; search and favorites are already implemented.
- Managed NPC roster and individual removal.
- Player utility profiles.
- Save/load format v1 for presets and sandbox data.

**Gate:** only after the existing sandbox is stable in game. Map travel remains separately gated.

### Phase 4 — Environment creation

**Goal:** allow controlled sandbox layouts.

- Verified object creation and removal.
- Placement, rotation, duplication, undo and redo.
- Layout save/load.
- Editor mode and selection.

**Gate:** one prop class must be proven to spawn, destroy and restore safely before the editor UI is designed.

### Phase 5 — Scenario creation

**Goal:** create repeatable challenge courses.

- Start, finish and checkpoint markers.
- Timer, splits and personal bests.
- Scenario save/load and test mode.
- Replay-style visualization only if supported.

**Gate:** verified marker, entity-lifecycle and timing paths, plus safe reset behavior.

### Phase 6 — Advanced developer tools

**Goal:** support deep troubleshooting and regression analysis.

- CPU-side performance estimates.
- Script/config/runtime summaries.
- Normal and advanced views.
- Exportable reports.
- Broader automated diagnostics.

## 6. Feature specifications

The following catalogue covers every requested feature. Each entry states its purpose, status, feasibility, dependencies, likely touch points, risks, testing needs and acceptance criteria.

### A. VR Diagnostics Center

**Phase 1 · Priority P1 · Feasibility MEDIUM · Complexity L · Status Implemented text slice; runtime untested**

**Purpose.** Give users one place to see whether OpenXR, the layer, actions, settings and calibration are healthy.

**Implemented in 1.7.0:** layer publication, runtime class/version, app API, per-hand profile and tracking, configured actions, and live action input values. **Still planned:** system-property checks, calibration compatibility, setup-health checks and diagnostic report export.

**User experience.** A read-only page with clear status rows, expandable details and a single **EXPORT DIAGNOSTIC REPORT** action. Unknown values read as `UNAVAILABLE`, never guessed.

| Planning area | Detail |
|---|---|
| Existing | Layer logs the target process, Wine state, instance app/engine name, action creation and suggested profiles. Plugin knows settings sync and registry registration. UI knows `tf2vrbb_settings_api`. |
| Add | Runtime name/version, OpenXR system properties, layer active state, current interaction profile per hand, tracking validity, action availability, config/calibration status, last errors, suggested steps |
| Likely files | `src/layer/Layer.cpp`, `src/layer/Config.*`, `src/plugin/Plugin.cpp`, `SettingsSync.*`, a new status bridge, new UI resources/scripts |
| APIs to verify | OpenXR `xrGetInstanceProperties`, `xrGetSystemProperties`, `xrGetCurrentInteractionProfile`, action-state queries already hooked; registry queries already used by `Registration.cpp` |
| Dependencies | A layer-to-plugin status bridge and a UI-readable report/ConVar format |
| Risks | Runtime data varies by Monado/WiVRn/SteamVR; no universal headset name; logs may be disabled in release; exposing paths/privacy; report size |
| Testing | Valid layer, missing manifest, disabled layer, old plugin, missing config, no headset, Touch/Index/unknown profile, WiVRn and SteamVR |
| Acceptance | User can distinguish layer missing, plugin missing, settings bridge disconnected, action unavailable, calibration invalid and restart-required states without reading a debugger |

The layer can access more than the UI can currently see. Direct runtime introspection must be proven in the layer first, then surfaced through a narrow bridge. An optional Linux-side helper may be proposed later for Monado/WiVRn/Envision logs, but it must be read-only, opt-in and separate from the mod.

### B. Live Controller Input Tester

**Phase 1 · Priority P1 for text v1, P2 for visualization · Feasibility MEDIUM for v1, LOW for full graphics · Complexity L · Status Implemented text v1; runtime untested**

**Purpose.** Let a user confirm that a physical controller, binding, tracking space and OpenXR action are working before blaming the game.

**User experience.**

- **v1:** controller-first text rows for left/right hand: profile, tracking valid, trigger, grip/squeeze, stick X/Y, stick click, primary button, tactical/reload/crouch action state.
- **v2:** a visual controller outline with labeled inputs. This is optional and must not delay v1.

| Planning area | Detail |
|---|---|
| Existing | Layer already reads squeeze, trigger, stick, stick click, jump, crouch, tactical and reload action states; tracks aim/head poses |
| Add | Current interaction-profile query, per-hand grip/aim pose availability, a throttled live state bridge, diagnostic UI |
| Likely files | `src/layer/Layer.cpp`, new action/pose hooks, new status bridge, new menu script/resource |
| APIs to verify | `xrGetCurrentInteractionProfile`, `xrGetActionStatePose`, existing `xrLocateSpace`/`xrLocateSpaces`; current profile paths are **not** already queried |
| Dependencies | Same bridge as A; fixed update budget to avoid stalling the game or UI |
| Risks | The runtime may not expose a friendly controller name; some actions are only active when bound; graphical UI update cost; controller artwork/assets |
| Testing | Touch, Index, unknown Monado profile, WiVRn suggested bindings, disconnected controller, controller sleeping, each hand independently |
| Acceptance | v1 shows real changes while controls move, identifies missing profiles/actions, remains responsive, and changes no gameplay input |

Do not promise a visual silhouette until RUI image/layout capabilities and a reusable asset set are verified.

### C. Advanced VR Calibration Manager

**Phase 2 · Priority P2 · Feasibility MEDIUM · Complexity L · Status Planned**

**Purpose.** Extend the current single saved calibration into recoverable named profiles.

**User experience.** A profile list with **ACTIVE**, **STANDING/SEATED**, height, arm span, native compatibility and last-used date; actions for select, duplicate, rename, export, import, backup and delete. Recalibration opens a guided explanation before the game's native calibration flow.

| Planning area | Detail |
|---|---|
| Existing | One `TF2VRBetterBindings.calibration.ini`, version 1, height/standing-Y/arm-span, native image-size check, automatic restore and startup skip |
| Add | Profile schema, active-profile pointer, content hash/version gate, backup/restore, import/export, UI, validation errors |
| Likely files | `src/plugin/CalibrationPersist.*`, `Plugin.cpp`, maybe a new profile manager; UI resources/scripts |
| APIs to verify | None new for stored values; native calibration writes remain RVA-based and must be checked for the installed Titanfall2VR version |
| Dependencies | Safe file I/O and UI; a reliable way to trigger or detect native recalibration |
| Risks | Hard-coded offsets break on Titanfall2VR updates; size-only matching is insufficient; seated/standing semantics may not exist; writing native flags incorrectly can skip or corrupt calibration |
| Testing | Same DLL restart, changed DLL, malformed profile, missing file, import from another machine, restore after deletion, both profile types |
| Acceptance | Profiles are selected explicitly, invalid native versions are refused rather than written, backups restore, and a profile never affects a different Titanfall2VR build |

**Seated profiles are technically uncertain.** Native calibration may store one standing pose; do not advertise seated support until the native flow is understood.

### D. Sprint Calibration Wizard

**Phase 2 · Priority P2 · Feasibility MEDIUM · Complexity M · Status Planned**

**Purpose.** Replace manual centimetre tuning with a guided live view of the start/stop thresholds.

**User experience.** Show current gun height below eyes, current start/stop thresholds, hysteresis band, lowered/raised state and a “capture current height” action. Finish with a named sprint profile that can be restored.

| Planning area | Detail |
|---|---|
| Existing | `start_below_eyes_cm` and `stop_below_eyes_cm` settings, live layer calculations, hysteresis and periodic diagnostics |
| Add | Live pose/threshold bridge, wizard page, capture actions, validation (`stop < start`), saved sprint profiles |
| Likely files | `src/layer/Layer.cpp` sprint path, `SettingsSync.*`, `tf2vrbb_menu.nut`, new menu resource |
| APIs to verify | No new game API is required for values; the missing piece is a read-only layer-to-UI state bridge |
| Dependencies | A/B bridge, settings sync, safe profile storage |
| Risks | Updating UI too often; missing pose or mismatched reference spaces; profile values changing while the wizard is open |
| Testing | Stationary capture, deliberate lowering/raising, missing tracking, start=stop edge, restart restoration, left/right sprint hand |
| Acceptance | User can capture and preview thresholds without editing numbers, and the saved values produce the same start/stop behavior after restart |

### E. Advanced Preset Manager

**Phase 2 · Priority P1 · Feasibility HIGH for v1, MEDIUM for versioned expansion · Complexity M · Status Planned**

**Purpose.** Turn three fixed slots into a manageable, portable position library.

**User experience.** Named entries with map, coordinates and timestamp; rename, duplicate, delete, import/export and backup; map-lock warnings before load; a safe maximum slot count.

| Planning area | Detail |
|---|---|
| Existing | Three fixed slots, map check, coordinate bounds, plain-text `map x y z yaw`, Safe I/O |
| Add | Schema version, names and metadata, directory/index strategy, delete and duplicate, confirmations, backup/restore |
| Likely files | `tf2vrsb_menu.nut`, `tf2vrsb_presets.menu`, client/server command allow-list |
| APIs to verify | Existing `NSSaveFile`, `NSLoadFile`, `NSDoesFileExist`; `NSDeleteFile` is not used and must be verified before deletion ships |
| Dependencies | Safe I/O, schema validation, map identity |
| Risks | Losing old presets; path traversal; malformed/oversized files; quota; deleting an active slot; map rename |
| Testing | Old-format load, missing file, corrupt file, duplicate name, delete confirmation, import/export, map mismatch, restart persistence |
| Acceptance | Existing three files still load unchanged, delete requires confirmation, invalid files never teleport the player, and a backup can restore the library |

**Safe limit:** choose a small slot/index range and validate it server- and UI-side. Do not expose a filesystem browser.

### F. Advanced Map Browser

**Phase 3 · Priority P2 · Feasibility HIGH for catalog UI, MEDIUM for custom metadata, LOW for transitions · Complexity L · Status Partial — search and favorites implemented**

**Purpose.** Make the existing 13-map catalog a useful reference and navigation tool without implying unsafe map travel.

**User experience.** Search by name or map ID, persistent favorites, categories, recently viewed, map descriptions, compatibility badges, dependency notes and optional preview images. Travel remains a separately gated action.

| Planning area | Detail |
|---|---|
| Existing | 13 known campaign IDs, current-map marker, details panel, name/ID search and Safe I/O favorites; no transition |
| Add | Metadata model, categories, recent list, map-specific notes; custom-map discovery only if a verified source exists |
| Likely files | `tf2vrsb_map*.nut/menu`, Safe I/O metadata, possibly C++ file scanning |
| APIs to verify | No verified custom-map registry; `GetMapName` is current-map only; preview images need an asset source and RUI image support |
| Dependencies | E/K for saved metadata; transition research separate |
| Risks | Inaccurate map IDs; multiplayer/campaign mode confusion; stale custom-map paths; missing images; users assuming selection loads a map |
| Testing | All 13 IDs, unknown current map, missing metadata, favorites persistence, search with controller, custom map absent/present |
| Acceptance | Catalog is accurate and clearly read-only; no selection triggers a level change; custom maps are shown only when a tested discovery source exists |

**Map transitions** require their own technical gate: checkpoint state, autosaves, mission scripts and level teardown must be tested on a disposable save before any `ChangeLevel` UI is exposed.

### G. World Editor

**Phase 4 · Priority P3 · Feasibility LOW / UNKNOWN · Complexity XL · Status Planned**

**Purpose.** A long-term environment tool for placing and arranging approved objects in campaign sandbox spaces.

**User experience.** An editing mode with object categories, preview, place, select, translate, rotate, duplicate, delete, undo, redo, grid snap where supported, and explicit save/load of layouts.

| Planning area | Detail |
|---|---|
| Existing | NPC creation only; no verified prop creation, asset registry or editable-object persistence |
| Add | A verified create/destroy path for one known object, a server-owned object registry, selection/edit commands, serialization, undo stack, editor UI |
| Likely files | New SERVER module, UI editor pages, client allow-list, C++/Squirrel bridge if required |
| APIs to verify | `CreateProp` is **not** verified and is currently forbidden by the verifier; asset paths, model lifetime, collision, networking and map teardown are all unresolved |
| Dependencies | A successful technical spike, object registry, K save/load, safe cleanup |
| Risks | Crashing or corrupting campaign levels; invalid assets; orphaned entities; save incompatibility; performance; accidental deletion |
| Testing | One prop spawn/destroy, map change, death/reset, undo, save/reload, malformed layout, cap enforcement |
| Acceptance | A single approved object can be created, selected, moved, deleted, undone and restored after restart without touching non-sandbox entities |

Do not build a general object browser until the creation path is proven. No arbitrary asset import is planned.

### H. NPC Sandbox Improvements

**Phase 3 · Priority P1 · Feasibility HIGH for managed roster, MEDIUM for categories/behaviour · Complexity L · Status Implemented; runtime untested**

**Purpose.** Build on the 1.6.0 catalog and managed roster with safer validation, presets and clearer spawn controls.

**User experience.** The shipped roster already shows per-entry ID, class, team and status with two-click removal. Remaining ideas are spawn presets, clearer spawn-point preview/validation, configurable limits and a per-spawn result history.

| Planning area | Detail |
|---|---|
| Existing | 62-entry catalog, six categories, search, details, 24 server-accepted AI settings, team selection, cap, distance, stable managed IDs, individual removal and clear-all confirmation |
| Add | Spawn presets, per-spawn result history, clearer spawn-point validation and optional squad commands |
| Likely files | `tf2vrsb_server.nut`, `tf2vrsb_menu.nut`, `tf2vrsb_npcs.menu`, command bridge |
| APIs in use | `CreateNPCFromAISettings`, `CreateNPC`, `DispatchSpawn`, `Destroy`, `GetNPCArray`; behaviour controls still need documented NPC/AI APIs not currently used |
| Dependencies | H registry, safe command IDs, K for spawn presets |
| Risks | Invalid handles after map change; deleting unowned NPCs; AI behavior incompatibility; cap bypass |
| Testing | Spawn/kill/remove one, map change, cap boundary, clear-all twice, stale handle, friendly/hostile teams |
| Acceptance | Every removal targets only a recorded sandbox handle; roster and counts stay consistent; a failed removal never deletes an unrelated NPC |

**Never** add a “delete all NPCs” or level-wide cleanup command.

### I. Player Utilities

**Phase 3 · Priority P2 · Feasibility HIGH for state/position tools, MEDIUM for movement profiles · Complexity M · Status Partial**

**Purpose.** Extend reversible player/session tools without turning the mod into a cheat menu.

**User experience.** Position readout, bookmark slots for the session, fly state, ground/velocity/traversal indicators, temporary movement presets, and a single **RESET TEMPORARY MODIFIERS** action.

| Planning area | Detail |
|---|---|
| Existing | Session bookmark, return/clear, fly/noclip, live position and yaw |
| Add | Multiple session bookmarks, last-position history, traversal diagnostics, temporary movement presets and reset |
| Likely files | `tf2vrsb_server.nut`, `tf2vrsb_menu.nut`, player menu resource |
| APIs to verify | Existing `SetOrigin`, `SetAngles`, `SetVelocity`, `SetPhysics`, `IsNoclipping`; any speed/gravity modification needs server-side think handling and a campaign-only guard |
| Dependencies | Safe reset path, map-change cleanup |
| Risks | Leaving movement modifiers active; death/reset conflicts; campaign progression side effects; multiplayer leakage |
| Testing | Save/return multiple points, map change, death, reset, fly landing, modifier cleanup |
| Acceptance | Every temporary change is reversible and resets on map change/death or through one clearly labeled action; multiplayer is rejected |

### J. Gauntlet and Scenario Builder

**Phase 5 · Priority P3 · Feasibility LOW / UNKNOWN · Complexity XL · Status Planned**

**Purpose.** Build repeatable custom challenge courses in campaign maps.

**User experience.** Create a course name; place start, finish and ordered checkpoints; test-run it; view elapsed time, splits and personal best; save, duplicate and share the scenario as validated data.

| Planning area | Detail |
|---|---|
| Existing | None of the marker, timer, scoring or course lifecycle exists |
| Add | Marker entities or trigger representation, ordered checkpoint state, run timer, split storage, reset/teleport rules, course persistence, test mode |
| Likely files | New scenario SERVER module, new UI pages, K storage, possible entity model work |
| APIs to verify | Existing Gauntlet scripts and trigger/think APIs must be inspected; no verified custom-course API currently exists |
| Dependencies | G object creation, stable markers, I reset, K schema, H lifecycle |
| Risks | Timer drift; checkpoint order exploits; leaving the map; death/reset soft-locks; collision/trigger mismatch; campaign script interference |
| Testing | Start, finish, missed checkpoint, out-of-order checkpoint, death, map leave, restart, malformed course, best-time persistence |
| Acceptance | A short course can be created, run, reset and restored after restart with no campaign state modification and no out-of-order completion |

Do not implement inert course buttons before marker and timer behavior is proven.

### K. Save and Load System

**Phase 3 for sandbox data; Phase 4-5 for layouts/scenarios · Priority P1 · Feasibility HIGH for mod-owned data, MEDIUM for environment data · Complexity L · Status Partial**

**Purpose.** A coherent, versioned persistence layer for everything the mod owns.

**User experience.** Preset browser with rename/duplicate/delete, import/export, backup and restore; clear schema/version errors; recovery from a malformed file; no campaign saves in the file picker.

| Planning area | Detail |
|---|---|
| Existing | Safe I/O position presets, settings INI, calibration INI; no generic manager |
| Add | Versioned schemas, manifest/index, atomic write strategy, backups, size limits, validation, migration, user-facing recovery |
| Likely files | UI preset scripts, new C++ or Squirrel persistence module, mod-safe I/O |
| APIs to verify | Existing `NSSaveFile`, `NSLoadFile`, `NSDoesFileExist`; `NSDeleteFile` and atomic rename are not currently verified |
| Dependencies | E/F/H/G/J data models |
| Risks | Losing user data; partial writes; quota; path traversal; incompatible future versions; importing malicious data |
| Testing | Empty/corrupt/oversized files, interrupted write, migration, backup restore, duplicate names, quota |
| Acceptance | Every file is versioned and validated before use, malformed data never applies partially, and no campaign save path is accessible |

### L. Advanced Developer Dashboard

**Phase 1 basic; Phase 6 advanced · Priority P1 · Feasibility HIGH for existing telemetry, MEDIUM for performance · Complexity L · Status Partial**

**Purpose.** Expand Developer Information into a support and profiling center.

**User experience.** Normal and advanced views covering map, session, coordinates, NPC/entity/managed counts, configuration, script state, layout diagnostics and recent events; a CPU-side performance section and exportable report.

| Planning area | Detail |
|---|---|
| Existing | Developer page, `[TF2VRSB]` logs, layout dump, overlay, status ConVars, settings bridge |
| Add | Runtime/layer/config summary, event ring buffer, script state checks, measured run-frame timing, report export |
| Likely files | `tf2vrsb_debug.nut`, developer menu, plugin/layer bridge, new report writer |
| APIs to verify | Plugin `runFrame` timing is available; there is no verified GPU frame-time API. Do not label a CPU estimate as FPS |
| Dependencies | A bridge, N checks, K report storage |
| Risks | Log volume; inaccurate performance claims; UI layout overflow; sensitive paths in reports |
| Testing | No session, missing bridge, frame timing over a known workload, report contents, disabled logging, headset readability |
| Acceptance | A support report states what was measured and what was unavailable; no metric is fabricated |

### M. VR Comfort and Interface Customization

**Phase 2 · Priority P2 · Feasibility MEDIUM · Complexity M · Status Partial**

**Purpose.** Make the interface readable and comfortable across headsets and seating arrangements.

**User experience.** Menu scale presets, overlay/menu opacity, high-contrast/readable themes, controller prompt style, input feedback preferences, and seated-mode guidance.

| Planning area | Detail |
|---|---|
| Existing | Overlay opacity, fixed RUI panels/fonts, native controller navigation, controller prompt helpers |
| Add | Saved UI scale/theme settings, alternate resource variants or verified dynamic styling, seated guidance |
| Likely files | `tf2vrbb_*.menu`, `tf2vrsb_*.menu`, menu scripts, ConVars |
| APIs to verify | `Hud_SetPos`, `Hud_SetSize`, `Hud_SetAlpha` are used only on the overlay today; general menu font/scale/color support is not proven. Arbitrary UI repositioning is not promised |
| Dependencies | M’s own setting bridge, testing in headset |
| Risks | Clipping, unreachable controls, unreadable text, VR comfort regressions, resource duplication |
| Testing | Every page at each scale/theme, controller focus, 16:9 and headset aspect ratios, seated height, WiVRn |
| Acceptance | Each preset is readable and navigable end to end; unsupported positioning is not presented as available |

### N. Automated Self-Diagnostics

**Phase 1 baseline; Phase 6 expanded · Priority P1 · Feasibility HIGH for component checks, MEDIUM for runtime checks · Complexity L · Status Planned**

**Purpose.** Detect common installation and compatibility failures without requiring a log reader.

**Checks.** Required package files, script initialization, expected ConVars, settings bridge, layer manifest, layer registration where the plugin can query it, configuration syntax, calibration compatibility, unsupported settings and version mismatch.

**User experience.** A one-page health summary with **PASS / WARN / FAIL / UNAVAILABLE**, plain-language explanations, suggested next steps, and **WRITE SUPPORT REPORT**.

| Planning area | Detail |
|---|---|
| Existing | Static verifier, settings API ConVar, registry registration, calibration validation, diagnostics logs |
| Add | In-game health page, status bridge, checks that are safe to run at menu time, report writer |
| Likely files | New UI page, plugin health module, layer status bridge, `scripts/verify-sandbox.py` |
| APIs to verify | Registry/read checks are available in C++; script initialization requires ConVars or file markers; runtime/action checks require the Phase 1 bridge |
| Dependencies | A, L, K |
| Risks | False confidence; expensive startup checks; leaking paths; guessing unsupported runtime details |
| Testing | Fresh install, missing DLL, disabled layer, old plugin, wrong settings, corrupt calibration, missing resource, supported/unsupported runtime |
| Acceptance | Every failure names the failed component and a safe next action; unknown checks are reported as unavailable, not passed |

## 7. WiVRn, Quest 3S and Linux compatibility

### 7.1 Current evidence

- The add-on is a Windows OpenXR layer and runs under Proton through the Windows OpenXR loader/WineOpenXR path.
- Proton's high-integrity process means the plugin registers the implicit layer under `HKLM` in the prefix, not `HKCU`.
- WiVRn's dashboard does not expose a per-app OpenXR binding editor.
- xrizer is an OpenVR compatibility layer and does not see native OpenXR actions.
- The layer submits suggested bindings under Wine for supported profiles: crouch on a configured thumbstick click, Reload Grab on trigger clicks, Tactical Ability on left X/A.
- Suggested bindings are limited to profiles the layer recognises (Touch, Index, Mixed Reality, Odyssey and Cosmos paths). Unknown profiles may receive no extra bindings.
- The layer classifies the runtime name returned by `xrGetInstanceProperties` and queries the current interaction profile per hand. Unknown profiles remain labelled as other; runtime-name strings are not sent to the UI.

### 7.2 Roadmap requirements

1. **No SteamVR dependency.** Prefer OpenXR APIs and OpenXR interaction profiles.
2. **Runtime-neutral diagnostics.** Identify Monado/WiVRn/SteamVR through OpenXR when possible; never infer solely from a process name.
3. **No external daemon by default.** A Linux-side helper for Monado/WiVRn/Envision logs may be considered only as an optional, read-only assistant.
4. **Graceful unknown profiles.** If a profile cannot be identified, show unknown and avoid promising bindings.
5. **Controller-neutral prompts.** Do not assume Touch X or Index A in prose unless the runtime/profile supports it.
6. **Proton-first registry behavior** remains part of setup checks and release tests.
7. **Headset readability** is tested for each new page, not just on a desktop monitor.

### 7.3 Target test matrix

| Environment | Required coverage |
|---|---|
| CachyOS + Proton + WiVRn + Quest 3S | Menus, actions, suggested bindings, overlay, settings persistence |
| Monado/Envision | Runtime identity, unknown profile behavior, action availability |
| SteamVR/OpenXR on Windows | Manual bindings, layer registration, calibration restore |
| 2D desktop launch | Graceful diagnostics when no headset/session exists |
| Game/TF2VR update | Calibration/native compatibility refusal, layer registration, console signature guard |

## 8. Proposed control-center experience

This is a future information architecture, **not** a request to register pages now.

```text
TF2VR Quality of Life
├── VR Control
│   ├── Runtime and headset status
│   ├── Input tester
│   └── Comfort
├── Better Bindings
│   ├── Actions and bindings
│   └── Crouch, sprint and tactical tuning
├── Campaign Sandbox
│   ├── Mission Control
│   ├── NPC Sandbox
│   ├── Player Utilities
│   └── Map Browser
├── Environment Tools
│   ├── Editor
│   └── Layouts
├── Challenge Builder
│   ├── Courses
│   └── Personal Bests
├── Preset Manager
│   ├── Positions
│   ├── Calibration
│   └── Settings backups
├── Developer Center
│   ├── Health Check
│   ├── Telemetry
│   ├── Layouts
│   └── Reports
└── Settings
    ├── Interface
    ├── Storage
    └── About
```

**Context rules:**

- Main menu: VR Control, Better Bindings, Preset Manager, Developer Center and Settings.
- Campaign pause: Campaign Sandbox, Environment Tools and Challenge Builder.
- Do not show a category before its first working page exists.
- Keep a persistent Back path and never trap focus.
- Advanced/unsafe tools stay behind a clear confirmation or developer view.
- Prefer a small number of pages with strong grouping over deep nested menus.

## 9. Technical dependencies and research backlog

| Research question | Why it matters | Current evidence |
|---|---|---|
| Can the layer read runtime/system identity through OpenXR and pass it to the plugin? | Diagnostics A and N | Runtime class/version is now read and published as an integer; system properties and report export remain unverified |
| Can the current interaction profile be queried per hand? | Input tester B, binding diagnostics A | Now queried per hand; unknown paths are classified as other and runtime-untested |
| Can grip/aim poses be tracked per controller without interfering with game actions? | Controller visualization B | Aim pose flags are tracked per hand; grip poses and graphical visualization remain unverified |
| Can the plugin expose compact live state to the UI at an acceptable rate? | A, B, D, L | A throttled at-15-Hz integer ConVar bridge now exists; runtime cost is unmeasured |
| Can `NSDeleteFile` be used safely for presets? | Preset manager E, storage K | Not used or verified |
| Can arbitrary world objects be created and destroyed? | World editor G, scenarios J | `CreateProp` is unverified and deliberately blocked by the static verifier |
| Can campaign levels be changed without corrupting checkpoints? | Map travel F | `ChangeLevel` exists but is untested and blocked |
| What are the real marker, timing and reset APIs for a Gauntlet course? | Scenario builder J | No implementation or verified API path |
| What CPU/GPU timing is available? | Advanced dashboard L | Plugin frame callback can measure CPU interval; no verified GPU timer |
| Can the RUI menus change scale/theme/position dynamically? | Comfort M | Only overlay labels use `Hud_SetPos/Size/Alpha` today |
| What are Safe I/O size and file-count limits? | Preset/storage E/K | Not documented in the repo; needs a bounded test |
| Can native calibration distinguish seated from standing? | Calibration C | Current persistence assumes one saved native calibration |

## 10. Risks and mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Hard-coded native calibration RVAs break after a Titanfall2VR update | High | Content/version gate; refuse writes on mismatch; clear **INCOMPATIBLE** diagnostic |
| Hard-coded engine command signature changes | High | Keep prologue check; disable commands when verification fails; log the failure |
| OpenXR layer behaviour differs across Monado/WiVRn/SteamVR | High | Feature detection; no assumptions from process name; test each runtime |
| Existing features are not runtime-tested | High | Phase 0 gate; disposable save; document pass/fail |
| UI cannot display dynamic controller graphics | Medium | Ship text tester first; make visuals a separate research gate |
| Safe I/O limits or deletion behavior are unknown | Medium | Bounded schema, backup, test quota; avoid directory browsing |
| World-object APIs are unsafe or unavailable | High | Technical spike only; one prop class; no general editor until proven |
| Gauntlet timing/markers interfere with campaign logic | High | Inspect shipped scripts; isolate scenario data; test reset/death/map change |
| Performance diagnostics become misleading | Medium | Label CPU estimates; never invent FPS/GPU data |
| Log/report contains sensitive paths | Medium | Redact user paths; opt-in export; document report contents |
| Scope growth creates unusable menus | Medium | One feature per page; no placeholders; phase gates |
| Packaging verifier drifts from documentation | Low | Update package expected-file checks in a separate packaging change when this file is included in releases |

## 11. Testing strategy and global definition of done

### 11.1 Test layers

1. **Static:** package contents, manifest, ConVars, menu/resource cross-references, bridge allow-list, unsafe API rejection.
2. **Unit:** C++ config parsing, registration, calibration compatibility, schema validation. The repository has conditional CMake test targets but no test sources today.
3. **Integration:** UI → CLIENT → SERVER commands in a disposable campaign; settings → INI → layer reload.
4. **Runtime:** Titanfall 2 campaign + VR headset; test on WiVRn and one other OpenXR path.
5. **Regression:** existing actions, settings, calibration, pause menu, overlay and presets after each feature.

### 11.2 Global definition of done

A feature is complete only when:

- Its required APIs are verified in source or a tested spike.
- All failures are handled without destructive fallback.
- The UI exposes no inert or misleading controls.
- World changes are server-validated and limited to mod-owned objects.
- Data is versioned, validated and recoverable.
- Static checks and relevant C++ tests pass.
- Runtime tests pass on the target headset path, or the feature is explicitly labelled **not run in game**.
- README and sandbox documentation are updated in a separate documentation change.
- No campaign save, map file or game-owned configuration is modified.

Static verification alone is **not** acceptance.

## 12. Milestones

| Milestone | Phase | Exit criteria |
|---|---|---|
| **M0 — Baseline proven** | 0 | Existing features tested in game; failures documented |
| **M1 — Diagnostics alpha** | 1 | Setup Check, runtime identity, input tester v1 and report export usable |
| **M2 — Personalization** | 2 | Calibration profiles and preset manager survive restart and recovery tests |
| **M3 — Sandbox 2** | 3 | The managed NPC roster and map metadata are runtime-validated, and the sandbox save format is stable |
| **M4 — Environment alpha** | 4 | One prop class can be placed, undone and restored safely |
| **M5 — Scenario alpha** | 5 | One complete course runs, resets and persists |
| **M6 — Developer toolkit** | 6 | Health report and CPU-side performance view are useful and accurate |

No dates are assigned. A milestone closes only when its exit criteria are demonstrated.

## 13. Long-term ideas

- Shareable calibration, position and sprint profiles using validated, versioned files.
- Shareable scenario and layout files with dependency checks, never executable content.
- Map thumbnails and descriptions sourced only from assets the project is allowed to redistribute.
- A read-only Linux helper for Monado/WiVRn/Envision logs, separate from the game mod.
- Photo/free-camera sandbox mode with guaranteed player-state restoration.
- Localization of menus and diagnostic messages.
- Accessibility presets, including high-contrast and seated layouts.
- A tested compatibility table by headset, runtime, Proton version and controller profile.
- Optional controller-specific binding recommendations where the runtime exposes stable profiles.

## 14. Next five features to implement

**Phase 0 runtime validation is the prerequisite and is not counted as a feature.**

1. **Setup Check and baseline self-diagnostics (A/N).** Highest support value; uses existing version, settings, registration and calibration information.
2. **Runtime identity plus diagnostic report export (A/L).** Makes every later bug report actionable.
3. **Text-based controller input tester (B v1).** Proves profile/action/tracking visibility before attempting graphics.
4. **Advanced preset manager v1 (E/K).** Completes the most visible sandbox gap with contained file-scope risk.
5. **Managed NPC roster and individual removal (H).** Improves the existing spawner while preserving its safety model.

Do not begin world objects or the Gauntlet builder until the required engine paths have passed a disposable-save spike.

## 15. Repository follow-up

This document is intentionally the only changed file in this planning task. Two separate changes are recommended after review:

- Point `README.md` at `docs/ROADMAP.md`; it currently links the repository-root roadmap.
- Add `docs/ROADMAP.md` to the package expected-file list if the documentation should ship in release ZIPs. The current build copies all of `docs/`, so the package verifier must be updated in that packaging change.
