// TF2VR Quality of life - in-game settings menu.
//
// Registered from mod.json:
//   "Before": "TF2VRBB_AddMenu"          - creates the menu pages
//   "After":  "TF2VRBB_AddMainMenuFooter" - puts the entry on the main menu
//
// Every row writes a ConVar that the mod's Northstar plugin mirrors into
// plugins/layer/TF2VRBetterBindings.ini, which is the only configuration file
// the OpenXR layer reads. No second settings store is used.

global function TF2VRBB_AddMenu
global function TF2VRBB_AddMainMenuFooter

// Keep in sync with the project version in CMakeLists.txt.
const string TF2VRBB_VERSION = "1.7.0"

const string TF2VRBB_MENU_ROOT = "TF2VRBBRoot"
const string TF2VRBB_MENU_CONTROLS = "TF2VRBBControls"
const string TF2VRBB_MENU_ACTIONS = "TF2VRBBActions"
const string TF2VRBB_MENU_GENERAL = "TF2VRBBGeneral"
const string TF2VRBB_MENU_ABOUT = "TF2VRBBAbout"
const string TF2VRBB_MENU_RESTORE = "TF2VRBBRestore"
const string TF2VRBB_MENU_DIAGNOSTICS = "TF2VRBBDiagnostics"

// Set to 1 by the 1.5.0 plugin once it can read and write the ini.
const string TF2VRBB_API_CONVAR = "tf2vrbb_settings_api"

const int TF2VRBB_ACTION_ROW_COUNT = 9
const int TF2VRBB_GENERAL_ROW_COUNT = 3
const int TF2VRBB_ROOT_ROW_COUNT = 6

struct TF2VRBBRow
{
	string label
	string conVar
	int minValue
	int maxValue
	int step
	// Non-empty for enum style rows, empty for numeric rows.
	array<string> values
	string unit
	int defaultValue
}

struct
{
	array<TF2VRBBRow> actionRows
	array<TF2VRBBRow> generalRows

	array<var> actionButtons
	array<var> generalButtons
	array<var> rootButtons

	var rootMenu
	var controlsMenu
	var actionsMenu
	var generalMenu
	var aboutMenu
	var restoreMenu
	var diagnosticsMenu

	var rootStatus
	var actionStatus
	var generalStatus
	var restoreStatus
	var aboutStorage

	var diagLayerStatus
	var diagSettingsStatus
	var diagRuntime
	var diagApi
	var diagProfileLeft
	var diagProfileRight
	var diagTrackLeft
	var diagTrackRight
	var diagActionConfig
	var diagSample
	var diagTriggerLeft
	var diagTriggerRight
	var diagGripLeft
	var diagGripRight
	var diagStickLeft
	var diagStickRight
	var diagStickClick
	var diagPrimary
	var diagCrouch
	var diagTactical
	var diagReload
	int diagRunId
	int diagStartSeq
	int diagLastSeq
	int diagStaleFrames
} file

////////////////////////////////////////////////////////////////////////////////
// Registration
////////////////////////////////////////////////////////////////////////////////

void function TF2VRBB_AddMenu()
{
	TF2VRBB_BuildRowData()

	AddMenu( TF2VRBB_MENU_ROOT, $"resource/ui/menus/tf2vrbb_root.menu", TF2VRBB_InitRoot )
	AddMenu( TF2VRBB_MENU_CONTROLS, $"resource/ui/menus/tf2vrbb_controls.menu", TF2VRBB_InitControls )
	AddMenu( TF2VRBB_MENU_ACTIONS, $"resource/ui/menus/tf2vrbb_actions.menu", TF2VRBB_InitActions )
	AddMenu( TF2VRBB_MENU_GENERAL, $"resource/ui/menus/tf2vrbb_general.menu", TF2VRBB_InitGeneral )
	AddMenu( TF2VRBB_MENU_ABOUT, $"resource/ui/menus/tf2vrbb_about.menu", TF2VRBB_InitAbout )
	AddMenu( TF2VRBB_MENU_RESTORE, $"resource/ui/menus/tf2vrbb_restore.menu", TF2VRBB_InitRestore )
	AddMenu( TF2VRBB_MENU_DIAGNOSTICS, $"resource/ui/menus/tf2vrbb_diagnostics.menu", TF2VRBB_InitDiagnostics )
}

// Runs after every menu exists and is created, so footers can be added to the
// vanilla main menu. GetMenu returns null for menus that are not registered.
void function TF2VRBB_AddMainMenuFooter()
{
	var mainMenu = GetMenu( "MainMenu" )
	if ( mainMenu == null )
		return

	AddMenuFooterOption( mainMenu, BUTTON_X, "%[X_BUTTON|]% TF2VR Quality of life", "TF2VR Quality of life",
		TF2VRBB_OnOpenFromMainMenu )
}

////////////////////////////////////////////////////////////////////////////////
// Settings description
////////////////////////////////////////////////////////////////////////////////

TF2VRBBRow function TF2VRBB_MakeToggleRow( string label, string conVar, int defaultValue )
{
	TF2VRBBRow row
	row.label = label
	row.conVar = conVar
	row.minValue = 0
	row.maxValue = 1
	row.step = 1

	array<string> values = []
	values.append( "OFF" )
	values.append( "ON" )
	row.values = values
	row.unit = ""
	row.defaultValue = defaultValue
	return row
}

