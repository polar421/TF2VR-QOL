#include "Config.h"
#include "Engine.h"
#include "GameVar.h"
#include "Log.h"

#include <windows.h>

#include <openxr/openxr.h>
#include <openxr/openxr_loader_negotiation.h>

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

namespace tf2vr
{
namespace
{
constexpr const wchar_t* kConfigFileName = L"TF2VRBetterBindings.ini";
constexpr const wchar_t* kLogFileName = L"TF2VRBetterBindings.log";
constexpr const char* kMenuActiveVar = "tf2vrbb_menu_active";
constexpr const char* kStartupPhaseVar = "tf2vrbb_startup_phase";
constexpr const char* kReloadHighlightVar = "tf2vr_reload_highlight";
constexpr const char* kGunAckVar = "tf2vr_gun_ack";
constexpr const char* kGrenadeAckVar = "tf2vr_grenade_ack";
constexpr const char* kGunGripToggleVar = "tf2vr_toggle_grip";
constexpr float kHeldThreshold = 0.5f;
constexpr const char* kGameplaySetName = "gameplay";
constexpr const char* kSqueezeActionName = "squeeze";
constexpr const char* kTriggerActionName = "trigger";
constexpr const char* kAimActionName = "aim";
constexpr const char* kStickClickActionName = "stick_click";
constexpr const char* kStickActionName = "stick";
constexpr const char* kJumpActionName = "primary";
constexpr uint64_t kSprintStopGapFrames = 2;
constexpr uint64_t kJumpPulseFrames = 6;
constexpr uint64_t kSprintPulseFrames = 8;
constexpr uint64_t kPitchLogFrames = 90;
constexpr const char* kCrouchActionName = "tf2vr_crouch";
constexpr const char* kCrouchLocalizedName = "Crouch";
constexpr const char* kTacticalActionName = "tf2vr_tactical";
constexpr const char* kTacticalLocalizedName = "Tactical Ability (Cloak)";
constexpr const char* kReloadGrabActionName = "tf2vr_reload_grab";
constexpr const char* kReloadGrabLocalizedName = "Reload Grab";
constexpr std::chrono::milliseconds kGunGrabWindow{500};
constexpr std::chrono::milliseconds kReloadEndGrace{200};
constexpr std::chrono::milliseconds kGrenadeMinPress{150};
constexpr int kMaxLoggedQueries = 8;
constexpr int kDiagIntervalFrames = 6;
constexpr int kDiagProfileIntervalFrames = 45;
constexpr int kDiagPoseStaleFrames = 90;
constexpr int kProfileOther = 99;

struct NextFunctions
{
    PFN_xrGetInstanceProcAddr getInstanceProcAddr = nullptr;
    PFN_xrDestroyInstance destroyInstance = nullptr;
    PFN_xrStringToPath stringToPath = nullptr;
    PFN_xrPathToString pathToString = nullptr;
    PFN_xrCreateActionSet createActionSet = nullptr;
    PFN_xrCreateAction createAction = nullptr;
    PFN_xrSuggestInteractionProfileBindings suggestInteractionProfileBindings = nullptr;
    PFN_xrSyncActions syncActions = nullptr;
    PFN_xrGetActionStateFloat getActionStateFloat = nullptr;
    PFN_xrGetActionStateBoolean getActionStateBoolean = nullptr;
    PFN_xrGetActionStateVector2f getActionStateVector2f = nullptr;
    PFN_xrCreateReferenceSpace createReferenceSpace = nullptr;
    PFN_xrCreateActionSpace createActionSpace = nullptr;
    PFN_xrLocateSpace locateSpace = nullptr;
    PFN_xrLocateSpaces locateSpaces = nullptr;
    PFN_xrLocateViews locateViews = nullptr;
    PFN_xrGetInstanceProperties getInstanceProperties = nullptr;
    PFN_xrGetCurrentInteractionProfile getCurrentInteractionProfile = nullptr;
};

struct AimSpace
{
    XrSpace space = XR_NULL_HANDLE;
    XrPath hand = XR_NULL_PATH;
};

struct SprintState
{
    bool lowered = false;
    bool pressed = false;
    uint64_t pulseEnd = 0;
    uint64_t stopStart = 0;
    uint64_t stopEnd = 0;
    bool stickZeroed = false;
    bool stickChanged = false;
    bool output = false;
    bool changed = false;
    XrTime changeTime = 0;
};

struct GripSlot
{
    XrPath path = XR_NULL_PATH;
    const char* name = "";
    bool sampled = false;
    bool routed = false;
    float output = 0.0f;
    bool changed = false;
    XrTime changeTime = 0;
    bool held = false;
    std::chrono::steady_clock::time_point heldAt;
    bool grabBound = false;
    bool rawPressed = false;
    std::chrono::steady_clock::time_point pressAt;
    bool grenadeHeld = false;
    bool waitRelease = false;
    bool rawActive = false;
    float raw = 0.0f;
};

struct ButtonState
{
    bool active = false;
    bool pressed = false;
    bool changed = false;
    XrTime changeTime = 0;
};

struct HandPoseState
{
    bool seen = false;
    uint64_t frame = 0;
    XrTime time = 0;
    XrSpaceLocationFlags flags = 0;
};

struct CrouchState
{
    bool jumpPressed = false;
    bool toggled = false;
    bool released = false;
    bool ducked = false;
    bool jumpPending = false;
    std::chrono::steady_clock::time_point jumpReleaseAt;
    uint64_t jumpPulseEnd = 0;
    bool jumpOverride = false;
    bool jumpOutput = false;
    bool jumpChanged = false;
};

struct TriggerOverride
{
    bool applies = false;
    bool blocked = false;
    bool reloadBlocked = false;
    bool waitRelease = false;
    float output = 0.0f;
    bool changed = false;
    XrTime changeTime = 0;
};

struct LayerState
{
    std::mutex mutex;
    bool active = false;
    std::wstring directory;
    std::wstring configPath;
    FILETIME configWriteTime{};
    DWORD configSize = 0;
    ULONGLONG nextConfigCheck = 0;
    Config config;
    NextFunctions next;
    XrInstance instance = XR_NULL_HANDLE;
    XrPath leftHand = XR_NULL_PATH;
    XrPath rightHand = XR_NULL_PATH;
    XrPath tacticalHand = XR_NULL_PATH;
    XrAction squeeze = XR_NULL_HANDLE;
    XrAction aim = XR_NULL_HANDLE;
    XrAction stickClick = XR_NULL_HANDLE;
    XrAction stick = XR_NULL_HANDLE;
    XrPath sprintHand = XR_NULL_PATH;
    std::vector<AimSpace> aimSpaces;
    std::vector<std::pair<XrSpace, XrReferenceSpaceType>> referenceSpaces;
    bool gunPoseValid = false;
    float gunPitch = 0.0f;
    float gunHeight = 0.0f;
    XrSpace gunPoseBase = XR_NULL_HANDLE;
    XrTime gunPoseTime = 0;
    bool headValid = false;
    float headHeight = 0.0f;
    XrSpace headBase = XR_NULL_HANDLE;
    XrTime headTime = 0;
    HandPoseState leftPose;
    HandPoseState rightPose;
    int runtimeKind = 0;
    XrVersion runtimeVersion = 0;
    XrVersion appApiVersion = 0;
    int profileLeft = 0;
    int profileRight = 0;
    uint64_t gunPoseLoggedFrame = 0;
    bool loggedBaseMismatch = false;
    bool loggedAimLocate = false;
    SprintState sprint;
    XrAction trigger = XR_NULL_HANDLE;
    XrAction reloadGrab = XR_NULL_HANDLE;
    XrAction crouch = XR_NULL_HANDLE;
    XrAction tactical = XR_NULL_HANDLE;
    bool wine = false;
    std::vector<XrPath> suggestedProfiles;
    std::vector<GripSlot> grips;
    ButtonState crouchButton;
    CrouchState crouchState;
    XrAction jump = XR_NULL_HANDLE;
    XrPath jumpHand = XR_NULL_PATH;
    ButtonState tacticalButton;
    TriggerOverride triggerOverride;
    GameVar menuActiveVar{kMenuActiveVar};
    GameVar startupPhaseVar{kStartupPhaseVar};
    GameVar reloadHighlightVar{kReloadHighlightVar};
    GameVar gunAckVar{kGunAckVar};
    GameVar grenadeAckVar{kGrenadeAckVar};
    GameVar gunGripToggleVar{kGunGripToggleVar};
    int menuState = -2;
    int startupPhase = -2;
    int reloadHighlight = 0;
    bool reloadWaiting = false;
    std::chrono::steady_clock::time_point reloadSeenAt;
    bool gunAckKnown = false;
    int gunAck = 0;
    bool grenadeAckKnown = false;
    int grenadeAck = 0;
    bool grenadeToggleActive = false;
    XrPath gunHand = XR_NULL_PATH;
    uint64_t frame = 0;
    int loggedSqueezeQueries = 0;
    int loggedBooleanQueries = 0;
    int loggedStickQueries = 0;
    bool loggedFirstSync = false;
    GameVar diagEnabledVar{"tf2vrbb_diag_enabled"};
    GameVar diagApiVar{"tf2vrbb_diag_api"};
    GameVar diagSeqVar{"tf2vrbb_diag_seq"};
    GameVar diagRuntimeKindVar{"tf2vrbb_diag_runtime_kind"};
    GameVar diagRuntimeVersionVar{"tf2vrbb_diag_runtime_version"};
    GameVar diagApiVersionVar{"tf2vrbb_diag_api_version"};
    GameVar diagProfileLeftVar{"tf2vrbb_diag_profile_left"};
    GameVar diagProfileRightVar{"tf2vrbb_diag_profile_right"};
    GameVar diagTrackingLeftVar{"tf2vrbb_diag_tracking_left"};
    GameVar diagTrackingRightVar{"tf2vrbb_diag_tracking_right"};
    GameVar diagTriggerLeftVar{"tf2vrbb_diag_trigger_left"};
    GameVar diagTriggerRightVar{"tf2vrbb_diag_trigger_right"};
    GameVar diagTriggerLeftActiveVar{"tf2vrbb_diag_trigger_left_active"};
    GameVar diagTriggerRightActiveVar{"tf2vrbb_diag_trigger_right_active"};
    GameVar diagGripLeftVar{"tf2vrbb_diag_grip_left"};
    GameVar diagGripRightVar{"tf2vrbb_diag_grip_right"};
    GameVar diagGripLeftActiveVar{"tf2vrbb_diag_grip_left_active"};
    GameVar diagGripRightActiveVar{"tf2vrbb_diag_grip_right_active"};
    GameVar diagStickLeftXVar{"tf2vrbb_diag_stick_left_x"};
    GameVar diagStickLeftYVar{"tf2vrbb_diag_stick_left_y"};
    GameVar diagStickLeftActiveVar{"tf2vrbb_diag_stick_left_active"};
    GameVar diagStickRightXVar{"tf2vrbb_diag_stick_right_x"};
    GameVar diagStickRightYVar{"tf2vrbb_diag_stick_right_y"};
    GameVar diagStickRightActiveVar{"tf2vrbb_diag_stick_right_active"};
    GameVar diagStickClickLeftVar{"tf2vrbb_diag_stick_click_left"};
    GameVar diagStickClickRightVar{"tf2vrbb_diag_stick_click_right"};
    GameVar diagPrimaryVar{"tf2vrbb_diag_primary"};
    GameVar diagCrouchVar{"tf2vrbb_diag_crouch"};
    GameVar diagTacticalVar{"tf2vrbb_diag_tactical"};
    GameVar diagReloadLeftVar{"tf2vrbb_diag_reload_left"};
    GameVar diagReloadRightVar{"tf2vrbb_diag_reload_right"};
    int diagSeq = 0;
};

LayerState& State()
{
    static LayerState state;
    return state;
}

std::wstring ModuleDirectory()
{
    HMODULE module = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(&State), &module);
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(module, path, MAX_PATH);
    std::wstring result = path;
    size_t slash = result.find_last_of(L"\\/");
    return slash == std::wstring::npos ? std::wstring() : result.substr(0, slash);
}

std::wstring ProcessFileName()
{
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    std::wstring result = path;
    size_t slash = result.find_last_of(L"\\/");
    return slash == std::wstring::npos ? result : result.substr(slash + 1);
}

std::string NarrowPath(const std::wstring& text)
{
    std::string result;
    for (wchar_t c : text)
        result += c < 128 ? static_cast<char>(c) : '?';
    return result;
}

void InitializeOnce()
{
    static std::once_flag once;
    std::call_once(once, [] {
        LayerState& s = State();
        s.directory = ModuleDirectory();
        s.configPath = s.directory + L"\\" + kConfigFileName;
        s.config = LoadConfig(s.configPath);
        WIN32_FILE_ATTRIBUTE_DATA attributes{};
        if (GetFileAttributesExW(s.configPath.c_str(), GetFileExInfoStandard, &attributes))
        {
            s.configWriteTime = attributes.ftLastWriteTime;
            s.configSize = attributes.nFileSizeLow;
        }
        std::wstring process = ProcessFileName();
        HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        s.wine = ntdll && GetProcAddress(ntdll, "wine_get_version") != nullptr;
        s.active = _wcsicmp(process.c_str(), s.config.targetProcess.c_str()) == 0;
        if (!s.active)
            return;

        LogOpen(s.directory + L"\\" + kLogFileName);
        Log("layer active in %s (wine=%d)", NarrowPath(process).c_str(), s.wine);
        Log("config: reload_grab=%d grenade_toggle=%d", s.config.reloadGrabEnabled, s.config.grenadeToggle);
        Log("config: crouch=%d press_cmd='%s' release_cmd='%s'", s.config.crouchEnabled, s.config.crouchPressCommand.c_str(),
            s.config.crouchReleaseCommand.c_str());
        Log("config: crouch mode=%s binding=%s uncrouch_on_jump=%d jump_delay_ms=%d", s.config.crouchMode.c_str(), s.config.crouchBinding.c_str(),
            s.config.crouchUncrouchOnJump, s.config.crouchJumpDelayMs);
        Log("config: tactical=%d hand=%s block_in_game=%d press_cmd='%s' release_cmd='%s'", s.config.tacticalEnabled, s.config.tacticalHand.c_str(),
            s.config.tacticalBlockHandTrigger, s.config.tacticalPressCommand.c_str(), s.config.tacticalReleaseCommand.c_str());
        Log("config: sprint=%d hand=%s start_below_eyes_cm=%d stop_below_eyes_cm=%d mode=%s stop_method=%s stop_frames=%d", s.config.sprintEnabled,
            s.config.sprintHand.c_str(), s.config.sprintStartBelowEyesCm, s.config.sprintStopBelowEyesCm, s.config.sprintMode.c_str(),
            s.config.sprintStopMethod.c_str(), s.config.sprintStopFrames);
    });
}

// Picks up settings that the in-game menu wrote while the game is running.
// Action on/off flags only take effect at startup because the actions are
// created with the instance; behaviour values are used every frame.
bool ReloadConfigIfChanged(LayerState& s)
{
    ULONGLONG now = GetTickCount64();
    if (now < s.nextConfigCheck)
        return false;
    s.nextConfigCheck = now + 1000;

    WIN32_FILE_ATTRIBUTE_DATA attributes{};
    if (!GetFileAttributesExW(s.configPath.c_str(), GetFileExInfoStandard, &attributes))
        return false;
    if (CompareFileTime(&attributes.ftLastWriteTime, &s.configWriteTime) == 0 && attributes.nFileSizeLow == s.configSize)
        return false;

    s.configWriteTime = attributes.ftLastWriteTime;
    s.configSize = attributes.nFileSizeLow;
    Config reloaded = LoadConfig(s.configPath);
    reloaded.targetProcess = s.config.targetProcess;
    s.config = reloaded;
    Log("config reloaded from disk");
    return true;
}

template <typename T>
bool ResolveNext(LayerState& s, const char* name, T& function)
{
    PFN_xrVoidFunction pointer = nullptr;
    if (XR_FAILED(s.next.getInstanceProcAddr(s.instance, name, &pointer)) || !pointer)
    {
        Log("next layer is missing %s", name);
        return false;
    }
    function = reinterpret_cast<T>(pointer);
    return true;
}

XrPath ToPath(LayerState& s, const char* text)
{
    XrPath path = XR_NULL_PATH;
    if (XR_FAILED(s.next.stringToPath(s.instance, text, &path)))
    {
        Log("xrStringToPath failed for %s", text);
        return XR_NULL_PATH;
    }
    return path;
}

std::string PathText(LayerState& s, XrPath path)
{
    if (path == XR_NULL_PATH)
        return "(null)";
    char buffer[XR_MAX_PATH_LENGTH] = {};
    uint32_t length = 0;
    if (XR_FAILED(s.next.pathToString(s.instance, path, XR_MAX_PATH_LENGTH, &length, buffer)))
        return "(invalid)";
    return buffer;
}

int EncodeVersion(XrVersion version)
{
    if (version == 0)
        return 0;
    uint32_t patch = std::min<uint32_t>(XR_VERSION_PATCH(version), 99);
    return static_cast<int>(XR_VERSION_MAJOR(version) * 10000 + XR_VERSION_MINOR(version) * 100 + patch);
}

int RuntimeKind(const char* name)
{
    if (!name || !name[0])
        return 0;
    std::string lower(name);
    for (char& character : lower)
        character = static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
    if (lower.find("wivrn") != std::string::npos)
        return 2;
    if (lower.find("monado") != std::string::npos)
        return 1;
    if (lower.find("steamvr") != std::string::npos)
        return 3;
    if (lower.find("oculus") != std::string::npos || lower.find("meta") != std::string::npos)
        return 4;
    if (lower.find("windows mixed reality") != std::string::npos || lower.find("wmr") != std::string::npos)
        return 5;
    if (lower.find("pico") != std::string::npos)
        return 6;
    return kProfileOther;
}

int ProfileKind(const std::string& profile)
{
    if (profile.empty() || profile == "(null)" || profile == "(invalid)")
        return 0;
    if (profile.find("/khr/simple_controller") != std::string::npos)
        return 1;
    if (profile.find("/oculus/") != std::string::npos || profile.find("/meta/") != std::string::npos)
        return 2;
    if (profile.find("/valve/index_controller") != std::string::npos)
        return 3;
    if (profile.find("/htc/") != std::string::npos)
        return 4;
    if (profile.find("/microsoft/") != std::string::npos)
        return 5;
    if (profile.find("/bytedance/pico") != std::string::npos)
        return 6;
    return kProfileOther;
}

int TrackingCode(const LayerState& s, const HandPoseState& pose)
{
    if (!pose.seen || s.frame < pose.frame || s.frame - pose.frame > kDiagPoseStaleFrames)
        return 0;
    bool orientationValid = (pose.flags & XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0;
    bool positionValid = (pose.flags & XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0;
    bool orientationTracked = (pose.flags & XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT) != 0;
    bool positionTracked = (pose.flags & XR_SPACE_LOCATION_POSITION_TRACKED_BIT) != 0;
    if (orientationValid && positionValid && orientationTracked && positionTracked)
        return 3;
    if (orientationValid && positionValid)
        return 2;
    return 1;
}

XrAction CreateLayerAction(LayerState& s, XrActionSet actionSet, const char* name, const char* localizedName, const std::vector<XrPath>& subactionPaths)
{
    XrActionCreateInfo info{XR_TYPE_ACTION_CREATE_INFO};
    strcpy_s(info.actionName, name);
    strcpy_s(info.localizedActionName, localizedName);
    info.actionType = XR_ACTION_TYPE_BOOLEAN_INPUT;
    info.countSubactionPaths = static_cast<uint32_t>(subactionPaths.size());
    info.subactionPaths = subactionPaths.empty() ? nullptr : subactionPaths.data();
    XrAction action = XR_NULL_HANDLE;
    XrResult created = s.next.createAction(actionSet, &info, &action);
    Log("action '%s' created in '%s' (%d)", name, kGameplaySetName, created);
    return XR_SUCCEEDED(created) ? action : XR_NULL_HANDLE;
}

GripSlot* FindGrip(LayerState& s, XrPath path)
{
    auto it = std::find_if(s.grips.begin(), s.grips.end(), [path](const GripSlot& grip) { return grip.path == path; });
    return it == s.grips.end() ? nullptr : &*it;
}

void ConfigureGrips(LayerState& s, const XrActionCreateInfo& info)
{
    s.grips.clear();
    for (uint32_t i = 0; i < info.countSubactionPaths; ++i)
    {
        XrPath path = info.subactionPaths[i];
        bool left = path == s.leftHand;
        bool right = path == s.rightHand;
        if (!left && !right)
            continue;
        GripSlot grip;
        grip.path = path;
        grip.name = left ? "left" : "right";
        s.grips.push_back(grip);
    }
    for (const GripSlot& grip : s.grips)
        Log("squeeze slot %s path=%s", grip.name, PathText(s, grip.path).c_str());
}

const char* HandName(const LayerState& s, XrPath hand)
{
    return hand == s.leftHand ? "left" : hand == s.rightHand ? "right" : "unknown";
}

void TrackHeld(GripSlot& grip, float output)
{
    bool held = output > kHeldThreshold;
    if (held && !grip.held)
        grip.heldAt = std::chrono::steady_clock::now();
    grip.held = held;
}

void UpdateReloadState(LayerState& s)
{
    int highlight = 0;
    if (!s.reloadHighlightVar.ReadInt(highlight))
        highlight = 0;
    if (highlight != s.reloadHighlight)
    {
        Log("reload highlight %d", highlight);
        s.reloadHighlight = highlight;
    }
    auto now = std::chrono::steady_clock::now();
    if (highlight != 0)
        s.reloadSeenAt = now;
    bool waiting = highlight != 0 || (s.reloadWaiting && now - s.reloadSeenAt < kReloadEndGrace);
    if (waiting == s.reloadWaiting)
        return;
    Log("reload %s", waiting ? "started" : "finished");
    s.reloadWaiting = waiting;
}

void UpdateSqueeze(LayerState& s, XrSession session)
{
    for (GripSlot& grip : s.grips)
    {
        XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
        get.action = s.squeeze;
        get.subactionPath = grip.path;
        XrActionStateFloat squeeze{XR_TYPE_ACTION_STATE_FLOAT};
        bool squeezeActive = XR_SUCCEEDED(s.next.getActionStateFloat(session, &get, &squeeze)) && squeeze.isActive;
        float raw = squeezeActive ? squeeze.currentState : 0.0f;
        grip.rawActive = squeezeActive;
        grip.raw = raw;

        bool grabbing = false;
        XrTime grabTime = 0;
        grip.grabBound = false;
        if (s.reloadGrab != XR_NULL_HANDLE)
        {
            get.action = s.reloadGrab;
            XrActionStateBoolean grab{XR_TYPE_ACTION_STATE_BOOLEAN};
            grip.grabBound = XR_SUCCEEDED(s.next.getActionStateBoolean(session, &get, &grab)) && grab.isActive;
            grabbing = grip.grabBound && grab.currentState;
            grabTime = grab.lastChangeTime;
        }

        auto now = std::chrono::steady_clock::now();
        bool rawPressed = raw > kHeldThreshold;
        bool rawEdge = rawPressed && !grip.rawPressed;
        if (rawEdge)
            grip.pressAt = now;
        grip.rawPressed = rawPressed;

        bool routed = grip.grabBound && s.reloadWaiting && grip.path != s.gunHand && !grip.grenadeHeld;
        if (routed != grip.routed)
            Log("%s hand: %s", grip.name, routed ? "grip blocked, reload grab active" : "grip restored");
        grip.routed = routed;

        float output = raw;
        if (grip.grenadeHeld)
        {
            output = rawEdge ? 0.0f : 1.0f;
            if (rawEdge)
            {
                grip.grenadeHeld = false;
                grip.waitRelease = true;
                Log("%s hand: grenade let go", grip.name);
            }
        }
        else if (grip.waitRelease)
        {
            output = 0.0f;
            if (!rawPressed)
                grip.waitRelease = false;
        }
        else if (routed)
        {
            output = grabbing ? 1.0f : 0.0f;
        }
        else if (s.grenadeToggleActive && !rawPressed && grip.output > kHeldThreshold && now - grip.pressAt < kGrenadeMinPress)
        {
            output = grip.output;
        }
        grip.changed = output != grip.output;
        grip.sampled = routed || grip.changed || output != raw;
        if (grip.changed)
            grip.changeTime = routed ? grabTime : squeeze.lastChangeTime;
        grip.output = output;
        TrackHeld(grip, output);
    }
}

const GripSlot* RecentGrab(const LayerState& s)
{
    auto now = std::chrono::steady_clock::now();
    const GripSlot* newest = nullptr;
    for (const GripSlot& grip : s.grips)
        if (now - grip.heldAt <= kGunGrabWindow && (!newest || grip.heldAt > newest->heldAt))
            newest = &grip;
    return newest;
}

void UpdateGrenade(LayerState& s)
{
    int toggle = 0;
    if (!s.gunGripToggleVar.ReadInt(toggle))
        toggle = 0;
    bool active = s.config.grenadeToggle && toggle == 1;
    if (active != s.grenadeToggleActive)
        Log("grenade toggle %s", active ? "on (Gun Grip is Toggle)" : "off");
    s.grenadeToggleActive = active;

    if (!active || s.menuState != 0)
    {
        for (GripSlot& grip : s.grips)
        {
            if (grip.grenadeHeld)
                Log("%s hand: grenade toggle cleared", grip.name);
            grip.grenadeHeld = false;
        }
    }

    int ack = 0;
    if (!s.grenadeAckVar.ReadInt(ack))
        return;
    if (!s.grenadeAckKnown)
    {
        s.grenadeAckKnown = true;
        s.grenadeAck = ack;
        return;
    }
    if (ack == s.grenadeAck)
        return;
    s.grenadeAck = ack;
    if (ack <= 0 || !active)
        return;

    const GripSlot* recent = RecentGrab(s);
    if (!recent)
    {
        Log("grenade ack %d: no recent grab", ack);
        return;
    }
    GripSlot& grip = *std::find_if(s.grips.begin(), s.grips.end(), [recent](const GripSlot& g) { return &g == recent; });
    if (grip.output <= kHeldThreshold)
    {
        Log("grenade ack %d: %s hand already let go", ack, grip.name);
        return;
    }
    grip.grenadeHeld = true;
    Log("grenade ack %d: %s hand holds the grenade until the next grip press", ack, grip.name);
}

void UpdateGunHand(LayerState& s)
{
    int ack = 0;
    if (!s.gunAckVar.ReadInt(ack))
        return;
    if (!s.gunAckKnown)
    {
        s.gunAckKnown = true;
        s.gunAck = ack;
        return;
    }
    if (ack == s.gunAck)
        return;
    s.gunAck = ack;
    if (ack <= 0)
        return;

    const GripSlot* newest = RecentGrab(s);
    if (!newest)
    {
        Log("gun ack %d: no recent grab, gun hand stays %s", ack, HandName(s, s.gunHand));
        return;
    }
    s.gunHand = newest->path;
    Log("gun ack %d: gun hand %s", ack, newest->name);
}

void UpdateCommandAction(LayerState& s, XrSession session, XrAction action, ButtonState& button, const char* label, const std::string& pressCommand,
                         const std::string& releaseCommand, std::vector<std::string>& commands)
{
    button.changed = false;
    if (action == XR_NULL_HANDLE)
        return;
    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = action;
    XrActionStateBoolean state{XR_TYPE_ACTION_STATE_BOOLEAN};
    if (XR_FAILED(s.next.getActionStateBoolean(session, &get, &state)))
        return;

    button.active = state.isActive == XR_TRUE;
    bool pressed = state.isActive && state.currentState == XR_TRUE;
    if (pressed == button.pressed)
        return;
    button.pressed = pressed;
    button.changed = true;
    button.changeTime = state.lastChangeTime;
    Log("%s %s", label, pressed ? "pressed" : "released");
    const std::string& command = pressed ? pressCommand : releaseCommand;
    if (!command.empty())
        commands.push_back(command);
}

void UpdateCrouch(LayerState& s, XrSession session, std::vector<std::string>& commands)
{
    ButtonState& button = s.crouchButton;
    CrouchState& c = s.crouchState;
    button.changed = false;
    if (s.crouch == XR_NULL_HANDLE)
        return;
    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = s.crouch;
    XrActionStateBoolean state{XR_TYPE_ACTION_STATE_BOOLEAN};
    if (XR_FAILED(s.next.getActionStateBoolean(session, &get, &state)))
        return;
    button.active = state.isActive == XR_TRUE;
    bool pressed = state.isActive && state.currentState == XR_TRUE;
    bool pressedEdge = pressed && !button.pressed;
    if (pressed != button.pressed)
    {
        button.pressed = pressed;
        button.changed = true;
        button.changeTime = state.lastChangeTime;
        Log("crouch %s", pressed ? "pressed" : "released");
    }

    bool jumpEdge = false;
    bool jumpPressed = false;
    if (s.jump != XR_NULL_HANDLE && s.jumpHand != XR_NULL_PATH)
    {
        get.action = s.jump;
        get.subactionPath = s.jumpHand;
        XrActionStateBoolean jump{XR_TYPE_ACTION_STATE_BOOLEAN};
        jumpPressed = XR_SUCCEEDED(s.next.getActionStateBoolean(session, &get, &jump)) && jump.isActive && jump.currentState;
        jumpEdge = jumpPressed && !c.jumpPressed;
        c.jumpPressed = jumpPressed;
    }

    bool buttonMode = s.config.crouchMode == "button";
    if (buttonMode)
    {
        c.toggled = false;
        if (!pressed)
            c.released = false;
    }
    else if (pressedEdge)
    {
        c.toggled = !c.toggled;
    }
    bool ducked = buttonMode ? pressed && !c.released : c.toggled;
    if (jumpEdge && ducked && s.config.crouchUncrouchOnJump)
    {
        if (buttonMode)
            c.released = true;
        else
            c.toggled = false;
        ducked = false;
        c.jumpPending = true;
        c.jumpReleaseAt = std::chrono::steady_clock::now() + std::chrono::milliseconds(std::max(s.config.crouchJumpDelayMs, 0));
        Log("crouch released by jump, jump held back %d ms", s.config.crouchJumpDelayMs);
    }
    if (c.jumpPending && std::chrono::steady_clock::now() >= c.jumpReleaseAt)
    {
        c.jumpPending = false;
        if (!jumpPressed)
            c.jumpPulseEnd = s.frame + kJumpPulseFrames;
        Log("jump passed on%s", jumpPressed ? "" : " as a tap");
    }
    bool pulsing = s.frame < c.jumpPulseEnd;
    bool jumpOutput = c.jumpPending ? false : jumpPressed || pulsing;
    c.jumpChanged = jumpOutput != c.jumpOutput;
    c.jumpOutput = jumpOutput;
    c.jumpOverride = c.jumpPending || pulsing;
    if (ducked == c.ducked)
        return;
    c.ducked = ducked;
    const std::string& command = ducked ? s.config.crouchPressCommand : s.config.crouchReleaseCommand;
    if (!command.empty())
        commands.push_back(command);
}

void UpdateMenuState(LayerState& s)
{
    int menu = -1;
    if (!s.menuActiveVar.ReadInt(menu))
        menu = -1;
    if (menu != s.menuState)
    {
        Log("menu state: %s", menu < 0 ? "unknown (companion script not running)" : menu ? "menu or start screen" : "gameplay");
        s.menuState = menu;
    }
    int phase = -1;
    if (!s.startupPhaseVar.ReadInt(phase))
        phase = -1;
    if (phase != s.startupPhase)
    {
        Log("startup phase: %d", phase);
        s.startupPhase = phase;
    }
}

void UpdateTacticalHand(LayerState& s)
{
    if (s.config.tacticalHand != "auto")
        return;
    XrPath support = s.gunHand == s.leftHand ? s.rightHand : s.leftHand;
    if (support == s.tacticalHand)
        return;
    s.tacticalHand = support;
    s.triggerOverride.applies = false;
    s.triggerOverride.blocked = false;
    Log("tactical hand %s (support hand)", HandName(s, support));
}

void UpdateTriggerOverride(LayerState& s, XrSession session)
{
    TriggerOverride& o = s.triggerOverride;
    o.changed = false;
    if (s.trigger == XR_NULL_HANDLE || s.tacticalHand == XR_NULL_PATH)
    {
        o.applies = false;
        return;
    }

    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = s.trigger;
    get.subactionPath = s.tacticalHand;
    XrActionStateFloat raw{XR_TYPE_ACTION_STATE_FLOAT};
    bool rawActive = XR_SUCCEEDED(s.next.getActionStateFloat(session, &get, &raw)) && raw.isActive;
    bool rawPressed = rawActive && raw.currentState > kHeldThreshold;

    const GripSlot* support = FindGrip(s, s.tacticalHand);
    bool reloadBlock = s.menuState == 0 && s.reloadWaiting && support && support->grabBound;
    if (o.reloadBlocked && !reloadBlock && !s.reloadWaiting && rawPressed && !o.waitRelease)
    {
        o.waitRelease = true;
        Log("%s trigger held back until released", HandName(s, s.tacticalHand));
    }
    if (o.waitRelease && !rawPressed)
        o.waitRelease = false;
    if (reloadBlock != o.reloadBlocked)
        Log("%s trigger %s", HandName(s, s.tacticalHand), reloadBlock ? "blocked (reload)" : "no longer blocked by the reload");
    o.reloadBlocked = reloadBlock;

    bool tacticalBound = s.tacticalButton.active;
    if (!tacticalBound && !reloadBlock && !o.waitRelease)
    {
        o.applies = false;
        return;
    }

    if (tacticalBound)
    {
        bool tacticalBlock = s.config.tacticalBlockHandTrigger && s.menuState == 0;
        if (tacticalBlock != o.blocked)
            Log("%s trigger %s", HandName(s, s.tacticalHand), tacticalBlock ? "blocked (gameplay, tactical bound)" : "passes through");
        o.blocked = tacticalBlock;
    }
    bool blocked = (tacticalBound && o.blocked) || reloadBlock || o.waitRelease;

    float output = std::max(s.tacticalButton.pressed ? 1.0f : 0.0f, rawActive && !blocked ? raw.currentState : 0.0f);
    o.changed = !o.applies || output != o.output;
    if (o.changed)
        o.changeTime = s.tacticalButton.changed || !rawActive ? s.tacticalButton.changeTime : raw.lastChangeTime;
    if (s.tacticalButton.changed)
        Log("tactical drives %s trigger = %.1f", HandName(s, s.tacticalHand), output);
    o.output = output;
    o.applies = true;
}

float PitchDegrees(const XrQuaternionf& q)
{
    float forwardUp = 2.0f * (q.w * q.x - q.y * q.z);
    return std::asin(std::clamp(forwardUp, -1.0f, 1.0f)) * 57.29578f;
}

const char* ReferenceSpaceName(const LayerState& s, XrSpace space)
{
    for (const auto& [handle, type] : s.referenceSpaces)
    {
        if (handle != space)
            continue;
        switch (type)
        {
        case XR_REFERENCE_SPACE_TYPE_VIEW: return "view";
        case XR_REFERENCE_SPACE_TYPE_LOCAL: return "local";
        case XR_REFERENCE_SPACE_TYPE_STAGE: return "stage";
        default: return "other reference";
        }
    }
    return "non-reference";
}

void RecordAimPose(LayerState& s, XrSpace space, XrSpace baseSpace, XrTime time, XrSpaceLocationFlags flags, const XrPosef& pose)
{
    auto it = std::find_if(s.aimSpaces.begin(), s.aimSpaces.end(), [space](const AimSpace& aim) { return aim.space == space; });
    if (it == s.aimSpaces.end())
        return;
    if (it->hand == s.leftHand || it->hand == s.rightHand)
    {
        HandPoseState& hand = it->hand == s.leftHand ? s.leftPose : s.rightPose;
        if (!hand.seen || time >= hand.time)
        {
            hand.seen = true;
            hand.frame = s.frame;
            hand.time = time;
            hand.flags = flags;
        }
    }
    if (!s.loggedAimLocate)
    {
        s.loggedAimLocate = true;
        Log("app locates aim %s relative to %s space", HandName(s, it->hand), ReferenceSpaceName(s, baseSpace));
    }
    XrSpaceLocationFlags needed = XR_SPACE_LOCATION_ORIENTATION_VALID_BIT | XR_SPACE_LOCATION_POSITION_VALID_BIT;
    if (it->hand != s.gunHand || (flags & needed) != needed || time < s.gunPoseTime)
        return;
    s.gunPitch = PitchDegrees(pose.orientation);
    s.gunHeight = pose.position.y;
    s.gunPoseBase = baseSpace;
    s.gunPoseTime = time;
    s.gunPoseValid = true;
}

void RecordHead(LayerState& s, XrSpace baseSpace, XrTime time, const XrView* views, uint32_t count)
{
    if (count == 0 || time < s.headTime)
        return;
    float sum = 0.0f;
    for (uint32_t i = 0; i < count; ++i)
        sum += views[i].pose.position.y;
    s.headHeight = sum / static_cast<float>(count);
    s.headBase = baseSpace;
    s.headTime = time;
    s.headValid = true;
}

void UpdateSprint(LayerState& s, XrSession session)
{
    SprintState& sprint = s.sprint;
    sprint.changed = false;
    if (!s.config.sprintEnabled)
        return;
    if (s.stickClick == XR_NULL_HANDLE || s.sprintHand == XR_NULL_PATH)
        return;

    bool sameBase = s.gunPoseBase == s.headBase;
    if (s.gunPoseValid && s.headValid && !sameBase && !s.loggedBaseMismatch)
    {
        s.loggedBaseMismatch = true;
        Log("gun and head are located in different spaces (%s, %s), sprint disabled", ReferenceSpaceName(s, s.gunPoseBase), ReferenceSpaceName(s, s.headBase));
    }
    bool measured = s.gunPoseValid && s.headValid && sameBase;
    float belowEyes = measured ? (s.headHeight - s.gunHeight) * 100.0f : 0.0f;
    bool lowered = sprint.lowered;
    if (!measured)
        lowered = false;
    else if (!lowered && belowEyes > static_cast<float>(s.config.sprintStartBelowEyesCm))
        lowered = true;
    else if (lowered && belowEyes < static_cast<float>(s.config.sprintStopBelowEyesCm))
        lowered = false;
    if (lowered != sprint.lowered)
        Log("gun %s: %.0f cm below eyes, pitch %.0f degrees", lowered ? "lowered" : "raised", belowEyes, s.gunPitch);
    bool stopMethod = s.config.sprintStopMethod == "stick";
    if (lowered)
    {
        sprint.stopStart = 0;
        sprint.stopEnd = 0;
    }
    else if (sprint.lowered && measured && stopMethod && s.menuState == 0 && !s.reloadWaiting)
    {
        sprint.stopStart = s.frame + kSprintStopGapFrames;
        sprint.stopEnd = sprint.stopStart + static_cast<uint64_t>(std::max(s.config.sprintStopFrames, 1));
        Log("sprint stop by %s", s.config.sprintStopMethod.c_str());
    }
    sprint.lowered = lowered;
    bool stopping = sprint.stopEnd != 0 && s.frame >= sprint.stopStart && s.frame < sprint.stopEnd;
    if (sprint.stopEnd != 0 && s.frame >= sprint.stopEnd)
    {
        sprint.stopStart = 0;
        sprint.stopEnd = 0;
    }
    if (measured && s.frame >= s.gunPoseLoggedFrame + kPitchLogFrames)
    {
        s.gunPoseLoggedFrame = s.frame;
        Log("gun %.0f cm below eyes, pitch %.0f degrees (%s hand)", belowEyes, s.gunPitch, HandName(s, s.gunHand));
    }

    bool wanted = lowered && s.menuState == 0 && !s.reloadWaiting;
    bool pressed = false;
    if (s.config.sprintMode == "pulse")
    {
        if (!wanted)
            sprint.pulseEnd = 0;
        else if (sprint.pulseEnd == 0)
            sprint.pulseEnd = s.frame + kSprintPulseFrames;
        pressed = sprint.pulseEnd != 0 && s.frame < sprint.pulseEnd;
    }
    else
    {
        pressed = wanted;
    }
    bool stickZeroed = stopping && s.config.sprintStopMethod == "stick";
    sprint.stickChanged = stickZeroed != sprint.stickZeroed;
    sprint.stickZeroed = stickZeroed;
    if (pressed != sprint.pressed)
        Log("sprint %s", pressed ? "pressed" : "released");
    sprint.pressed = pressed;

    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = s.stickClick;
    get.subactionPath = s.sprintHand;
    XrActionStateBoolean raw{XR_TYPE_ACTION_STATE_BOOLEAN};
    bool rawPressed = XR_SUCCEEDED(s.next.getActionStateBoolean(session, &get, &raw)) && raw.isActive && raw.currentState;
    bool output = rawPressed || pressed;
    sprint.changed = output != sprint.output;
    if (sprint.changed)
        sprint.changeTime = rawPressed != sprint.output && raw.lastChangeTime != 0 ? raw.lastChangeTime : s.gunPoseTime;
    sprint.output = output;
}

XrResult XRAPI_CALL LayerGetInstanceProcAddr(XrInstance instance, const char* name, PFN_xrVoidFunction* function);

XrResult XRAPI_CALL HookDestroyInstance(XrInstance instance)
{
    LayerState& s = State();
    XrResult result = s.next.destroyInstance(instance);
    std::lock_guard lock(s.mutex);
    s.squeeze = XR_NULL_HANDLE;
    s.trigger = XR_NULL_HANDLE;
    s.reloadGrab = XR_NULL_HANDLE;
    s.crouch = XR_NULL_HANDLE;
    s.tactical = XR_NULL_HANDLE;
    s.suggestedProfiles.clear();
    s.grips.clear();
    s.crouchButton = {};
    s.tacticalButton = {};
    s.triggerOverride = {};
    s.aim = XR_NULL_HANDLE;
    s.stickClick = XR_NULL_HANDLE;
    s.stick = XR_NULL_HANDLE;
    s.jump = XR_NULL_HANDLE;
    s.crouchState = {};
    s.aimSpaces.clear();
    s.referenceSpaces.clear();
    s.gunPoseValid = false;
    s.gunPoseTime = 0;
    s.headValid = false;
    s.headTime = 0;
    s.leftPose = {};
    s.rightPose = {};
    s.profileLeft = 0;
    s.profileRight = 0;
    s.runtimeKind = 0;
    s.runtimeVersion = 0;
    s.appApiVersion = 0;
    s.diagApiVar.WriteInt(0);
    s.diagSeq = 0;
    s.sprint = {};
    s.instance = XR_NULL_HANDLE;
    Log("instance destroyed (%d)", result);
    return result;
}

XrResult XRAPI_CALL HookCreateActionSet(XrInstance instance, const XrActionSetCreateInfo* createInfo, XrActionSet* actionSet)
{
    LayerState& s = State();
    XrResult result = s.next.createActionSet(instance, createInfo, actionSet);
    if (XR_FAILED(result) || !createInfo)
        return result;

    Log("action set '%s' created", createInfo->actionSetName);
    if (std::strcmp(createInfo->actionSetName, kGameplaySetName) != 0)
        return result;

    XrAction tactical = s.config.tacticalEnabled ? CreateLayerAction(s, *actionSet, kTacticalActionName, kTacticalLocalizedName, {}) : XR_NULL_HANDLE;
    XrAction crouch = s.config.crouchEnabled ? CreateLayerAction(s, *actionSet, kCrouchActionName, kCrouchLocalizedName, {}) : XR_NULL_HANDLE;
    XrAction reloadGrab =
        s.config.reloadGrabEnabled ? CreateLayerAction(s, *actionSet, kReloadGrabActionName, kReloadGrabLocalizedName, {s.leftHand, s.rightHand}) : XR_NULL_HANDLE;

    std::lock_guard lock(s.mutex);
    s.tactical = tactical;
    s.crouch = crouch;
    s.reloadGrab = reloadGrab;
    s.tacticalButton = {};
    s.crouchButton = {};
    s.suggestedProfiles.clear();
    return result;
}

bool IsTouchController(const std::string& profile)
{
    return profile.find("/touch_controller") != std::string::npos;
}

bool IsIndexController(const std::string& profile)
{
    return profile.find("/index_controller") != std::string::npos;
}

bool SupportsThumbstickClick(const std::string& profile)
{
    return IsTouchController(profile) || IsIndexController(profile) || profile.find("/mixed_reality_controller") != std::string::npos ||
           profile.find("/odyssey_controller") != std::string::npos || profile.find("/vive_cosmos_controller") != std::string::npos;
}

bool SupportsTriggerClick(const std::string& profile)
{
    return IsTouchController(profile) || IsIndexController(profile) || profile.find("/vive_controller") != std::string::npos ||
           profile.find("/vive_cosmos_controller") != std::string::npos || profile.find("/mixed_reality_controller") != std::string::npos ||
           profile.find("/odyssey_controller") != std::string::npos;
}

const char* TacticalBindingPath(const std::string& profile)
{
    if (IsTouchController(profile))
        return "/user/hand/left/input/x/click";
    if (IsIndexController(profile))
        return "/user/hand/left/input/a/click";
    return nullptr;
}

bool AddLayerBinding(LayerState& s, std::vector<XrActionSuggestedBinding>& bindings, const std::string& profile, const char* actionName,
                     XrAction action, const char* pathText)
{
    XrPath path = ToPath(s, pathText);
    if (path == XR_NULL_PATH)
    {
        Log("binding skip: profile=%s action=%s path=%s reason=xrStringToPath failed", profile.c_str(), actionName, pathText);
        return false;
    }
    bindings.push_back({action, path});
    Log("binding add: profile=%s action=%s path=%s", profile.c_str(), actionName, pathText);
    return true;
}

// WiVRn's dashboard has no per-app OpenXR binding editor, and xrizer is an
// OpenVR compatibility layer, so neither can bind an action created here.
// Submit suggested bindings alongside the game's own suggestions instead.
// Windows keeps the manual SteamVR binding flow for the added actions.
XrResult XRAPI_CALL HookSuggestInteractionProfileBindings(XrInstance instance, const XrInteractionProfileSuggestedBinding* suggested)
{
    LayerState& s = State();
    if (!s.next.suggestInteractionProfileBindings)
    {
        Log("bindings: next xrSuggestInteractionProfileBindings is missing");
        return XR_ERROR_FUNCTION_UNSUPPORTED;
    }
    if (!suggested)
    {
        Log("bindings: null suggestion; passing through");
        return s.next.suggestInteractionProfileBindings(instance, suggested);
    }

    std::string profile = PathText(s, suggested->interactionProfile);
    uint32_t gameCount = suggested->countSuggestedBindings;
    if (!suggested->suggestedBindings || gameCount == 0)
    {
        Log("bindings: profile=%s game=%u no game bindings; passing through", profile.c_str(), static_cast<unsigned>(gameCount));
        return s.next.suggestInteractionProfileBindings(instance, suggested);
    }

    Log("bindings: profile=%s game=%u wine=%d crouch_action=%d reload_action=%d tactical_action=%d crouch_binding=%s", profile.c_str(),
        static_cast<unsigned>(gameCount), s.wine, s.crouch != XR_NULL_HANDLE, s.reloadGrab != XR_NULL_HANDLE, s.tactical != XR_NULL_HANDLE,
        s.config.crouchBinding.c_str());

    if (std::find(s.suggestedProfiles.begin(), s.suggestedProfiles.end(), suggested->interactionProfile) != s.suggestedProfiles.end())
    {
        Log("bindings: profile=%s already suggested; passing through", profile.c_str());
        return s.next.suggestInteractionProfileBindings(instance, suggested);
    }

    std::vector<XrActionSuggestedBinding> bindings(suggested->suggestedBindings, suggested->suggestedBindings + gameCount);
    bool crouchAdded = false;
    bool reloadAdded = false;
    bool tacticalAdded = false;

    if (s.crouch == XR_NULL_HANDLE)
    {
        Log("binding skip: profile=%s action=crouch reason=disabled", profile.c_str());
    }
    else if (s.config.crouchBinding == "none")
    {
        Log("binding skip: profile=%s action=crouch reason=binding is none", profile.c_str());
    }
    else if (!SupportsThumbstickClick(profile))
    {
        Log("binding skip: profile=%s action=crouch reason=profile has no thumbstick click", profile.c_str());
    }
    else
    {
        if (s.config.crouchBinding == "right_thumbstick_click" || s.config.crouchBinding == "both_thumbstick_click")
            crouchAdded |= AddLayerBinding(s, bindings, profile, "crouch", s.crouch, "/user/hand/right/input/thumbstick/click");
        if (s.config.crouchBinding == "left_thumbstick_click" || s.config.crouchBinding == "both_thumbstick_click")
            crouchAdded |= AddLayerBinding(s, bindings, profile, "crouch", s.crouch, "/user/hand/left/input/thumbstick/click");
    }

    if (!s.wine)
    {
        Log("binding skip: profile=%s action=reload_grab,tactical reason=not running under Wine", profile.c_str());
    }
    else
    {
        if (s.reloadGrab == XR_NULL_HANDLE)
            Log("binding skip: profile=%s action=reload_grab reason=disabled", profile.c_str());
        else if (!SupportsTriggerClick(profile))
            Log("binding skip: profile=%s action=reload_grab reason=profile has no trigger click", profile.c_str());
        else
        {
            reloadAdded |= AddLayerBinding(s, bindings, profile, "reload_grab", s.reloadGrab, "/user/hand/left/input/trigger/click");
            reloadAdded |= AddLayerBinding(s, bindings, profile, "reload_grab", s.reloadGrab, "/user/hand/right/input/trigger/click");
        }

        const char* tacticalPath = s.tactical == XR_NULL_HANDLE ? nullptr : TacticalBindingPath(profile);
        if (s.tactical == XR_NULL_HANDLE)
            Log("binding skip: profile=%s action=tactical reason=disabled", profile.c_str());
        else if (!tacticalPath)
            Log("binding skip: profile=%s action=tactical reason=profile has no Touch X / Index A", profile.c_str());
        else
            tacticalAdded = AddLayerBinding(s, bindings, profile, "tactical", s.tactical, tacticalPath);
    }

    if (!crouchAdded && !reloadAdded && !tacticalAdded)
    {
        Log("bindings: profile=%s no layer bindings; passing through", profile.c_str());
        return s.next.suggestInteractionProfileBindings(instance, suggested);
    }

    uint32_t totalCount = static_cast<uint32_t>(bindings.size());
    Log("bindings: profile=%s suggesting %u total (%u game + %u layer)", profile.c_str(), static_cast<unsigned>(totalCount),
        static_cast<unsigned>(gameCount), static_cast<unsigned>(totalCount - gameCount));

    XrInteractionProfileSuggestedBinding copy = *suggested;
    copy.suggestedBindings = bindings.data();
    copy.countSuggestedBindings = totalCount;
    XrResult result = s.next.suggestInteractionProfileBindings(instance, &copy);
    if (XR_FAILED(result))
    {
        Log("bindings: runtime rejected batch for %s result=%d; retrying with game's %u", profile.c_str(), result,
            static_cast<unsigned>(gameCount));
        XrResult fallback = s.next.suggestInteractionProfileBindings(instance, suggested);
        Log("bindings: fallback for %s result=%d", profile.c_str(), fallback);
        return fallback;
    }

    s.suggestedProfiles.push_back(suggested->interactionProfile);
    Log("bindings: runtime accepted %u bindings for %s result=%d", static_cast<unsigned>(totalCount), profile.c_str(), result);
    if (crouchAdded)
        Log("suggested crouch binding '%s' for %s", s.config.crouchBinding.c_str(), profile.c_str());
    if (reloadAdded)
        Log("suggested reload grab on both trigger clicks for %s", profile.c_str());
    if (tacticalAdded)
        Log("suggested tactical on left %s for %s", IsTouchController(profile) ? "X" : "A", profile.c_str());
    return result;
}

XrResult XRAPI_CALL HookCreateAction(XrActionSet actionSet, const XrActionCreateInfo* createInfo, XrAction* action)
{
    LayerState& s = State();
    XrResult result = s.next.createAction(actionSet, createInfo, action);
    if (XR_FAILED(result) || !createInfo)
        return result;

    Log("action '%s' type %d subaction paths %u", createInfo->actionName, createInfo->actionType, createInfo->countSubactionPaths);
    std::lock_guard lock(s.mutex);
    if (createInfo->actionType == XR_ACTION_TYPE_POSE_INPUT && std::strcmp(createInfo->actionName, kAimActionName) == 0)
        s.aim = *action;
    else if (createInfo->actionType == XR_ACTION_TYPE_BOOLEAN_INPUT && std::strcmp(createInfo->actionName, kJumpActionName) == 0)
        s.jump = *action;
    else if (createInfo->actionType == XR_ACTION_TYPE_VECTOR2F_INPUT && std::strcmp(createInfo->actionName, kStickActionName) == 0)
        s.stick = *action;
    else if (createInfo->actionType == XR_ACTION_TYPE_BOOLEAN_INPUT && std::strcmp(createInfo->actionName, kStickClickActionName) == 0)
        s.stickClick = *action;
    if (createInfo->actionType != XR_ACTION_TYPE_FLOAT_INPUT)
        return result;

    if (std::strcmp(createInfo->actionName, kTriggerActionName) == 0)
    {
        s.trigger = *action;
    }
    else if (std::strcmp(createInfo->actionName, kSqueezeActionName) == 0)
    {
        s.squeeze = *action;
        ConfigureGrips(s, *createInfo);
    }
    return result;
}

XrResult XRAPI_CALL HookCreateReferenceSpace(XrSession session, const XrReferenceSpaceCreateInfo* createInfo, XrSpace* space)
{
    LayerState& s = State();
    XrResult result = s.next.createReferenceSpace(session, createInfo, space);
    if (XR_FAILED(result) || !createInfo || !space)
        return result;
    std::lock_guard lock(s.mutex);
    s.referenceSpaces.emplace_back(*space, createInfo->referenceSpaceType);
    return result;
}

XrResult XRAPI_CALL HookCreateActionSpace(XrSession session, const XrActionSpaceCreateInfo* createInfo, XrSpace* space)
{
    LayerState& s = State();
    XrResult result = s.next.createActionSpace(session, createInfo, space);
    if (XR_FAILED(result) || !createInfo || !space)
        return result;
    std::lock_guard lock(s.mutex);
    if (s.aim == XR_NULL_HANDLE || createInfo->action != s.aim)
        return result;
    s.aimSpaces.push_back({*space, createInfo->subactionPath});
    Log("aim space created for %s hand", HandName(s, createInfo->subactionPath));
    return result;
}

XrResult XRAPI_CALL HookLocateSpace(XrSpace space, XrSpace baseSpace, XrTime time, XrSpaceLocation* location)
{
    LayerState& s = State();
    XrResult result = s.next.locateSpace(space, baseSpace, time, location);
    if (XR_FAILED(result) || !location)
        return result;
    std::lock_guard lock(s.mutex);
    RecordAimPose(s, space, baseSpace, time, location->locationFlags, location->pose);
    return result;
}

XrResult XRAPI_CALL HookLocateSpaces(XrSession session, const XrSpacesLocateInfo* locateInfo, XrSpaceLocations* spaceLocations)
{
    LayerState& s = State();
    XrResult result = s.next.locateSpaces(session, locateInfo, spaceLocations);
    if (XR_FAILED(result) || !locateInfo || !spaceLocations || !spaceLocations->locations)
        return result;
    std::lock_guard lock(s.mutex);
    uint32_t count = std::min(locateInfo->spaceCount, spaceLocations->locationCount);
    for (uint32_t i = 0; i < count; ++i)
        RecordAimPose(s, locateInfo->spaces[i], locateInfo->baseSpace, locateInfo->time, spaceLocations->locations[i].locationFlags,
                      spaceLocations->locations[i].pose);
    return result;
}

XrResult XRAPI_CALL HookLocateViews(XrSession session, const XrViewLocateInfo* viewLocateInfo, XrViewState* viewState, uint32_t viewCapacityInput,
                                    uint32_t* viewCountOutput, XrView* views)
{
    LayerState& s = State();
    XrResult result = s.next.locateViews(session, viewLocateInfo, viewState, viewCapacityInput, viewCountOutput, views);
    if (XR_FAILED(result) || !viewLocateInfo || !viewState || !viewCountOutput || !views || viewCapacityInput == 0)
        return result;
    if (!(viewState->viewStateFlags & XR_VIEW_STATE_POSITION_VALID_BIT))
        return result;
    std::lock_guard lock(s.mutex);
    RecordHead(s, viewLocateInfo->space, viewLocateInfo->displayTime, views, std::min(*viewCountOutput, viewCapacityInput));
    return result;
}

struct FloatSample
{
    bool active = false;
    float value = 0.0f;
};

struct BooleanSample
{
    bool active = false;
    bool pressed = false;
};

struct VectorSample
{
    bool active = false;
    XrVector2f value{};
};

FloatSample SampleFloat(LayerState& s, XrSession session, XrAction action, XrPath path)
{
    FloatSample sample;
    if (action == XR_NULL_HANDLE || !s.next.getActionStateFloat)
        return sample;
    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = action;
    get.subactionPath = path;
    XrActionStateFloat state{XR_TYPE_ACTION_STATE_FLOAT};
    if (XR_FAILED(s.next.getActionStateFloat(session, &get, &state)))
        return sample;
    sample.active = state.isActive == XR_TRUE;
    sample.value = sample.active ? state.currentState : 0.0f;
    return sample;
}

BooleanSample SampleBoolean(LayerState& s, XrSession session, XrAction action, XrPath path)
{
    BooleanSample sample;
    if (action == XR_NULL_HANDLE || !s.next.getActionStateBoolean)
        return sample;
    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = action;
    get.subactionPath = path;
    XrActionStateBoolean state{XR_TYPE_ACTION_STATE_BOOLEAN};
    if (XR_FAILED(s.next.getActionStateBoolean(session, &get, &state)))
        return sample;
    sample.active = state.isActive == XR_TRUE;
    sample.pressed = sample.active && state.currentState == XR_TRUE;
    return sample;
}

VectorSample SampleVector(LayerState& s, XrSession session, XrAction action, XrPath path)
{
    VectorSample sample;
    if (action == XR_NULL_HANDLE || !s.next.getActionStateVector2f)
        return sample;
    XrActionStateGetInfo get{XR_TYPE_ACTION_STATE_GET_INFO};
    get.action = action;
    get.subactionPath = path;
    XrActionStateVector2f state{XR_TYPE_ACTION_STATE_VECTOR2F};
    if (XR_FAILED(s.next.getActionStateVector2f(session, &get, &state)))
        return sample;
    sample.active = state.isActive == XR_TRUE;
    sample.value = sample.active ? state.currentState : XrVector2f{};
    return sample;
}

int Percent(float value)
{
    return static_cast<int>(std::lround(std::clamp(value, 0.0f, 1.0f) * 100.0f));
}

int SignedPercent(float value)
{
    return static_cast<int>(std::lround(std::clamp(value, -1.0f, 1.0f) * 100.0f));
}

int BooleanCode(const BooleanSample& sample)
{
    return !sample.active ? 0 : sample.pressed ? 2 : 1;
}

int CurrentProfile(LayerState& s, XrSession session, XrPath hand)
{
    if (!s.next.getCurrentInteractionProfile || hand == XR_NULL_PATH)
        return 0;
    XrInteractionProfileState state{XR_TYPE_INTERACTION_PROFILE_STATE};
    if (XR_FAILED(s.next.getCurrentInteractionProfile(session, hand, &state)))
        return 0;
    return ProfileKind(PathText(s, state.interactionProfile));
}

void UpdateDiagnostics(LayerState& s, XrSession session)
{
    int enabled = 0;
    if (!s.diagEnabledVar.ReadInt(enabled) || enabled != 1)
        return;
    if (s.frame % kDiagIntervalFrames != 0)
        return;

    if (s.frame == kDiagIntervalFrames || s.frame % kDiagProfileIntervalFrames == 0)
    {
        s.profileLeft = CurrentProfile(s, session, s.leftHand);
        s.profileRight = CurrentProfile(s, session, s.rightHand);
    }

    FloatSample triggerLeft = SampleFloat(s, session, s.trigger, s.leftHand);
    FloatSample triggerRight = SampleFloat(s, session, s.trigger, s.rightHand);
    const GripSlot* gripLeft = FindGrip(s, s.leftHand);
    const GripSlot* gripRight = FindGrip(s, s.rightHand);
    VectorSample stickLeft = SampleVector(s, session, s.stick, s.leftHand);
    VectorSample stickRight = SampleVector(s, session, s.stick, s.rightHand);

    s.diagRuntimeKindVar.WriteInt(s.runtimeKind);
    s.diagRuntimeVersionVar.WriteInt(EncodeVersion(s.runtimeVersion));
    s.diagApiVersionVar.WriteInt(EncodeVersion(s.appApiVersion));
    s.diagProfileLeftVar.WriteInt(s.profileLeft);
    s.diagProfileRightVar.WriteInt(s.profileRight);
    s.diagTrackingLeftVar.WriteInt(TrackingCode(s, s.leftPose));
    s.diagTrackingRightVar.WriteInt(TrackingCode(s, s.rightPose));

    s.diagTriggerLeftVar.WriteInt(triggerLeft.active ? Percent(triggerLeft.value) : 0);
    s.diagTriggerRightVar.WriteInt(triggerRight.active ? Percent(triggerRight.value) : 0);
    s.diagTriggerLeftActiveVar.WriteInt(triggerLeft.active ? 1 : 0);
    s.diagTriggerRightActiveVar.WriteInt(triggerRight.active ? 1 : 0);

    s.diagGripLeftVar.WriteInt(gripLeft && gripLeft->rawActive ? Percent(gripLeft->raw) : 0);
    s.diagGripRightVar.WriteInt(gripRight && gripRight->rawActive ? Percent(gripRight->raw) : 0);
    s.diagGripLeftActiveVar.WriteInt(gripLeft && gripLeft->rawActive ? 1 : 0);
    s.diagGripRightActiveVar.WriteInt(gripRight && gripRight->rawActive ? 1 : 0);

    s.diagStickLeftXVar.WriteInt(stickLeft.active ? SignedPercent(stickLeft.value.x) : 0);
    s.diagStickLeftYVar.WriteInt(stickLeft.active ? SignedPercent(stickLeft.value.y) : 0);
    s.diagStickLeftActiveVar.WriteInt(stickLeft.active ? 1 : 0);
    s.diagStickRightXVar.WriteInt(stickRight.active ? SignedPercent(stickRight.value.x) : 0);
    s.diagStickRightYVar.WriteInt(stickRight.active ? SignedPercent(stickRight.value.y) : 0);
    s.diagStickRightActiveVar.WriteInt(stickRight.active ? 1 : 0);

    s.diagStickClickLeftVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.stickClick, s.leftHand)));
    s.diagStickClickRightVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.stickClick, s.rightHand)));
    s.diagPrimaryVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.jump, s.jumpHand)));
    s.diagCrouchVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.crouch, XR_NULL_PATH)));
    s.diagTacticalVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.tactical, XR_NULL_PATH)));
    s.diagReloadLeftVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.reloadGrab, s.leftHand)));
    s.diagReloadRightVar.WriteInt(BooleanCode(SampleBoolean(s, session, s.reloadGrab, s.rightHand)));

    s.diagApiVar.WriteInt(1);
    ++s.diagSeq;
    s.diagSeqVar.WriteInt(s.diagSeq);
}

