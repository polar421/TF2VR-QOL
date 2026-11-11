// TF2VR Campaign Sandbox - NPC catalog and managed roster UI.
//
// This page is read-only until a player presses a catalog row, then a details
// page, then SPAWN. The UI sends only one of the fixed client commands and
// never creates or destroys an entity itself.

global function TF2VRSB_NpcBrowserInit
global function TF2VRSB_InitNpcBrowser
global function TF2VRSB_InitNpcDetails
global function TF2VRSB_InitNpcManaged

const string TF2VRSB_NPC_BROWSER_MENU = "TF2VRSBSandboxNpcBrowser"
const string TF2VRSB_NPC_DETAILS_MENU = "TF2VRSBSandboxNpcDetails"
const string TF2VRSB_NPC_MANAGED_MENU = "TF2VRSBSandboxNpcManaged"

const string TF2VRSB_NPC_RESULT_CVAR = "tf2vrsb_result"
const string TF2VRSB_NPC_MANAGED_COUNT_CVAR = "tf2vrsb_managed_count"
const string TF2VRSB_NPC_LEVEL_COUNT_CVAR = "tf2vrsb_npc_count"
const string TF2VRSB_NPC_CAP_CVAR = "tf2vrsb_cap"
const string TF2VRSB_NPC_DISTANCE_CVAR = "tf2vrsb_spawn_distance"
const string TF2VRSB_NPC_CATEGORY_CVAR = "tf2vrsb_npc_category"
const string TF2VRSB_NPC_TEAM_CVAR = "tf2vrsb_spawn_team"
const string TF2VRSB_NPC_REQUEST_CVAR = "tf2vrsb_request_npc"
const string TF2VRSB_NPC_REQUEST_TEAM_CVAR = "tf2vrsb_request_team"
const string TF2VRSB_NPC_REQUEST_MANAGED_CVAR = "tf2vrsb_request_managed"
const string TF2VRSB_NPC_SELECTED_COUNT_CVAR = "tf2vrsb_selected_count"
const string TF2VRSB_NPC_PAGE_CVAR = "tf2vrsb_managed_page"
const string TF2VRSB_NPC_PAGES_CVAR = "tf2vrsb_managed_pages"
const string TF2VRSB_NPC_READY_CVAR = "tf2vrsb_ready"

const int TF2VRSB_NPC_RESULTS_PER_PAGE = 6
const int TF2VRSB_NPC_MANAGED_PER_PAGE = 8

struct TF2VRSB_NpcEntry
{
	string id
	string name
	string category
	string entityId
	string status
	string restrictions
	string dependencies
	bool spawnable
}

struct
{
	var browserMenu
	var detailsMenu
	var managedMenu

	array<var> resultButtons
	array<var> managedButtons

	var searchEntry
	var categorySwitch
	var resultSummary
	var browserStatus

	var detailName
	var detailCategory
	var detailEntity
	var detailCompat
	var detailCount
	var detailRestrictions
	var detailDependencies
	var detailTeam
	var detailSpawn
	var detailManaged
	var detailStatus

	var managedCount
	var managedPageLabel
	var managedStatus

	array<TF2VRSB_NpcEntry> catalog
	array<int> filtered

	int page
	int selectedIndex
	int pendingManagedId
	bool removeArmed
	bool clearArmed
} file

////////////////////////////////////////////////////////////////////////////////
// Registration and initialization
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_NpcBrowserInit()
{
	AddMenu( TF2VRSB_NPC_BROWSER_MENU, $"resource/ui/menus/tf2vrsb_npcs.menu", TF2VRSB_InitNpcBrowser )
	AddMenu( TF2VRSB_NPC_DETAILS_MENU, $"resource/ui/menus/tf2vrsb_npc_details.menu", TF2VRSB_InitNpcDetails )
	AddMenu( TF2VRSB_NPC_MANAGED_MENU, $"resource/ui/menus/tf2vrsb_npc_managed.menu", TF2VRSB_InitNpcManaged )
	print( "[TF2VRSB] NPC browser, details and managed-roster menus registered\n" )
}