TF2VRBBRow function TF2VRBB_MakeModeRow( string label, string conVar, int defaultValue )
{
	TF2VRBBRow row
	row.label = label
	row.conVar = conVar
	row.minValue = 0
	row.maxValue = 1
	row.step = 1

	array<string> values = []
	values.append( "TOGGLE" )
	values.append( "BUTTON" )
	row.values = values
	row.unit = ""
	row.defaultValue = defaultValue
	return row
}

TF2VRBBRow function TF2VRBB_MakeBindingRow( string label, string conVar, int defaultValue )
{
	TF2VRBBRow row
	row.label = label
	row.conVar = conVar
	row.minValue = 0
	row.maxValue = 3
	row.step = 1

	array<string> values = []
	values.append( "NONE" )
	values.append( "LEFT STICK CLICK" )
	values.append( "RIGHT STICK CLICK" )
	values.append( "BOTH STICK CLICKS" )
	row.values = values
	row.unit = ""
	row.defaultValue = defaultValue
	return row
}

TF2VRBBRow function TF2VRBB_MakeNumberRow( string label, string conVar, int minValue, int maxValue, int step, string unit, int defaultValue )
{
	TF2VRBBRow row
	row.label = label
	row.conVar = conVar
	row.minValue = minValue
	row.maxValue = maxValue
	row.step = step
	row.unit = unit

	array<string> values = []
	row.values = values
	row.defaultValue = defaultValue
	return row
}

void function TF2VRBB_BuildRowData()
{
	array<TF2VRBBRow> actions = []
	actions.append( TF2VRBB_MakeToggleRow( "RELOAD GRAB", "tf2vrbb_reload_grab", 1 ) )
	actions.append( TF2VRBB_MakeToggleRow( "GRENADE TOGGLE", "tf2vrbb_grenade_toggle", 0 ) )
	actions.append( TF2VRBB_MakeToggleRow( "CROUCH ACTION", "tf2vrbb_crouch_enabled", 1 ) )
	actions.append( TF2VRBB_MakeModeRow( "CROUCH MODE", "tf2vrbb_crouch_button_mode", 0 ) )
	actions.append( TF2VRBB_MakeBindingRow( "CROUCH BINDING", "tf2vrbb_crouch_binding", 0 ) )
	actions.append( TF2VRBB_MakeToggleRow( "UNCROUCH ON JUMP", "tf2vrbb_uncrouch_on_jump", 0 ) )
	actions.append( TF2VRBB_MakeNumberRow( "JUMP DELAY", "tf2vrbb_jump_delay_ms", 0, 1000, 50, " MS", 250 ) )
	actions.append( TF2VRBB_MakeToggleRow( "TACTICAL ACTION", "tf2vrbb_tactical_enabled", 1 ) )
	actions.append( TF2VRBB_MakeToggleRow( "TACTICAL BLOCKS HAND TRIGGER", "tf2vrbb_tactical_block_trigger", 1 ) )
	file.actionRows = actions

	array<TF2VRBBRow> general = []
	general.append( TF2VRBB_MakeToggleRow( "SPRINT ACTION", "tf2vrbb_sprint_enabled", 0 ) )
	general.append( TF2VRBB_MakeNumberRow( "SPRINT START HEIGHT", "tf2vrbb_sprint_start_cm", 5, 150, 5, " CM", 30 ) )
	general.append( TF2VRBB_MakeNumberRow( "SPRINT STOP HEIGHT", "tf2vrbb_sprint_stop_cm", 0, 145, 5, " CM", 20 ) )
	file.generalRows = general
}

////////////////////////////////////////////////////////////////////////////////
// Menu initialisation
////////////////////////////////////////////////////////////////////////////////

void function TF2VRBB_InitRoot()
{
	file.rootMenu = GetMenu( TF2VRBB_MENU_ROOT )
	file.rootStatus = Hud_GetChild( file.rootMenu, "Status" )
	file.rootButtons = TF2VRBB_GetRowButtons( file.rootMenu, TF2VRBB_ROOT_ROW_COUNT )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row0", "CONTROLS" )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row1", "ACTION SETTINGS" )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row2", "GENERAL OPTIONS" )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row3", "VR DIAGNOSTICS" )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row4", "ABOUT" )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row5", "RESTORE DEFAULTS" )

	TF2VRBB_WireNav( file.rootButtons )
	TF2VRBB_BindRootRows()

	AddMenuFooterOption( file.rootMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.rootMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnRootOpen )
}

