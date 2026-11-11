// TF2VR Campaign Sandbox - UI VM.
//
// The pause entry is appended to InGameSPMenu, the campaign pause menu. The
// UI only reads status ConVars and asks the SERVER VM to act through client
// commands. It never changes world entities directly.
//
// Status ConVars are written by tf2vrsb_server.nut.

global function TF2VRSB_AddSandboxMenus
global function TF2VRSB_AddPauseEntry

const string TF2VRSB_VERSION = "1.5.0"
const string TF2VRSB_PAUSE_MENU = "InGameSPMenu"

const string TF2VRSB_ROOT = "TF2VRSBSandboxRoot"
const string TF2VRSB_MAPS = "TF2VRSBSandboxMaps"
const string TF2VRSB_NPCS = "TF2VRSBSandboxNpcs"
const string TF2VRSB_PLAYER = "TF2VRSBSandboxPlayer"
const string TF2VRSB_PRESETS = "TF2VRSBSandboxPresets"
const string TF2VRSB_DEVELOPER = "TF2VRSBSandboxDeveloper"

const string TF2VRSB_RESULT = "tf2vrsb_result"
const string TF2VRSB_MAP = "tf2vrsb_map"
const string TF2VRSB_MODE = "tf2vrsb_mode"
const string TF2VRSB_READY = "tf2vrsb_ready"
const string TF2VRSB_X = "tf2vrsb_x"
const string TF2VRSB_Y = "tf2vrsb_y"
const string TF2VRSB_Z = "tf2vrsb_z"
const string TF2VRSB_YAW = "tf2vrsb_yaw"
const string TF2VRSB_NPC_COUNT = "tf2vrsb_npc_count"
const string TF2VRSB_ENTITY_COUNT = "tf2vrsb_entity_count"
const string TF2VRSB_MANAGED_COUNT = "tf2vrsb_managed_count"
const string TF2VRSB_BOOKMARK = "tf2vrsb_bookmark"
const string TF2VRSB_FLY = "tf2vrsb_fly"
const string TF2VRSB_DEBUG = "tf2vrsb_debug"

const string TF2VRSB_REQUEST_MAP = "tf2vrsb_request_map"
const string TF2VRSB_REQUEST_X = "tf2vrsb_request_x"
const string TF2VRSB_REQUEST_Y = "tf2vrsb_request_y"
const string TF2VRSB_REQUEST_Z = "tf2vrsb_request_z"
const string TF2VRSB_REQUEST_YAW = "tf2vrsb_request_yaw"

struct
{
	var rootMenu
	var mapsMenu
	var npcsMenu
	var playerMenu
	var presetsMenu
	var developerMenu

	array<var> rootButtons
	array<var> mapButtons
	array<var> npcButtons
	array<var> playerButtons
	array<var> presetButtons
	array<var> developerButtons

	array<string> mapIds
	array<string> mapNames

	var rootSession
	var rootMap
	var rootCounts
	var rootStatus

	var mapsCurrent
	var mapsDetails
	var mapsStatus

	var npcManaged
	var npcStatus

	var playerBookmark
	var playerPosition
	var playerStatus

	var presetStatus
	var presetSlot0
	var presetSlot1
	var presetSlot2

	var devMap
	var devMode
	var devPosition
	var devCounts
	var devCap
	var devLimits

	int selectedMap
	bool clearArmed
	string lastLoggedResult

	string activeLayoutPage
	var activeLayoutMenu
} file

////////////////////////////////////////////////////////////////////////////////
// Registration
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_AddSandboxMenus()
{
	AddMenu( TF2VRSB_ROOT, $"resource/ui/menus/tf2vrsb_root.menu", TF2VRSB_InitRoot )
	AddMenu( TF2VRSB_MAPS, $"resource/ui/menus/tf2vrsb_maps.menu", TF2VRSB_InitMaps )
	AddMenu( TF2VRSB_NPCS, $"resource/ui/menus/tf2vrsb_npcs.menu", TF2VRSB_InitNpcs )
	AddMenu( TF2VRSB_PLAYER, $"resource/ui/menus/tf2vrsb_player.menu", TF2VRSB_InitPlayer )
	AddMenu( TF2VRSB_PRESETS, $"resource/ui/menus/tf2vrsb_presets.menu", TF2VRSB_InitPresets )
	AddMenu( TF2VRSB_DEVELOPER, $"resource/ui/menus/tf2vrsb_developer.menu", TF2VRSB_InitDeveloper )

	print( "[TF2VRSB] sandbox menus registered\n" )
}

void function TF2VRSB_AddPauseEntry()
{
	var pauseMenu = GetMenu( TF2VRSB_PAUSE_MENU )
	if ( pauseMenu == null )
	{
		print( "[TF2VRSB] InGameSPMenu is not registered; sandbox pause entry unavailable\n" )
		return
	}

	AddMenuFooterOption( pauseMenu, BUTTON_Y,
		PrependControllerPrompts( BUTTON_Y, " SANDBOX / DEV TOOLS" ),
		"SANDBOX / DEV TOOLS",
		TF2VRSB_OpenSandbox )

	print( "[TF2VRSB] sandbox pause entry registered on " + TF2VRSB_PAUSE_MENU + "\n" )
}