XrResult XRAPI_CALL HookSyncActions(XrSession session, const XrActionsSyncInfo* syncInfo)
{
    LayerState& s = State();
    XrResult result = s.next.syncActions(session, syncInfo);
    if (XR_FAILED(result))
        return result;

    std::vector<std::string> commands;
    {
        std::lock_guard lock(s.mutex);
        if (!s.loggedFirstSync)
        {
            s.loggedFirstSync = true;
            Log("first xrSyncActions (%d)", result);
        }
        ++s.frame;
        ReloadConfigIfChanged(s);
        UpdateMenuState(s);
        UpdateReloadState(s);
        if (s.squeeze != XR_NULL_HANDLE)
        {
            UpdateSqueeze(s, session);
            UpdateGunHand(s);
            UpdateGrenade(s);
        }
        UpdateCrouch(s, session, commands);
        UpdateCommandAction(s, session, s.tactical, s.tacticalButton, "tactical", s.config.tacticalPressCommand, s.config.tacticalReleaseCommand,
                            commands);
        UpdateTacticalHand(s);
        UpdateTriggerOverride(s, session);
        UpdateSprint(s, session);
        UpdateDiagnostics(s, session);
    }

    for (const std::string& command : commands)
    {
        bool sent = EngineExecute(command.c_str());
        Log("command '%s' %s", command.c_str(), sent ? "sent" : "not sent");
    }
    return result;
}

