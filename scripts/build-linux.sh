#!/usr/bin/env bash
# Cross-compile the Windows build of TF2VR Better Bindings on Linux, assemble
# the release package and check what came out.
#
#   scripts/build-linux.sh --clean
#   scripts/build-linux.sh --install "<Titanfall 2>/TF2VR/packages"
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/build-linux.sh [options]

Builds the OpenXR layer and Northstar plugin for Windows with MinGW-w64,
creates the release package and zip, and verifies both.

Options:
  --build-dir DIR    CMake build directory (default: build-linux)
  --clean            delete the build directory before configuring
  --install DIR      copy the package into DIR (a TF2VR\packages folder),
                     keeping an existing plugins/layer/TF2VRBetterBindings.ini
                     and plugins/layer/TF2VRBetterBindings.calibration.ini
  --jobs N           parallel build jobs (default: all CPUs)
  --check-deps-only  report missing tools and exit
  -h, --help         show this help
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$root/build-linux"
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
clean=0
install_dir=""
deps_only=0

while [ $# -gt 0 ]; do
    case "$1" in
        --build-dir) build_dir="${2:?--build-dir needs a value}"; shift 2 ;;
        --clean) clean=1; shift ;;
        --install) install_dir="${2:?--install needs a value}"; shift 2 ;;
        --jobs) jobs="${2:?--jobs needs a value}"; shift 2 ;;
        --check-deps-only) deps_only=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

has() { command -v "$1" >/dev/null 2>&1; }

version="$(sed -n 's/^project(TF2VRBetterBindings VERSION \([0-9][0-9.]*\).*/\1/p' "$root/CMakeLists.txt" | head -n1)"
if [ -z "$version" ]; then
    echo "error: could not read the project version from CMakeLists.txt" >&2
    exit 1
fi
package_name="Nighteyes-TF2VRBetterBindings-$version"

install_hint() {
    if has apt-get; then
        echo "sudo apt install -y cmake g++-mingw-w64-x86-64 git python3"
    elif has pacman; then
        echo "sudo pacman -S --needed cmake mingw-w64-gcc git python"
    elif has dnf; then
        echo "sudo dnf install -y cmake mingw64-gcc-c++ git python3"
    else
        echo "install cmake >= 3.24, a MinGW-w64 x86_64 g++ toolchain, git and python3"
    fi
}

missing=()
cmake_problem=""
if ! has cmake; then
    cmake_problem="cmake is not installed (need >= 3.24)"
else
    cmake_ver="$(cmake --version | sed -n '1s/.* \([0-9][0-9.]*\)$/\1/p')"
    if [ -z "$cmake_ver" ] || [ "$(printf '%s\n%s\n' 3.24 "$cmake_ver" | sort -V | head -n1)" != "3.24" ]; then
        cmake_problem="cmake $cmake_ver is too old (need >= 3.24); on Ubuntu 22.04: python3 -m pip install --user 'cmake>=3.24'"
    fi
fi
[ -z "$cmake_problem" ] || missing+=("$cmake_problem")

mingw_cxx=""
for candidate in x86_64-w64-mingw32-g++ x86_64-w64-mingw32-g++-posix x86_64-w64-mingw32-g++-win32 x86_64-w64-mingw32-clang++; do
    if has "$candidate"; then
        mingw_cxx="$candidate"
        break
    fi
done
[ -n "$mingw_cxx" ] || missing+=("MinGW-w64 x86_64 g++ (x86_64-w64-mingw32-g++) is not on PATH")

has git || missing+=("git is not installed (CMake downloads the OpenXR headers with it)")
has python3 || missing+=("python3 is not installed (used to verify the package)")

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing tools:" >&2
    for item in "${missing[@]}"; do echo "  - $item" >&2; done
    echo >&2
    echo "Install them with:" >&2
    echo "  $(install_hint)" >&2
    exit 1
fi