void function TF2VRBB_InitControls()
{
	file.controlsMenu = GetMenu( TF2VRBB_MENU_CONTROLS )

	AddMenuFooterOption( file.controlsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	Hud_AddEventHandler( Hud_GetChild( file.controlsMenu, "BtnBack" ), UIE_CLICK, TF2VRBB_OnBackButton )
	AddMenuEventHandler( file.controlsMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnControlsOpen )
}

void function TF2VRBB_InitActions()
{
	file.actionsMenu = GetMenu( TF2VRBB_MENU_ACTIONS )
	file.actionStatus = Hud_GetChild( file.actionsMenu, "Status" )
	file.actionButtons = []
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchReloadGrab", "RELOAD GRAB" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchGrenadeToggle", "GRENADE TOGGLE" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchCrouchAction", "CROUCH ACTION" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchCrouchMode", "CROUCH MODE" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchCrouchBinding", "CROUCH BINDING" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchUncrouchOnJump", "UNCROUCH ON JUMP" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchJumpDelay", "JUMP DELAY" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchTacticalAction", "TACTICAL ACTION" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchTacticalBlockTrigger", "TACTICAL BLOCKS HAND TRIGGER" )

	AddMenuFooterOption( file.actionsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.actionsMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnActionsOpen )
}

void function TF2VRBB_InitGeneral()
{
	file.generalMenu = GetMenu( TF2VRBB_MENU_GENERAL )
	file.generalStatus = Hud_GetChild( file.generalMenu, "Status" )
	file.generalButtons = []
	TF2VRBB_SetButtonLabel( file.generalMenu, "SwitchSprintAction", "SPRINT ACTION" )
	TF2VRBB_SetButtonLabel( file.generalMenu, "SwitchSprintStart", "SPRINT START HEIGHT" )
	TF2VRBB_SetButtonLabel( file.generalMenu, "SwitchSprintStop", "SPRINT STOP HEIGHT" )

	AddMenuFooterOption( file.generalMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.generalMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnGeneralOpen )
}

void function TF2VRBB_InitAbout()
{
	file.aboutMenu = GetMenu( TF2VRBB_MENU_ABOUT )
	file.aboutStorage = Hud_GetChild( file.aboutMenu, "StorageLabel" )

	Hud_SetText( Hud_GetChild( file.aboutMenu, "VersionLabel" ), "TF2VR QUALITY OF LIFE " + TF2VRBB_VERSION )
	Hud_AddEventHandler( Hud_GetChild( file.aboutMenu, "BtnBack" ), UIE_CLICK, TF2VRBB_OnBackButton )

	AddMenuFooterOption( file.aboutMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.aboutMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnAboutOpen )
}

void function TF2VRBB_InitDiagnostics()
{
	file.diagnosticsMenu = GetMenu( TF2VRBB_MENU_DIAGNOSTICS )
	file.diagLayerStatus = Hud_GetChild( file.diagnosticsMenu, "LayerStatus" )
	file.diagSettingsStatus = Hud_GetChild( file.diagnosticsMenu, "SettingsStatus" )
	file.diagRuntime = Hud_GetChild( file.diagnosticsMenu, "RuntimeInfo" )
	file.diagApi = Hud_GetChild( file.diagnosticsMenu, "ApiInfo" )
	file.diagProfileLeft = Hud_GetChild( file.diagnosticsMenu, "ProfileLeft" )
	file.diagProfileRight = Hud_GetChild( file.diagnosticsMenu, "ProfileRight" )
	file.diagTrackLeft = Hud_GetChild( file.diagnosticsMenu, "TrackingLeft" )
	file.diagTrackRight = Hud_GetChild( file.diagnosticsMenu, "TrackingRight" )
	file.diagActionConfig = Hud_GetChild( file.diagnosticsMenu, "ActionConfig" )
	file.diagSample = Hud_GetChild( file.diagnosticsMenu, "SampleState" )
	file.diagTriggerLeft = Hud_GetChild( file.diagnosticsMenu, "TriggerLeft" )
	file.diagTriggerRight = Hud_GetChild( file.diagnosticsMenu, "TriggerRight" )
	file.diagGripLeft = Hud_GetChild( file.diagnosticsMenu, "GripLeft" )
	file.diagGripRight = Hud_GetChild( file.diagnosticsMenu, "GripRight" )
	file.diagStickLeft = Hud_GetChild( file.diagnosticsMenu, "StickLeft" )
	file.diagStickRight = Hud_GetChild( file.diagnosticsMenu, "StickRight" )
	file.diagStickClick = Hud_GetChild( file.diagnosticsMenu, "StickClick" )
	file.diagPrimary = Hud_GetChild( file.diagnosticsMenu, "Primary" )
	file.diagCrouch = Hud_GetChild( file.diagnosticsMenu, "Crouch" )
	file.diagTactical = Hud_GetChild( file.diagnosticsMenu, "Tactical" )
	file.diagReload = Hud_GetChild( file.diagnosticsMenu, "ReloadGrab" )

	Hud_AddEventHandler( Hud_GetChild( file.diagnosticsMenu, "BtnBack" ), UIE_CLICK, TF2VRBB_OnBackButton )
	AddMenuFooterOption( file.diagnosticsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.diagnosticsMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnDiagnosticsOpen )
}

void function TF2VRBB_InitRestore()
{
	file.restoreMenu = GetMenu( TF2VRBB_MENU_RESTORE )
	file.restoreStatus = Hud_GetChild( file.restoreMenu, "Status" )

	var restoreButton = Hud_GetChild( file.restoreMenu, "BtnRestore" )
	var cancelButton = Hud_GetChild( file.restoreMenu, "BtnCancel" )

	// A local inferred from Hud_GetChild has no known type, so calling methods on
	// it does not compile. The Hud_* helpers take var parameters and do it.
	Hud_SetNavUp( restoreButton, cancelButton )
	Hud_SetNavDown( restoreButton, cancelButton )
	Hud_SetNavUp( cancelButton, restoreButton )
	Hud_SetNavDown( cancelButton, restoreButton )

	Hud_AddEventHandler( restoreButton, UIE_CLICK, TF2VRBB_OnRestoreConfirmed )
	Hud_AddEventHandler( cancelButton, UIE_CLICK, TF2VRBB_OnBackButton )

	AddMenuFooterOption( file.restoreMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.restoreMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnRestoreOpen )
}

////////////////////////////////////////////////////////////////////////////////
// Helpers
////////////////////////////////////////////////////////////////////////////////

array<var> function TF2VRBB_GetRowButtons( var menu, int count )
{
	array<var> buttons = []
	for ( int i = 0; i < count; i++ )
	{
		var button = Hud_GetChild( menu, "Row" + string( i ) )
		if ( button == null )
		{
			print( "[TF2VRBB][layout] missing Row" + string( i ) + "\n" )
			continue
		}
		buttons.append( button )
	}
	return buttons
}

void function TF2VRBB_SetButtonLabel( var menu, string childName, string label )
{
	var button = Hud_GetChild( menu, childName )
	if ( button != null )
		SetButtonRuiText( button, label )
	else
		print( "[TF2VRBB][layout] missing label target " + childName + "\n" )
}

void function TF2VRBB_WireNav( array<var> buttons )
{
	int count = buttons.len()
	if ( count == 0 )
		return

	for ( int i = 0; i < count; i++ )
	{
		Hud_SetNavUp( buttons[ i ], buttons[ ( i + count - 1 ) % count ] )
		Hud_SetNavDown( buttons[ i ], buttons[ ( i + 1 ) % count ] )
	}
}

////////////////////////////////////////////////////////////////////////////////
// Layout diagnostics
////////////////////////////////////////////////////////////////////////////////

string function TF2VRBB_HudParentInfo( var hud )
{
	var parentHud = Hud_GetParent( hud )
	if ( parentHud == null )
		return "parent=NULL"

	return "parentAbs=(" + string( Hud_GetAbsX( parentHud ) ) + "," + string( Hud_GetAbsY( parentHud ) ) + ")"
		+ " parentSize=(" + string( Hud_GetWidth( parentHud ) ) + "x" + string( Hud_GetHeight( parentHud ) ) + ")"
}

void function TF2VRBB_LogHudChild( var menu, string name )
{
	var hud = Hud_GetChild( menu, name )
	if ( hud == null )
	{
		print( "[TF2VRBB][layout] " + name + " = NULL\n" )
		return
	}

	print( "[TF2VRBB][layout] " + name
		+ " rel=(" + string( Hud_GetX( hud ) ) + "," + string( Hud_GetY( hud ) ) + ")"
		+ " abs=(" + string( Hud_GetAbsX( hud ) ) + "," + string( Hud_GetAbsY( hud ) ) + ")"
		+ " size=(" + string( Hud_GetWidth( hud ) ) + "x" + string( Hud_GetHeight( hud ) ) + ")"
		+ " visible=" + ( Hud_IsVisible( hud ) ? "1" : "0" )
		+ " enabled=" + ( Hud_IsEnabled( hud ) ? "1" : "0" )
		+ " scriptID=" + Hud_GetScriptID( hud )
		+ " " + TF2VRBB_HudParentInfo( hud )
		+ " text=\"" + Hud_GetUTF8Text( hud ) + "\"\n" )
}

void function TF2VRBB_LogPageHeader( string page, var menu )
{
	print( "[TF2VRBB][layout] page=" + page + " screen="
		+ string( GetScreenSize()[ 0 ] ) + "x" + string( GetScreenSize()[ 1 ] ) + "\n" )
	print( "[TF2VRBB][layout] page=" + page + " menu"
		+ " rel=(" + string( Hud_GetX( menu ) ) + "," + string( Hud_GetY( menu ) ) + ")"
		+ " abs=(" + string( Hud_GetAbsX( menu ) ) + "," + string( Hud_GetAbsY( menu ) ) + ")"
		+ " size=(" + string( Hud_GetWidth( menu ) ) + "x" + string( Hud_GetHeight( menu ) ) + ")"
		+ " visible=" + ( Hud_IsVisible( menu ) ? "1" : "0" ) + "\n" )
}

void function TF2VRBB_LogRootLayout()
{
	WaitFrame()
	WaitFrame()

	TF2VRBB_LogPageHeader( "root", file.rootMenu )
	TF2VRBB_LogHudChild( file.rootMenu, "Panel" )
	TF2VRBB_LogHudChild( file.rootMenu, "AccentTop" )
	TF2VRBB_LogHudChild( file.rootMenu, "PanelHeader" )
	TF2VRBB_LogHudChild( file.rootMenu, "HeaderRule" )
	TF2VRBB_LogHudChild( file.rootMenu, "SubHeader" )
	TF2VRBB_LogHudChild( file.rootMenu, "ButtonRowAnchor" )

	for ( int i = 0; i < TF2VRBB_ROOT_ROW_COUNT; i++ )
		TF2VRBB_LogHudChild( file.rootMenu, "Row" + string( i ) )

	TF2VRBB_LogHudChild( file.rootMenu, "HintText" )
	TF2VRBB_LogHudChild( file.rootMenu, "Status" )
	print( "[TF2VRBB][layout] root buttons=" + string( file.rootButtons.len() ) + "\n" )
}

void function TF2VRBB_LogActionsLayout()
{
	WaitFrame()
	WaitFrame()

	TF2VRBB_LogPageHeader( "actions", file.actionsMenu )
	TF2VRBB_LogHudChild( file.actionsMenu, "Panel" )
	TF2VRBB_LogHudChild( file.actionsMenu, "PanelHeader" )
	TF2VRBB_LogHudChild( file.actionsMenu, "HeaderRule" )
	TF2VRBB_LogHudChild( file.actionsMenu, "SubHeader" )

	array<string> names = []
	names.append( "SwitchReloadGrab" )
	names.append( "SwitchGrenadeToggle" )
	names.append( "SwitchCrouchAction" )
	names.append( "SwitchCrouchMode" )
	names.append( "SwitchCrouchBinding" )
	names.append( "SwitchUncrouchOnJump" )
	names.append( "SwitchJumpDelay" )
	names.append( "SwitchTacticalAction" )
	names.append( "SwitchTacticalBlockTrigger" )
	for ( int i = 0; i < names.len(); i++ )
		TF2VRBB_LogHudChild( file.actionsMenu, names[ i ] )

	TF2VRBB_LogHudChild( file.actionsMenu, "HintText" )
	TF2VRBB_LogHudChild( file.actionsMenu, "Status" )
	print( "[TF2VRBB][layout] action buttons=" + string( file.actionButtons.len() ) + "\n" )
}

void function TF2VRBB_LogGeneralLayout()
{
	WaitFrame()
	WaitFrame()

	TF2VRBB_LogPageHeader( "general", file.generalMenu )
	TF2VRBB_LogHudChild( file.generalMenu, "Panel" )
	TF2VRBB_LogHudChild( file.generalMenu, "PanelHeader" )
	TF2VRBB_LogHudChild( file.generalMenu, "HeaderRule" )
	TF2VRBB_LogHudChild( file.generalMenu, "SubHeader" )

	array<string> names = []
	names.append( "SwitchSprintAction" )
	names.append( "SwitchSprintStart" )
	names.append( "SwitchSprintStop" )
	for ( int i = 0; i < names.len(); i++ )
		TF2VRBB_LogHudChild( file.generalMenu, names[ i ] )

	TF2VRBB_LogHudChild( file.generalMenu, "HintText" )
	TF2VRBB_LogHudChild( file.generalMenu, "NoteText" )
	TF2VRBB_LogHudChild( file.generalMenu, "Status" )
	print( "[TF2VRBB][layout] general buttons=" + string( file.generalButtons.len() ) + "\n" )
}

void function TF2VRBB_LogControlsLayout()
{
	WaitFrame()
	WaitFrame()

	TF2VRBB_LogPageHeader( "controls", file.controlsMenu )
	TF2VRBB_LogHudChild( file.controlsMenu, "Panel" )
	TF2VRBB_LogHudChild( file.controlsMenu, "PanelHeader" )
	TF2VRBB_LogHudChild( file.controlsMenu, "HeaderRule" )
	TF2VRBB_LogHudChild( file.controlsMenu, "SubHeader" )

	for ( int i = 0; i < 5; i++ )
	{
		TF2VRBB_LogHudChild( file.controlsMenu, "Entry" + string( i ) )
		TF2VRBB_LogHudChild( file.controlsMenu, "Desc" + string( i ) )
	}

	TF2VRBB_LogHudChild( file.controlsMenu, "BtnBack" )
}

void function TF2VRBB_LogAboutLayout()
{
	WaitFrame()
	WaitFrame()

	TF2VRBB_LogPageHeader( "about", file.aboutMenu )
	TF2VRBB_LogHudChild( file.aboutMenu, "Panel" )
	TF2VRBB_LogHudChild( file.aboutMenu, "PanelHeader" )
	TF2VRBB_LogHudChild( file.aboutMenu, "HeaderRule" )
	TF2VRBB_LogHudChild( file.aboutMenu, "VersionLabel" )
	TF2VRBB_LogHudChild( file.aboutMenu, "StorageLabel" )
	TF2VRBB_LogHudChild( file.aboutMenu, "BtnBack" )
}

void function TF2VRBB_LogRestoreLayout()
{
	WaitFrame()
	WaitFrame()

	TF2VRBB_LogPageHeader( "restore", file.restoreMenu )
	TF2VRBB_LogHudChild( file.restoreMenu, "Panel" )
	TF2VRBB_LogHudChild( file.restoreMenu, "PanelHeader" )
	TF2VRBB_LogHudChild( file.restoreMenu, "HeaderRule" )
	TF2VRBB_LogHudChild( file.restoreMenu, "WarningText" )
	TF2VRBB_LogHudChild( file.restoreMenu, "DefaultsText" )
	TF2VRBB_LogHudChild( file.restoreMenu, "BtnRestore" )
	TF2VRBB_LogHudChild( file.restoreMenu, "BtnCancel" )
	TF2VRBB_LogHudChild( file.restoreMenu, "Status" )
}

string function TF2VRBB_RowText( TF2VRBBRow row, int value )
{
	int clamped = value
	if ( clamped < row.minValue )
		clamped = row.minValue
	if ( clamped > row.maxValue )
		clamped = row.maxValue

	if ( row.values.len() > 0 )
	{
		int index = clamped
		if ( index < 0 )
			index = 0
		if ( index >= row.values.len() )
			index = row.values.len() - 1
		return row.label + "        " + row.values[ index ]
	}

	return row.label + "        " + string( clamped ) + row.unit
}

void function TF2VRBB_RefreshRows( array<var> buttons, array<TF2VRBBRow> rows )
{
	int count = buttons.len()
	for ( int i = 0; i < rows.len(); i++ )
	{
		if ( i >= count )
			break
		Hud_SetText( buttons[ i ], TF2VRBB_RowText( rows[ i ], GetConVarInt( rows[ i ].conVar ) ) )
	}
}

void function TF2VRBB_RefreshAll()
{
	TF2VRBB_RefreshRows( file.actionButtons, file.actionRows )
	TF2VRBB_RefreshRows( file.generalButtons, file.generalRows )
	TF2VRBB_UpdateStorageLabel()
}

void function TF2VRBB_UpdateStorageLabel()
{
	bool saving = GetConVarInt( TF2VRBB_API_CONVAR ) == 1
	if ( file.aboutStorage != null )
	{
		if ( saving )
			Hud_SetText( file.aboutStorage, "SETTINGS FILE: CONNECTED - CHANGES ARE WRITTEN IMMEDIATELY" )
		else
			Hud_SetText( file.aboutStorage, "SETTINGS FILE: NOT CONNECTED - INSTALL THE " + TF2VRBB_VERSION + " PLUGIN DLL" )
	}

	if ( file.rootStatus != null )
		Hud_SetText( file.rootStatus, saving ? "SETTINGS FILE CONNECTED" : "SETTINGS FILE NOT CONNECTED - REBUILD THE PLUGIN" )
}

void function TF2VRBB_ShowSaved()
{
	bool saving = GetConVarInt( TF2VRBB_API_CONVAR ) == 1
	string message = saving ? "SAVED TO TF2VRBETTERBINDINGS.INI" : "NOT SAVED - THE PLUGIN DLL IS OUT OF DATE"

	if ( file.rootStatus != null )
		Hud_SetText( file.rootStatus, message )
	if ( file.actionStatus != null )
		Hud_SetText( file.actionStatus, message )
	if ( file.generalStatus != null )
		Hud_SetText( file.generalStatus, message )
}

void function TF2VRBB_ValidateSprint()
{
	int start = GetConVarInt( "tf2vrbb_sprint_start_cm" )
	int stop = GetConVarInt( "tf2vrbb_sprint_stop_cm" )
	if ( stop < start )
		return

	stop = start - 5
	if ( stop < 0 )
		stop = 0
	SetConVarInt( "tf2vrbb_sprint_stop_cm", stop )
}

void function TF2VRBB_CycleRow( TF2VRBBRow row, var button )
{
	int value = GetConVarInt( row.conVar )
	int next = value + row.step
	if ( next > row.maxValue )
		next = row.minValue
	if ( next < row.minValue )
		next = row.minValue

	SetConVarInt( row.conVar, next )
	Hud_SetText( button, TF2VRBB_RowText( row, next ) )
	TF2VRBB_ShowSaved()
}

////////////////////////////////////////////////////////////////////////////////
// Callbacks
////////////////////////////////////////////////////////////////////////////////

string function TF2VRBB_DiagTwoDigits( int value )
{
	return value < 10 ? "0" + string( value ) : string( value )
}

string function TF2VRBB_DiagVersion( int encoded )
{
	if ( encoded <= 0 )
		return "NOT REPORTED"
	return string( encoded / 10000 ) + "." + TF2VRBB_DiagTwoDigits( ( encoded / 100 ) % 100 ) + "." + TF2VRBB_DiagTwoDigits( encoded % 100 )
}

string function TF2VRBB_DiagRuntime( int code )
{
	if ( code == 1 )
		return "MONADO"
	if ( code == 2 )
		return "WIVRN"
	if ( code == 3 )
		return "STEAMVR"
	if ( code == 4 )
		return "OCULUS/META"
	if ( code == 5 )
		return "WMR"
	if ( code == 6 )
		return "PICO"
	if ( code == 99 )
		return "OTHER RUNTIME"
	return "NOT REPORTED"
}

string function TF2VRBB_DiagProfile( int code )
{
	if ( code == 1 )
		return "KHR SIMPLE"
	if ( code == 2 )
		return "OCULUS/META TOUCH"
	if ( code == 3 )
		return "VALVE INDEX"
	if ( code == 4 )
		return "HTC VIVE"
	if ( code == 5 )
		return "WMR"
	if ( code == 6 )
		return "PICO"
	if ( code == 99 )
		return "OTHER PROFILE"
	return "NO PROFILE"
}

string function TF2VRBB_DiagTracking( int code )
{
	if ( code == 3 )
		return "TRACKED"
	if ( code == 2 )
		return "POSE VALID"
	if ( code == 1 )
		return "NOT TRACKED"
	return "NO POSE DATA"
}

string function TF2VRBB_DiagAction( int code )
{
	if ( code == 2 )
		return "PRESSED"
	if ( code == 1 )
		return "READY"
	return "NO SIGNAL"
}

string function TF2VRBB_DiagOnOff( int value )
{
	return value == 1 ? "ON" : "OFF"
}

string function TF2VRBB_DiagBar( int value )
{
	int clamped = value
	if ( clamped < 0 )
		clamped = 0
	if ( clamped > 100 )
		clamped = 100
	int filled = ( clamped + 5 ) / 10
	string bar = ""
	for ( int i = 0; i < 10; i++ )
	{
		if ( i < filled )
			bar += "#"
		else
			bar += "-"
	}
	return "[" + bar + "] " + string( clamped ) + "%"
}

string function TF2VRBB_DiagInput( string label, string valueVar, string activeVar )
{
	if ( GetConVarInt( activeVar ) != 1 )
		return label + "  NO ACTIVE BINDING"
	return label + "  " + TF2VRBB_DiagBar( GetConVarInt( valueVar ) )
}

string function TF2VRBB_DiagStick( string label, string xVar, string yVar, string activeVar )
{
	if ( GetConVarInt( activeVar ) != 1 )
		return label + "  NO ACTIVE BINDING"
	int x = GetConVarInt( xVar )
	int y = GetConVarInt( yVar )
	return label + "  X " + ( x > 0 ? "+" + string( x ) : string( x ) ) + "  Y " + ( y > 0 ? "+" + string( y ) : string( y ) )
}

string function TF2VRBB_DiagReloadLine()
{
	return "RELOAD GRAB  L " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_reload_left" ) )
		+ "  R " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_reload_right" ) )
}

void function TF2VRBB_RefreshDiagnostics()
{
	if ( file.diagnosticsMenu == null )
		return

	int apiConnected = GetConVarInt( "tf2vrbb_diag_api" ) == 1 ? 1 : 0
	int sequence = GetConVarInt( "tf2vrbb_diag_seq" )
	Hud_SetText( file.diagLayerStatus, "LAYER: " + ( apiConnected == 1 ? "CONNECTED" : "NO DATA" ) )
	Hud_SetText( file.diagSettingsStatus, "SETTINGS BRIDGE: " + ( GetConVarInt( "tf2vrbb_settings_api" ) == 1 ? "CONNECTED" : "NOT CONNECTED" ) )
	int runtimeKind = GetConVarInt( "tf2vrbb_diag_runtime_kind" )
	int runtimeVersion = GetConVarInt( "tf2vrbb_diag_runtime_version" )
	if ( runtimeKind == 0 && runtimeVersion == 0 )
		Hud_SetText( file.diagRuntime, "RUNTIME: NOT REPORTED" )
	else
		Hud_SetText( file.diagRuntime, "RUNTIME: " + TF2VRBB_DiagRuntime( runtimeKind ) + " / " + TF2VRBB_DiagVersion( runtimeVersion ) )
	Hud_SetText( file.diagApi, "APP API " + TF2VRBB_DiagVersion( GetConVarInt( "tf2vrbb_diag_api_version" ) ) )
	Hud_SetText( file.diagProfileLeft, "PROFILE L: " + TF2VRBB_DiagProfile( GetConVarInt( "tf2vrbb_diag_profile_left" ) ) )
	Hud_SetText( file.diagProfileRight, "PROFILE R: " + TF2VRBB_DiagProfile( GetConVarInt( "tf2vrbb_diag_profile_right" ) ) )
	Hud_SetText( file.diagTrackLeft, "TRACK L: " + TF2VRBB_DiagTracking( GetConVarInt( "tf2vrbb_diag_tracking_left" ) ) )
	Hud_SetText( file.diagTrackRight, "TRACK R: " + TF2VRBB_DiagTracking( GetConVarInt( "tf2vrbb_diag_tracking_right" ) ) )
	Hud_SetText( file.diagActionConfig, "CONFIGURED: RELOAD " + TF2VRBB_DiagOnOff( GetConVarInt( "tf2vrbb_reload_grab" ) )
		+ " / CROUCH " + TF2VRBB_DiagOnOff( GetConVarInt( "tf2vrbb_crouch_enabled" ) )
		+ " / TACTICAL " + TF2VRBB_DiagOnOff( GetConVarInt( "tf2vrbb_tactical_enabled" ) ) )
	if ( apiConnected != 1 )
	{
		file.diagStaleFrames = 0
		Hud_SetText( file.diagSample, "SAMPLE: NONE - LAYER NOT PUBLISHING" )
	}
	else if ( sequence != file.diagLastSeq )
	{
		file.diagLastSeq = sequence
		file.diagStaleFrames = 0
		Hud_SetText( file.diagSample, "SAMPLE: LIVE #" + string( sequence ) )
	}
	else
	{
		file.diagStaleFrames += 1
		if ( sequence == file.diagStartSeq && file.diagStaleFrames < 100 )
			Hud_SetText( file.diagSample, "SAMPLE: WAITING FOR NEXT SYNC" )
		else if ( file.diagStaleFrames < 100 )
			Hud_SetText( file.diagSample, "SAMPLE: LIVE #" + string( sequence ) )
		else
			Hud_SetText( file.diagSample, "SAMPLE: STALE - NO NEW SYNC" )
	}

	Hud_SetText( file.diagTriggerLeft, TF2VRBB_DiagInput( "TRIGGER L", "tf2vrbb_diag_trigger_left", "tf2vrbb_diag_trigger_left_active" ) )
	Hud_SetText( file.diagTriggerRight, TF2VRBB_DiagInput( "TRIGGER R", "tf2vrbb_diag_trigger_right", "tf2vrbb_diag_trigger_right_active" ) )
	Hud_SetText( file.diagGripLeft, TF2VRBB_DiagInput( "GRIP L", "tf2vrbb_diag_grip_left", "tf2vrbb_diag_grip_left_active" ) )
	Hud_SetText( file.diagGripRight, TF2VRBB_DiagInput( "GRIP R", "tf2vrbb_diag_grip_right", "tf2vrbb_diag_grip_right_active" ) )
	Hud_SetText( file.diagStickLeft, TF2VRBB_DiagStick( "STICK L", "tf2vrbb_diag_stick_left_x", "tf2vrbb_diag_stick_left_y", "tf2vrbb_diag_stick_left_active" ) )
	Hud_SetText( file.diagStickRight, TF2VRBB_DiagStick( "STICK R", "tf2vrbb_diag_stick_right_x", "tf2vrbb_diag_stick_right_y", "tf2vrbb_diag_stick_right_active" ) )
	Hud_SetText( file.diagStickClick, "STICK CLICK  L " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_stick_click_left" ) )
		+ "  R " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_stick_click_right" ) ) )
	Hud_SetText( file.diagPrimary, "PRIMARY (JUMP)  " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_primary" ) ) )
	Hud_SetText( file.diagCrouch, "CROUCH  " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_crouch" ) ) )
	Hud_SetText( file.diagTactical, "TACTICAL  " + TF2VRBB_DiagAction( GetConVarInt( "tf2vrbb_diag_tactical" ) ) )
	Hud_SetText( file.diagReload, TF2VRBB_DiagReloadLine() )
}

void function TF2VRBB_OnOpenFromMainMenu( var button )
{
	TF2VRBB_RefreshAll()
	AdvanceMenu( GetMenu( TF2VRBB_MENU_ROOT ) )
}

void function TF2VRBB_OnRootOpen()
{
	TF2VRBB_RefreshAll()
	FocusDefaultMenuItem( file.rootMenu )
	thread TF2VRBB_LogRootLayout()
}

void function TF2VRBB_OnDiagnosticsOpen()
{
	file.diagRunId += 1
	file.diagStartSeq = GetConVarInt( "tf2vrbb_diag_seq" )
	file.diagLastSeq = file.diagStartSeq
	file.diagStaleFrames = 0
	SetConVarInt( "tf2vrbb_diag_enabled", 1 )
	TF2VRBB_RefreshDiagnostics()
	FocusDefaultMenuItem( file.diagnosticsMenu )
	thread TF2VRBB_DiagnosticsThink( file.diagRunId )
}

void function TF2VRBB_DiagnosticsThink( int runId )
{
	WaitFrame()
	WaitFrame()
	while ( file.diagRunId == runId && GetActiveMenu() == file.diagnosticsMenu )
	{
		TF2VRBB_RefreshDiagnostics()
		WaitFrame()
		WaitFrame()
	}
	if ( file.diagRunId == runId )
		SetConVarInt( "tf2vrbb_diag_enabled", 0 )
}

void function TF2VRBB_OnListPageOpen()
{
	TF2VRBB_RefreshAll()
}

void function TF2VRBB_OnControlsOpen()
{
	TF2VRBB_OnListPageOpen()
	thread TF2VRBB_LogControlsLayout()
}

void function TF2VRBB_OnActionsOpen()
{
	TF2VRBB_OnListPageOpen()
	thread TF2VRBB_LogActionsLayout()
}

void function TF2VRBB_OnGeneralOpen()
{
	TF2VRBB_OnListPageOpen()
	thread TF2VRBB_LogGeneralLayout()
}

void function TF2VRBB_OnAboutOpen()
{
	TF2VRBB_OnListPageOpen()
	thread TF2VRBB_LogAboutLayout()
}

void function TF2VRBB_OnRestoreOpen()
{
	TF2VRBB_UpdateStorageLabel()
	if ( file.restoreStatus != null )
		Hud_SetText( file.restoreStatus, "" )
	FocusDefaultMenuItem( file.restoreMenu )
	thread TF2VRBB_LogRestoreLayout()
}

// Each button gets its own handler that captures its page index, so no HUD
// property has to be read back at click time.
void function TF2VRBB_BindRootRows()
{
	for ( int i = 0; i < file.rootButtons.len(); i++ )
	{
		int index = i
		var button = file.rootButtons[ i ]
		Hud_AddEventHandler( button, UIE_CLICK,
			void function( var clicked ) : ( index )
			{
				TF2VRBB_OpenRootPage( index )
			} )
	}
}

void function TF2VRBB_BindSettingRows( array<var> buttons, bool sprintRows )
{
	for ( int i = 0; i < buttons.len(); i++ )
	{
		int index = i
		var button = buttons[ i ]
		Hud_AddEventHandler( button, UIE_CLICK,
			void function( var clicked ) : ( index, sprintRows )
			{
				TF2VRBB_OnSettingRowClicked( index, clicked, sprintRows )
			} )
	}
}

void function TF2VRBB_OpenRootPage( int index )
{
	if ( index == 0 )
	{
		AdvanceMenu( GetMenu( TF2VRBB_MENU_CONTROLS ) )
		return
	}
	if ( index == 1 )
	{
		AdvanceMenu( GetMenu( TF2VRBB_MENU_ACTIONS ) )
		return
	}
	if ( index == 2 )
	{
		AdvanceMenu( GetMenu( TF2VRBB_MENU_GENERAL ) )
		return
	}
	if ( index == 3 )
	{
		AdvanceMenu( GetMenu( TF2VRBB_MENU_DIAGNOSTICS ) )
		return
	}
	if ( index == 4 )
	{
		AdvanceMenu( GetMenu( TF2VRBB_MENU_ABOUT ) )
		return
	}
	if ( index == 5 )
	{
		AdvanceMenu( GetMenu( TF2VRBB_MENU_RESTORE ) )
	}
}

void function TF2VRBB_OnSettingRowClicked( int index, var button, bool sprintRows )
{
	if ( sprintRows )
	{
		if ( index < 0 || index >= file.generalRows.len() )
			return
		TF2VRBB_CycleRow( file.generalRows[ index ], button )
		TF2VRBB_ValidateSprint()
		TF2VRBB_RefreshRows( file.generalButtons, file.generalRows )
		return
	}

	if ( index < 0 || index >= file.actionRows.len() )
		return
	TF2VRBB_CycleRow( file.actionRows[ index ], button )
}

void function TF2VRBB_OnRestoreConfirmed( var button )
{
	for ( int i = 0; i < file.actionRows.len(); i++ )
		SetConVarInt( file.actionRows[ i ].conVar, file.actionRows[ i ].defaultValue )

	for ( int i = 0; i < file.generalRows.len(); i++ )
		SetConVarInt( file.generalRows[ i ].conVar, file.generalRows[ i ].defaultValue )

	TF2VRBB_RefreshRows( file.actionButtons, file.actionRows )
	TF2VRBB_RefreshRows( file.generalButtons, file.generalRows )
	TF2VRBB_ShowSaved()

	if ( file.restoreStatus != null )
		Hud_SetText( file.restoreStatus, "DEFAULTS RESTORED" )
}

void function TF2VRBB_OnBackButton( var button )
{
	CloseActiveMenu( true )
}