XrResult XRAPI_CALL HookGetActionStateFloat(XrSession session, const XrActionStateGetInfo* getInfo, XrActionStateFloat* state)
{
    LayerState& s = State();
    XrResult result = s.next.getActionStateFloat(session, getInfo, state);
    if (XR_FAILED(result) || !getInfo || !state)
        return result;

    std::lock_guard lock(s.mutex);
    if (s.trigger != XR_NULL_HANDLE && getInfo->action == s.trigger)
    {
        const TriggerOverride& o = s.triggerOverride;
        if (!o.applies || getInfo->subactionPath != s.tacticalHand)
            return result;
        state->isActive = XR_TRUE;
        state->currentState = o.output;
        state->changedSinceLastSync = o.changed ? XR_TRUE : XR_FALSE;
        if (o.changed && o.changeTime != 0)
            state->lastChangeTime = o.changeTime;
        return result;
    }

    if (s.squeeze == XR_NULL_HANDLE || getInfo->action != s.squeeze)
        return result;
    if (s.loggedSqueezeQueries < kMaxLoggedQueries)
    {
        ++s.loggedSqueezeQueries;
        Log("app queried squeeze with subaction path %s", PathText(s, getInfo->subactionPath).c_str());
    }

    GripSlot* grip = FindGrip(s, getInfo->subactionPath);
    if (!grip || !grip->sampled)
        return result;
    state->isActive = XR_TRUE;
    state->currentState = grip->output;
    state->changedSinceLastSync = grip->changed ? XR_TRUE : XR_FALSE;
    if (grip->changed && grip->changeTime != 0)
        state->lastChangeTime = grip->changeTime;
    return result;
}

