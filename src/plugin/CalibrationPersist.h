#pragma once

#include <windows.h>

namespace tf2vrbb
{
using CalibrationLogFn = void (*)(int level, const char* message);

// Saves Titanfall2VR's native startup calibration after the first successful
// calibration and restores it on later launches. The saved values live in a
// plugin-owned ini next to the layer config, so the game's own files are never
// modified.
void CalibrationPersistInit(HMODULE pluginModule, CalibrationLogFn log);

// Called once per frame by the Northstar plugin.
void CalibrationPersistFrame();
}