void function TF2VRSB_InitNpcBrowser()
{
	file.browserMenu = GetMenu( TF2VRSB_NPC_BROWSER_MENU )
	file.searchEntry = Hud_GetChild( file.browserMenu, "SearchEntry" )
	file.categorySwitch = Hud_GetChild( file.browserMenu, "SwitchCategory" )
	file.resultSummary = Hud_GetChild( file.browserMenu, "ResultSummary" )
	file.browserStatus = Hud_GetChild( file.browserMenu, "BrowserStatus" )
	file.resultButtons = TF2VRSB_NpcChildren( file.browserMenu, "Npc", TF2VRSB_NPC_RESULTS_PER_PAGE )

	file.catalog = TF2VRSB_BuildNpcCatalog()
	file.filtered = []
	file.page = 0
	file.selectedIndex = -1
	file.pendingManagedId = -1

	for ( int i = 0; i < file.resultButtons.len(); i++ )
	{
		int row = i
		Hud_AddEventHandler( file.resultButtons[ i ], UIE_CLICK,
			void function( var clicked ) : ( row )
			{
				TF2VRSB_NpcOpenDetails( row )
			} )
	}
	TF2VRSB_NpcWireVertical( file.resultButtons )

	if ( file.searchEntry != null )
		Hud_AddEventHandler( file.searchEntry, UIE_CHANGE, TF2VRSB_NpcOnSearchChanged )
	if ( file.categorySwitch != null )
		Hud_AddEventHandler( file.categorySwitch, UIE_CHANGE, TF2VRSB_NpcOnCategoryChanged )

	TF2VRSB_NpcBind( file.browserMenu, "BtnPrev", TF2VRSB_NpcOnPagePrev )
	TF2VRSB_NpcBind( file.browserMenu, "BtnNext", TF2VRSB_NpcOnPageNext )
	TF2VRSB_NpcBind( file.browserMenu, "BtnManaged", TF2VRSB_NpcOnOpenManaged )
	TF2VRSB_NpcBind( file.browserMenu, "BtnClear", TF2VRSB_NpcOnClear )

	AddMenuFooterOption( file.browserMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_NpcAddLayoutFooter( file.browserMenu )
	AddMenuEventHandler( file.browserMenu, eUIEvent.MENU_OPEN, TF2VRSB_NpcOnBrowserOpen )
}

void function TF2VRSB_InitNpcDetails()
{
	file.detailsMenu = GetMenu( TF2VRSB_NPC_DETAILS_MENU )
	file.detailName = Hud_GetChild( file.detailsMenu, "NpcName" )
	file.detailCategory = Hud_GetChild( file.detailsMenu, "NpcCategoryValue" )
	file.detailEntity = Hud_GetChild( file.detailsMenu, "NpcEntityValue" )
	file.detailCompat = Hud_GetChild( file.detailsMenu, "NpcCompatValue" )
	file.detailCount = Hud_GetChild( file.detailsMenu, "NpcCountValue" )
	file.detailRestrictions = Hud_GetChild( file.detailsMenu, "NpcRestrictionsValue" )
	file.detailDependencies = Hud_GetChild( file.detailsMenu, "NpcDependenciesValue" )
	file.detailTeam = Hud_GetChild( file.detailsMenu, "SwitchTeam" )
	file.detailSpawn = Hud_GetChild( file.detailsMenu, "SpawnSelected" )
	file.detailManaged = Hud_GetChild( file.detailsMenu, "BtnManaged" )
	file.detailStatus = Hud_GetChild( file.detailsMenu, "DetailsStatus" )

	if ( file.detailTeam != null )
		Hud_AddEventHandler( file.detailTeam, UIE_CHANGE, TF2VRSB_NpcOnTeamChanged )
	TF2VRSB_NpcBind( file.detailsMenu, "SpawnSelected", TF2VRSB_NpcOnSpawn )
	TF2VRSB_NpcBind( file.detailsMenu, "BtnManaged", TF2VRSB_NpcOnOpenManaged )
	TF2VRSB_NpcBind( file.detailsMenu, "BtnBack", TF2VRSB_NpcOnBack )

	AddMenuFooterOption( file.detailsMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_NpcAddLayoutFooter( file.detailsMenu )
	AddMenuEventHandler( file.detailsMenu, eUIEvent.MENU_OPEN, TF2VRSB_NpcOnDetailsOpen )
}

void function TF2VRSB_InitNpcManaged()
{
	file.managedMenu = GetMenu( TF2VRSB_NPC_MANAGED_MENU )
	file.managedCount = Hud_GetChild( file.managedMenu, "ManagedCount" )
	file.managedPageLabel = Hud_GetChild( file.managedMenu, "ManagedPageLabel" )
	file.managedStatus = Hud_GetChild( file.managedMenu, "ManagedStatus" )
	file.managedButtons = TF2VRSB_NpcChildren( file.managedMenu, "Managed", TF2VRSB_NPC_MANAGED_PER_PAGE )

	file.removeArmed = false
	file.clearArmed = false
	file.pendingManagedId = -1

	for ( int i = 0; i < file.managedButtons.len(); i++ )
	{
		int slot = i
		Hud_AddEventHandler( file.managedButtons[ i ], UIE_CLICK,
			void function( var clicked ) : ( slot )
			{
				TF2VRSB_NpcOnManagedRow( slot )
			} )
	}
	TF2VRSB_NpcWireVertical( file.managedButtons )

	TF2VRSB_NpcBind( file.managedMenu, "BtnPrev", TF2VRSB_NpcOnManagedPrev )
	TF2VRSB_NpcBind( file.managedMenu, "BtnNext", TF2VRSB_NpcOnManagedNext )
	TF2VRSB_NpcBind( file.managedMenu, "BtnClear", TF2VRSB_NpcOnClear )
	TF2VRSB_NpcBind( file.managedMenu, "BtnBack", TF2VRSB_NpcOnBack )

	AddMenuFooterOption( file.managedMenu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )
	TF2VRSB_NpcAddLayoutFooter( file.managedMenu )
	AddMenuEventHandler( file.managedMenu, eUIEvent.MENU_OPEN, TF2VRSB_NpcOnManagedOpen )
}

////////////////////////////////////////////////////////////////////////////////
// Page events
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_NpcOnBrowserOpen()
{
	file.page = 0
	file.clearArmed = false
	TF2VRSB_NpcRequestStatus()
	TF2VRSB_RefreshNpcBrowser()
	FocusDefaultMenuItem( file.browserMenu )
	thread TF2VRSB_NpcLogBrowserLayout( file.browserMenu )
}

void function TF2VRSB_NpcOnDetailsOpen()
{
	file.clearArmed = false
	TF2VRSB_NpcRequestStatus()
	TF2VRSB_RefreshNpcDetails()
	FocusDefaultMenuItem( file.detailsMenu )
	thread TF2VRSB_NpcLogDetailsLayout( file.detailsMenu )
}

void function TF2VRSB_NpcOnManagedOpen()
{
	file.removeArmed = false
	file.pendingManagedId = -1
	file.clearArmed = false
	TF2VRSB_NpcRequestStatus()
	TF2VRSB_RefreshNpcManaged()
	FocusDefaultMenuItem( file.managedMenu )
	thread TF2VRSB_NpcLogManagedLayout( file.managedMenu )
}

void function TF2VRSB_NpcOnBack( var button )
{
	CloseActiveMenu( true )
}

void function TF2VRSB_NpcOnOpenManaged( var button )
{
	file.removeArmed = false
	file.pendingManagedId = -1
	AdvanceMenu( GetMenu( TF2VRSB_NPC_MANAGED_MENU ) )
}

void function TF2VRSB_NpcOnSearchChanged( var button )
{
	file.page = 0
	TF2VRSB_RefreshNpcBrowser()
}

void function TF2VRSB_NpcOnCategoryChanged( var button )
{
	file.page = 0
	TF2VRSB_RefreshNpcBrowser()
}

void function TF2VRSB_NpcOnTeamChanged( var button )
{
	TF2VRSB_RefreshNpcDetails()
}

void function TF2VRSB_NpcOpenDetails( int row )
{
	int index = file.page * TF2VRSB_NPC_RESULTS_PER_PAGE + row
	if ( index < 0 || index >= file.filtered.len() )
		return

	file.selectedIndex = file.filtered[ index ]
	TF2VRSB_NpcEntry entry = file.catalog[ file.selectedIndex ]
	SetConVarString( TF2VRSB_NPC_REQUEST_CVAR, entry.id )
	SetConVarInt( TF2VRSB_NPC_REQUEST_TEAM_CVAR, GetConVarInt( TF2VRSB_NPC_TEAM_CVAR ) )
	TF2VRSB_LogEvent( "npc-selected", entry.id )
	AdvanceMenu( GetMenu( TF2VRSB_NPC_DETAILS_MENU ) )
}

void function TF2VRSB_NpcOnSpawn( var button )
{
	if ( file.selectedIndex < 0 || file.selectedIndex >= file.catalog.len() )
		return

	TF2VRSB_NpcEntry entry = file.catalog[ file.selectedIndex ]
	SetConVarString( TF2VRSB_NPC_REQUEST_CVAR, entry.id )
	SetConVarInt( TF2VRSB_NPC_REQUEST_TEAM_CVAR, GetConVarInt( TF2VRSB_NPC_TEAM_CVAR ) )
	if ( !entry.spawnable )
	{
		SetConVarString( TF2VRSB_NPC_RESULT_CVAR, "UNAVAILABLE: " + entry.restrictions )
		TF2VRSB_RefreshNpcDetails()
		return
	}

	string teamText = GetConVarInt( TF2VRSB_NPC_TEAM_CVAR ) == 0 ? "FRIENDLY" : "HOSTILE"
	TF2VRSB_NpcBeginAction( "tf2vrsb_spawn_npc", "SPAWNING " + entry.name + " // " + teamText )
}

void function TF2VRSB_NpcOnPagePrev( var button )
{
	if ( file.page > 0 )
		file.page--
	TF2VRSB_RefreshNpcBrowser()
}

void function TF2VRSB_NpcOnPageNext( var button )
{
	int pages = ( file.filtered.len() + TF2VRSB_NPC_RESULTS_PER_PAGE - 1 ) / TF2VRSB_NPC_RESULTS_PER_PAGE
	if ( pages < 1 )
		pages = 1
	if ( file.page < pages - 1 )
		file.page++
	TF2VRSB_RefreshNpcBrowser()
}

void function TF2VRSB_NpcOnManagedPrev( var button )
{
	int page = GetConVarInt( TF2VRSB_NPC_PAGE_CVAR )
	if ( page > 0 )
		page--
	SetConVarInt( TF2VRSB_NPC_PAGE_CVAR, page )
	TF2VRSB_NpcResetManagedArm()
	TF2VRSB_NpcRequestStatus()
}

void function TF2VRSB_NpcOnManagedNext( var button )
{
	int page = GetConVarInt( TF2VRSB_NPC_PAGE_CVAR )
	int pages = GetConVarInt( TF2VRSB_NPC_PAGES_CVAR )
	if ( page < pages - 1 )
		page++
	SetConVarInt( TF2VRSB_NPC_PAGE_CVAR, page )
	TF2VRSB_NpcResetManagedArm()
	TF2VRSB_NpcRequestStatus()
}

////////////////////////////////////////////////////////////////////////////////
// Managed roster
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_NpcOnManagedRow( int slot )
{
	int managedId = GetConVarInt( "tf2vrsb_managed_id_" + string( slot ) )
	if ( managedId < 0 )
		return

	if ( file.removeArmed && file.pendingManagedId == managedId )
	{
		file.removeArmed = false
		file.pendingManagedId = -1
		SetConVarInt( TF2VRSB_NPC_REQUEST_MANAGED_CVAR, managedId )
		TF2VRSB_NpcBeginAction( "tf2vrsb_remove_managed", "REMOVING MANAGED NPC #" + string( managedId ) )
		return
	}

	file.removeArmed = true
	file.pendingManagedId = managedId
	SetConVarString( TF2VRSB_NPC_RESULT_CVAR, "CONFIRM REMOVE #" + string( managedId ) + " // PRESS THE ROW AGAIN" )
	TF2VRSB_RefreshNpcManaged()
	thread TF2VRSB_NpcDisarmManagedLater( managedId )
}

void function TF2VRSB_NpcDisarmManagedLater( int managedId )
{
	for ( int i = 0; i < 240; i++ )
		WaitFrame()
	if ( file.pendingManagedId == managedId )
	{
		file.removeArmed = false
		file.pendingManagedId = -1
		TF2VRSB_RefreshNpcManaged()
	}
}

void function TF2VRSB_NpcOnClear( var button )
{
	int managed = GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR )
	if ( managed <= 0 )
	{
		file.clearArmed = false
		SetConVarString( TF2VRSB_NPC_RESULT_CVAR, "NO SANDBOX-MANAGED NPCs TO CLEAR" )
		TF2VRSB_RefreshNpcSurfaces()
		return
	}

	if ( !file.clearArmed )
	{
		file.clearArmed = true
		SetConVarString( TF2VRSB_NPC_RESULT_CVAR, "CONFIRM CLEAR ALL " + string( managed ) + " MANAGED NPCs // PRESS AGAIN" )
		TF2VRSB_RefreshNpcSurfaces()
		thread TF2VRSB_NpcDisarmClearLater()
		return
	}

	file.clearArmed = false
	TF2VRSB_NpcBeginAction( "tf2vrsb_clear_managed", "CLEARING SANDBOX-MANAGED NPCs" )
}

void function TF2VRSB_NpcDisarmClearLater()
{
	for ( int i = 0; i < 240; i++ )
		WaitFrame()
	if ( file.clearArmed )
	{
		file.clearArmed = false
		TF2VRSB_RefreshNpcSurfaces()
	}
}

void function TF2VRSB_NpcResetManagedArm()
{
	file.removeArmed = false
	file.pendingManagedId = -1
	TF2VRSB_RefreshNpcManaged()
}

////////////////////////////////////////////////////////////////////////////////
// Refresh
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_RefreshNpcSurfaces()
{
	TF2VRSB_RefreshNpcBrowser()
	TF2VRSB_RefreshNpcDetails()
	TF2VRSB_RefreshNpcManaged()
}

void function TF2VRSB_RefreshNpcBrowser()
{
	if ( file.browserMenu == null )
		return

	string query = ""
	if ( file.searchEntry != null )
		query = Hud_GetUTF8Text( file.searchEntry ).tolower()

	int category = GetConVarInt( TF2VRSB_NPC_CATEGORY_CVAR )
	if ( category < 0 || category > 6 )
		category = 0

	file.filtered = []
	for ( int i = 0; i < file.catalog.len(); i++ )
	{
		TF2VRSB_NpcEntry entry = file.catalog[ i ]
		string categoryName = TF2VRSB_NpcCategoryName( category )
		if ( category > 0 && entry.category != categoryName )
			continue
		if ( query != "" )
		{
			string haystack = ( entry.name + " " + entry.category + " " + entry.id + " " + entry.status ).tolower()
			if ( haystack.find( query ) == null )
				continue
		}
		file.filtered.append( i )
	}

	int pages = ( file.filtered.len() + TF2VRSB_NPC_RESULTS_PER_PAGE - 1 ) / TF2VRSB_NPC_RESULTS_PER_PAGE
	if ( pages < 1 )
		pages = 1
	if ( file.page >= pages )
		file.page = pages - 1
	if ( file.page < 0 )
		file.page = 0

	for ( int slot = 0; slot < file.resultButtons.len(); slot++ )
	{
		int index = file.page * TF2VRSB_NPC_RESULTS_PER_PAGE + slot
		if ( index >= 0 && index < file.filtered.len() )
		{
			TF2VRSB_NpcEntry entry = file.catalog[ file.filtered[ index ] ]
			SetButtonRuiText( file.resultButtons[ slot ], entry.name + "  [" + entry.status + "]" )
			Hud_SetEnabled( file.resultButtons[ slot ], true )
		}
		else
		{
			SetButtonRuiText( file.resultButtons[ slot ], "-- NO MATCH --" )
			Hud_SetEnabled( file.resultButtons[ slot ], false )
		}
	}

	int shown = file.filtered.len()
	Hud_SetText( file.resultSummary, "CATEGORY: " + TF2VRSB_NpcCategoryName( category )
		+ "  //  " + string( shown ) + " ENTRIES  //  PAGE " + string( file.page + 1 ) + "/" + string( pages )
		+ "  //  " + string( GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR ) ) + "/"
		+ string( GetConVarInt( TF2VRSB_NPC_CAP_CVAR ) ) + " MANAGED" )
	Hud_SetText( file.browserStatus, GetConVarString( TF2VRSB_NPC_RESULT_CVAR ) )

	TF2VRSB_NpcSetEnabled( file.browserMenu, "BtnPrev", file.page > 0 )
	TF2VRSB_NpcSetEnabled( file.browserMenu, "BtnNext", file.page < pages - 1 )
	TF2VRSB_NpcSetEnabled( file.browserMenu, "BtnManaged", GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR ) > 0 )
	TF2VRSB_NpcSetButton( file.browserMenu, "BtnClear", file.clearArmed
		? "CONFIRM: CLEAR ALL MANAGED NPCs"
		: "CLEAR ALL SANDBOX-MANAGED NPCs", true )
}