echo "cmake:  $(cmake --version | head -n1)"
echo "c++:    $(command -v "$mingw_cxx")"
echo "target: $($mingw_cxx -dumpmachine)"
echo "mod:    $package_name"

if [ "$deps_only" -eq 1 ]; then
    echo "dependencies look usable"
    exit 0
fi

if [ "$clean" -eq 1 ]; then
    echo "== cleaning $build_dir =="
    rm -rf "$build_dir"
fi

echo "== configuring =="
cmake -S "$root" -B "$build_dir" \
    -DCMAKE_TOOLCHAIN_FILE="$root/cmake/toolchain-mingw-w64.cmake" \
    -DCMAKE_BUILD_TYPE=Release

echo "== building =="
cmake --build "$build_dir" --parallel "$jobs"

echo "== packaging =="
cmake --build "$build_dir" --parallel "$jobs" --target dist_package

package_dir="$build_dir/package/$package_name"
zip_path="$build_dir/$package_name.zip"

echo "== verifying =="
python3 - "$package_dir" "$zip_path" "$version" <<'PY'
import json
import struct
import sys
import zipfile
from pathlib import Path

pkg = Path(sys.argv[1])
zip_path = Path(sys.argv[2])
version = sys.argv[3]
mod_dir = "mods/Nighteyes.TF2VRBetterBindings"
menu_pages = ["about", "actions", "controls", "general", "restore", "root"]
sandbox_pages = ["root", "maps", "npcs", "player", "presets", "developer"]

expected = [
    "LICENSE",
    "README.md",
    "docs/SANDBOX.md",
    "unregister-layer.ps1",
    f"{mod_dir}/mod.json",
    f"{mod_dir}/mod/scripts/vscripts/tf2vrbb_menu_state.nut",
    f"{mod_dir}/mod/scripts/vscripts/ui/tf2vrbb_menu.nut",
    f"{mod_dir}/mod/scripts/vscripts/tf2vrsb_client.nut",
    f"{mod_dir}/mod/scripts/vscripts/tf2vrsb_server.nut",
    f"{mod_dir}/mod/scripts/vscripts/ui/tf2vrsb_menu.nut",
]
expected += [f"{mod_dir}/mod/resource/ui/menus/tf2vrbb_{page}.menu" for page in menu_pages]
expected += [f"{mod_dir}/mod/resource/ui/menus/tf2vrsb_{page}.menu" for page in sandbox_pages]
expected += [
    "plugins/TF2VRBetterBindings.dll",
    "plugins/layer/TF2VRBetterBindingsLayer.dll",
    "plugins/layer/TF2VRBetterBindings.ini",
    "plugins/layer/XR_APILAYER_NIGHTEYES_tf2vr_better_bindings.json",
]

required_convars = {
    "tf2vrbb_menu_active", "tf2vrbb_startup_phase", "tf2vrbb_settings_api",
    "tf2vrbb_reload_grab", "tf2vrbb_grenade_toggle", "tf2vrbb_crouch_enabled",
    "tf2vrbb_crouch_button_mode", "tf2vrbb_crouch_binding", "tf2vrbb_uncrouch_on_jump", "tf2vrbb_jump_delay_ms",
    "tf2vrbb_tactical_enabled", "tf2vrbb_tactical_block_trigger",
    "tf2vrbb_sprint_enabled", "tf2vrbb_sprint_start_cm", "tf2vrbb_sprint_stop_cm",
    "tf2vrsb_map", "tf2vrsb_mode", "tf2vrsb_ready", "tf2vrsb_x", "tf2vrsb_y",
    "tf2vrsb_z", "tf2vrsb_yaw", "tf2vrsb_npc_count", "tf2vrsb_entity_count",
    "tf2vrsb_managed_count", "tf2vrsb_bookmark", "tf2vrsb_result", "tf2vrsb_cap",
    "tf2vrsb_spawn_distance", "tf2vrsb_request_map", "tf2vrsb_request_x",
    "tf2vrsb_request_y", "tf2vrsb_request_z", "tf2vrsb_request_yaw",
}

