#pragma once

#include <windows.h>

namespace tf2vrbb
{
// Points the settings bridge at the OpenXR layer's ini, which lives in the
// layer folder next to the plugin's own folder.
void SettingsSyncInit(HMODULE pluginModule);

// Called once per frame by the Northstar plugin. The first successful call
// seeds the tf2vrbb_* ConVars from the ini; later calls mirror changes made by
// the in-game menu back into the same ini.
void SettingsSyncFrame();
}
