# TF2VR Quality of life

Extra OpenXR actions and optional features for [CircuitLord's Titanfall 2 VR mod](https://github.com/CircuitLord/CircuitLordVRModInstaller). **On SteamVR, nothing changes until you bind an action or turn a feature on.** Under Wine/Proton the layer supplies Linux suggested bindings for the added actions. Works left-handed too.

## Campaign sandbox (experimental)

Version 1.5.0 adds an experimental sandbox entry to the **real campaign pause menu**, with log-based menu diagnostics and a campaign fly/noclip toggle. Load a single-player mission, pause, and press **Y** for **SANDBOX / DEV TOOLS**. The entry is appended to `InGameSPMenu`; the vanilla Resume, Restart, Settings and Quit entries are not replaced. B returns to the pause menu.

This is a deliberately small, source-verified vertical slice. Pages are wired to real actions through the documented UI → CLIENT (`RunClientScript`) → SERVER (`ClientCommand` and `AddClientCommandCallback`) path; there are no decorative buttons for systems that have not been validated. Implementation is not the same as gameplay verification: see the testing status below. The interface uses dark panels, orange technical labels and native controller navigation so it can be read inside the game's own VR menu path.

| Screen | State | What it does |
|---|---|---|
| **Mission Control** | Implemented; not run in game | Live campaign map, NPC and sandbox-managed counts, server status, and navigation |
| **Maps & Environments** | Catalog only | Lists the 13 campaign map IDs used by the game, marks the current one and shows whether travel is available. Travel is intentionally disabled |
| **NPC Sandbox** | Implemented; not run in game | Wires hostile IMC soldier, hostile IMC spectre, and friendly soldier spawns in front of the player. Enforces a 2-10 NPC cap and clears only NPCs this sandbox created |
| **Player Utilities** | Implemented; not run in game | Wires save, return and clear for a position bookmark, plus a noclip fly toggle with a live status label |
| **Position Presets** | Implemented; not run in game | Wires three position slots under the mod's own Safe I/O folder, map-locked on load |
| **Developer Information** | Implemented; not run in game | Map ID, session mode, coordinates, counts, cap and spawn distance, plus a layout dump button and debug-log switch |

The NPC path places NPCs 100-300 units ahead of the player, requires a clear trace and solid ground, and caps them with the `NPC CAP` switch. `CLEAR MANAGED NPCs` asks for a second click and only calls `Destroy()` on handles recorded by the sandbox. Campaign entities are never scanned and deleted.

Position presets are plain text in Northstar's mod-scoped Safe I/O folder. They contain a map ID, three coordinates and yaw. The SERVER VM rejects a preset from another map, a malformed preset, or out-of-range coordinates. Campaign saves, map files and the Proton prefix are not read or modified.

### Fly and menu diagnostics

**FLY (NOCLIP)** in Player Utilities toggles the player between `MOVETYPE_NOCLIP` and `MOVETYPE_WALK`, using the same API as Northstar's `_northstar_cheatcommands.nut`. It is campaign-only, requires a living player, and clears velocity when toggled. Noclip ignores collision, so it can pass through geometry and leave campaign bounds; tap the row again to land. It is not an overlay, a teleport, god mode or a campaign-progression tool.

**DEBUG LOGGING** is on by default (`tf2vrsb_debug 1`). Opening a sandbox page writes `[TF2VRSB][layout]` lines containing the screen size, the page's own position and size, and each control's relative/absolute position, size, visibility, enabled state, parent geometry, script ID and text. `[state]` lines record the status ConVars, and `[event]` lines record page navigation, map selection, status requests, commands and preset loads. The SERVER VM adds `[TF2VRSB][server]` lines for accepted actions. **LOG CURRENT LAYOUT TO NSLOG** in Developer Information dumps the current page again, and the **DEBUG LOGGING** switch stops the diagnostics when you want a quiet log. Read them in `TF2VR\logs\nslog*.txt`. Nothing is drawn over the menu and no geometry is changed by logging.

### Not implemented in this build

Map transitions, world-object placement/editing, individual NPC removal, and the Gauntlet builder are **not** exposed as working controls. They depend on level-transition, spawn-model, navigation and scenario behavior that cannot be validated without a game session, and a bad implementation can corrupt a campaign state or delete unrelated entities. The map page and Developer Information page say so rather than presenting inert controls. Position preset rename, duplicate, browse and delete are also not implemented; there are three fixed slots.

The sandbox has been source-inspected, packaged and statically checked, but **has not been run in Titanfall 2 or a Quest 3S/WiVRn headset in this development environment**. The pause footer, NPC spawning, teleports, fly/noclip, layout logging, Safe I/O and native-menu VR presentation remain runtime tests. Treat the feature as experimental and start with a disposable campaign session.

See [docs/SANDBOX.md](docs/SANDBOX.md) for the PDF-to-implementation checklist, API evidence, VM boundaries and test plan.

## Actions

Bind them in SteamVR → Settings → Controllers → **Manage Controller Bindings** → Titanfall 2 VR → **Edit**. On Linux, bind them in the controller binding editor of the active OpenXR runtime if it exposes the app's actions; they are part of the Titanfall 2 VR **gameplay** action set.

WiVRn's dashboard does not expose per-app OpenXR actions, and xrizer is the OpenVR compatibility layer, so neither lists these actions. For those setups, use **Action Settings → Crouch Binding** in the in-game menu, or set `[crouch] binding=right_thumbstick_click` in `TF2VR\packages\Nighteyes-TF2VRQualityOfLife-<version>\plugins\layer\TF2VRBetterBindings.ini` (also `left_thumbstick_click`, `both_thumbstick_click`, or `none`). It is applied at startup, so restart the game after changing it. The layer also suggests **Reload Grab** on both trigger clicks and **Tactical Ability** on left **X** (Touch/Meta) or left **A** (Index); both actions are enabled by default.

| Action | What it does | Bind it to |
|---|---|---|
| **Reload Grab** | Grab magazines and rack slides with the trigger. While you reload, Grip on that hand grabs nothing, so Grip only holds the gun | Each **Trigger**, *Use as Button*, next to the mod's own trigger. **Linux/Proton:** suggested on both trigger clicks |
| **Crouch** | Crouch | Any button. Set **Crouch Mode** to **Toggle** to press once to crouch and again to stand, or to **Button** to crouch while held |
| **Tactical Ability** | Cloak. The trigger of the hand without the gun then stops cloaking | Any button. **Linux/Proton:** suggested on left **X** (Touch/Meta) or left **A** (Index) |

Tip: set the mod's **VR Settings → Gun Grip** to **Toggle** to hold your gun with one press of Grip.

## Calibration is saved after the first run

The first time you start the game, calibrate normally. Once Titanfall2VR reports the calibration as complete, the plugin writes it to `TF2VR\packages\Nighteyes-TF2VRQualityOfLife-<version>\plugins\layer\TF2VRBetterBindings.calibration.ini`. On later launches the plugin restores the saved height and arm span and marks the native startup calibration as done, so the calibration screen is skipped.

The file is tied to the installed `Titanfall2VR.dll`. If Titanfall2VR is updated, the old file is ignored and you calibrate once again, after which the new values are saved.

To recalibrate on purpose, delete `TF2VRBetterBindings.calibration.ini` and start the game. Deleting the file is the only reset; the plugin never edits any of CircuitLord's files.

## Settings menu

**TF2VR QUALITY OF LIFE** is a page in the game's own front end. Press **X** on the main menu, or click **TF2VR Quality of life** in the footer.

| Page | What it does |
|---|---|
| **Controls** | Lists the actions this add-on adds and what to bind them to |
| **Action Settings** | Reload Grab, Grenade Toggle, Crouch, Crouch Binding, Crouch Mode, Uncrouch on Jump, Jump Delay, Tactical Ability, Tactical trigger blocking |
| **General Options** | Sprint, and the two sprint heights |
| **About** | Version, what the add-on is, and whether the settings file is connected |
| **Restore Defaults** | Puts every setting above back to its default after a confirmation click |

Select a row to change its value. The menu writes the same `TF2VRBetterBindings.ini` the OpenXR layer reads; the mod's Northstar plugin mirrors each row into that file, so nothing needs editing by hand any more.

- Behaviour values (crouch mode, jump delay, sprint heights, tactical trigger blocking, grenade toggle, reload grab) are picked up by the layer about a second after the row changes.
- Turning a whole action on or off changes which OpenXR actions exist, so it applies after restarting the game.
- If a row says **NOT SAVED**, the plugin DLL is older than the menu: rebuild so `TF2VRBetterBindings.dll` contains the settings bridge. The menu still works, it just cannot write the file.

> [!IMPORTANT]
> **Optional features** can also be turned on from **Action Settings** and **General Options**. Editing `TF2VR\packages\Nighteyes-TF2VRQualityOfLife-<version>\plugins\layer\TF2VRBetterBindings.ini` by hand still works, and the menu always reads the values that are in that file.
>
> | Setting | What it does |
> |---|---|
> | `[sprint] enabled=1` | Sprint by holding your gun low; raise it to aim and the sprint stops |
> | `[grenade] toggle=1` | Grenades toggle like guns: press Grip to take one, press it again to throw. Needs **Gun Grip** on **Toggle** |
> | `[crouch] uncrouch_on_jump=1` | Jumping out of a crouch or slide stands you up and jumps |

<details>
<summary>All other settings</summary>

| Setting | Default | What it does |
|---|---|---|
| `[tactical] block_hand_trigger_in_game` | `1` | `0` = the trigger keeps cloaking after you bind **Tactical Ability** (it still never cloaks during a reload while **Reload Grab** is bound) |
| `[crouch] mode` | `toggle` | `toggle` = press to crouch, press again to stand; `button` = crouch while the button is held |
| `[crouch] jump_delay_ms` | `250` | Raise it if jumping out of a crouch only stands you up |
| `[crouch] binding` | `none` | Suggested OpenXR binding for **Crouch**: `none`, `left_thumbstick_click`, `right_thumbstick_click`, or `both_thumbstick_click`. Applied at startup; use it when the runtime has no per-app binding editor |
| `[sprint] start_below_eyes_cm` | `30` | How far below your eyes the gun must be to sprint |
| `[sprint] stop_below_eyes_cm` | `20` | How close to your eyes the gun must come to stop |
| `[reload_grab] enabled` | `1` | `0` = remove the **Reload Grab** action |

</details>

This is an unofficial add-on. It does not modify or include any of CircuitLord's files, and it is not affiliated with CircuitLord, Respawn, EA or Northstar.

## Install

1. Download `Nighteyes-TF2VRQualityOfLife-<version>.zip` from the [Releases](../../releases) page. You need Titanfall 2 VR installed with CircuitLord's installer.
2. Extract the zip into `<Titanfall 2 folder>\TF2VR\packages\`, so you get `TF2VR\packages\Nighteyes-TF2VRQualityOfLife-<version>\plugins\...`. If you are upgrading from the old package name, follow the upgrade steps below first, and remove the old folder before launching.
3. **START THE GAME, QUIT, AND START IT AGAIN! IT DOES NOT WORK ON THE FIRST START!** This also applies after every update.
4. Bind the actions you want in SteamVR, or in your OpenXR runtime's binding editor on Linux. If the editor has no per-app actions, use the layer's Linux suggestions described above; set `[crouch] binding` for crouch.

### Upgrading from `Nighteyes.TF2VRBetterBindings`

The package and Northstar mod ID are now **TF2VR Quality of life**, but `TF2VRBetterBindings.dll`, `TF2VRBetterBindingsLayer.dll`, `TF2VRBetterBindings.ini`, `TF2VRBetterBindings.calibration.ini` and the layer manifest keep their names. Your settings and calibration therefore remain valid.

1. Extract the new zip next to the old `Nighteyes-TF2VRBetterBindings-<version>` folder.
2. Copy `plugins\layer\TF2VRBetterBindings.ini` and, if present, `plugins\layer\TF2VRBetterBindings.calibration.ini` from the old folder into the same `plugins\layer` folder of the new package. This replaces the new package's default INI with your settings.
3. Delete the old folder before launching the game. Do not run both packages at once: both would load the same DLL and actions.
4. Start the game, quit, and start it again as usual.

`scripts/build-linux.sh --install "<Titanfall 2>/TF2VR/packages"` performs the copy automatically. It imports the newest settings and calibration it finds in either package name, then reminds you to remove the other folder.

### Linux / Proton

Titanfall 2 VR uses the Windows OpenXR loader with WineOpenXR as its runtime under Proton. The add-on's Windows layer works there too. Proton runs the game at high integrity, and the OpenXR loader ignores per-user (HKCU) implicit layers in that case, so the plugin registers the layer for the whole Proton prefix under `HKLM` on the first start. Start the game once, quit, and start it again; the extra actions then appear in the runtime's binding editor. If the runtime has no per-app editor (WiVRn's dashboard does not), the layer submits suggested bindings at startup: **Crouch** on the button set by `[crouch] binding` (set it to `right_thumbstick_click`; the package default is `none`), **Reload Grab** on both trigger clicks, and **Tactical Ability** on left **X** (Touch/Meta) or left **A** (Index). Disable either action to remove its suggestion. xrizer is the OpenVR compatibility layer and does not see native OpenXR actions.

## Troubleshooting

- **The actions are missing in the binding editor**: start the game a second time, then reopen the binding editor. On Linux, check that the layer manifest is registered under `HKLM\Software\Khronos\OpenXR\1\ApiLayers\Implicit` in the Proton prefix. `TF2VR\logs\nslog*.txt` has lines tagged `[TF2VRBB]` that say whether the add-on is active.
- **The actions are missing in xrizer**: xrizer binds OpenVR actions only. Titanfall 2 VR runs on the OpenXR runtime shown in `TF2VR\plugins\Titanfall2VR-data\engine.txt`; use the layer's `[crouch] binding` setting or an OpenXR binding editor instead.
- **Crouch is unbound on WiVRn/Monado**: set `[crouch] binding=right_thumbstick_click` in the layer INI and restart. The development log next to the layer DLL shows `suggested crouch binding ...` when the game submits its bindings.
- **Reload Grab or Tactical is unbound on WiVRn/Monado**: the layer suggests both trigger clicks for Reload Grab and left X (Touch/Meta) or left A (Index) for Tactical. If the layer log says the suggestion was rejected, the runtime rejected the profile's paths; bind the action in the runtime editor or disable it.
- **Running the game as administrator** stops the add-on from loading. Start it normally.

## Uninstall

Delete the `Nighteyes-TF2VRQualityOfLife-<version>` folder. A leftover layer registration under `HKEY_CURRENT_USER\Software\Khronos\OpenXR\1\ApiLayers\Implicit` on Windows, or under `HKEY_LOCAL_MACHINE\Software\Khronos\OpenXR\1\ApiLayers\Implicit` in the Proton prefix, is harmless. `unregister-layer.ps1` in the package removes the per-user entry; add `-Machine` to remove the machine-wide one.

## Building from source

Requirements: Visual Studio 2022 or 2026 with the C++ workload, CMake 3.24+, Git (CMake fetches the Khronos OpenXR headers).

```
cmake -S . -B build -A x64
cmake --build build --config Release
cmake --build build --config Release --target dist_package
```

`dist_package` produces `build\package\Nighteyes-TF2VRQualityOfLife-<version>\` and `build\Nighteyes-TF2VRQualityOfLife-<version>.zip`. Configure with `-DTF2VR_PACKAGES_DIR="<Titanfall 2>\TF2VR\packages"` to get an `install_tf2vr` target that copies the package there, keeping an existing `.ini`.

### Building on Linux

The layer and plugin are Windows DLLs, so a Linux machine cross-compiles them with MinGW-w64. `scripts/build-linux.sh` configures, builds, packages and verifies the result:

```
scripts/build-linux.sh --clean
scripts/build-linux.sh --install "<Titanfall 2>/TF2VR/packages"
```

It writes `build-linux/package/Nighteyes-TF2VRQualityOfLife-<version>/` and `build-linux/Nighteyes-TF2VRQualityOfLife-<version>.zip`, and fails if a DLL is not x64, a file is missing, `mod.json` or the ini holds the wrong values, or the zip is incomplete. `--install` copies the package, keeps an existing `TF2VRBetterBindings.ini`, and imports the newest INI and calibration from an older package folder when the new package is installed for the first time.

Requirements: CMake 3.24+, a MinGW-w64 x86_64 g++ (`sudo apt install g++-mingw-w64-x86-64` on Debian/Ubuntu, `mingw-w64-gcc` on Arch, `mingw64-gcc-c++` on Fedora), Git and Python 3. Ubuntu 22.04 packages CMake 3.22, so `python3 -m pip install --user "cmake>=3.24"` is needed there.

The cross build skips `/W4 /WX` and the `__try/__except` fault guard in `GameVar.cpp` (GCC has no SEH), so releases should still be built with MSVC; the cross build is for testing and for Linux-only machines.

## Credits and license

MIT License, see [LICENSE](LICENSE).

- [CircuitLord](https://github.com/CircuitLord) for Titanfall 2 VR. This add-on requires it but does not contain any of it.
- [Northstar](https://github.com/R2Northstar/NorthstarLauncher) (MIT) for the plugin interface and its documentation of engine internals.
- [Khronos OpenXR SDK](https://github.com/KhronosGroup/OpenXR-SDK) headers (Apache-2.0), fetched at build time.