min_mingw_runtime_imports = {
    "libstdc++-6.dll",
    "libgcc_s_seh-1.dll",
    "libgcc_s_dw2-1.dll",
    "libwinpthread-1.dll",
    "libssp-0.dll",
}

ini_expected = {
    ("reload_grab", "enabled"): "1",
    ("grenade", "toggle"): "0",
    ("crouch", "enabled"): "1",
    ("crouch", "mode"): "toggle",
    ("crouch", "binding"): "none",
    ("crouch", "uncrouch_on_jump"): "0",
    ("crouch", "jump_delay_ms"): "250",
    ("tactical", "enabled"): "1",
    ("tactical", "block_hand_trigger_in_game"): "1",
    ("sprint", "enabled"): "0",
    ("sprint", "start_below_eyes_cm"): "30",
    ("sprint", "stop_below_eyes_cm"): "20",
}

problems = []
def read(path):
    return path.read_text(encoding="utf-8", errors="replace")

def pe_info(path):
    with path.open("rb") as handle:
        head = handle.read(0x40)
        if len(head) < 0x40 or head[:2] != b"MZ":
            return None
        offset = struct.unpack_from("<I", head, 0x3c)[0]
        handle.seek(offset)
        if handle.read(4) != b"PE\0\0":
            return None
        machine, _sections, _stamp, _symtab, _symbols, _optional_size, characteristics = struct.unpack(
            "<HHIIIHH", handle.read(20)
        )
    return machine, characteristics

def pe_imports(path):
    data = path.read_bytes()
    if data[:2] != b"MZ":
        return set()
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        return set()
    _machine, sections, _stamp, _symtab, _symbols, optional_size, _chars = struct.unpack_from(
        "<HHIIIHH", data, pe + 4
    )
    optional = pe + 24
    magic = struct.unpack_from("<H", data, optional)[0]
    if magic == 0x20B:
        directories = optional + 112
    elif magic == 0x10B:
        directories = optional + 96
    else:
        return set()
    import_rva = struct.unpack_from("<I", data, directories + 8)[0]
    if not import_rva:
        return set()

    section_table = optional + optional_size
    layout = []
    for index in range(sections):
        base = section_table + index * 40
        virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", data, base + 8)
        layout.append((virtual_address, max(virtual_size, raw_size), raw_pointer))

    def file_offset(rva):
        for virtual_address, size, raw_pointer in layout:
            if virtual_address <= rva < virtual_address + size:
                return raw_pointer + (rva - virtual_address)
        return None

    names = set()
    cursor = file_offset(import_rva)
    if cursor is None:
        return names
    while cursor + 20 <= len(data):
        entry = struct.unpack_from("<IIIII", data, cursor)
        if not any(entry):
            break
        name_offset = file_offset(entry[3])
        if name_offset is None:
            break
        end = data.find(b"\0", name_offset, name_offset + 256)
        if end == -1:
            break
        names.add(data[name_offset:end].decode("ascii", "replace").lower())
        cursor += 20
    return names

if not pkg.is_dir():
    problems.append(f"package folder missing: {pkg}")