void function TF2VRSB_RefreshNpcDetails()
{
	if ( file.detailsMenu == null )
		return

	if ( file.selectedIndex < 0 || file.selectedIndex >= file.catalog.len() )
	{
		Hud_SetText( file.detailName, "NO NPC SELECTED" )
		Hud_SetText( file.detailCategory, "OPEN THE NPC BROWSER AND SELECT AN ENTRY" )
		Hud_SetText( file.detailEntity, "" )
		Hud_SetText( file.detailCompat, "" )
		Hud_SetText( file.detailCount, "" )
		Hud_SetText( file.detailRestrictions, "" )
		Hud_SetText( file.detailDependencies, "" )
		Hud_SetText( file.detailStatus, "NO SELECTION" )
		Hud_SetEnabled( file.detailSpawn, false )
		Hud_SetEnabled( file.detailTeam, false )
		Hud_SetEnabled( file.detailManaged, GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR ) > 0 )
		SetButtonRuiText( file.detailSpawn, "SPAWN UNAVAILABLE" )
		return
	}

	TF2VRSB_NpcEntry entry = file.catalog[ file.selectedIndex ]
	Hud_SetText( file.detailName, entry.name )
	Hud_SetText( file.detailCategory, "CATEGORY: " + entry.category + "    STATUS: " + entry.status )
	Hud_SetText( file.detailEntity, "ENTITY BASE: " + entry.entityId + "    AI SETTINGS: " + entry.id )
	Hud_SetText( file.detailCompat, "CREATE PATH: CreateNPCFromAISettings + DispatchSpawn"
		+ ( entry.spawnable ? "    RUNTIME: SOURCE-VERIFIED / NOT IN-GAME TESTED" : "    SPAWN BUTTON: DISABLED" ) )
	Hud_SetText( file.detailCount, "MANAGED OF THIS TYPE: " + string( GetConVarInt( TF2VRSB_NPC_SELECTED_COUNT_CVAR ) )
		+ "    TOTAL MANAGED: " + string( GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR ) ) + "/"
		+ string( GetConVarInt( TF2VRSB_NPC_CAP_CVAR ) )
		+ "    SPAWN AHEAD: " + string( GetConVarInt( TF2VRSB_NPC_DISTANCE_CVAR ) ) + " UNITS" )
	Hud_SetText( file.detailRestrictions, "RESTRICTIONS: " + entry.restrictions )
	Hud_SetText( file.detailDependencies, "DEPENDENCIES: " + entry.dependencies )
	Hud_SetText( file.detailStatus, GetConVarString( TF2VRSB_NPC_RESULT_CVAR ) )

	bool canSpawn = entry.spawnable
	Hud_SetEnabled( file.detailSpawn, canSpawn )
	Hud_SetEnabled( file.detailTeam, canSpawn )
	Hud_SetEnabled( file.detailManaged, GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR ) > 0 )
	SetButtonRuiText( file.detailSpawn, canSpawn
		? "SPAWN " + entry.name + "  //  " + ( GetConVarInt( TF2VRSB_NPC_TEAM_CVAR ) == 0 ? "PLAYER TEAM" : "HOSTILE" )
		: "SPAWN UNAVAILABLE - " + entry.status )
}