void function TF2VRSB_OpenSandbox( var button )
{
	TF2VRSB_LogEvent( "menu-open", "pause-footer" )
	TF2VRSB_RequestStatus()
	AdvanceMenu( GetMenu( TF2VRSB_ROOT ) )
}

////////////////////////////////////////////////////////////////////////////////
// Root
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_InitRoot()
{
	file.rootMenu = GetMenu( TF2VRSB_ROOT )
	file.rootSession = Hud_GetChild( file.rootMenu, "SessionValue" )
	file.rootMap = Hud_GetChild( file.rootMenu, "MapValue" )
	file.rootCounts = Hud_GetChild( file.rootMenu, "CountValue" )
	file.rootStatus = Hud_GetChild( file.rootMenu, "Status" )
	file.rootButtons = TF2VRSB_GetButtons( file.rootMenu, "Row", 6 )

	TF2VRSB_SetButtonLabel( file.rootMenu, "Row0", "MAPS & ENVIRONMENTS" )
	TF2VRSB_SetButtonLabel( file.rootMenu, "Row1", "NPC SANDBOX" )
	TF2VRSB_SetButtonLabel( file.rootMenu, "Row2", "PLAYER UTILITIES" )
	TF2VRSB_SetButtonLabel( file.rootMenu, "Row3", "DEVELOPER INFORMATION" )
	TF2VRSB_SetButtonLabel( file.rootMenu, "Row4", "POSITION PRESETS" )
	TF2VRSB_SetButtonLabel( file.rootMenu, "Row5", "CLOSE SANDBOX" )

	TF2VRSB_WireVertical( file.rootButtons )
	for ( int i = 0; i < file.rootButtons.len(); i++ )
	{
		int index = i
		var button = file.rootButtons[ i ]
		Hud_AddEventHandler( button, UIE_CLICK,
			void function( var clicked ) : ( index )
			{
				TF2VRSB_OnRootRow( index )
			} )
	}
	AddMenuFooterOption( file.rootMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_AddLayoutFooter( file.rootMenu )
	AddMenuEventHandler( file.rootMenu, eUIEvent.MENU_OPEN, TF2VRSB_OnRootOpen )
}

void function TF2VRSB_OnRootRow( int index )
{
	TF2VRSB_LogEvent( "navigate", "root row=" + string( index ) )
	switch ( index )
	{
		case 0:
			AdvanceMenu( GetMenu( TF2VRSB_MAPS ) )
			break
		case 1:
			AdvanceMenu( GetMenu( TF2VRSB_NPCS ) )
			break
		case 2:
			AdvanceMenu( GetMenu( TF2VRSB_PLAYER ) )
			break
		case 3:
			AdvanceMenu( GetMenu( TF2VRSB_DEVELOPER ) )
			break
		case 4:
			AdvanceMenu( GetMenu( TF2VRSB_PRESETS ) )
			break
		case 5:
			CloseActiveMenu( true )
			break
	}
}

void function TF2VRSB_OnRootOpen()
{
	TF2VRSB_LogEvent( "menu-open", "root" )
	TF2VRSB_RequestStatus()
	FocusDefaultMenuItem( file.rootMenu )
	thread TF2VRSB_LogRootLayout( file.rootMenu )
}

////////////////////////////////////////////////////////////////////////////////
// Map catalog
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_InitMaps()
{
	file.mapsMenu = GetMenu( TF2VRSB_MAPS )
	file.mapsCurrent = Hud_GetChild( file.mapsMenu, "CurrentMapValue" )
	file.mapsDetails = Hud_GetChild( file.mapsMenu, "MapDetails" )
	file.mapsStatus = Hud_GetChild( file.mapsMenu, "MapStatus" )
	file.mapButtons = TF2VRSB_GetButtons( file.mapsMenu, "Map", 13 )

	array<string> ids = [
		"sp_training", "sp_crashsite", "sp_sewers1", "sp_boomtown_start",
		"sp_boomtown", "sp_boomtown_end", "sp_hub_timeshift", "sp_timeshift_spoke02",
		"sp_beacon", "sp_beacon_spoke0", "sp_tday", "sp_s2s", "sp_skyway_v1"
	]
	array<string> names = [
		"TRAINING", "CRASH SITE", "SEWERS", "BOOMTOWN // START",
		"BOOMTOWN", "BOOMTOWN // END", "TIMESHIFT HUB", "TIMESHIFT SPOKE",
		"BEACON", "BEACON SPOKE", "T-DAY", "S2S", "SKYWAY"
	]
	file.mapIds = ids
	file.mapNames = names

	for ( int i = 0; i < file.mapButtons.len() && i < names.len(); i++ )
		SetButtonRuiText( file.mapButtons[ i ], names[ i ] )

	TF2VRSB_WireVertical( file.mapButtons )
	for ( int i = 0; i < file.mapButtons.len(); i++ )
	{
		int index = i
		var button = file.mapButtons[ i ]
		Hud_AddEventHandler( button, UIE_CLICK,
			void function( var clicked ) : ( index )
			{
				TF2VRSB_SelectMap( index )
			} )
	}
	AddMenuFooterOption( file.mapsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_AddLayoutFooter( file.mapsMenu )
	AddMenuEventHandler( file.mapsMenu, eUIEvent.MENU_OPEN, TF2VRSB_OnMapsOpen )
}

void function TF2VRSB_OnMapsOpen()
{
	TF2VRSB_LogEvent( "menu-open", "maps" )
	TF2VRSB_RequestStatus()
	TF2VRSB_SelectMap( file.selectedMap )
	FocusDefaultMenuItem( file.mapsMenu )
	thread TF2VRSB_LogMapsLayout( file.mapsMenu )
}

void function TF2VRSB_SelectMap( int index )
{
	if ( index < 0 || index >= file.mapIds.len() )
		return
	file.selectedMap = index
	TF2VRSB_LogEvent( "map-select", "index=" + string( index ) + " id=" + file.mapIds[ index ] )

	string current = GetConVarString( TF2VRSB_MAP )
	string id = file.mapIds[ index ]
	string text = file.mapNames[ index ] + "  [" + id + "]\n"
	if ( id == current )
		text += "CURRENT SESSION MAP\n"
	else
		text += "CATALOG CANDIDATE - NOT LOADED BY THIS BUILD\n"
	text += "Map travel is disabled until campaign transitions are runtime-tested."

	if ( file.mapsDetails != null )
		Hud_SetText( file.mapsDetails, text )
	TF2VRSB_UpdateMapButtons()
}

void function TF2VRSB_UpdateMapButtons()
{
	string current = GetConVarString( TF2VRSB_MAP )
	for ( int i = 0; i < file.mapButtons.len() && i < file.mapNames.len(); i++ )
	{
		string label = file.mapNames[ i ]
		if ( file.mapIds[ i ] == current )
			label = "> " + label
		SetButtonRuiText( file.mapButtons[ i ], label )
	}

	if ( file.mapsCurrent != null )
		Hud_SetText( file.mapsCurrent, "CURRENT MAP: " + TF2VRSB_DisplayMap( current ) + "  [" + current + "]" )
}

////////////////////////////////////////////////////////////////////////////////
// NPC sandbox
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_InitNpcs()
{
	file.npcsMenu = GetMenu( TF2VRSB_NPCS )
	file.npcManaged = Hud_GetChild( file.npcsMenu, "ManagedValue" )
	file.npcStatus = Hud_GetChild( file.npcsMenu, "NpcStatus" )

	var spawnSoldier = Hud_GetChild( file.npcsMenu, "SpawnHostileSoldier" )
	var spawnSpectre = Hud_GetChild( file.npcsMenu, "SpawnHostileSpectre" )
	var spawnFriendly = Hud_GetChild( file.npcsMenu, "SpawnFriendlySoldier" )
	var clearManaged = Hud_GetChild( file.npcsMenu, "ClearManaged" )
	var capSwitch = Hud_GetChild( file.npcsMenu, "SwitchNpcCap" )
	var distanceSwitch = Hud_GetChild( file.npcsMenu, "SwitchSpawnDistance" )
	var backButton = Hud_GetChild( file.npcsMenu, "BtnBack" )

	TF2VRSB_SetButtonLabel( file.npcsMenu, "SpawnHostileSoldier", "SPAWN HOSTILE IMC SOLDIER" )
	TF2VRSB_SetButtonLabel( file.npcsMenu, "SpawnHostileSpectre", "SPAWN HOSTILE IMC SPECTRE" )
	TF2VRSB_SetButtonLabel( file.npcsMenu, "SpawnFriendlySoldier", "SPAWN FRIENDLY SOLDIER" )
	TF2VRSB_SetButtonLabel( file.npcsMenu, "ClearManaged", "CLEAR MANAGED NPCs" )
	TF2VRSB_SetButtonLabel( file.npcsMenu, "BtnBack", "BACK TO MISSION CONTROL" )

	Hud_AddEventHandler( spawnSoldier, UIE_CLICK, TF2VRSB_OnSpawnHostileSoldier )
	Hud_AddEventHandler( spawnSpectre, UIE_CLICK, TF2VRSB_OnSpawnHostileSpectre )
	Hud_AddEventHandler( spawnFriendly, UIE_CLICK, TF2VRSB_OnSpawnFriendlySoldier )
	Hud_AddEventHandler( clearManaged, UIE_CLICK, TF2VRSB_OnClearManaged )
	Hud_AddEventHandler( backButton, UIE_CLICK, TF2VRSB_OnBack )

	file.npcButtons = []
	file.npcButtons.append( spawnSoldier )
	file.npcButtons.append( spawnSpectre )
	file.npcButtons.append( spawnFriendly )
	file.npcButtons.append( clearManaged )
	file.npcButtons.append( capSwitch )
	file.npcButtons.append( distanceSwitch )
	file.npcButtons.append( backButton )
	TF2VRSB_WireVertical( file.npcButtons )

	AddMenuFooterOption( file.npcsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_AddLayoutFooter( file.npcsMenu )
	AddMenuEventHandler( file.npcsMenu, eUIEvent.MENU_OPEN, TF2VRSB_OnNpcsOpen )
}

void function TF2VRSB_OnNpcsOpen()
{
	file.clearArmed = false
	TF2VRSB_SetButtonLabel( file.npcsMenu, "ClearManaged", "CLEAR MANAGED NPCs" )
	TF2VRSB_LogEvent( "menu-open", "npcs" )
	TF2VRSB_RequestStatus()
	FocusDefaultMenuItem( file.npcsMenu )
	thread TF2VRSB_LogNpcsLayout( file.npcsMenu )
}

void function TF2VRSB_OnSpawnHostileSoldier( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_spawn_imc_soldier", "SPAWNING HOSTILE SOLDIER" )
}

void function TF2VRSB_OnSpawnHostileSpectre( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_spawn_imc_spectre", "SPAWNING HOSTILE SPECTRE" )
}

void function TF2VRSB_OnSpawnFriendlySoldier( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_spawn_friendly_soldier", "SPAWNING FRIENDLY SOLDIER" )
}

void function TF2VRSB_OnClearManaged( var button )
{
	if ( !file.clearArmed )
	{
		file.clearArmed = true
		TF2VRSB_SetButtonLabel( file.npcsMenu, "ClearManaged", "CONFIRM: CLEAR MANAGED NPCs" )
		SetConVarString( TF2VRSB_RESULT, "CLICK AGAIN TO REMOVE ONLY SANDBOX NPCs" )
		TF2VRSB_UpdateStatusLabels()
		thread TF2VRSB_DisarmClearAfterTime()
		return
	}

	file.clearArmed = false
	TF2VRSB_SetButtonLabel( file.npcsMenu, "ClearManaged", "CLEAR MANAGED NPCs" )
	TF2VRSB_BeginAction( "tf2vrsb_clear_managed", "CLEARING MANAGED NPCs" )
}

void function TF2VRSB_DisarmClearAfterTime()
{
	for ( int i = 0; i < 180; i++ )
	{
		if ( !file.clearArmed )
			return
		WaitFrame()
	}
	file.clearArmed = false
	TF2VRSB_SetButtonLabel( file.npcsMenu, "ClearManaged", "CLEAR MANAGED NPCs" )
}

////////////////////////////////////////////////////////////////////////////////
// Player utilities
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_InitPlayer()
{
	file.playerMenu = GetMenu( TF2VRSB_PLAYER )
	file.playerBookmark = Hud_GetChild( file.playerMenu, "BookmarkValue" )
	file.playerPosition = Hud_GetChild( file.playerMenu, "PositionValue" )
	file.playerStatus = Hud_GetChild( file.playerMenu, "Status" )

	var saveButton = Hud_GetChild( file.playerMenu, "SaveBookmark" )
	var returnButton = Hud_GetChild( file.playerMenu, "ReturnBookmark" )
	var clearButton = Hud_GetChild( file.playerMenu, "ClearBookmark" )
	var flyButton = Hud_GetChild( file.playerMenu, "ToggleFly" )
	var backButton = Hud_GetChild( file.playerMenu, "BtnBack" )

	TF2VRSB_SetButtonLabel( file.playerMenu, "SaveBookmark", "SAVE POSITION BOOKMARK" )
	TF2VRSB_SetButtonLabel( file.playerMenu, "ReturnBookmark", "RETURN TO POSITION BOOKMARK" )
	TF2VRSB_SetButtonLabel( file.playerMenu, "ClearBookmark", "CLEAR POSITION BOOKMARK" )
	TF2VRSB_SetButtonLabel( file.playerMenu, "ToggleFly", "FLY (NOCLIP): OFF - TAP TO FLY" )
	TF2VRSB_SetButtonLabel( file.playerMenu, "BtnBack", "BACK TO MISSION CONTROL" )

	Hud_AddEventHandler( saveButton, UIE_CLICK, TF2VRSB_OnSaveBookmark )
	Hud_AddEventHandler( returnButton, UIE_CLICK, TF2VRSB_OnReturnBookmark )
	Hud_AddEventHandler( clearButton, UIE_CLICK, TF2VRSB_OnClearBookmark )
	Hud_AddEventHandler( flyButton, UIE_CLICK, TF2VRSB_OnToggleFly )
	Hud_AddEventHandler( backButton, UIE_CLICK, TF2VRSB_OnBack )

	file.playerButtons = []
	file.playerButtons.append( saveButton )
	file.playerButtons.append( returnButton )
	file.playerButtons.append( clearButton )
	file.playerButtons.append( flyButton )
	file.playerButtons.append( backButton )
	TF2VRSB_WireVertical( file.playerButtons )

	AddMenuFooterOption( file.playerMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_AddLayoutFooter( file.playerMenu )
	AddMenuEventHandler( file.playerMenu, eUIEvent.MENU_OPEN, TF2VRSB_OnPlayerOpen )
}

void function TF2VRSB_OnPlayerOpen()
{
	TF2VRSB_LogEvent( "menu-open", "player" )
	TF2VRSB_RequestStatus()
	FocusDefaultMenuItem( file.playerMenu )
	thread TF2VRSB_LogPlayerLayout( file.playerMenu )
}

void function TF2VRSB_OnSaveBookmark( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_save_bookmark", "SAVING POSITION BOOKMARK" )
}

void function TF2VRSB_OnReturnBookmark( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_return_bookmark", "RETURNING TO BOOKMARK" )
}

void function TF2VRSB_OnClearBookmark( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_clear_bookmark", "CLEARING POSITION BOOKMARK" )
}

void function TF2VRSB_OnToggleFly( var button )
{
	TF2VRSB_BeginAction( "tf2vrsb_toggle_fly", "TOGGLING NOCLIP FLY" )
}

////////////////////////////////////////////////////////////////////////////////
// Position presets (Safe I/O, mod-scoped)
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_InitPresets()
{
	file.presetsMenu = GetMenu( TF2VRSB_PRESETS )
	file.presetStatus = Hud_GetChild( file.presetsMenu, "PresetStatus" )
	file.presetSlot0 = Hud_GetChild( file.presetsMenu, "Slot0Status" )
	file.presetSlot1 = Hud_GetChild( file.presetsMenu, "Slot1Status" )
	file.presetSlot2 = Hud_GetChild( file.presetsMenu, "Slot2Status" )

	var save1 = Hud_GetChild( file.presetsMenu, "Save1" )
	var load1 = Hud_GetChild( file.presetsMenu, "Load1" )
	var save2 = Hud_GetChild( file.presetsMenu, "Save2" )
	var load2 = Hud_GetChild( file.presetsMenu, "Load2" )
	var save3 = Hud_GetChild( file.presetsMenu, "Save3" )
	var load3 = Hud_GetChild( file.presetsMenu, "Load3" )
	var backButton = Hud_GetChild( file.presetsMenu, "BtnBack" )

	TF2VRSB_SetButtonLabel( file.presetsMenu, "Save1", "SAVE CURRENT POSITION TO SLOT 1" )
	TF2VRSB_SetButtonLabel( file.presetsMenu, "Save2", "SAVE CURRENT POSITION TO SLOT 2" )
	TF2VRSB_SetButtonLabel( file.presetsMenu, "Save3", "SAVE CURRENT POSITION TO SLOT 3" )
	TF2VRSB_SetButtonLabel( file.presetsMenu, "Load1", "LOAD POSITION FROM SLOT 1" )
	TF2VRSB_SetButtonLabel( file.presetsMenu, "Load2", "LOAD POSITION FROM SLOT 2" )
	TF2VRSB_SetButtonLabel( file.presetsMenu, "Load3", "LOAD POSITION FROM SLOT 3" )
	TF2VRSB_SetButtonLabel( file.presetsMenu, "BtnBack", "BACK TO MISSION CONTROL" )

	TF2VRSB_BindPresetButton( save1, 1, true )
	TF2VRSB_BindPresetButton( load1, 1, false )
	TF2VRSB_BindPresetButton( save2, 2, true )
	TF2VRSB_BindPresetButton( load2, 2, false )
	TF2VRSB_BindPresetButton( save3, 3, true )
	TF2VRSB_BindPresetButton( load3, 3, false )
	Hud_AddEventHandler( backButton, UIE_CLICK, TF2VRSB_OnBack )

	file.presetButtons = []
	file.presetButtons.append( save1 )
	file.presetButtons.append( load1 )
	file.presetButtons.append( save2 )
	file.presetButtons.append( load2 )
	file.presetButtons.append( save3 )
	file.presetButtons.append( load3 )
	file.presetButtons.append( backButton )
	TF2VRSB_WireVertical( file.presetButtons )

	AddMenuFooterOption( file.presetsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_AddLayoutFooter( file.presetsMenu )
	AddMenuEventHandler( file.presetsMenu, eUIEvent.MENU_OPEN, TF2VRSB_OnPresetsOpen )
}

void function TF2VRSB_OnPresetsOpen()
{
	TF2VRSB_LogEvent( "menu-open", "presets" )
	TF2VRSB_RequestStatus()
	TF2VRSB_UpdatePresetLabels()
	FocusDefaultMenuItem( file.presetsMenu )
	thread TF2VRSB_LogPresetsLayout( file.presetsMenu )
}

string function TF2VRSB_PresetPath( int slot )
{
	return "sandbox_position_" + string( slot ) + ".txt"
}

void function TF2VRSB_OnSavePreset( int slot )
{
	if ( GetConVarInt( TF2VRSB_READY ) != 1 )
	{
		SetConVarString( TF2VRSB_RESULT, "NO SESSION - POSITION NOT SAVED" )
		TF2VRSB_UpdateStatusLabels()
		return
	}
	thread TF2VRSB_SavePresetThread( slot )
}

void function TF2VRSB_SavePresetThread( int slot )
{
	string path = TF2VRSB_PresetPath( slot )
	string payload = GetConVarString( TF2VRSB_MAP ) + " " + GetConVarString( TF2VRSB_X ) + " "
		+ GetConVarString( TF2VRSB_Y ) + " " + GetConVarString( TF2VRSB_Z ) + " "
		+ GetConVarString( TF2VRSB_YAW )

	NSSaveFile( path, payload )
	WaitFrame()
	if ( NSDoesFileExist( path ) )
		SetConVarString( TF2VRSB_RESULT, "POSITION PRESET " + string( slot ) + " SAVED" )
	else
		SetConVarString( TF2VRSB_RESULT, "SAVE FAILED - SAFE I/O UNAVAILABLE" )

	TF2VRSB_UpdatePresetLabels()
	TF2VRSB_UpdateStatusLabels()
}

void function TF2VRSB_OnLoadPreset( int slot )
{
	string path = TF2VRSB_PresetPath( slot )
	if ( !NSDoesFileExist( path ) )
	{
		SetConVarString( TF2VRSB_RESULT, "POSITION PRESET " + string( slot ) + " IS EMPTY" )
		TF2VRSB_UpdateStatusLabels()
		return
	}
	SetConVarString( TF2VRSB_RESULT, "LOADING POSITION PRESET " + string( slot ) )
	NSLoadFile( path, TF2VRSB_OnPresetLoaded, TF2VRSB_OnPresetLoadFailed )
	TF2VRSB_UpdateStatusLabels()
}

void function TF2VRSB_OnPresetLoaded( string content )
{
	array<string> parts = split( content, " " )
	if ( parts.len() < 5 )
	{
		SetConVarString( TF2VRSB_RESULT, "PRESET INVALID - NO CHANGES MADE" )
		TF2VRSB_UpdateStatusLabels()
		return
	}

	string mapName = parts[ 0 ]
	if ( mapName != GetConVarString( TF2VRSB_MAP ) )
	{
		SetConVarString( TF2VRSB_RESULT, "PRESET BELONGS TO ANOTHER MAP" )
		TF2VRSB_UpdateStatusLabels()
		return
	}

	SetConVarString( TF2VRSB_REQUEST_MAP, parts[ 0 ] )
	SetConVarString( TF2VRSB_REQUEST_X, parts[ 1 ] )
	SetConVarString( TF2VRSB_REQUEST_Y, parts[ 2 ] )
	SetConVarString( TF2VRSB_REQUEST_Z, parts[ 3 ] )
	SetConVarString( TF2VRSB_REQUEST_YAW, parts[ 4 ] )
	TF2VRSB_LogEvent( "preset-load", "slot map=" + mapName + " xyz=" + parts[ 1 ] + "," + parts[ 2 ] + "," + parts[ 3 ] )
	RunClientScript( "TF2VRSB_SendCommand", "tf2vrsb_load_preset" )
	thread TF2VRSB_RefreshAfterFrames( 8 )
}

void function TF2VRSB_OnPresetLoadFailed()
{
	TF2VRSB_LogEvent( "preset-load-failed", "Safe I/O callback" )
	SetConVarString( TF2VRSB_RESULT, "PRESET COULD NOT BE READ - NO CHANGES MADE" )
	TF2VRSB_UpdateStatusLabels()
}

void function TF2VRSB_UpdatePresetLabels()
{
	if ( file.presetsMenu == null )
		return

	if ( file.presetSlot0 != null )
		Hud_SetText( file.presetSlot0, TF2VRSB_PresetStatusText( 1 ) )
	if ( file.presetSlot1 != null )
		Hud_SetText( file.presetSlot1, TF2VRSB_PresetStatusText( 2 ) )
	if ( file.presetSlot2 != null )
		Hud_SetText( file.presetSlot2, TF2VRSB_PresetStatusText( 3 ) )
}

string function TF2VRSB_PresetStatusText( int slot )
{
	return "SLOT " + string( slot ) + ": " + ( NSDoesFileExist( TF2VRSB_PresetPath( slot ) ) ? "SAVED POSITION" : "EMPTY" )
}

////////////////////////////////////////////////////////////////////////////////
// Developer information
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_InitDeveloper()
{
	file.developerMenu = GetMenu( TF2VRSB_DEVELOPER )
	file.devMap = Hud_GetChild( file.developerMenu, "MapValue" )
	file.devMode = Hud_GetChild( file.developerMenu, "ModeValue" )
	file.devPosition = Hud_GetChild( file.developerMenu, "PositionValue" )
	file.devCounts = Hud_GetChild( file.developerMenu, "CountsValue" )
	file.devCap = Hud_GetChild( file.developerMenu, "CapValue" )
	file.devLimits = Hud_GetChild( file.developerMenu, "LimitsValue" )

	var logLayoutButton = Hud_GetChild( file.developerMenu, "LogLayout" )
	var refreshButton = Hud_GetChild( file.developerMenu, "Refresh" )
	var debugSwitch = Hud_GetChild( file.developerMenu, "SwitchDebug" )
	var backButton = Hud_GetChild( file.developerMenu, "BtnBack" )
	TF2VRSB_SetButtonLabel( file.developerMenu, "LogLayout", "LOG CURRENT LAYOUT TO NSLOG" )
	TF2VRSB_SetButtonLabel( file.developerMenu, "Refresh", "REFRESH SESSION TELEMETRY" )
	TF2VRSB_SetButtonLabel( file.developerMenu, "BtnBack", "BACK TO MISSION CONTROL" )
	Hud_AddEventHandler( logLayoutButton, UIE_CLICK, TF2VRSB_OnLogLayout )
	Hud_AddEventHandler( refreshButton, UIE_CLICK, TF2VRSB_OnRefreshDeveloper )
	Hud_AddEventHandler( backButton, UIE_CLICK, TF2VRSB_OnBack )

	file.developerButtons = []
	file.developerButtons.append( logLayoutButton )
	file.developerButtons.append( refreshButton )
	file.developerButtons.append( debugSwitch )
	file.developerButtons.append( backButton )
	TF2VRSB_WireVertical( file.developerButtons )

	AddMenuFooterOption( file.developerMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_AddLayoutFooter( file.developerMenu )
	AddMenuEventHandler( file.developerMenu, eUIEvent.MENU_OPEN, TF2VRSB_OnDeveloperOpen )
}

void function TF2VRSB_OnDeveloperOpen()
{
	TF2VRSB_LogEvent( "menu-open", "developer" )
	TF2VRSB_RequestStatus()
	FocusDefaultMenuItem( file.developerMenu )
	thread TF2VRSB_LogDeveloperLayout( file.developerMenu )
}

void function TF2VRSB_OnRefreshDeveloper( var button )
{
	TF2VRSB_LogEvent( "telemetry-refresh", "developer" )
	TF2VRSB_RequestStatus()
}

void function TF2VRSB_OnLogLayout( var button )
{
	if ( GetConVarInt( TF2VRSB_DEBUG ) != 1 )
	{
		SetConVarString( TF2VRSB_RESULT, "DEBUG LOGGING IS OFF - ENABLE THE SWITCH BELOW" )
		TF2VRSB_UpdateStatusLabels()
		return
	}

	TF2VRSB_LogEvent( "layout-request", "developer" )
	thread TF2VRSB_LogDeveloperLayout( file.developerMenu )
}

////////////////////////////////////////////////////////////////////////////////
// Status and transport
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_RequestStatus()
{
	TF2VRSB_LogEvent( "status-request", "ready=" + string( GetConVarInt( TF2VRSB_READY ) ) )
	if ( GetConVarInt( TF2VRSB_READY ) != 1 )
		SetConVarString( TF2VRSB_RESULT, "CONTACTING CAMPAIGN SESSION" )
	RunClientScript( "TF2VRSB_SendCommand", "tf2vrsb_status" )
	thread TF2VRSB_RefreshAfterFrames( 6 )
}

void function TF2VRSB_BeginAction( string command, string pendingText )
{
	TF2VRSB_LogEvent( "command", command + " pending=\"" + pendingText + "\"" )
	SetConVarString( TF2VRSB_RESULT, pendingText )
	TF2VRSB_UpdateStatusLabels()
	RunClientScript( "TF2VRSB_SendCommand", command )
	thread TF2VRSB_RefreshAfterFrames( 8 )
}

void function TF2VRSB_RefreshAfterFrames( int frames )
{
	for ( int i = 0; i < frames; i++ )
		WaitFrame()
	TF2VRSB_UpdateStatusLabels()
}

void function TF2VRSB_UpdateStatusLabels()
{
	string mapName = GetConVarString( TF2VRSB_MAP )
	string display = TF2VRSB_DisplayMap( mapName )
	string mode = GetConVarString( TF2VRSB_MODE )
	string result = GetConVarString( TF2VRSB_RESULT )
	bool ready = GetConVarInt( TF2VRSB_READY ) == 1
	bool bookmark = GetConVarInt( TF2VRSB_BOOKMARK ) == 1
	bool flying = GetConVarInt( TF2VRSB_FLY ) == 1
	string coords = GetConVarString( TF2VRSB_X ) + ", " + GetConVarString( TF2VRSB_Y ) + ", " + GetConVarString( TF2VRSB_Z )

	if ( file.rootSession != null )
		Hud_SetText( file.rootSession, "SESSION: " + ( ready ? ( mode == "" ? "CAMPAIGN" : mode ) : "CONNECTING TO SERVER VM" ) )
	if ( file.rootMap != null )
		Hud_SetText( file.rootMap, "MAP: " + display + "  [" + mapName + "]" )
	if ( file.rootCounts != null )
		Hud_SetText( file.rootCounts, "SANDBOX NPCs: " + GetConVarString( TF2VRSB_MANAGED_COUNT )
			+ " / " + string( GetConVarInt( "tf2vrsb_cap" ) )
			+ "    NPCs IN LEVEL: " + GetConVarString( TF2VRSB_NPC_COUNT ) )
	if ( file.rootStatus != null )
		Hud_SetText( file.rootStatus, result )

	if ( file.mapsStatus != null )
		Hud_SetText( file.mapsStatus, ready ? "SESSION MAP DATA ONLINE // LOADING DISABLED" : "WAITING FOR SERVER VM" )
	if ( file.mapsCurrent != null )
		Hud_SetText( file.mapsCurrent, "CURRENT MAP: " + display + "  [" + mapName + "]" )
	TF2VRSB_UpdateMapButtons()

	if ( file.npcManaged != null )
		Hud_SetText( file.npcManaged, "MANAGED: " + GetConVarString( TF2VRSB_MANAGED_COUNT )
			+ " / " + string( GetConVarInt( "tf2vrsb_cap" ) )
			+ "    LEVEL NPCs: " + GetConVarString( TF2VRSB_NPC_COUNT ) )
	if ( file.npcStatus != null )
		Hud_SetText( file.npcStatus, result )

	if ( file.playerBookmark != null )
		Hud_SetText( file.playerBookmark, "BOOKMARK: " + ( bookmark ? "SAVED IN THIS SESSION" : "NOT SET" ) )
	if ( file.playerPosition != null )
		Hud_SetText( file.playerPosition, "POSITION: " + coords + "    YAW: " + GetConVarString( TF2VRSB_YAW )
			+ "    FLY: " + ( flying ? "ON" : "OFF" ) )
	if ( file.playerStatus != null )
		Hud_SetText( file.playerStatus, result )
	if ( file.playerMenu != null )
		TF2VRSB_SetButtonLabel( file.playerMenu, "ToggleFly", flying
			? "FLY (NOCLIP): ON - TAP TO LAND"
			: "FLY (NOCLIP): OFF - TAP TO FLY" )

	if ( file.devMap != null )
		Hud_SetText( file.devMap, "MAP ID: " + mapName + "    DISPLAY: " + display )
	if ( file.devMode != null )
		Hud_SetText( file.devMode, "MODE: " + ( mode == "" ? "UNKNOWN" : mode ) + "    SESSION: " + ( ready ? "ONLINE" : "OFFLINE" ) )
	if ( file.devPosition != null )
		Hud_SetText( file.devPosition, "PLAYER POSITION: " + coords + "    YAW: " + GetConVarString( TF2VRSB_YAW ) )
	if ( file.devCounts != null )
		Hud_SetText( file.devCounts, "ENTITIES: " + GetConVarString( TF2VRSB_ENTITY_COUNT )
			+ "    NPCs: " + GetConVarString( TF2VRSB_NPC_COUNT )
			+ "    SANDBOX NPCs: " + GetConVarString( TF2VRSB_MANAGED_COUNT ) )
	if ( file.devCap != null )
		Hud_SetText( file.devCap, "NPC CAP: " + string( GetConVarInt( "tf2vrsb_cap" ) )
			+ "    SPAWN DISTANCE: " + string( GetConVarInt( "tf2vrsb_spawn_distance" ) ) + " UNITS" )
	if ( file.devLimits != null )
		Hud_SetText( file.devLimits, "TF2VR SANDBOX " + TF2VRSB_VERSION
			+ " // FLY=" + ( flying ? "ON" : "OFF" )
			+ " DEBUG=" + ( GetConVarInt( TF2VRSB_DEBUG ) == 1 ? "ON" : "OFF" ) + "\n"
			+ "AVAILABLE: PAUSE MENU, SESSION INFO, MAP CATALOG, NPCs, BOOKMARK, FLY, POSITION PRESETS.\n"
			+ "NOT AVAILABLE: MAP TRAVEL, WORLD OBJECTS, GAUNTLET MARKERS. THESE REQUIRE IN-GAME VALIDATION.\n"
			+ "Y TOGGLES ON-SCREEN LAYOUT BOUNDS: ORANGE=MENU, CYAN=CONTROLS. THE CHOICE IS SAVED." )

	if ( file.presetStatus != null )
		Hud_SetText( file.presetStatus, result )
	TF2VRSB_UpdatePresetLabels()

	if ( result != file.lastLoggedResult )
	{
		file.lastLoggedResult = result
		TF2VRSB_LogState( "result-changed" )
	}
}

string function TF2VRSB_DisplayMap( string mapName )
{
	switch ( mapName )
	{
		case "sp_training": return "TRAINING"
		case "sp_crashsite": return "CRASH SITE"
		case "sp_sewers1": return "SEWERS"
		case "sp_boomtown_start": return "BOOMTOWN // START"
		case "sp_boomtown": return "BOOMTOWN"
		case "sp_boomtown_end": return "BOOMTOWN // END"
		case "sp_hub_timeshift": return "TIMESHIFT HUB"
		case "sp_timeshift_spoke02": return "TIMESHIFT SPOKE"
		case "sp_beacon": return "BEACON"
		case "sp_beacon_spoke0": return "BEACON SPOKE"
		case "sp_tday": return "T-DAY"
		case "sp_s2s": return "S2S"
		case "sp_skyway_v1": return "SKYWAY"
	}
	if ( mapName == "" )
		return "NO CAMPAIGN MAP"
	return mapName
}

void function TF2VRSB_OnBack( var button )
{
	CloseActiveMenu( true )
}

////////////////////////////////////////////////////////////////////////////////
// Helpers
////////////////////////////////////////////////////////////////////////////////

array<var> function TF2VRSB_GetButtons( var menu, string prefix, int count )
{
	array<var> buttons = []
	for ( int i = 0; i < count; i++ )
	{
		var button = Hud_GetChild( menu, prefix + string( i ) )
		if ( button != null )
			buttons.append( button )
		else
			print( "[TF2VRSB] missing menu control " + prefix + string( i ) + "\n" )
	}
	return buttons
}

void function TF2VRSB_SetButtonLabel( var menu, string childName, string label )
{
	var button = Hud_GetChild( menu, childName )
	if ( button != null )
		SetButtonRuiText( button, label )
}

void function TF2VRSB_AddLayoutFooter( var menu )
{
	AddMenuFooterOption( menu, BUTTON_Y,
		PrependControllerPrompts( BUTTON_Y, " LAYOUT BOUNDS" ),
		"LAYOUT BOUNDS",
		TF2VRSB_ToggleLayoutOverlay )
}

void function TF2VRSB_WireVertical( array<var> buttons )
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

void function TF2VRSB_BindPresetButton( var button, int slot, bool save )
{
	Hud_AddEventHandler( button, UIE_CLICK,
		void function( var clicked ) : ( slot, save )
		{
			if ( save )
				TF2VRSB_OnSavePreset( slot )
			else
				TF2VRSB_OnLoadPreset( slot )
		} )
}