XrResult XRAPI_CALL HookGetActionStateBoolean(XrSession session, const XrActionStateGetInfo* getInfo, XrActionStateBoolean* state)
{
    LayerState& s = State();
    XrResult result = s.next.getActionStateBoolean(session, getInfo, state);
    if (XR_FAILED(result) || !getInfo || !state)
        return result;

    std::lock_guard lock(s.mutex);
    bool watched = (s.jump != XR_NULL_HANDLE && getInfo->action == s.jump) || (s.stickClick != XR_NULL_HANDLE && getInfo->action == s.stickClick);
    if (watched && s.loggedBooleanQueries < kMaxLoggedQueries * 2)
    {
        ++s.loggedBooleanQueries;
        Log("app queried %s with subaction path %s", getInfo->action == s.jump ? "jump button" : "stick_click", PathText(s, getInfo->subactionPath).c_str());
    }
    if (s.jump != XR_NULL_HANDLE && getInfo->action == s.jump && getInfo->subactionPath == s.jumpHand)
    {
        const CrouchState& c = s.crouchState;
        if (!c.jumpOverride && !c.jumpChanged)
            return result;
        state->isActive = XR_TRUE;
        state->currentState = c.jumpOutput ? XR_TRUE : XR_FALSE;
        state->changedSinceLastSync = c.jumpChanged ? XR_TRUE : XR_FALSE;
        return result;
    }
    if (!s.config.sprintEnabled || s.stickClick == XR_NULL_HANDLE || getInfo->action != s.stickClick || getInfo->subactionPath != s.sprintHand)
        return result;
    const SprintState& sprint = s.sprint;
    if (!sprint.pressed && !sprint.changed)
        return result;
    state->isActive = XR_TRUE;
    state->currentState = sprint.output ? XR_TRUE : XR_FALSE;
    state->changedSinceLastSync = sprint.changed ? XR_TRUE : XR_FALSE;
    if (sprint.changed && sprint.changeTime != 0)
        state->lastChangeTime = sprint.changeTime;
    return result;
}