else:
    actual = sorted(path.relative_to(pkg).as_posix() for path in pkg.rglob("*") if path.is_file())
    for rel in expected:
        if rel not in actual:
            problems.append(f"missing from package: {rel}")
    for rel in actual:
        if rel not in expected:
            problems.append(f"unexpected file: {rel}")

    for dll in ("plugins/TF2VRBetterBindings.dll", "plugins/layer/TF2VRBetterBindingsLayer.dll"):
        path = pkg / dll
        if not path.is_file():
            continue
        info = pe_info(path)
        if info is None:
            problems.append(f"{dll}: not a Windows PE file")
            continue
        machine, characteristics = info
        if machine != 0x8664:
            problems.append(f"{dll}: machine 0x{machine:04x}, expected x86-64 (0x8664)")
        if not characteristics & 0x2000:
            problems.append(f"{dll}: not linked as a DLL")
        for dependency in sorted(pe_imports(path) & min_mingw_runtime_imports):
            problems.append(
                f"{dll}: imports {dependency}, which the game does not ship "
                f"(Windows error 126); link the GCC runtime statically"
            )

    mod = json.loads(read(pkg / mod_dir / "mod.json"))
    if mod.get("Version") != version:
        problems.append(f"mod.json version {mod.get('Version')!r}, expected {version!r}")
    convar_names = {entry.get("Name") for entry in mod.get("ConVars", [])}
    for name in sorted(required_convars - convar_names):
        problems.append(f"mod.json is missing ConVar {name}")

    scripts = mod.get("Scripts", [])
    if len(scripts) != 5:
        problems.append(f"mod.json lists {len(scripts)} scripts, expected 5")
    for script in scripts:
        run_on = script.get("RunOn")
        if run_on not in ("UI", "CLIENT", "SERVER"):
            problems.append(f"script {script.get('Path')}: RunOn {run_on!r}, expected 'UI', 'CLIENT' or 'SERVER'")
        path = pkg / mod_dir / "mod/scripts/vscripts" / script.get("Path", "")
        if not path.is_file():
            problems.append(f"script file missing: {script.get('Path')}")
            continue
        text = read(path)
        callbacks = list((script.get("UICallback") or {}).values())
        callbacks += list((script.get("ClientCallback") or {}).values())
        callbacks += list((script.get("ServerCallback") or {}).values())
        if not callbacks:
            problems.append(f"script {script.get('Path')} has no UI or server callback")
        for callback in callbacks:
            if f"function {callback}" not in text:
                problems.append(f"script {script.get('Path')} does not define {callback}")

    menu_files = [f"tf2vrbb_{page}.menu" for page in menu_pages]
    menu_files += [f"tf2vrsb_{page}.menu" for page in sandbox_pages]
    for menu_file in menu_files:
        path = pkg / mod_dir / "mod/resource/ui/menus" / menu_file
        if path.is_file():
            text = read(path)
            if text.count("{") != text.count("}"):
                problems.append(f"{path.name}: unbalanced braces")

    nut = read(pkg / mod_dir / "mod/scripts/vscripts/ui/tf2vrbb_menu.nut")
    if nut.count("{") != nut.count("}"):
        problems.append("tf2vrbb_menu.nut: unbalanced braces")
    if "AddMenuFooterOption(" not in nut:
        problems.append("tf2vrbb_menu.nut: no AddMenuFooterOption call")

    sandbox_nut = read(pkg / mod_dir / "mod/scripts/vscripts/ui/tf2vrsb_menu.nut")
    if sandbox_nut.count("{") != sandbox_nut.count("}"):
        problems.append("tf2vrsb_menu.nut: unbalanced braces")
    for required in ("InGameSPMenu", "AddMenuFooterOption(", "RunClientScript(", "NSSaveFile(", "NSLoadFile("):
        if required not in sandbox_nut:
            problems.append(f"tf2vrsb_menu.nut: missing {required}")

    client_nut = read(pkg / mod_dir / "mod/scripts/vscripts/tf2vrsb_client.nut")
    if client_nut.count("{") != client_nut.count("}"):
        problems.append("tf2vrsb_client.nut: unbalanced braces")
    for required in ("GetLocalClientPlayer(", "ClientCommand("):
        if required not in client_nut:
            problems.append(f"tf2vrsb_client.nut: missing {required}")

    server_nut = read(pkg / mod_dir / "mod/scripts/vscripts/tf2vrsb_server.nut")
    if server_nut.count("{") != server_nut.count("}"):
        problems.append("tf2vrsb_server.nut: unbalanced braces")
    for required in ("AddClientCommandCallback(", "CreateNPC(", "Destroy()", "SetOrigin("):
        if required not in server_nut:
            problems.append(f"tf2vrsb_server.nut: missing {required}")

    ini = {}
    section = None
    for line in read(pkg / "plugins/layer/TF2VRBetterBindings.ini").splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            ini[section] = {}
        elif "=" in line and section is not None:
            key, value = line.split("=", 1)
            ini[section][key.strip()] = value.strip()
    for (section_name, key), value in ini_expected.items():
        actual_value = ini.get(section_name, {}).get(key)
        if actual_value != value:
            problems.append(f"ini [{section_name}] {key} = {actual_value!r}, expected {value!r}")

    manifest = json.loads(read(pkg / "plugins/layer/XR_APILAYER_NIGHTEYES_tf2vr_better_bindings.json"))
    library = manifest.get("api_layer", {}).get("library_path", "")
    library_name = library.replace("\\", "/").split("/")[-1]
    if library_name != "TF2VRBetterBindingsLayer.dll":
        problems.append(f"manifest library_path {library!r} does not point at the layer DLL")
    elif not (pkg / "plugins/layer" / library_name).is_file():
        problems.append("manifest points at a layer DLL that is not in the package")

    readme = read(pkg / "README.md")
    for heading in ("## Settings menu", "## Campaign sandbox (experimental)", "### Building on Linux"):
        if heading not in readme:
            problems.append(f"README.md is missing {heading!r}")