void function TF2VRSB_RefreshNpcManaged()
{
	if ( file.managedMenu == null )
		return

	int managed = GetConVarInt( TF2VRSB_NPC_MANAGED_COUNT_CVAR )
	int cap = GetConVarInt( TF2VRSB_NPC_CAP_CVAR )
	int page = GetConVarInt( TF2VRSB_NPC_PAGE_CVAR )
	int pages = GetConVarInt( TF2VRSB_NPC_PAGES_CVAR )
	if ( pages < 1 )
		pages = 1

	Hud_SetText( file.managedCount, "MANAGED SANDBOX NPCs: " + string( managed ) + " / " + string( cap )
		+ "    NPCs IN LEVEL: " + string( GetConVarInt( TF2VRSB_NPC_LEVEL_COUNT_CVAR ) ) )
	Hud_SetText( file.managedPageLabel, "PAGE " + string( page + 1 ) + " / " + string( pages )
		+ "    PRESS A ROW TWICE TO REMOVE THAT SANDBOX NPC" )
	Hud_SetText( file.managedStatus, GetConVarString( TF2VRSB_NPC_RESULT_CVAR ) )

	for ( int slot = 0; slot < file.managedButtons.len(); slot++ )
	{
		int managedId = GetConVarInt( "tf2vrsb_managed_id_" + string( slot ) )
		string label = GetConVarString( "tf2vrsb_managed_" + string( slot ) )
		if ( managedId < 0 || label == "" )
		{
			SetButtonRuiText( file.managedButtons[ slot ], "-- EMPTY SLOT --" )
			Hud_SetEnabled( file.managedButtons[ slot ], false )
			continue
		}
		if ( file.removeArmed && file.pendingManagedId == managedId )
			label = "CONFIRM REMOVE: " + label
		SetButtonRuiText( file.managedButtons[ slot ], label )
		Hud_SetEnabled( file.managedButtons[ slot ], true )
	}

	TF2VRSB_NpcSetEnabled( file.managedMenu, "BtnPrev", page > 0 )
	TF2VRSB_NpcSetEnabled( file.managedMenu, "BtnNext", page < pages - 1 )
	TF2VRSB_NpcSetButton( file.managedMenu, "BtnClear", file.clearArmed
		? "CONFIRM: CLEAR ALL MANAGED NPCs"
		: "CLEAR ALL SANDBOX-MANAGED NPCs", true )
}