XrResult XRAPI_CALL HookGetActionStateVector2f(XrSession session, const XrActionStateGetInfo* getInfo, XrActionStateVector2f* state)
{
    LayerState& s = State();
    XrResult result = s.next.getActionStateVector2f(session, getInfo, state);
    if (XR_FAILED(result) || !getInfo || !state)
        return result;

    std::lock_guard lock(s.mutex);
    if (s.stick != XR_NULL_HANDLE && getInfo->action == s.stick && s.loggedStickQueries < kMaxLoggedQueries)
    {
        ++s.loggedStickQueries;
        Log("app queried stick with subaction path %s", PathText(s, getInfo->subactionPath).c_str());
    }
    if (!s.config.sprintEnabled || s.stick == XR_NULL_HANDLE || getInfo->action != s.stick || getInfo->subactionPath != s.sprintHand)
        return result;
    if (s.sprint.stickZeroed)
    {
        state->currentState = {0.0f, 0.0f};
        state->changedSinceLastSync = s.sprint.stickChanged ? XR_TRUE : state->changedSinceLastSync;
    }
    else if (s.sprint.stickChanged)
        state->changedSinceLastSync = XR_TRUE;
    return result;
}

struct Hook
{
    const char* name;
    PFN_xrVoidFunction function;
};

