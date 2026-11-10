#include "CalibrationPersist.h"

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string>

#include <psapi.h>

// Titanfall2VR.dll is closed source, but its startup calibration stores the
// results in a fixed state block. These RVAs are for the current DLL and are
// checked against the DLL's SizeOfImage before anything is written.
//
// 0x4ac1fc  float   calibrated standing height
// 0x4ac20c  double  calibrated standing Y
// 0x4ac214  int     calibrated arm span
// 0x4ac1d2  bool    height / standing calibration valid
// 0x4ac208  bool    calibration complete
// 0x45d618  struct  startup phase state (phase is the first int; 5 = done)

namespace tf2vrbb
{
namespace
{
constexpr uintptr_t kHeightRva = 0x4AC1FC;
constexpr uintptr_t kStandingYRva = 0x4AC20C;
constexpr uintptr_t kArmSpanRva = 0x4AC214;
constexpr uintptr_t kCalibratedRva = 0x4AC208;
constexpr uintptr_t kHeightValidRva = 0x4AC1D2;
constexpr uintptr_t kStartupPhaseRva = 0x45D618;
constexpr uintptr_t kStartupElapsedRva = kStartupPhaseRva + 0x18;

constexpr DWORD kNativeLookupIntervalMs = 500;
constexpr int kStableFramesNeeded = 60;

constexpr const wchar_t* kSection = L"calibration";
constexpr const wchar_t* kConfigFileName = L"TF2VRBetterBindings.calibration.ini";
constexpr const wchar_t* kLayerFolder = L"layer";

struct State
{
    std::wstring path;
    CalibrationLogFn log = nullptr;
    HMODULE native = nullptr;
    size_t nativeSize = 0;

    bool saved = false;
    bool restorable = false;
    bool restoredThisLaunch = false;
    bool saveDone = false;
    unsigned long long savedNativeSize = 0;
    double height = 0.0;
    double standingY = 0.0;
    int armSpan = 0;

    ULONGLONG nextNativeLookup = 0;
    ULONGLONG nextDiagnostic = 0;
    bool loggedZeroCalibration = false;
    int stableFrames = 0;
};

State g_state;

void Log(int level, const char* format, ...)
{
    if (!g_state.log)
        return;
    char buffer[512] = {};
    va_list args;
    va_start(args, format);
    std::vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    g_state.log(level, buffer);
}

std::wstring ModuleDirectory(HMODULE module)
{
    wchar_t path[MAX_PATH] = {};
    if (!GetModuleFileNameW(module, path, MAX_PATH))
        return {};
    std::wstring result = path;
    size_t slash = result.find_last_of(L"\\/");
    return slash == std::wstring::npos ? std::wstring() : result.substr(0, slash);
}

std::wstring ReadString(const wchar_t* key, const wchar_t* fallback)
{
    wchar_t buffer[128] = {};
    GetPrivateProfileStringW(kSection, key, fallback, buffer,
                             static_cast<DWORD>(sizeof(buffer) / sizeof(buffer[0])), g_state.path.c_str());
    return buffer;
}

bool ParseNumber(const wchar_t* text, double& value)
{
    if (!text || !*text)
        return false;
    wchar_t* end = nullptr;
    value = std::wcstod(text, &end);
    return end && *end == L'\0';
}

bool ParseInteger(const wchar_t* text, unsigned long long& value)
{
    if (!text || !*text)
        return false;
    wchar_t* end = nullptr;
    value = std::wcstoull(text, &end, 10);
    return end && *end == L'\0';
}

void LoadSavedCalibration()
{
    if (GetFileAttributesW(g_state.path.c_str()) == INVALID_FILE_ATTRIBUTES)
        return;

    int version = GetPrivateProfileIntW(kSection, L"version", 0, g_state.path.c_str());
    int enabled = GetPrivateProfileIntW(kSection, L"enabled", 1, g_state.path.c_str());
    int saved = GetPrivateProfileIntW(kSection, L"saved", 0, g_state.path.c_str());
    if (version != 1 || enabled == 0 || saved != 1)
    {
        Log(1, "calibration file is present but not usable (version=%d enabled=%d saved=%d)", version, enabled, saved);
        return;
    }

    unsigned long long nativeSize = 0;
    double height = 0.0;
    double standingY = 0.0;
    unsigned long long armSpan = 0;
    if (!ParseInteger(ReadString(L"native_size", L"0").c_str(), nativeSize) ||
        !ParseNumber(ReadString(L"height", L"0").c_str(), height) ||
        !ParseNumber(ReadString(L"standing_y", L"0").c_str(), standingY) ||
        !ParseInteger(ReadString(L"arm_span", L"0").c_str(), armSpan) ||
        nativeSize == 0 || height < 0.3 || height > 3.0 || standingY < 0.3 || standingY > 3.0 ||
        armSpan == 0 || armSpan > 10000)
    {
        Log(1, "calibration file has invalid values; ignoring it");
        return;
    }

    g_state.saved = true;
    g_state.savedNativeSize = nativeSize;
    g_state.height = height;
    g_state.standingY = standingY;
    g_state.armSpan = static_cast<int>(armSpan);
    Log(0, "saved calibration loaded: height=%.3f standing_y=%.3f arm_span=%d", height, standingY, g_state.armSpan);
}

bool AcceptNativeModule(HMODULE module)
{
    if (!module)
        return false;
    if (g_state.native)
        return true;

    auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(module);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE)
        return false;
    auto nt = reinterpret_cast<const IMAGE_NT_HEADERS64*>(
        reinterpret_cast<const unsigned char*>(module) + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE || nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC)
        return false;

