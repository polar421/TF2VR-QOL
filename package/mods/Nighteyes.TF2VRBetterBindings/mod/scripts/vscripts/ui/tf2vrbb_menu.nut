// TF2VR Better Bindings - in-game settings menu.
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
const string TF2VRBB_VERSION = "1.3.0"

const string TF2VRBB_MENU_ROOT = "TF2VRBBRoot"
const string TF2VRBB_MENU_CONTROLS = "TF2VRBBControls"
const string TF2VRBB_MENU_ACTIONS = "TF2VRBBActions"
const string TF2VRBB_MENU_GENERAL = "TF2VRBBGeneral"
const string TF2VRBB_MENU_ABOUT = "TF2VRBBAbout"
const string TF2VRBB_MENU_RESTORE = "TF2VRBBRestore"

// Set to 1 by the 1.3.0 plugin once it can read and write the ini.
const string TF2VRBB_API_CONVAR = "tf2vrbb_settings_api"

const int TF2VRBB_ACTION_ROW_COUNT = 8
const int TF2VRBB_GENERAL_ROW_COUNT = 3
const int TF2VRBB_ROOT_ROW_COUNT = 5

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

	var rootStatus
	var actionStatus
	var generalStatus
	var restoreStatus
	var aboutStorage
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
}

// Runs after every menu exists and is created, so footers can be added to the
// vanilla main menu. GetMenu returns null for menus that are not registered.
void function TF2VRBB_AddMainMenuFooter()
{
	var mainMenu = GetMenu( "MainMenu" )
	if ( mainMenu == null )
		return

	AddMenuFooterOption( mainMenu, BUTTON_X, "%[X_BUTTON|]% TF2VR Better Bindings", "TF2VR Better Bindings",
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
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row3", "ABOUT" )
	TF2VRBB_SetButtonLabel( file.rootMenu, "Row4", "RESTORE DEFAULTS" )

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
	AddMenuEventHandler( file.controlsMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnListPageOpen )
}

void function TF2VRBB_InitActions()
{
	file.actionsMenu = GetMenu( TF2VRBB_MENU_ACTIONS )
	file.actionStatus = Hud_GetChild( file.actionsMenu, "Status" )
	file.actionButtons = TF2VRBB_GetRowButtons( file.actionsMenu, TF2VRBB_ACTION_ROW_COUNT )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchReloadGrab", "RELOAD GRAB" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchGrenadeToggle", "GRENADE TOGGLE" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchCrouchAction", "CROUCH ACTION" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchCrouchMode", "CROUCH MODE" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchUncrouchOnJump", "UNCROUCH ON JUMP" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchJumpDelay", "JUMP DELAY" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchTacticalAction", "TACTICAL ACTION" )
	TF2VRBB_SetButtonLabel( file.actionsMenu, "SwitchTacticalBlockTrigger", "TACTICAL BLOCKS HAND TRIGGER" )

	TF2VRBB_WireNav( file.actionButtons )
	TF2VRBB_BindSettingRows( file.actionButtons, false )

	AddMenuFooterOption( file.actionsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.actionsMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnListPageOpen )
}

void function TF2VRBB_InitGeneral()
{
	file.generalMenu = GetMenu( TF2VRBB_MENU_GENERAL )
	file.generalStatus = Hud_GetChild( file.generalMenu, "Status" )
	file.generalButtons = TF2VRBB_GetRowButtons( file.generalMenu, TF2VRBB_GENERAL_ROW_COUNT )
	TF2VRBB_SetButtonLabel( file.generalMenu, "SwitchSprintAction", "SPRINT ACTION" )
	TF2VRBB_SetButtonLabel( file.generalMenu, "SwitchSprintStart", "SPRINT START HEIGHT" )
	TF2VRBB_SetButtonLabel( file.generalMenu, "SwitchSprintStop", "SPRINT STOP HEIGHT" )

	TF2VRBB_WireNav( file.generalButtons )
	TF2VRBB_BindSettingRows( file.generalButtons, true )

	AddMenuFooterOption( file.generalMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.generalMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnListPageOpen )
}

void function TF2VRBB_InitAbout()
{
	file.aboutMenu = GetMenu( TF2VRBB_MENU_ABOUT )
	file.aboutStorage = Hud_GetChild( file.aboutMenu, "StorageLabel" )

	Hud_SetText( Hud_GetChild( file.aboutMenu, "VersionLabel" ), "TF2VR BETTER BINDINGS " + TF2VRBB_VERSION )
	Hud_AddEventHandler( Hud_GetChild( file.aboutMenu, "BtnBack" ), UIE_CLICK, TF2VRBB_OnBackButton )

	AddMenuFooterOption( file.aboutMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	AddMenuEventHandler( file.aboutMenu, eUIEvent.MENU_OPEN, TF2VRBB_OnListPageOpen )
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
			continue
		buttons.append( button )
	}
	return buttons
}

void function TF2VRBB_SetButtonLabel( var menu, string childName, string label )
{
	var button = Hud_GetChild( menu, childName )
	if ( button != null )
		SetButtonRuiText( button, label )
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

void function TF2VRBB_OnOpenFromMainMenu( var button )
{
	TF2VRBB_RefreshAll()
	AdvanceMenu( GetMenu( TF2VRBB_MENU_ROOT ) )
}

void function TF2VRBB_OnRootOpen()
{
	TF2VRBB_RefreshAll()
	FocusDefaultMenuItem( file.rootMenu )
}

void function TF2VRBB_OnListPageOpen()
{
	TF2VRBB_RefreshAll()
}

void function TF2VRBB_OnRestoreOpen()
{
	TF2VRBB_UpdateStorageLabel()
	if ( file.restoreStatus != null )
		Hud_SetText( file.restoreStatus, "" )
	FocusDefaultMenuItem( file.restoreMenu )
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
		AdvanceMenu( GetMenu( TF2VRBB_MENU_ABOUT ) )
		return
	}
	if ( index == 4 )
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