const Hook kHooks[] = {
    {"xrGetInstanceProcAddr", reinterpret_cast<PFN_xrVoidFunction>(&LayerGetInstanceProcAddr)},
    {"xrDestroyInstance", reinterpret_cast<PFN_xrVoidFunction>(&HookDestroyInstance)},
    {"xrCreateActionSet", reinterpret_cast<PFN_xrVoidFunction>(&HookCreateActionSet)},
    {"xrCreateAction", reinterpret_cast<PFN_xrVoidFunction>(&HookCreateAction)},
    {"xrSuggestInteractionProfileBindings", reinterpret_cast<PFN_xrVoidFunction>(&HookSuggestInteractionProfileBindings)},
    {"xrSyncActions", reinterpret_cast<PFN_xrVoidFunction>(&HookSyncActions)},
    {"xrGetActionStateFloat", reinterpret_cast<PFN_xrVoidFunction>(&HookGetActionStateFloat)},
    {"xrGetActionStateBoolean", reinterpret_cast<PFN_xrVoidFunction>(&HookGetActionStateBoolean)},
    {"xrGetActionStateVector2f", reinterpret_cast<PFN_xrVoidFunction>(&HookGetActionStateVector2f)},
    {"xrCreateReferenceSpace", reinterpret_cast<PFN_xrVoidFunction>(&HookCreateReferenceSpace)},
    {"xrCreateActionSpace", reinterpret_cast<PFN_xrVoidFunction>(&HookCreateActionSpace)},
    {"xrLocateSpace", reinterpret_cast<PFN_xrVoidFunction>(&HookLocateSpace)},
    {"xrLocateSpaces", reinterpret_cast<PFN_xrVoidFunction>(&HookLocateSpaces)},
    {"xrLocateViews", reinterpret_cast<PFN_xrVoidFunction>(&HookLocateViews)},
};

