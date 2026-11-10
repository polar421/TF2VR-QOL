# TF2VR Better Bindings

Extra OpenXR actions and optional features for [CircuitLord's Titanfall 2 VR mod](https://github.com/CircuitLord/CircuitLordVRModInstaller). **Nothing changes until you bind an action or turn a feature on.** Works left-handed too.

## Actions

Bind them in SteamVR → Settings → Controllers → **Manage Controller Bindings** → Titanfall 2 VR → **Edit**. On Linux, bind them in the controller binding editor of the active OpenXR runtime (for example WiVRn or Monado); they are part of the Titanfall 2 VR **gameplay** action set.

| Action | What it does | Bind it to |
|---|---|---|
| **Reload Grab** | Grab magazines and rack slides with the trigger. While you reload, Grip on that hand grabs nothing, so Grip only holds the gun | Each **Trigger**, *Use as Button*, next to the mod's own trigger |
| **Crouch** | Crouch | Any button: *Use as Button* to hold, *Use as Toggle Button* to toggle |
| **Tactical Ability** | Cloak. The trigger of the hand without the gun then stops cloaking | Any button |

Tip: set the mod's **VR Settings → Gun Grip** to **Toggle** to hold your gun with one press of Grip.

## Calibration is saved after the first run

The first time you start the game, calibrate normally. Once Titanfall2VR reports the calibration as complete, the plugin writes it to `TF2VR\packages\Nighteyes-TF2VRBetterBindings-<version>\plugins\layer\TF2VRBetterBindings.calibration.ini`. On later launches the plugin restores the saved height and arm span and marks the native startup calibration as done, so the calibration screen is skipped.

The file is tied to the installed `Titanfall2VR.dll`. If Titanfall2VR is updated, the old file is ignored and you calibrate once again, after which the new values are saved.

To recalibrate on purpose, delete `TF2VRBetterBindings.calibration.ini` and start the game. Deleting the file is the only reset; the plugin never edits any of CircuitLord's files.

## Settings menu

**TF2VR BETTER BINDINGS** is a page in the game's own front end. Press **X** on the main menu, or click **TF2VR Better Bindings** in the footer.

| Page | What it does |
|---|---|
| **Controls** | Lists the actions this add-on adds and what to bind them to |
| **Action Settings** | Reload Grab, Grenade Toggle, Crouch, Crouch Mode, Uncrouch on Jump, Jump Delay, Tactical Ability, Tactical trigger blocking |
| **General Options** | Sprint, and the two sprint heights |
| **About** | Version, what the add-on is, and whether the settings file is connected |
| **Restore Defaults** | Puts every setting above back to its default after a confirmation click |

Select a row to change its value. The menu writes the same `TF2VRBetterBindings.ini` the OpenXR layer reads; the mod's Northstar plugin mirrors each row into that file, so nothing needs editing by hand any more.

- Behaviour values (crouch mode, jump delay, sprint heights, tactical trigger blocking, grenade toggle, reload grab) are picked up by the layer about a second after the row changes.
- Turning a whole action on or off changes which OpenXR actions exist, so it applies after restarting the game.
- If a row says **NOT SAVED**, the plugin DLL is older than the menu: rebuild so `TF2VRBetterBindings.dll` contains the settings bridge. The menu still works, it just cannot write the file.

> [!IMPORTANT]
> **Optional features** can also be turned on from **Action Settings** and **General Options**. Editing `TF2VR\packages\Nighteyes-TF2VRBetterBindings-<version>\plugins\layer\TF2VRBetterBindings.ini` by hand still works, and the menu always reads the values that are in that file.
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
| `[crouch] mode` | `toggle` | Set to `button` if **Crouch** is bound as *Use as Button* and `uncrouch_on_jump` is on |
| `[crouch] jump_delay_ms` | `250` | Raise it if jumping out of a crouch only stands you up |
| `[sprint] start_below_eyes_cm` | `30` | How far below your eyes the gun must be to sprint |
| `[sprint] stop_below_eyes_cm` | `20` | How close to your eyes the gun must come to stop |
| `[reload_grab] enabled` | `1` | `0` = remove the **Reload Grab** action |

</details>

This is an unofficial add-on. It does not modify or include any of CircuitLord's files, and it is not affiliated with CircuitLord, Respawn, EA or Northstar.

## Install

1. Download `Nighteyes-TF2VRBetterBindings-<version>.zip` from the [Releases](../../releases) page. You need Titanfall 2 VR installed with CircuitLord's installer.
2. Delete any older `Nighteyes-TF2VRBetterBindings-<version>` folder (copy its `TF2VRBetterBindings.ini` first to keep your settings). Extract the zip into `<Titanfall 2 folder>\TF2VR\packages\`, so you get `TF2VR\packages\Nighteyes-TF2VRBetterBindings-<version>\plugins\...`.
3. **START THE GAME, QUIT, AND START IT AGAIN! IT DOES NOT WORK ON THE FIRST START!** This also applies after every update.
4. Bind the actions you want in SteamVR, or in your OpenXR runtime's binding editor on Linux.

### Linux / Proton

Titanfall 2 VR uses the Windows OpenXR loader with WineOpenXR as its runtime under Proton. The add-on's Windows layer works there too. Proton runs the game at high integrity, and the OpenXR loader ignores per-user (HKCU) implicit layers in that case, so the plugin registers the layer for the whole Proton prefix under `HKLM` on the first start. Start the game once, quit, and start it again; the extra actions then appear in the runtime's binding editor.

## Troubleshooting

- **The actions are missing in the binding editor**: start the game a second time, then reopen the binding editor. On Linux, check that the layer manifest is registered under `HKLM\Software\Khronos\OpenXR\1\ApiLayers\Implicit` in the Proton prefix. `TF2VR\logs\nslog*.txt` has lines tagged `[TF2VRBB]` that say whether the add-on is active.
- **Running the game as administrator** stops the add-on from loading. Start it normally.

## Uninstall

Delete the `Nighteyes-TF2VRBetterBindings-<version>` folder. A leftover layer registration under `HKEY_CURRENT_USER\Software\Khronos\OpenXR\1\ApiLayers\Implicit` on Windows, or under `HKEY_LOCAL_MACHINE\Software\Khronos\OpenXR\1\ApiLayers\Implicit` in the Proton prefix, is harmless. `unregister-layer.ps1` in the package removes the per-user entry; add `-Machine` to remove the machine-wide one.

## Building from source

Requirements: Visual Studio 2022 or 2026 with the C++ workload, CMake 3.24+, Git (CMake fetches the Khronos OpenXR headers).

```
cmake -S . -B build -A x64
cmake --build build --config Release
cmake --build build --config Release --target dist_package
```

`dist_package` produces `build\package\Nighteyes-TF2VRBetterBindings-<version>\` and `build\Nighteyes-TF2VRBetterBindings-<version>.zip`. Configure with `-DTF2VR_PACKAGES_DIR="<Titanfall 2>\TF2VR\packages"` to get an `install_tf2vr` target that copies the package there, keeping an existing `.ini`.

### Building on Linux

The layer and plugin are Windows DLLs, so a Linux machine cross-compiles them with MinGW-w64. `scripts/build-linux.sh` configures, builds, packages and verifies the result:

```
scripts/build-linux.sh --clean
scripts/build-linux.sh --install "<Titanfall 2>/TF2VR/packages"
```

It writes `build-linux/package/Nighteyes-TF2VRBetterBindings-<version>/` and `build-linux/Nighteyes-TF2VRBetterBindings-<version>.zip`, and fails if a DLL is not x64, a file is missing, `mod.json` or the ini holds the wrong values, or the zip is incomplete. `--install` copies the package and keeps an existing `TF2VRBetterBindings.ini`.

Requirements: CMake 3.24+, a MinGW-w64 x86_64 g++ (`sudo apt install g++-mingw-w64-x86-64` on Debian/Ubuntu, `mingw-w64-gcc` on Arch, `mingw64-gcc-c++` on Fedora), Git and Python 3. Ubuntu 22.04 packages CMake 3.22, so `python3 -m pip install --user "cmake>=3.24"` is needed there.

The cross build skips `/W4 /WX` and the `__try/__except` fault guard in `GameVar.cpp` (GCC has no SEH), so releases should still be built with MSVC; the cross build is for testing and for Linux-only machines.

## Credits and license

MIT License, see [LICENSE](LICENSE).

- [CircuitLord](https://github.com/CircuitLord) for Titanfall 2 VR. This add-on requires it but does not contain any of it.
- [Northstar](https://github.com/R2Northstar/NorthstarLauncher) (MIT) for the plugin interface and its documentation of engine internals.
- [Khronos OpenXR SDK](https://github.com/KhronosGroup/OpenXR-SDK) headers (Apache-2.0), fetched at build time.
