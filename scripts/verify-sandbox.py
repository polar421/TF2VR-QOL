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

MOD_DIR = "mods/Nighteyes.TF2VRQualityOfLife"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify-sandbox.py <package-folder>", file=sys.stderr)
        return 2

    pkg = Path(sys.argv[1])
    mod = pkg / MOD_DIR
    manifest = json.loads(read(mod / "mod.json"))
    convar_entries = manifest.get("ConVars", [])
    convars = {entry.get("Name") for entry in convar_entries}

    ui_path = mod / "mod/scripts/vscripts/ui/tf2vrsb_menu.nut"
    npc_ui_path = mod / "mod/scripts/vscripts/ui/tf2vrsb_npc_browser.nut"
    debug_path = mod / "mod/scripts/vscripts/ui/tf2vrsb_debug.nut"
    settings_ui_path = mod / "mod/scripts/vscripts/ui/tf2vrbb_menu.nut"
    diagnostics_path = mod / "mod/resource/ui/menus/tf2vrbb_diagnostics.menu"
    client_path = mod / "mod/scripts/vscripts/tf2vrsb_client.nut"
    server_path = mod / "mod/scripts/vscripts/tf2vrsb_server.nut"
    ui = read(ui_path)
    npc_ui = read(npc_ui_path)
    debug = read(debug_path)
    settings_ui = read(settings_ui_path)
    diagnostics = read(diagnostics_path)
    combined_ui = ui + "\n" + npc_ui
    client = read(client_path)
    server = read(server_path)
    problems: list[str] = []

    for convar_name, default in (
        ("tf2vrsb_overlay", "0"),
        ("tf2vrsb_overlay_opacity", "20"),
    ):
        entry = next(
            (item for item in convar_entries if item.get("Name") == convar_name),
            None,
        )
        if entry is None:
            problems.append(f"missing overlay ConVar: {convar_name}")
            continue
        if entry.get("DefaultValue") != default:
            problems.append(f"{convar_name} must default to {default}")
        flags = entry.get("Flags")
        if not isinstance(flags, int) or flags & 128 == 0:
            problems.append(f"{convar_name} must use FCVAR_ARCHIVE (128)")

    for required in (
        "GetConVarInt( TF2VRSB_LAYOUT_OPACITY )",
        "SetConVarInt( TF2VRSB_LAYOUT_OPACITY, next )",
        "Hud_SetAlpha( box, alpha )",
        "TF2VRSB_OverlayOpacityLabel()",
        "TF2VRSB_CycleOverlayOpacity",
    ):
        if required not in debug:
            problems.append(f"tf2vrsb_debug.nut: missing {required}")

    for required in (
        'Hud_GetChild( file.developerMenu, "OverlayOpacity" )',
        "Hud_AddEventHandler( opacityButton, UIE_CLICK, TF2VRSB_CycleOverlayOpacity )",
    ):
        if required not in ui:
            problems.append(f"tf2vrsb_menu.nut: missing {required}")

    # Diagnostics labels and lifecycle. These are settings-menu controls, not
    # part of the campaign sandbox, so they are checked separately.
    diag_controls: set[str] = set()
    diag_lines = diagnostics.splitlines()
    for index, line in enumerate(diag_lines[:-1]):
        match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*$", line)
        if match and diag_lines[index + 1].strip() == "{":
            diag_controls.add(match.group(1))
    for child in re.findall(r'Hud_GetChild\(\s*file\.diagnosticsMenu,\s*"([^"]+)"\s*\)', settings_ui):
        if child not in diag_controls:
            problems.append(f"tf2vrbb_diagnostics.menu: Hud_GetChild missing {child}")
    for required in (
        "TF2VRBB_InitDiagnostics",
        "TF2VRBB_RefreshDiagnostics",
        "TF2VRBB_DiagnosticsThink",
        'SetConVarInt( "tf2vrbb_diag_enabled", 1 )',
        'SetConVarInt( "tf2vrbb_diag_enabled", 0 )',
        "GetActiveMenu() == file.diagnosticsMenu",
    ):
        if required not in settings_ui:
            problems.append(f"tf2vrbb_menu.nut: missing diagnostics hook {required}")
    root_resource = read(mod / "mod/resource/ui/menus/tf2vrbb_root.menu")
    for row in range(6):
        if not re.search(r"^\s*Row" + str(row) + r"\s*$", root_resource, re.MULTILINE):
            problems.append(f"tf2vrbb_root.menu: missing diagnostics root row Row{row}")

    # Menu registrations and the resources they reference. The UI uses
    # string constants for menu IDs, so resolve those before comparing.
    constants = dict(re.findall(r'const\s+string\s+(\w+)\s*=\s*"([^"]+)"', ui))
    constants.update(dict(re.findall(r'const\s+string\s+(\w+)\s*=\s*"([^"]+)"', npc_ui)))
    menu_paths: dict[str, str] = {}
    for source in (ui, npc_ui):
        for menu_token, rel in re.findall(r'AddMenu\(\s*(\w+)\s*,\s*\$"([^"]+)"', source):
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

    for rel in sorted(set(menu_paths.values())):
        if not Path(rel).name.startswith("tf2vrsb_") or not rel.endswith(".menu"):
            continue
        resource = read(mod / "mod" / rel)
        if 'bgcolor_override "242 141 28 255"' not in resource:
            problems.append(f"{rel}: menu overlay background must be fully opaque")
        if resource.count('bgcolor_override "0 220 255 255"') != 15:
            problems.append(f"{rel}: expected 15 fully opaque control overlay backgrounds")

    menu_vars = {
        "rootMenu": "TF2VRSBSandboxRoot",
        "mapsMenu": "TF2VRSBSandboxMaps",
        "browserMenu": "TF2VRSBSandboxNpcBrowser",
        "detailsMenu": "TF2VRSBSandboxNpcDetails",
        "managedMenu": "TF2VRSBSandboxNpcManaged",
        "playerMenu": "TF2VRSBSandboxPlayer",
        "presetsMenu": "TF2VRSBSandboxPresets",
        "developerMenu": "TF2VRSBSandboxDeveloper",
    }
    overlay_controls = {"DebugMenu", "DebugLegend"} | {
        f"Debug{index}" for index in range(15)
    }
    for variable, menu_id in menu_vars.items():
        rel = menu_paths.get(menu_id)
        if not rel:
            problems.append(f"missing AddMenu declaration for {menu_id}")
            continue
        controls = controls_by_path[rel]
        for match in re.finditer(
            r'Hud_GetChild\(\s*file\.' + variable + r'\s*,\s*"([^"]+)"\s*\)', combined_ui
        ):
            if match.group(1) not in controls:
                problems.append(f"{rel}: Hud_GetChild missing {match.group(1)}")
        for match in re.finditer(
            r'TF2VRSB_SetButtonLabel\(\s*file\.' + variable + r'\s*,\s*"([^"]+)"',
            combined_ui,
        ):
            if match.group(1) not in controls:
                problems.append(f"{rel}: SetButtonLabel missing {match.group(1)}")
        missing_overlay = overlay_controls - controls
        if missing_overlay:
            problems.append(
                f"{rel}: missing overlay controls {', '.join(sorted(missing_overlay))}"
            )
        if (f"TF2VRSB_AddLayoutFooter( file.{variable} )" not in combined_ui
                and f"TF2VRSB_NpcAddLayoutFooter( file.{variable} )" not in npc_ui):
            problems.append(f"{menu_id}: layout overlay footer is not registered")

    for pattern, source in (
        (r'TF2VRSB_GetButtons\(\s*file\.(\w+)\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*\)', ui),
        (r'TF2VRSB_NpcChildren\(\s*file\.(\w+)\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*\)', npc_ui),
    ):
        for variable, prefix, count in re.findall(pattern, source):
            rel = menu_paths.get(menu_vars.get(variable, ""))
            if not rel:
                continue
            for index in range(int(count)):
                name = f"{prefix}{index}"
                if name not in controls_by_path[rel]:
                    problems.append(f"{rel}: generated control missing {name}")

    for pattern in (
        r'TF2VRSB_NpcBind\(\s*file\.(\w+)\s*,\s*"([^"]+)"',
        r'TF2VRSB_NpcSet(?:Button|Enabled)\(\s*file\.(\w+)\s*,\s*"([^"]+)"',
    ):
        for variable, name in re.findall(pattern, npc_ui):
            rel = menu_paths.get(menu_vars.get(variable, ""))
            if rel and name not in controls_by_path[rel]:
                problems.append(f"{rel}: referenced control missing {name}")

    # VM bridge and command coverage.
    for target in sorted(set(re.findall(r'RunClientScript\(\s*"([^"]+)"', combined_ui))):
        if not re.search(r"global\s+function\s+" + re.escape(target) + r"\b", client):
            problems.append(f"client bridge target is not global: {target}")
    if "player.ClientCommand( command )" not in client:
        problems.append("client bridge does not send player.ClientCommand")

    ui_commands = set(
        re.findall(r'RunClientScript\(\s*"TF2VRSB_SendCommand"\s*,\s*"([^"]+)"', combined_ui)
    )
    ui_commands |= set(re.findall(r'TF2VRSB_BeginAction\(\s*"([^"]+)"', combined_ui))
    ui_commands |= set(re.findall(r'TF2VRSB_NpcBeginAction\(\s*"([^"]+)"', npc_ui))
    server_commands = set(
        re.findall(r'AddClientCommandCallback\(\s*"([^"]+)"', server)
    )
    for command in sorted(ui_commands - server_commands):
        problems.append(f"UI command has no SERVER callback: {command}")
    for command in sorted(server_commands - ui_commands):
        problems.append(f"SERVER command is unused by the UI: {command}")
    for command in sorted(server_commands):
        if f'"{command}"' not in client:
            problems.append(f"CLIENT allow-list is missing SERVER command: {command}")

    # The diagnostic module may manipulate only its own overlay labels; it
    # must expose the expected hooks and stay out of server/world APIs.
    for required in (
        "TF2VRSB_LogPage(",
        "TF2VRSB_LogState(",
        "TF2VRSB_LogEvent(",
        "TF2VRSB_DrawLayoutOverlay(",
        "GetConVarInt( TF2VRSB_LAYOUT_OVERLAY )",
        "SetConVarInt( TF2VRSB_LAYOUT_OVERLAY",
        "Hud_GetAbsX(",
        "Hud_SetPos(",
        "Hud_SetSize(",
    ):
        if required not in debug:
            problems.append(f"debug UI module is missing {required}")
    for forbidden in ("RunClientScript(", "ClientCommand(", "SetOrigin(", "CreateNPC("):
        if forbidden in debug:
            problems.append(f"debug UI module must not call server/world API: {forbidden}")

    # ConVar declarations used by either script.
    for label, text in (("UI", combined_ui), ("SETTINGS", settings_ui), ("DEBUG", debug), ("CLIENT", client), ("SERVER", server)):
        for match in re.finditer(
            r'(?:Get|Set)ConVar(?:String|Int|Float)\(\s*"((?:tf2vrbb|tf2vrsb)_[^"]+)"',
            text,
        ):
            convar_name = match.group(1)
            # Dynamic slot names are assembled from a declared prefix.
            if convar_name.endswith("_"):
                continue
            if convar_name not in convars:
                problems.append(f"{label}: undeclared ConVar {convar_name}")

    # The feature boundary must stay closed while these APIs are unverified.
    for needle, reason in (
        ("ChangeLevel(", "map transitions must remain disabled"),
        ("CreateProp(", "world object placement has no verified API"),
    ):
        if needle in server or needle in combined_ui:
            problems.append(f"{needle} appears, but {reason}")

    if "InGameSPMenu" not in ui:
        problems.append("pause entry does not target InGameSPMenu")
    if "AddMenuFooterOption( pauseMenu, BUTTON_Y" not in ui:
        problems.append("pause entry is not the Y footer option")
    if "NSDeleteFile(" in combined_ui:
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
        f"{len(controls_by_path)} resources, 7 scripts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