XrResult XRAPI_CALL LayerGetInstanceProcAddr(XrInstance instance, const char* name, PFN_xrVoidFunction* function)
{
    if (!name || !function)
        return XR_ERROR_VALIDATION_FAILURE;

    LayerState& s = State();
    if (s.active)
    {
        for (const Hook& hook : kHooks)
        {
            if (std::strcmp(hook.name, name) == 0 && (hook.function != reinterpret_cast<PFN_xrVoidFunction>(&HookLocateSpaces) || s.next.locateSpaces))
            {
                *function = hook.function;
                return XR_SUCCESS;
            }
        }
    }

    if (!s.next.getInstanceProcAddr)
    {
        *function = nullptr;
        return XR_ERROR_HANDLE_INVALID;
    }
    return s.next.getInstanceProcAddr(instance, name, function);
}

XrResult XRAPI_CALL LayerCreateApiLayerInstance(const XrInstanceCreateInfo* info, const XrApiLayerCreateInfo* layerInfo, XrInstance* instance)
{
    if (!layerInfo || !layerInfo->nextInfo || !layerInfo->nextInfo->nextGetInstanceProcAddr || !layerInfo->nextInfo->nextCreateApiLayerInstance)
        return XR_ERROR_INITIALIZATION_FAILED;

    InitializeOnce();
    LayerState& s = State();

    XrApiLayerCreateInfo chained = *layerInfo;
    chained.nextInfo = layerInfo->nextInfo->next;
    XrResult result = layerInfo->nextInfo->nextCreateApiLayerInstance(info, &chained, instance);
    if (XR_FAILED(result))
    {
        Log("next xrCreateApiLayerInstance failed (%d)", result);
        return result;
    }

    std::lock_guard lock(s.mutex);
    s.instance = *instance;
    s.next = {};
    s.next.getInstanceProcAddr = layerInfo->nextInfo->nextGetInstanceProcAddr;
    s.appApiVersion = info ? info->applicationInfo.apiVersion : XR_CURRENT_API_VERSION;
    s.runtimeKind = 0;
    s.runtimeVersion = 0;
    if (!s.active)
        return result;

    if (info)
        Log("instance created for app '%s' engine '%s'", info->applicationInfo.applicationName, info->applicationInfo.engineName);

    bool resolved = ResolveNext(s, "xrDestroyInstance", s.next.destroyInstance) &&
                    ResolveNext(s, "xrStringToPath", s.next.stringToPath) &&
                    ResolveNext(s, "xrPathToString", s.next.pathToString) &&
                    ResolveNext(s, "xrCreateActionSet", s.next.createActionSet) &&
                    ResolveNext(s, "xrCreateAction", s.next.createAction) &&
                    ResolveNext(s, "xrSuggestInteractionProfileBindings", s.next.suggestInteractionProfileBindings) &&
                    ResolveNext(s, "xrSyncActions", s.next.syncActions) &&
                    ResolveNext(s, "xrGetActionStateFloat", s.next.getActionStateFloat) &&
                    ResolveNext(s, "xrGetActionStateBoolean", s.next.getActionStateBoolean) &&
                    ResolveNext(s, "xrGetActionStateVector2f", s.next.getActionStateVector2f) &&
                    ResolveNext(s, "xrCreateReferenceSpace", s.next.createReferenceSpace) &&
                    ResolveNext(s, "xrCreateActionSpace", s.next.createActionSpace) &&
                    ResolveNext(s, "xrLocateSpace", s.next.locateSpace) &&
                    ResolveNext(s, "xrLocateViews", s.next.locateViews);
    if (!resolved)
    {
        Log("layer disabled: next functions unavailable");
        s.active = false;
        return result;
    }

    PFN_xrVoidFunction instanceProperties = nullptr;
    if (XR_SUCCEEDED(s.next.getInstanceProcAddr(s.instance, "xrGetInstanceProperties", &instanceProperties)) && instanceProperties)
        s.next.getInstanceProperties = reinterpret_cast<PFN_xrGetInstanceProperties>(instanceProperties);
    PFN_xrVoidFunction currentProfile = nullptr;
    if (XR_SUCCEEDED(s.next.getInstanceProcAddr(s.instance, "xrGetCurrentInteractionProfile", &currentProfile)) && currentProfile)
        s.next.getCurrentInteractionProfile = reinterpret_cast<PFN_xrGetCurrentInteractionProfile>(currentProfile);
    if (s.next.getInstanceProperties)
    {
        XrInstanceProperties properties{XR_TYPE_INSTANCE_PROPERTIES};
        if (XR_SUCCEEDED(s.next.getInstanceProperties(s.instance, &properties)))
        {
            s.runtimeKind = RuntimeKind(properties.runtimeName);
            s.runtimeVersion = properties.runtimeVersion;
            Log("runtime '%s' kind %d version %llu", properties.runtimeName, s.runtimeKind,
                static_cast<unsigned long long>(s.runtimeVersion));
        }
    }
    if (!s.next.getInstanceProperties || !s.next.getCurrentInteractionProfile)
        Log("diagnostics: optional identity/profile queries unavailable");

    s.leftHand = ToPath(s, "/user/hand/left");
    s.rightHand = ToPath(s, "/user/hand/right");
    s.tacticalHand = s.config.tacticalHand == "left" ? s.leftHand : s.config.tacticalHand == "right" ? s.rightHand : XR_NULL_PATH;
    PFN_xrVoidFunction locateSpaces = nullptr;
    if (XR_SUCCEEDED(s.next.getInstanceProcAddr(s.instance, "xrLocateSpaces", &locateSpaces)))
        s.next.locateSpaces = reinterpret_cast<PFN_xrLocateSpaces>(locateSpaces);
    s.jumpHand = s.rightHand;
    s.sprintHand = s.config.sprintHand == "left" ? s.leftHand : s.config.sprintHand == "right" ? s.rightHand : XR_NULL_PATH;
    s.gunHand = s.rightHand;
    if (s.config.tacticalHand == "auto")
        s.tacticalHand = s.leftHand;
    Log("gun hand right until a gun is drawn or picked up");
    return result;
}
}
}