    size_t size = nt->OptionalHeader.SizeOfImage;
    if (size <= kStartupPhaseRva + 0x80)
        return false;

    g_state.native = module;
    g_state.nativeSize = size;
    Log(0, "Titanfall2VR.dll found (base=%p, image=%zu bytes)", static_cast<void*>(module), size);

    if (g_state.saved && g_state.savedNativeSize != 0 && g_state.savedNativeSize != size)
    {
        Log(1, "saved calibration belongs to a different Titanfall2VR.dll (saved image %llu, current %zu); ignoring it",
            g_state.savedNativeSize, size);
        g_state.saved = false;
    }
    if (g_state.saved)
        g_state.restorable = true;
    return true;
}

bool FindNative()
{
    if (g_state.native)
        return true;

    if (AcceptNativeModule(GetModuleHandleW(L"Titanfall2VR.dll")))
        return true;

    // Fallback for Wine and for modules the plugin loader opened under a
    // different name. Enumerate the process modules and match the base name.
    HMODULE modules[1024] = {};
    DWORD needed = 0;
    if (EnumProcessModules(GetCurrentProcess(), modules, static_cast<DWORD>(sizeof(modules)), &needed))
    {
        DWORD count = needed / sizeof(HMODULE);
        if (count > 1024)
            count = 1024;
        for (DWORD i = 0; i < count; ++i)
        {
            wchar_t name[MAX_PATH] = {};
            if (GetModuleBaseNameW(GetCurrentProcess(), modules[i], name, MAX_PATH) &&
                _wcsicmp(name, L"Titanfall2VR.dll") == 0)
                return AcceptNativeModule(modules[i]);
        }
    }
    return false;
}

template <typename T>
T ReadRva(uintptr_t rva)
{
    T value{};
    std::memcpy(&value, reinterpret_cast<const unsigned char*>(g_state.native) + rva, sizeof(T));
    return value;
}

template <typename T>
void WriteRva(uintptr_t rva, T value)
{
    std::memcpy(reinterpret_cast<unsigned char*>(g_state.native) + rva, &value, sizeof(T));
}

void ApplyCalibration()
{
    WriteRva<float>(kHeightRva, static_cast<float>(g_state.height));
    WriteRva<double>(kStandingYRva, g_state.standingY);
    WriteRva<int32_t>(kArmSpanRva, g_state.armSpan);
    WriteRva<uint8_t>(kHeightValidRva, 1);
    WriteRva<uint8_t>(kCalibratedRva, 1);
}

void ApplyStartupSkip()
{
    WriteRva<int32_t>(kStartupPhaseRva, 5);
    WriteRva<int32_t>(kStartupElapsedRva, 0);
}

bool SaveCalibration()
{
    std::wstring temp = g_state.path + L".tmp";
    DeleteFileW(temp.c_str());

    wchar_t nativeSize[32] = {};
    wchar_t height[64] = {};
    wchar_t standingY[64] = {};
    wchar_t armSpan[32] = {};
    std::swprintf(nativeSize, 32, L"%llu", g_state.nativeSize);
    std::swprintf(height, 64, L"%.6f", g_state.height);
    std::swprintf(standingY, 64, L"%.6f", g_state.standingY);
    std::swprintf(armSpan, 32, L"%d", g_state.armSpan);

    bool ok = WritePrivateProfileStringW(kSection, L"version", L"1", temp.c_str()) &&
              WritePrivateProfileStringW(kSection, L"enabled", L"1", temp.c_str()) &&
              WritePrivateProfileStringW(kSection, L"saved", L"1", temp.c_str()) &&
              WritePrivateProfileStringW(kSection, L"native_size", nativeSize, temp.c_str()) &&
              WritePrivateProfileStringW(kSection, L"height", height, temp.c_str()) &&
              WritePrivateProfileStringW(kSection, L"standing_y", standingY, temp.c_str()) &&
              WritePrivateProfileStringW(kSection, L"arm_span", armSpan, temp.c_str());
    if (!ok)
    {
        DeleteFileW(temp.c_str());
        Log(2, "could not write the calibration file");
        return false;
    }

    if (!MoveFileExW(temp.c_str(), g_state.path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
    {
        DeleteFileW(temp.c_str());
        Log(2, "could not replace the calibration file (Windows error %lu)", GetLastError());
        return false;
    }

    g_state.saved = true;
    g_state.restorable = true;
    g_state.restoredThisLaunch = true;
    g_state.savedNativeSize = g_state.nativeSize;
    g_state.saveDone = true;
    Log(0, "calibration saved: height=%.3f standing_y=%.3f arm_span=%d", g_state.height, g_state.standingY, g_state.armSpan);
    return true;
}

void MaybeSaveCalibration()
{
    if (g_state.saveDone || (g_state.saved && g_state.restorable))
        return;

    int phase = ReadRva<int32_t>(kStartupPhaseRva);
    bool calibrated = ReadRva<uint8_t>(kCalibratedRva) != 0;
    bool heightValid = ReadRva<uint8_t>(kHeightValidRva) != 0;
    float height = ReadRva<float>(kHeightRva);
    double standingY = ReadRva<double>(kStandingYRva);
    int32_t armSpan = ReadRva<int32_t>(kArmSpanRva);

    bool valid = phase == 5 && (calibrated || heightValid) && height >= 0.3f && height <= 3.0f &&
                 standingY >= 0.3 && standingY <= 3.0 && armSpan > 0 && armSpan <= 10000;
    if (!valid)
    {
        g_state.stableFrames = 0;
        return;
    }

    if (++g_state.stableFrames < kStableFramesNeeded)
        return;

    g_state.height = height;
    g_state.standingY = standingY;
    g_state.armSpan = armSpan;
    if (SaveCalibration())
        ApplyStartupSkip();
}
}

void CalibrationPersistInit(HMODULE pluginModule, CalibrationLogFn log)
{
    g_state.log = log;
    std::wstring directory = ModuleDirectory(pluginModule);
    if (directory.empty())
    {
        Log(1, "calibration persistence disabled: plugin folder is unavailable");
        return;
    }

    g_state.path = directory + L"\\" + kLayerFolder + L"\\" + kConfigFileName;
    LoadSavedCalibration();
    if (!g_state.saved)
        Log(0, "no saved calibration yet; the first completed calibration will be saved automatically");
}

void CalibrationPersistSetNativeModule(HMODULE module)
{
    AcceptNativeModule(module);
}

void CalibrationPersistFrame()
{
    if (g_state.path.empty())
        return;

    ULONGLONG now = GetTickCount64();
    if (!g_state.native)
    {
        if (now < g_state.nextNativeLookup)
            return;
        g_state.nextNativeLookup = now + kNativeLookupIntervalMs;
        if (!FindNative())
        {
            if (now >= g_state.nextDiagnostic)
            {
                g_state.nextDiagnostic = now + 5000;
                Log(1, "waiting for Titanfall2VR.dll (GetModuleHandle=%p)",
                    static_cast<void*>(GetModuleHandleW(L"Titanfall2VR.dll")));
            }
            return;
        }
    }

    if (g_state.restorable)
    {
        ApplyCalibration();
        ApplyStartupSkip();
        if (!g_state.restoredThisLaunch)
        {
            g_state.restoredThisLaunch = true;
            Log(0, "calibration restored; startup calibration is marked complete");
        }
    }
    else
    {
        MaybeSaveCalibration();
    }

    if (!g_state.saved && now >= g_state.nextDiagnostic)
    {
        g_state.nextDiagnostic = now + 5000;
        int phase = ReadRva<int32_t>(kStartupPhaseRva);
        bool calibrated = ReadRva<uint8_t>(kCalibratedRva) != 0;
        bool heightValid = ReadRva<uint8_t>(kHeightValidRva) != 0;
        Log(0, "native phase=%d calibrated=%d height_valid=%d height=%.3f standing_y=%.3f arm_span=%d",
            phase, calibrated, heightValid, ReadRva<float>(kHeightRva), ReadRva<double>(kStandingYRva),
            ReadRva<int32_t>(kArmSpanRva));

        if (phase == 5 && !calibrated && !heightValid && ReadRva<float>(kHeightRva) == 0.0f &&
            ReadRva<double>(kStandingYRva) == 0.0 && ReadRva<int32_t>(kArmSpanRva) == 0 &&
            !g_state.loggedZeroCalibration)
        {
            g_state.loggedZeroCalibration = true;
            Log(0, "native phase 5 has zero calibration values; the calibration was skipped or never captured, so there is nothing valid to save yet");
        }
    }
}
}