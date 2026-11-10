#include "Registration.h"
#include "SettingsSync.h"
#include "CalibrationPersist.h"

#include <windows.h>

#include <cctype>
#include <cstdint>
#include <cstring>
#include <string>

namespace
{
constexpr const wchar_t* kImplicitLayersKey = L"Software\\Khronos\\OpenXR\\1\\ApiLayers\\Implicit";
constexpr const wchar_t* kLayerFolder = L"\\layer\\";
constexpr const wchar_t* kManifestName = L"XR_APILAYER_NIGHTEYES_tf2vr_better_bindings.json";
constexpr int64_t kContextClient = 0x2;

enum PluginString : int
{
    Name = 0,
    LogName = 1,
    DependencyName = 2,
};

enum PluginField : int
{
    Context = 0,
    Color = 1,
};

enum LogLevel : int
{
    Info = 0,
    Warn = 1,
    Error = 2,
};

struct PluginNorthstarData
{
    HMODULE pluginHandle;
    uint64_t size;
};

// Northstar's interfaces are MSVC C++ classes, and other compilers give a
// different vtable layout. They are declared here as the plugin documentation
// describes them for non-C++ build tools: an instance that only holds a pointer
// to an array of function pointers, each taking the instance as its first
// argument. This is the same memory layout MSVC produces, without depending on
// the compiler's own virtual dispatch.
struct SysVTable
{
    void (*log)(void* self, HMODULE handle, int level, char* message);
    void (*unload)(void* self, HMODULE handle);
    void (*reload)(void* self, HMODULE handle);
};

struct SysObject
{
    SysVTable* vtable;
};

struct PluginIdVTable
{
    const char* (*getString)(void* self, int property);
    int64_t (*getField)(void* self, int property);
};

struct PluginIdObject
{
    PluginIdVTable* vtable;
};

struct PluginCallbacksVTable
{
    void (*init)(void* self, HMODULE northstarModule, const PluginNorthstarData* initData, bool reloaded);
    void (*finalize)(void* self);
    bool (*unload)(void* self);
    void (*onSqvmCreated)(void* self, void* sqvm);
    void (*onSqvmDestroying)(void* self, void* sqvm);
    void (*onLibraryLoaded)(void* self, HMODULE module, const char* name);
    void (*runFrame)(void* self);
};

struct PluginCallbacksObject
{
    PluginCallbacksVTable* vtable;
};

using CreateInterfaceFn = void* (*)(const char* name, int* status);

void* g_sys = nullptr;
bool g_loggedRunFrame = false;

void SysLog(int level, const std::string& message)
{
    if (!g_sys)
        return;
    SysObject* sys = static_cast<SysObject*>(g_sys);
    if (sys->vtable && sys->vtable->log)
        sys->vtable->log(sys, nullptr, level, const_cast<char*>(message.c_str()));
}

void CalibrationLog(int level, const char* message)
{
    if (!message)
        return;
    SysLog(level, std::string("calibration: ") + message);
}

std::string Narrow(const std::wstring& text)
{
    if (text.empty())
        return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
    std::string result(static_cast<size_t>(size), '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), result.data(), size, nullptr, nullptr);
    return result;
}

bool IsTitanfall2VRName(const char* name)
{
    if (!name)
        return false;
    std::string lower(name);
    for (char& character : lower)
        character = static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
    return lower.find("titanfall2vr") != std::string::npos;
}

bool RunningUnderWine()
{
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    return ntdll && GetProcAddress(ntdll, "wine_get_version") != nullptr;
}

std::wstring ModuleDirectory(HMODULE module)
{
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(module, path, MAX_PATH);
    std::wstring result = path;
    size_t slash = result.find_last_of(L"\\/");
    return slash == std::wstring::npos ? std::wstring() : result.substr(0, slash);
}

const char* PluginIdGetString(void*, int property)
{
    switch (property)
    {
    case Name: return "TF2VRBetterBindings";
    case LogName: return "TF2VRBB";
    case DependencyName: return "TF2VRBetterBindings";
    default: return nullptr;
    }
}

int64_t PluginIdGetField(void*, int property)
{
    return property == Context ? kContextClient : 0;
}

PluginIdVTable g_pluginIdVTable = {PluginIdGetString, PluginIdGetField};
PluginIdObject g_pluginId = {&g_pluginIdVTable};

void PluginInit(void*, HMODULE northstarModule, const PluginNorthstarData* initData, bool)
{
    auto createInterface = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(northstarModule, "CreateInterface"));
    if (createInterface)
        g_sys = createInterface("NSSys001", nullptr);

    tf2vrbb::SettingsSyncInit(initData ? initData->pluginHandle : nullptr);
    tf2vrbb::CalibrationPersistInit(initData ? initData->pluginHandle : nullptr, CalibrationLog);

    // Wine's OpenXR bridge forwards to the native Linux loader, which only
    // loads ELF API layers. A Windows layer DLL can never be negotiated here,
    // so registering it would only add a dead registry entry.
    if (RunningUnderWine())
    {
        SysLog(Warn, "Wine/Proton detected: the OpenXR bridge loads native Linux API layers only, so the binding layer is inactive. The settings menu works; the extra actions do not.");
        return;
    }

    std::wstring layerDirectory = ModuleDirectory(initData ? initData->pluginHandle : nullptr) + kLayerFolder;
    std::wstring manifest = layerDirectory + kManifestName;
    if (GetFileAttributesW(manifest.c_str()) == INVALID_FILE_ATTRIBUTES)
    {
        SysLog(Error, "OpenXR layer manifest missing: " + Narrow(manifest));
        return;
    }

    tf2vrbb::RegistrationReport report = tf2vrbb::RegisterImplicitLayer(HKEY_CURRENT_USER, kImplicitLayersKey, manifest);
    if (report.removedStale > 0)
        SysLog(Info, "removed " + std::to_string(report.removedStale) + " registration(s) of other copies of the layer");

    switch (report.result)
    {
    case tf2vrbb::RegistrationResult::Failed:
        SysLog(Error, "could not register the OpenXR layer under HKEY_CURRENT_USER");
        break;
    case tf2vrbb::RegistrationResult::DisabledByUser:
        SysLog(Info, "OpenXR layer is disabled in the registry (value is not 0); leaving it disabled");
        break;
    case tf2vrbb::RegistrationResult::Registered:
        SysLog(Warn, "OpenXR layer registered for this Windows user. Restart the game once to activate TF2VR Better Bindings.");
        break;
    case tf2vrbb::RegistrationResult::AlreadyRegistered:
        SysLog(Info, "OpenXR layer registered");
        break;
    }
}

void PluginFinalize(void*) {}

bool PluginUnload(void*)
{
    return true;
}

void PluginOnSqvmCreated(void*, void*) {}

void PluginOnSqvmDestroying(void*, void*) {}

void PluginOnLibraryLoaded(void*, HMODULE module, const char* name)
{
    if (IsTitanfall2VRName(name))
        tf2vrbb::CalibrationPersistSetNativeModule(module);
}

void PluginRunFrame(void*)
{
    if (!g_loggedRunFrame)
    {
        g_loggedRunFrame = true;
        SysLog(Info, "run frame callback active");
    }
    tf2vrbb::SettingsSyncFrame();
    tf2vrbb::CalibrationPersistFrame();
}

PluginCallbacksVTable g_pluginCallbacksVTable = {
    PluginInit,
    PluginFinalize,
    PluginUnload,
    PluginOnSqvmCreated,
    PluginOnSqvmDestroying,
    PluginOnLibraryLoaded,
    PluginRunFrame,
};

PluginCallbacksObject g_pluginCallbacks = {&g_pluginCallbacksVTable};
}

extern "C" __declspec(dllexport) void* CreateInterface(const char* name, int* status)
{
    void* result = nullptr;
    if (name && std::strcmp(name, "PluginId001") == 0)
        result = &g_pluginId;
    else if (name && std::strcmp(name, "PluginCallbacks001") == 0)
        result = &g_pluginCallbacks;
    if (status)
        *status = result ? 0 : 1;
    return result;
}