extern "C" __declspec(dllexport) XrResult XRAPI_CALL xrNegotiateLoaderApiLayerInterface(const XrNegotiateLoaderInfo* loaderInfo, const char* layerName, XrNegotiateApiLayerRequest* request)
{
    (void)layerName;
    if (!loaderInfo || !request)
        return XR_ERROR_INITIALIZATION_FAILED;
    if (loaderInfo->structType != XR_LOADER_INTERFACE_STRUCT_LOADER_INFO || loaderInfo->structVersion != XR_LOADER_INFO_STRUCT_VERSION ||
        loaderInfo->structSize != sizeof(XrNegotiateLoaderInfo))
        return XR_ERROR_INITIALIZATION_FAILED;
    if (request->structType != XR_LOADER_INTERFACE_STRUCT_API_LAYER_REQUEST || request->structVersion != XR_API_LAYER_INFO_STRUCT_VERSION ||
        request->structSize != sizeof(XrNegotiateApiLayerRequest))
        return XR_ERROR_INITIALIZATION_FAILED;
    if (loaderInfo->minInterfaceVersion > XR_CURRENT_LOADER_API_LAYER_VERSION || loaderInfo->maxInterfaceVersion < XR_CURRENT_LOADER_API_LAYER_VERSION)
        return XR_ERROR_INITIALIZATION_FAILED;

    XrVersion apiVersion = std::min<XrVersion>(XR_CURRENT_API_VERSION, loaderInfo->maxApiVersion);
    if (apiVersion < loaderInfo->minApiVersion)
        return XR_ERROR_INITIALIZATION_FAILED;

    tf2vr::InitializeOnce();
    request->layerInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
    request->layerApiVersion = apiVersion;
    request->getInstanceProcAddr = tf2vr::LayerGetInstanceProcAddr;
    request->createApiLayerInstance = tf2vr::LayerCreateApiLayerInstance;
    return XR_SUCCESS;
}
