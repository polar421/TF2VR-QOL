#include "SettingsSync.h"

#include <cstring>
#include <cwchar>
#include <string>

// Mirrors the in-game menu's ConVars into the OpenXR layer's configuration
// file. The layer reads that file; the menu only ever writes ConVars, so the
// ini stays the single source of truth and no second settings store exists.

namespace tf2vrbb
{
namespace
{
using CreateInterfaceFn = void* (*)(const char* name, int* returnCode);
using FindVarFn = void* (*)(void* self, const char* name);

// Same layout the OpenXR layer already relies on for tf2vrbb_menu_active.
constexpr size_t kFindVarIndex = 16;
constexpr size_t kNameOffset = 0x18;
constexpr size_t kIntValueOffset = 0x5C;
constexpr ULONGLONG kRetryIntervalMs = 250;

constexpr const wchar_t* kConfigFileName = L"TF2VRBetterBindings.ini";
constexpr const wchar_t* kLayerFolder = L"layer";
constexpr const char* kApiVar = "tf2vrbb_settings_api";

enum class ValueKind
{
    Toggle,
    Number,
    CrouchMode,
    CrouchBinding,
};

struct Setting
{
    const char* conVar;
    const wchar_t* section;
    const wchar_t* key;
    ValueKind kind;
    int minimum;
    int maximum;
    int defaultValue;
};

const Setting kSettings[] = {
    {"tf2vrbb_reload_grab", L"reload_grab", L"enabled", ValueKind::Toggle, 0, 1, 1},
    {"tf2vrbb_grenade_toggle", L"grenade", L"toggle", ValueKind::Toggle, 0, 1, 0},
    {"tf2vrbb_crouch_enabled", L"crouch", L"enabled", ValueKind::Toggle, 0, 1, 1},
    {"tf2vrbb_crouch_button_mode", L"crouch", L"mode", ValueKind::CrouchMode, 0, 1, 0},
    {"tf2vrbb_crouch_binding", L"crouch", L"binding", ValueKind::CrouchBinding, 0, 3, 0},
    {"tf2vrbb_uncrouch_on_jump", L"crouch", L"uncrouch_on_jump", ValueKind::Toggle, 0, 1, 0},
    {"tf2vrbb_jump_delay_ms", L"crouch", L"jump_delay_ms", ValueKind::Number, 0, 1000, 250},
    {"tf2vrbb_tactical_enabled", L"tactical", L"enabled", ValueKind::Toggle, 0, 1, 1},
    {"tf2vrbb_tactical_block_trigger", L"tactical", L"block_hand_trigger_in_game", ValueKind::Toggle, 0, 1, 1},
    {"tf2vrbb_sprint_enabled", L"sprint", L"enabled", ValueKind::Toggle, 0, 1, 0},
    {"tf2vrbb_sprint_start_cm", L"sprint", L"start_below_eyes_cm", ValueKind::Number, 5, 150, 30},
    {"tf2vrbb_sprint_stop_cm", L"sprint", L"stop_below_eyes_cm", ValueKind::Number, 0, 145, 20},
};

constexpr size_t kSettingCount = sizeof(kSettings) / sizeof(kSettings[0]);

struct State
{
    std::wstring configPath;
    bool ready = false;
    void* cvarInterface = nullptr;
    FindVarFn findVar = nullptr;
    unsigned char* conVars[kSettingCount] = {};
    unsigned char* apiConVar = nullptr;
    int lastValue[kSettingCount] = {};
    ULONGLONG nextAttempt = 0;
};

State g_state;

std::wstring ModuleDirectory(HMODULE module)
{
    wchar_t path[MAX_PATH] = {};
    if (!GetModuleFileNameW(module, path, MAX_PATH))
        return {};
    std::wstring result = path;
    size_t slash = result.find_last_of(L"\\/");
    return slash == std::wstring::npos ? std::wstring() : result.substr(0, slash);
}

void* FindConVarRaw(const char* name)
{
    if (!g_state.findVar || !g_state.cvarInterface)
        return nullptr;
    void* conVar = g_state.findVar(g_state.cvarInterface, name);
    if (!conVar)
        return nullptr;
    const char* actual = *reinterpret_cast<const char* const*>(static_cast<unsigned char*>(conVar) + kNameOffset);
    if (!actual || std::strcmp(actual, name) != 0)
        return nullptr;
    return conVar;
}

bool ResolveInterfaces()
{
    if (g_state.cvarInterface && g_state.findVar)
        return true;

    HMODULE vstdlib = GetModuleHandleW(L"vstdlib.dll");
    if (!vstdlib)
        return false;

    auto createInterface = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(vstdlib, "CreateInterface"));
    if (!createInterface)
        return false;

    void* cvar = createInterface("VEngineCvar007", nullptr);
    if (!cvar)
        return false;