////////////////////////////////////////////////////////////////////////////////
// Transport
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_NpcRequestStatus()
{
	if ( GetConVarInt( TF2VRSB_NPC_READY_CVAR ) != 1 )
		SetConVarString( TF2VRSB_NPC_RESULT_CVAR, "CONTACTING CAMPAIGN SESSION" )
	RunClientScript( "TF2VRSB_SendCommand", "tf2vrsb_status" )
	thread TF2VRSB_NpcRefreshAfterFrames( 6 )
}

void function TF2VRSB_NpcBeginAction( string command, string pendingText )
{
	TF2VRSB_LogEvent( "command", command + " pending=\"" + pendingText + "\"" )
	SetConVarString( TF2VRSB_NPC_RESULT_CVAR, pendingText )
	TF2VRSB_RefreshNpcSurfaces()
	RunClientScript( "TF2VRSB_SendCommand", command )
	thread TF2VRSB_NpcRefreshAfterFrames( 10 )
}

void function TF2VRSB_NpcRefreshAfterFrames( int frames )
{
	for ( int i = 0; i < frames; i++ )
		WaitFrame()
	TF2VRSB_RefreshNpcSurfaces()
}

////////////////////////////////////////////////////////////////////////////////
// Layout logging
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_NpcLogBrowserLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"SearchEntry", "SwitchCategory", "ResultSummary",
		"Npc0", "Npc1", "Npc2", "Npc3", "Npc4", "Npc5",
		"BtnPrev", "BtnNext", "BtnManaged", "BtnClear", "BrowserStatus",
		"FooterButtons"
	]
	TF2VRSB_LogPage( "npc_browser", menu, names )
}

