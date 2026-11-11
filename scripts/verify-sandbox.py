#!/usr/bin/env python3
"""Cross-check the packaged campaign sandbox scripts and menu resources.

This is deliberately narrower than a Squirrel compiler: it checks names and
links that a package verifier can prove without Titanfall 2 running. It is
called by scripts/build-linux.sh after the package is assembled.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

MOD_DIR = "mods/Nighteyes.TF2VRBetterBindings"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify-sandbox.py <package-folder>", file=sys.stderr)
        return 2

    pkg = Path(sys.argv[1])
    mod = pkg / MOD_DIR
    manifest = json.loads(read(mod / "mod.json"))
    convars = {entry.get("Name") for entry in manifest.get("ConVars", [])}

    ui_path = mod / "mod/scripts/vscripts/ui/tf2vrsb_menu.nut"
    client_path = mod / "mod/scripts/vscripts/tf2vrsb_client.nut"
    server_path = mod / "mod/scripts/vscripts/tf2vrsb_server.nut"
    ui = read(ui_path)
    client = read(client_path)
    server = read(server_path)
    problems: list[str] = []

    # Menu registrations and the resources they reference. The UI uses
    # string constants for menu IDs, so resolve those before comparing.
    constants = dict(re.findall(r'const\s+string\s+(\w+)\s*=\s*"([^"]+)"', ui))
    menu_paths: dict[str, str] = {}
    for menu_token, rel in re.findall(r'AddMenu\(\s*(\w+)\s*,\s*\$"([^"]+)"', ui):
        menu_id = constants.get(menu_token, menu_token)
        menu_paths[menu_id] = rel
        if not (mod / "mod" / rel).is_file():
            problems.append(f"AddMenu resource missing: {rel}")

    controls_by_path: dict[str, set[str]] = {}
    for rel in sorted(set(menu_paths.values())):
        lines = read(mod / "mod" / rel).splitlines()
        names: set[str] = set()
        for index, line in enumerate(lines[:-1]):
            match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*$", line)
            if not match or lines[index + 1].strip() != "{":
                continue
            name = match.group(1)
            # SwitchButton and DialogListButton contain a nested list block,
            # once per control; it is not a HUD control.
            if name == "list":
                continue
            if name in names:
                problems.append(f"{rel}: duplicate control {name}")
            names.add(name)
        controls_by_path[rel] = names

    menu_vars = {
        "rootMenu": "TF2VRSBSandboxRoot",
        "mapsMenu": "TF2VRSBSandboxMaps",
        "npcsMenu": "TF2VRSBSandboxNpcs",
        "playerMenu": "TF2VRSBSandboxPlayer",
        "presetsMenu": "TF2VRSBSandboxPresets",
        "developerMenu": "TF2VRSBSandboxDeveloper",
    }
    for variable, menu_id in menu_vars.items():
        rel = menu_paths.get(menu_id)
        if not rel:
            problems.append(f"missing AddMenu declaration for {menu_id}")
            continue
        controls = controls_by_path[rel]
        for match in re.finditer(
            r'Hud_GetChild\(\s*file\.' + variable + r'\s*,\s*"([^"]+)"\s*\)', ui
        ):
            if match.group(1) not in controls:
                problems.append(f"{rel}: Hud_GetChild missing {match.group(1)}")
        for match in re.finditer(
            r'TF2VRSB_SetButtonLabel\(\s*file\.' + variable + r'\s*,\s*"([^"]+)"',
            ui,
        ):
            if match.group(1) not in controls:
                problems.append(f"{rel}: SetButtonLabel missing {match.group(1)}")

    for variable, prefix, count in re.findall(
        r'TF2VRSB_GetButtons\(\s*file\.(\w+)\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*\)', ui
    ):
        rel = menu_paths.get(menu_vars.get(variable, ""))
        if not rel:
            continue
        for index in range(int(count)):
            name = f"{prefix}{index}"
            if name not in controls_by_path[rel]:
                problems.append(f"{rel}: generated control missing {name}")

    # VM bridge and command coverage.
    for target in sorted(set(re.findall(r'RunClientScript\(\s*"([^"]+)"', ui))):
        if not re.search(r"global\s+function\s+" + re.escape(target) + r"\b", client):
            problems.append(f"client bridge target is not global: {target}")
    if "player.ClientCommand( command )" not in client:
        problems.append("client bridge does not send player.ClientCommand")

    ui_commands = set(
        re.findall(r'RunClientScript\(\s*"TF2VRSB_SendCommand"\s*,\s*"([^"]+)"', ui)
    )
    ui_commands |= set(re.findall(r'TF2VRSB_BeginAction\(\s*"([^"]+)"', ui))
    server_commands = set(
        re.findall(r'AddClientCommandCallback\(\s*"([^"]+)"', server)
    )
    for command in sorted(ui_commands - server_commands):
        problems.append(f"UI command has no SERVER callback: {command}")
    for command in sorted(server_commands - ui_commands):
        problems.append(f"SERVER command is unused by the UI: {command}")

    # ConVar declarations used by either script.
    for label, text in (("UI", ui), ("CLIENT", client), ("SERVER", server)):
        for match in re.finditer(
            r'(?:Get|Set)ConVar(?:String|Int|Float)\(\s*"((?:tf2vrbb|tf2vrsb)_[^"]+)"',
            text,
        ):
            if match.group(1) not in convars:
                problems.append(f"{label}: undeclared ConVar {match.group(1)}")

    # The feature boundary must stay closed while these APIs are unverified.
    for needle, reason in (
        ("ChangeLevel(", "map transitions must remain disabled"),
        ("CreateProp(", "world object placement has no verified API"),
    ):
        if needle in server or needle in ui:
            problems.append(f"{needle} appears, but {reason}")

    if "InGameSPMenu" not in ui:
        problems.append("pause entry does not target InGameSPMenu")
    if "AddMenuFooterOption( pauseMenu, BUTTON_Y" not in ui:
        problems.append("pause entry is not the Y footer option")
    if "NSDeleteFile(" in ui:
        problems.append("preset deletion is not implemented and must not be advertised")

    # Preset path must stay inside the mod-scoped root.
    for path in re.findall(r'return\s+"(sandbox_position_[^"]+)"', ui):
        if "/" in path or ".." in path or not path.endswith(".txt"):
            problems.append(f"unsafe preset path: {path}")

    if problems:
        print(f"FAIL: {len(problems)} sandbox cross-reference problem(s)", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(
        f"sandbox cross-references: {len(convars)} ConVars, "
        f"{len(menu_paths)} menus, {len(ui_commands)} commands, "
        f"{len(controls_by_path)} resources"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