    g_state.cvarInterface = cvar;
    g_state.findVar = reinterpret_cast<FindVarFn>((*static_cast<void***>(cvar))[kFindVarIndex]);
    return g_state.findVar != nullptr;
}

int ReadIntVar(unsigned char* conVar)
{
    return *reinterpret_cast<const volatile int*>(conVar + kIntValueOffset);
}

void WriteIntVar(unsigned char* conVar, int value)
{
    *reinterpret_cast<volatile int*>(conVar + kIntValueOffset) = value;
}

int Clamp(const Setting& setting, int value)
{
    if (value < setting.minimum)
        return setting.minimum;
    if (value > setting.maximum)
        return setting.maximum;
    return value;
}

void WriteSetting(const Setting& setting, int value)
{
    std::wstring text;
    if (setting.kind == ValueKind::CrouchMode)
        text = value == 1 ? L"button" : L"toggle";
    else if (setting.kind == ValueKind::CrouchBinding)
        text = value == 1 ? L"left_thumbstick_click" : value == 2 ? L"right_thumbstick_click" : value == 3 ? L"both_thumbstick_click" : L"none";
    else
        text = std::to_wstring(value);

    WritePrivateProfileStringW(setting.section, setting.key, text.c_str(), g_state.configPath.c_str());
}

// Reads the ini once and pushes it into the ConVars so the menu shows the
// values the layer is actually running with.
void SeedFromConfig()
{
    for (size_t i = 0; i < kSettingCount; ++i)
    {
        const Setting& setting = kSettings[i];
        int value = static_cast<int>(GetPrivateProfileIntW(setting.section, setting.key, setting.defaultValue, g_state.configPath.c_str()));

        if (setting.kind == ValueKind::CrouchMode)
        {
            wchar_t buffer[32] = {};
            GetPrivateProfileStringW(setting.section, setting.key, L"toggle", buffer, static_cast<DWORD>(sizeof(buffer) / sizeof(buffer[0])),
                                     g_state.configPath.c_str());
            value = _wcsicmp(buffer, L"button") == 0 ? 1 : 0;
        }
        else if (setting.kind == ValueKind::CrouchBinding)
        {
            wchar_t buffer[64] = {};
            GetPrivateProfileStringW(setting.section, setting.key, L"none", buffer, static_cast<DWORD>(sizeof(buffer) / sizeof(buffer[0])),
                                     g_state.configPath.c_str());
            value = _wcsicmp(buffer, L"left_thumbstick_click") == 0 ? 1
                  : _wcsicmp(buffer, L"right_thumbstick_click") == 0 ? 2
                  : _wcsicmp(buffer, L"both_thumbstick_click") == 0 ? 3
                  : 0;
        }

        value = Clamp(setting, value);
        g_state.lastValue[i] = value;
        WriteIntVar(g_state.conVars[i], value);
    }

    if (g_state.apiConVar)
        WriteIntVar(g_state.apiConVar, 1);
}

bool TryResolveVars()
{
    if (!ResolveInterfaces())
        return false;

    unsigned char* conVars[kSettingCount] = {};
    for (size_t i = 0; i < kSettingCount; ++i)
    {
        void* conVar = FindConVarRaw(kSettings[i].conVar);
        if (!conVar)
            return false;
        conVars[i] = static_cast<unsigned char*>(conVar);
    }

    void* apiConVar = FindConVarRaw(kApiVar);
    if (!apiConVar)
        return false;

    for (size_t i = 0; i < kSettingCount; ++i)
        g_state.conVars[i] = conVars[i];
    g_state.apiConVar = static_cast<unsigned char*>(apiConVar);
    return true;
}
}

void SettingsSyncInit(HMODULE pluginModule)
{
    std::wstring directory = ModuleDirectory(pluginModule);
    if (directory.empty())
        return;

    g_state.configPath = directory + L"\\" + kLayerFolder + L"\\" + kConfigFileName;
}

void SettingsSyncFrame()
{
    if (g_state.configPath.empty())
        return;

    if (!g_state.ready)
    {
        ULONGLONG now = GetTickCount64();
        if (now < g_state.nextAttempt)
            return;
        g_state.nextAttempt = now + kRetryIntervalMs;

        if (!TryResolveVars())
            return;

        SeedFromConfig();
        g_state.ready = true;
        return;
    }

    for (size_t i = 0; i < kSettingCount; ++i)
    {
        const Setting& setting = kSettings[i];
        int value = ReadIntVar(g_state.conVars[i]);

        int clamped = Clamp(setting, value);
        if (clamped != value)
        {
            WriteIntVar(g_state.conVars[i], clamped);
            value = clamped;
        }

        if (value == g_state.lastValue[i])
            continue;

        g_state.lastValue[i] = value;
        WriteSetting(setting, value);
    }
}
}