if not zip_path.is_file():
    problems.append(f"zip missing: {zip_path}")
else:
    with zipfile.ZipFile(zip_path) as archive:
        names = set(archive.namelist())
    for rel in expected:
        if f"{pkg.name}/{rel}" not in names:
            problems.append(f"zip is missing {rel}")

if problems:
    print(f"FAIL: {len(problems)} problem(s) in the package", file=sys.stderr)
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)
    sys.exit(1)

print(f"verified {len(expected)} files: both DLLs x64, mod.json {version} with "
      f"{len(required_convars)} ConVars, 5 UI/CLIENT/SERVER scripts and 12 menu resources, "
      f"ini and manifest consistent, zip complete")
PY

echo
python3 "$root/scripts/verify-sandbox.py" "$package_dir"

echo
echo "package: $package_dir"
echo "zip:     $zip_path"

if [ -n "$install_dir" ]; then
    if [ ! -d "$install_dir" ]; then
        echo "error: install directory does not exist: $install_dir" >&2
        exit 1
    fi
    destination="$install_dir/$package_name"
    mkdir -p "$destination"
    kept_ini=""
    if [ -f "$destination/plugins/layer/TF2VRBetterBindings.ini" ]; then
        kept_ini="$(mktemp)"
        cp "$destination/plugins/layer/TF2VRBetterBindings.ini" "$kept_ini"
    fi
    kept_calibration=""
    if [ -f "$destination/plugins/layer/TF2VRBetterBindings.calibration.ini" ]; then
        kept_calibration="$(mktemp)"
        cp "$destination/plugins/layer/TF2VRBetterBindings.calibration.ini" "$kept_calibration"
    fi
    cp -a "$package_dir/." "$destination/"
    if [ -n "$kept_ini" ]; then
        cp "$kept_ini" "$destination/plugins/layer/TF2VRBetterBindings.ini"
        rm -f "$kept_ini"
        echo "kept the existing TF2VRBetterBindings.ini"
    fi
    if [ -n "$kept_calibration" ]; then
        cp "$kept_calibration" "$destination/plugins/layer/TF2VRBetterBindings.calibration.ini"
        rm -f "$kept_calibration"
        echo "kept the existing TF2VRBetterBindings.calibration.ini"
    fi
    echo "installed: $destination"
    shopt -s nullglob
    for other in "$install_dir"/Nighteyes-TF2VRBetterBindings-*; do
        if [ "$other" != "$destination" ]; then
            echo "note: another copy is installed at $other - remove it so only one package loads"
        fi
    done
    shopt -u nullglob
fi

echo
echo "next: start the game, quit, and start it again so the plugin registers the layer"