void function TF2VRSB_NpcLogDetailsLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"NpcName", "NpcCategoryValue", "NpcEntityValue", "NpcCompatValue",
		"NpcCountValue", "NpcRestrictionsValue", "NpcDependenciesValue",
		"SwitchTeam", "SpawnSelected", "BtnManaged", "BtnBack",
		"DetailsStatus", "FooterButtons"
	]
	TF2VRSB_LogPage( "npc_details", menu, names )
}

void function TF2VRSB_NpcLogManagedLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"ManagedCount", "ManagedPageLabel",
		"Managed0", "Managed1", "Managed2", "Managed3",
		"Managed4", "Managed5", "Managed6", "Managed7",
		"BtnPrev", "BtnNext", "BtnClear", "BtnBack",
		"ManagedStatus", "FooterButtons"
	]
	TF2VRSB_LogPage( "npc_managed", menu, names )
}

////////////////////////////////////////////////////////////////////////////////
// Catalog
////////////////////////////////////////////////////////////////////////////////

array<TF2VRSB_NpcEntry> function TF2VRSB_BuildNpcCatalog()
{
	array<TF2VRSB_NpcEntry> list = []

	TF2VRSB_NpcAdd( list, "npc_soldier", "RIFLEMAN", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_soldier_specialist", "IMC SPECIALIST", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_soldier_specialist_militia", "MILITIA SPECIALIST", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_soldier_sidearm", "SIDEARM SOLDIER", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_soldier_shield_captain", "SHIELD CAPTAIN", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_soldier_hero_bear", "BEAR", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_soldier_hero_sarah", "SARAH", "HUMAN", "npc_soldier",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_pilot_elite", "ELITE PILOT", "HUMAN", "npc_pilot_elite",
		"NOT_TESTED", "ELITE PILOT AI SETTINGS // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_pilot_elite_assassin", "ELITE ASSASSIN", "HUMAN", "npc_pilot_elite",
		"NOT_TESTED", "ELITE PILOT AI SETTINGS // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_pilot_elite_assassin_cqb", "ELITE ASSASSIN CQB", "HUMAN", "npc_pilot_elite",
		"NOT_TESTED", "ELITE PILOT AI SETTINGS // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_pilot_elite_assassin_sniper", "ELITE ASSASSIN SNIPER", "HUMAN", "npc_pilot_elite",
		"NOT_TESTED", "ELITE PILOT AI SETTINGS // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )

	TF2VRSB_NpcAdd( list, "npc_spectre", "SPECTRE", "MECHANICAL", "npc_spectre",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_stalker", "STALKER", "MECHANICAL", "npc_stalker",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_marvin", "MARVIN", "MECHANICAL", "npc_marvin",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_super_spectre", "REAPER / SUPER SPECTRE", "MECHANICAL", "npc_super_spectre",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_stalker_zombie", "ZOMBIE STALKER", "MECHANICAL", "npc_stalker",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_stalker_zombie_mossy", "MOSSY ZOMBIE STALKER", "MECHANICAL", "npc_stalker",
		"VERIFIED_SPAWNABLE", "CAMPAIGN AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )

	TF2VRSB_NpcAdd( list, "npc_prowler", "PROWLER", "WILDLIFE", "npc_prowler",
		"VERIFIED_SPAWNABLE", "CAMPAIGN WILDLIFE // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )

	TF2VRSB_NpcAdd( list, "npc_drone", "ATTACK DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"VERIFIED_SPAWNABLE", "AERIAL AI // NEEDS OPEN SPACE // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_drone_beam", "BEAM DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"VERIFIED_SPAWNABLE", "AERIAL AI // NEEDS OPEN SPACE // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_drone_plasma", "PLASMA DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"VERIFIED_SPAWNABLE", "AERIAL AI // NEEDS OPEN SPACE // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_drone_worker", "WORKER DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"VERIFIED_SPAWNABLE", "AERIAL AI // NEEDS OPEN SPACE // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_frag_drone", "FRAG DRONE / TICK", "DRONES / AIRCRAFT", "npc_frag_drone",
		"VERIFIED_SPAWNABLE", "GROUND DRONE AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )
	TF2VRSB_NpcAdd( list, "npc_frag_drone_throwable", "THROWABLE FRAG DRONE", "DRONES / AIRCRAFT", "npc_frag_drone",
		"VERIFIED_SPAWNABLE", "GROUND DRONE AI // RUNTIME TEST PENDING", "NONE BEYOND A CAMPAIGN MAP", true )

	TF2VRSB_NpcAdd( list, "npc_soldier_bish", "BISH", "HUMAN", "npc_soldier",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_blisk", "BLISK", "HUMAN", "npc_soldier",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_drone_summoner", "DRONE SUMMONER", "HUMAN", "npc_soldier",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_spyglass", "SPYGLASS", "HUMAN", "npc_soldier",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_training_sentry", "TRAINING SENTRY", "HUMAN", "npc_soldier",
		"AI_SETTING_ONLY", "TRAINING AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_pve_sandbox", "PVE SANDBOX SOLDIER", "HUMAN", "npc_soldier",
		"AI_SETTING_ONLY", "PVE TEST AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_pve_specialist", "PVE SPECIALIST", "HUMAN", "npc_soldier",
		"AI_SETTING_ONLY", "PVE TEST AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_soldier_pve_eliteguard", "PVE ELITE GUARD", "HUMAN", "npc_soldier",
		"AI_SETTING_ONLY", "PVE TEST AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_spectre_mortar", "SPECTRE MORTAR", "MECHANICAL", "npc_spectre",
		"AI_SETTING_ONLY", "MORTAR AI SETTINGS // SPECIALIZED SPAWN PATH REQUIRED", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_super_spectre_burnmeter", "SUPER SPECTRE BURN METER", "MECHANICAL", "npc_super_spectre",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_super_spectre_calmer", "SUPER SPECTRE CALMER", "MECHANICAL", "npc_super_spectre",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_drone_cloaked", "CLOAKED DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_drone_rocket", "ROCKET DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_drone_shield", "SHIELD DRONE", "DRONES / AIRCRAFT", "npc_drone",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )

	TF2VRSB_NpcAdd( list, "npc_gunship", "GUNSHIP", "LARGE NPCs", "npc_gunship",
		"VERIFIED_BUT_MAP_DEPENDENT", "REQUIRES FLIGHT PATH / SCRIPTED MAP SUPPORT", "SPECIALIZED MAP SETUP", false )
	TF2VRSB_NpcAdd( list, "npc_gunship_scripted", "SCRIPTED GUNSHIP", "LARGE NPCs", "npc_gunship",
		"REQUIRES_SPECIAL_SPAWNER", "CAMPAIGN SCRIPTED SPAWNER REQUIRED", "CAMPAIGN MAP SCRIPT", false )
	TF2VRSB_NpcAdd( list, "npc_dropship", "DROPSHIP", "LARGE NPCs", "npc_dropship",
		"REQUIRES_SPECIAL_SPAWNER", "FLIGHT PATH AND DROP SEQUENCE REQUIRED", "CAMPAIGN SPAWNER/DROPSHIP PATH", false )
	TF2VRSB_NpcAdd( list, "npc_dropship_dogfighter", "DOGFIGHTER DROPSHIP", "LARGE NPCs", "npc_dropship",
		"DEPRECATED", "DEPRECATED AI SETTINGS // NOT OFFERED FOR SPAWN", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_dropship_hero", "HERO DROPSHIP", "LARGE NPCs", "npc_dropship",
		"REQUIRES_SPECIAL_SPAWNER", "CAMPAIGN SCRIPTED DROPSHIP REQUIRED", "CAMPAIGN MAP SCRIPT", false )

	TF2VRSB_NpcAdd( list, "npc_titan_atlas", "ATLAS TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "TITAN SPAWNER AND TITAN LOADOUT REQUIRED", "SPECIALIZED TITAN SPAWNER", false )
	TF2VRSB_NpcAdd( list, "npc_titan_ogre", "OGRE TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "TITAN SPAWNER AND TITAN LOADOUT REQUIRED", "SPECIALIZED TITAN SPAWNER", false )
	TF2VRSB_NpcAdd( list, "npc_titan_stryder", "STRYDER TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "TITAN SPAWNER AND TITAN LOADOUT REQUIRED", "SPECIALIZED TITAN SPAWNER", false )
	TF2VRSB_NpcAdd( list, "npc_titan_vanguard", "VANGUARD TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "TITAN SPAWNER AND TITAN LOADOUT REQUIRED", "SPECIALIZED TITAN SPAWNER", false )
	TF2VRSB_NpcAdd( list, "npc_titan_sarah", "SARAH'S TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "SCRIPTED TITAN SPAWN REQUIRED", "CAMPAIGN MAP SCRIPT", false )
	TF2VRSB_NpcAdd( list, "npc_titan_buddy", "BUDDY TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "SCRIPTED BUDDY TITAN PATH REQUIRED", "CAMPAIGN MAP SCRIPT", false )
	TF2VRSB_NpcAdd( list, "npc_titan_auto", "AUTO TITAN", "LARGE NPCs", "npc_titan",
		"REQUIRES_SPECIAL_SPAWNER", "AUTO-TITAN SPAWNER / LOADOUT REQUIRED", "SPECIALIZED TITAN SPAWNER", false )

	TF2VRSB_NpcAdd( list, "npc_turret_mega", "MEGA TURRET", "OTHER ENTITIES", "npc_turret_mega",
		"REQUIRES_SPECIAL_SPAWNER", "TURRET MODEL, OWNER AND TURRET SETTINGS REQUIRED", "CreateTurretEnt", false )
	TF2VRSB_NpcAdd( list, "npc_turret_mega_nowindup", "MEGA TURRET NOWINDUP", "OTHER ENTITIES", "npc_turret_mega",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_turret_mega_windup", "MEGA TURRET WINDUP", "OTHER ENTITIES", "npc_turret_mega",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_turret_mega_attrition", "MEGA TURRET ATTRITION", "OTHER ENTITIES", "npc_turret_mega",
		"REQUIRES_SPECIAL_SPAWNER", "TURRET SPAWNER AND OWNER REQUIRED", "CreateTurretEnt", false )
	TF2VRSB_NpcAdd( list, "npc_turret_mega_fortwar", "MEGA TURRET FORT WAR", "OTHER ENTITIES", "npc_turret_mega",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry", "SENTRY TURRET", "OTHER ENTITIES", "npc_turret_sentry",
		"REQUIRES_SPECIAL_SPAWNER", "TURRET MODEL, OWNER AND TURRET SETTINGS REQUIRED", "CreateTurretEnt", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry_plasma", "PLASMA SENTRY", "OTHER ENTITIES", "npc_turret_sentry",
		"REQUIRES_SPECIAL_SPAWNER", "TURRET MODEL, OWNER AND TURRET SETTINGS REQUIRED", "CreateTurretEnt", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry_burn_card_at", "SENTRY BURN CARD AT", "OTHER ENTITIES", "npc_turret_sentry",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry_burn_card_ap", "SENTRY BURN CARD AP", "OTHER ENTITIES", "npc_turret_sentry",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry_tactical_ability", "SENTRY TACTICAL ABILITY", "OTHER ENTITIES", "npc_turret_sentry",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry_tday", "T-DAY SENTRY", "OTHER ENTITIES", "npc_turret_sentry",
		"REQUIRES_SPECIAL_SPAWNER", "TURRET SPAWNER, OWNER AND T-DAY SETUP REQUIRED", "CreateTurretEnt", false )
	TF2VRSB_NpcAdd( list, "npc_turret_sentry_windup", "SENTRY WINDUP", "OTHER ENTITIES", "npc_turret_sentry",
		"DEPRECATED", "DEPRECATED TURRET AI SETTINGS", "NONE", false )

	return list
}

void function TF2VRSB_NpcAdd( array<TF2VRSB_NpcEntry> list, string id, string name, string category,
	string entityId, string status, string restrictions, string dependencies, bool spawnable )
{
	TF2VRSB_NpcEntry entry
	entry.id = id
	entry.name = name
	entry.category = category
	entry.entityId = entityId
	entry.status = status
	entry.restrictions = restrictions
	entry.dependencies = dependencies
	entry.spawnable = spawnable
	list.append( entry )
}

////////////////////////////////////////////////////////////////////////////////
// Helpers
////////////////////////////////////////////////////////////////////////////////

string function TF2VRSB_NpcCategoryName( int category )
{
	switch ( category )
	{
		case 1: return "HUMAN"
		case 2: return "MECHANICAL"
		case 3: return "WILDLIFE"
		case 4: return "DRONES / AIRCRAFT"
		case 5: return "LARGE NPCs"
		case 6: return "OTHER ENTITIES"
	}
	return "ALL"
}

array<var> function TF2VRSB_NpcChildren( var menu, string prefix, int count )
{
	array<var> children = []
	for ( int i = 0; i < count; i++ )
	{
		var child = Hud_GetChild( menu, prefix + string( i ) )
		if ( child != null )
			children.append( child )
		else
			print( "[TF2VRSB] missing NPC control " + prefix + string( i ) + "\n" )
	}
	return children
}

void function TF2VRSB_NpcBind( var menu, string childName, void functionref( var ) callback )
{
	var child = Hud_GetChild( menu, childName )
	if ( child != null )
		Hud_AddEventHandler( child, UIE_CLICK, callback )
}

void function TF2VRSB_NpcWireVertical( array<var> buttons )
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

void function TF2VRSB_NpcSetButton( var menu, string childName, string label, bool enabled )
{
	var button = Hud_GetChild( menu, childName )
	if ( button == null )
		return
	SetButtonRuiText( button, label )
	Hud_SetEnabled( button, enabled )
}

void function TF2VRSB_NpcSetEnabled( var menu, string childName, bool enabled )
{
	var button = Hud_GetChild( menu, childName )
	if ( button != null )
		Hud_SetEnabled( button, enabled )
}

void function TF2VRSB_NpcAddLayoutFooter( var menu )
{
	AddMenuFooterOption( menu, BUTTON_Y,
		PrependControllerPrompts( BUTTON_Y, " LAYOUT BOUNDS" ),
		"LAYOUT BOUNDS",
		TF2VRSB_ToggleLayoutOverlay )
}
