# TF2VR Quality of Life — Roadmap

This is a proposal, not a release commitment. The order is deliberate: the
features already shipped should be exercised in Titanfall 2 before new work is
allowed to change more campaign state.

## Current baseline

- Three optional OpenXR actions: **Reload Grab**, **Crouch** and **Tactical
  Ability**, with an in-game settings page and saved calibration.
- An experimental campaign pause-menu sandbox with a 62-entry NPC catalog,
  stable managed-NPC IDs, individual removal, a position bookmark, three saved
  presets, fly/noclip and a searchable read-only 38-entry map catalog with metadata, category filters, paging and persistent favorites.
- Layout logging, an on-screen bounds overlay, and saved overlay opacity.
- A read-only VR diagnostics page and live text action tester in the settings menu, built from verified OpenXR action-state and pose hooks.
- A Linux/MinGW cross-build with a static package and menu verifier.

## Design filters

Before a feature goes on the implementation list, it should pass these checks:

1. **Runtime evidence first.** No new control is shipped just because an API
   looks plausible in the scripts or documentation.
2. **Narrow server commands.** New world actions get a dedicated client command,
   an allow-list entry, and full session validation on the server.
3. **Touch only what the mod owns.** NPC cleanup must never remove campaign
   entities; position features must never write campaign saves.
4. **Reversible by default.** Prefer actions that can be undone or abandoned
   from the pause menu.
5. **Useful in the headset.** A setting or diagnostic that needs a keyboard and
   a log reader is a last resort.
6. **Static checks stay current.** Every new menu, control, ConVar and command
   should be covered by `scripts/verify-sandbox.py` or the package verifier.

## At a glance

| Priority | Work | Effort | Risk | Why |
|---|---|---:|---|---|
| 0 | Validate the current build in game | M | None | Everything else depends on a trustworthy baseline |
| 1 | Setup Check page | M | Low | Installation mistakes are the most common support problem |
| 1 | VR diagnostics and text input tester | M | Low | Implemented in 1.7.0; needs headset validation before report export |
| 1 | Preset management | S | Low | Completes the most visible gap in the sandbox |
| 1 | NPC catalog runtime validation | M | Medium | The 1.6.0 catalog and managed roster have not been exercised in game |
| 1 | Overlay accessibility | S | Low | The diagnostic overlay is already useful; make it readable for more people |
| 1 | Settings profiles and per-page resets | M | Low | Makes a growing settings file portable and recoverable |
| 1 | Release automation | S | None | Prevents packaging regressions between releases |
| 2 | Calibration profiles | L | Medium | High comfort value, but it touches CircuitLord's calibration flow |
| 2 | Comfort and input presets | M | Low | Tunes existing features without adding new actions |
| 3 | Photo / free camera | L | Medium | High sandbox payoff with contained campaign risk |
| 3 | Map travel | L | High | Useful, but only after campaign transitions are proven safe |
| 4 | World props and Gauntlet builder | XL | Very high | Large scope with unverified engine paths |

## Phase 0 — Runtime proof

**Goal:** replace "source-verified" with "tested on a disposable campaign save."

Run the full test plan in [`SANDBOX.md`](SANDBOX.md) and record a pass/fail
matrix with the game version, TF2VR version, headset and runtime. At minimum:

- Open the pause entry and every sandbox page with controller and keyboard.
- Spawn a sample from each NPC category, remove one tracked NPC, change the cap
  and distance, clear managed NPCs, and confirm campaign NPCs survive.
- Save, return to and clear a bookmark; save and load a preset; confirm another
  map's preset is rejected.
- Toggle fly, verify the status label and movement, then land.
- Toggle the bounds overlay, cycle opacity, and confirm both values survive a
  clean restart.
- Open **VR DIAGNOSTICS**, confirm the layer/runtime/profile/tracking rows, and move every tested action while watching the live values.
- Check the new `Hud_SetAlpha` behavior at 10% and 100% in the headset.
- Repeat the menu and comfort checks through WiVRn on the Quest 3S.

**Exit criteria:** every shipped control either passes or is clearly labelled
unsupported in the README. Fix blockers in a small `1.7.x` release before adding
new surface area. Do not add another OpenXR action until the current three have
been exercised in the headset.

## Phase 1 — Finish the edges

### VR diagnostics and input tester (implemented in 1.7.0)

The 1.7.0 settings menu has a read-only **VR DIAGNOSTICS** page. It reports the
layer publication state, settings bridge, runtime class/version, app API
version, per-hand interaction profile, pose validity and configured optional
actions. Its live column samples trigger, grip, stick, stick click, primary,
crouch, tactical and reload action states from the layer. Unsupported queries,
inactive controllers and unbound actions are labelled rather than guessed.

This is a text v1, not the full diagnostics center. Report export, setup-health
checks, calibration compatibility, graphical controller visualization, battery
state and face/menu button reporting remain outstanding. The page has not been
exercised in a headset.

### Setup Check page

A read-only **SETUP CHECK** page in the existing settings menu. It should show
what the UI can actually verify:

- Add-on version and whether the settings bridge is connected.
- Which optional actions are enabled and which changes need a restart.
- Whether calibration is saved and whether it matches the installed
  `Titanfall2VR.dll`.
- The active settings file and whether the latest menu change was mirrored.
- A one-click **WRITE SUPPORT SUMMARY** that puts versions, enabled actions,
  saved-state flags and the log path into `nslog`.

Checks that require the layer or registry can be summarized from existing logs;
the page should not pretend to know something it cannot read.

**Why first:** most reported failures are installation, layer-registration or
restart issues rather than broken gameplay logic.

### Position preset management

Keep the three fixed slots, but make each one easier to manage:

- Optional labels, with the map and coordinates shown in the slot summary.
- Rename, duplicate and delete with a confirmation step.
- A backward-compatible reader for the current `map x y z yaw` files.
- Clear feedback when a preset is empty, malformed or from another map.

This completes the feature without adding a general file browser.

### NPC catalog and managed roster (implemented in 1.6.0)

The 1.6.0 build ships a 62-entry catalog, six category filters, text search,
details, a 24-entry server allow-list and stable managed-NPC IDs. Required
follow-up work is runtime validation, not more surface area:

- Spawn one entry from each enabled category on a disposable campaign mission.
- Confirm search, category paging and details work with controller and keyboard.
- Remove a single managed ID and verify that no campaign NPC disappears.
- Confirm map changes discard old handles without touching the old level.
- Keep clear-managed confirmation and never remove unowned entities.

Behaviour controls, spawn presets and squad commands still wait for runtime
evidence that models, teams and navigation work in campaign maps.

### Overlay accessibility

- Three overlay scales, saved like the current opacity.
- A high-contrast palette; a colour-blind-safe alternative if HUD colours can
  be changed through a verified API.
- Keep the default look and the existing 10–100% opacity cycle unchanged.

### Settings profiles

- Per-page **Restore Defaults**, in addition to the global reset.
- Export and import the settings profile through the mod's Safe I/O folder.
- Visible **RESTART REQUIRED** badges for action toggles.
- Show the effective value next to each setting so a silent fallback is obvious.

### Release automation

- Build with MSVC on Windows and the existing MinGW cross-build on Linux.
- Run both package verifiers and retain the ZIP as a CI artifact.
- Add a short changelog and a release checklist that includes the runtime test
  status.

## Phase 2 — Comfort and input

These are worthwhile after the baseline is trusted, but they touch interfaces
owned by CircuitLord's mod or the OpenXR runtime.

### Calibration profiles

Named standing/seated profiles with manual height and arm-span values, plus a
restore path. The existing calibration file stays compatible. This needs a
careful audit of how Titanfall2VR marks calibration complete before it can ship.

### Comfort presets

Presets for the existing sprint thresholds and crouch timing, rather than new
actions:

- Relaxed, Default and Tight sprint sensitivity.
- Short and Long jump-delay presets.
- A clear indication when the layer has picked up a changed behaviour value.

### Runtime and controller guidance

A small compatibility page that shows the recommended setup for SteamVR,
WiVRn/Monado and Proton, including which actions have suggested bindings and
which need manual binding. Do not silently rewrite runtime configuration.

## Phase 3 — Sandbox expansion

Only start these after Phase 0 passes and the relevant APIs have been verified.

### Photo / free camera

A player-independent camera with pause, HUD hiding, FOV/roll controls and a
reliable return to the player. This is a strong screenshot and inspection tool
and is less risky than editing the world. It still needs a tested camera path
and a guaranteed restore.

### NPC squads and simple behaviour

Groups of two to five, with hold-position or follow modes where the AI supports
them. This requires navigation, team and cleanup testing in several campaign
maps. It is not a replacement for a general entity spawner.

### Map travel

An experimental **TRAVEL** action with a confirmation step, a disposable-save
warning, and a clear return path. It must be proven not to break checkpoint,
autosave or mission-state transitions before it appears outside Developer
Information.

### World objects and Gauntlet builder

These remain deferred until there is verified prop creation, undo and scenario
support. They are significantly larger than the current sandbox and should not
be represented by inert buttons in the meantime.

## Later

- Localization for the settings and sandbox labels.
- Installer or mod-manager integration that preserves the existing INI and
  calibration files.
- A public compatibility table for tested headsets, runtimes and Proton setups.
- More controller-specific suggested bindings, where the runtime exposes a
  stable profile mechanism.

## Deliberately not planned

- Campaign save or checkpoint editing.
- Deleting arbitrary entities or "cleaning" the whole level.
- Automatic progression unlocks or mission skipping.
- Unbounded or arbitrary-class NPC spawners.
- Any modification to files owned by CircuitLord's mod or the game.
- A Gauntlet builder in the near term; it is a separate, project-scale feature
  that should wait for tested map, marker and scenario support.

## Definition of done

A roadmap item is complete only when it has:

1. A verified engine or mod API path.
2. UI wiring, controller navigation, and a footer/back path.
3. A server-side validation and cleanup story, if it changes world state.
4. Coverage in the static verifier or an explained exception.
5. A runtime test result, or an explicit **NOT RUN IN GAME** note.
6. Updated README and sandbox documentation.
