// TF2VR Campaign Sandbox - SERVER VM.
//
// All world state changes happen here. UI commands are intentionally narrow
// and every action validates the local campaign session and sandbox limits.
// Only NPCs created by this file are ever destroyed by the sandbox.

global function TF2VRSB_ServerInit

const int TF2VRSB_MAX_NPC_CAP = 20
const int TF2VRSB_MAX_SPAWN_DISTANCE = 512
const int TF2VRSB_ENTITY_SCAN_LIMIT = 50000
const int TF2VRSB_MANAGED_PAGE_SIZE = 8

struct
{
	array<entity> managed
	array<int> managedIds
	array<string> managedTypes
	array<int> managedTeams
	int nextManagedId
	string mapName
	bool bookmarkSet
	vector bookmarkOrigin
	vector bookmarkAngles
} file

void function TF2VRSB_ServerInit()
{
	file.managed = []
	file.managedIds = []
	file.managedTypes = []
	file.managedTeams = []
	file.nextManagedId = 1
	file.mapName = ""
	file.bookmarkSet = false
	file.bookmarkOrigin = < 0, 0, 0 >
	file.bookmarkAngles = < 0, 0, 0 >

	AddClientCommandCallback( "tf2vrsb_status", TF2VRSB_CommandStatus )
	AddClientCommandCallback( "tf2vrsb_spawn_npc", TF2VRSB_CommandSpawnNpc )
	AddClientCommandCallback( "tf2vrsb_remove_managed", TF2VRSB_CommandRemoveManaged )
	AddClientCommandCallback( "tf2vrsb_clear_managed", TF2VRSB_CommandClearManaged )
	AddClientCommandCallback( "tf2vrsb_save_bookmark", TF2VRSB_CommandSaveBookmark )
	AddClientCommandCallback( "tf2vrsb_return_bookmark", TF2VRSB_CommandReturnBookmark )
	AddClientCommandCallback( "tf2vrsb_clear_bookmark", TF2VRSB_CommandClearBookmark )
	AddClientCommandCallback( "tf2vrsb_toggle_fly", TF2VRSB_CommandToggleFly )
	AddClientCommandCallback( "tf2vrsb_load_preset", TF2VRSB_CommandLoadPreset )

	print( "[TF2VRSB] server sandbox commands registered\n" )
}

////////////////////////////////////////////////////////////////////////////////
// Verified catalog
////////////////////////////////////////////////////////////////////////////////

// Every entry here is an AI-settings name from Titanfall's extracted
// scripts/aisettings/classes.txt. CreateNPCFromAISettings reads the BaseClass
// field and is the same path the game's development spawner uses. Entries are
// still RUNTIME UNTESTED; this list only controls what the server accepts.
array<string> function TF2VRSB_SpawnableNpcIds()
{
	return [
		"npc_soldier",
		"npc_soldier_specialist",
		"npc_soldier_specialist_militia",
		"npc_soldier_sidearm",
		"npc_soldier_shield_captain",
		"npc_soldier_hero_bear",
		"npc_soldier_hero_sarah",
		"npc_pilot_elite",
		"npc_pilot_elite_assassin",
		"npc_pilot_elite_assassin_cqb",
		"npc_pilot_elite_assassin_sniper",
		"npc_spectre",
		"npc_stalker",
		"npc_marvin",
		"npc_super_spectre",
		"npc_stalker_zombie",
		"npc_stalker_zombie_mossy",
		"npc_prowler",
		"npc_drone",
		"npc_drone_beam",
		"npc_drone_plasma",
		"npc_drone_worker",
		"npc_frag_drone",
		"npc_frag_drone_throwable"
	]
}

string function TF2VRSB_NpcDisplay( string id )
{
	switch ( id )
	{
		case "npc_soldier": return "RIFLEMAN"
		case "npc_soldier_specialist": return "IMC SPECIALIST"
		case "npc_soldier_specialist_militia": return "MILITIA SPECIALIST"
		case "npc_soldier_sidearm": return "SIDEARM SOLDIER"
		case "npc_soldier_shield_captain": return "SHIELD CAPTAIN"
		case "npc_soldier_hero_bear": return "BEAR"
		case "npc_soldier_hero_sarah": return "SARAH"
		case "npc_pilot_elite": return "ELITE PILOT"
		case "npc_pilot_elite_assassin": return "ELITE ASSASSIN"
		case "npc_pilot_elite_assassin_cqb": return "ELITE ASSASSIN CQB"
		case "npc_pilot_elite_assassin_sniper": return "ELITE ASSASSIN SNIPER"
		case "npc_spectre": return "SPECTRE"
		case "npc_stalker": return "STALKER"
		case "npc_marvin": return "MARVIN"
		case "npc_super_spectre": return "REAPER / SUPER SPECTRE"
		case "npc_stalker_zombie": return "ZOMBIE STALKER"
		case "npc_stalker_zombie_mossy": return "MOSSY ZOMBIE STALKER"
		case "npc_prowler": return "PROWLER"
		case "npc_drone": return "ATTACK DRONE"
		case "npc_drone_beam": return "BEAM DRONE"
		case "npc_drone_plasma": return "PLASMA DRONE"
		case "npc_drone_worker": return "WORKER DRONE"
		case "npc_frag_drone": return "FRAG DRONE / TICK"
		case "npc_frag_drone_throwable": return "THROWABLE FRAG DRONE"
		case "npc_drone_cloaked": return "CLOAKED DRONE"
		case "npc_drone_rocket": return "ROCKET DRONE"
		case "npc_drone_shield": return "SHIELD DRONE"
		case "npc_gunship": return "GUNSHIP"
		case "npc_gunship_scripted": return "SCRIPTED GUNSHIP"
		case "npc_dropship": return "DROPSHIP"
		case "npc_dropship_dogfighter": return "DOGFIGHTER DROPSHIP"
		case "npc_dropship_hero": return "HERO DROPSHIP"
		case "npc_titan_atlas": return "ATLAS TITAN"
		case "npc_titan_ogre": return "OGRE TITAN"
		case "npc_titan_stryder": return "STRYDER TITAN"
		case "npc_titan_vanguard": return "VANGUARD TITAN"
		case "npc_titan_sarah": return "SARAH'S TITAN"
		case "npc_titan_buddy": return "BUDDY TITAN"
		case "npc_titan_auto": return "AUTO TITAN"
		case "npc_turret_mega": return "MEGA TURRET"
		case "npc_turret_sentry": return "SENTRY TURRET"
		case "npc_turret_sentry_plasma": return "PLASMA SENTRY"
		case "npc_turret_sentry_tday": return "T-DAY SENTRY"
	}
	return id
}

string function TF2VRSB_ManagedPageLabel( int index )
{
	if ( index < 0 || index >= file.managed.len() )
		return ""

	string team = file.managedTeams[ index ] == TEAM_IMC ? "IMC" : ( file.managedTeams[ index ] == TEAM_MILITIA ? "MILITIA" : "OTHER" )
	return "#" + string( file.managedIds[ index ] ) + "  " + TF2VRSB_NpcDisplay( file.managedTypes[ index ] ) + "  [" + team + "]"
}

////////////////////////////////////////////////////////////////////////////////
// Commands
////////////////////////////////////////////////////////////////////////////////

bool function TF2VRSB_CommandStatus( entity player, array<string> args )
{
	SetConVarString( "tf2vrsb_result", "SESSION ONLINE" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandSpawnNpc( entity player, array<string> args )
{
	string reason = TF2VRSB_SessionReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()

	string npcType = GetConVarString( "tf2vrsb_request_npc" )
	if ( TF2VRSB_SpawnableNpcIds().find( npcType ) == -1 )
	{
		TF2VRSB_Reject( player, "NPC TYPE IS NOT IN THE SANDBOX CATALOG" )
		return false
	}

	int cap = GetConVarInt( "tf2vrsb_cap" )
	if ( cap < 1 )
		cap = 1
	if ( cap > TF2VRSB_MAX_NPC_CAP )
		cap = TF2VRSB_MAX_NPC_CAP
	if ( file.managed.len() >= cap )
	{
		TF2VRSB_Reject( player, "NPC CAP REACHED (" + string( cap ) + ")" )
		return false
	}

	int distance = GetConVarInt( "tf2vrsb_spawn_distance" )
	if ( distance < 64 )
		distance = 64
	if ( distance > TF2VRSB_MAX_SPAWN_DISTANCE )
		distance = TF2VRSB_MAX_SPAWN_DISTANCE

	vector forward = AnglesToForward( player.GetAngles() )
	vector origin = player.GetOrigin() + forward * float( distance ) + < 0, 0, 8 >
	TraceResults clear = TraceLine( player.EyePosition(), origin + < 0, 0, 64 >,
		[ player ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	if ( clear.startSolid || clear.fraction < 0.95 )
	{
		TF2VRSB_Reject( player, "NO CLEAR SPAWN POSITION AHEAD" )
		return false
	}

	bool hostile = GetConVarInt( "tf2vrsb_request_team" ) != 0
	int friendlyTeam = player.GetTeam()
	int team = hostile ? ( friendlyTeam == TEAM_IMC ? TEAM_MILITIA : TEAM_IMC ) : friendlyTeam

	entity npc = CreateNPCFromAISettings( npcType, team, origin, player.GetAngles() )
	if ( !IsValid( npc ) )
	{
		TF2VRSB_Reject( player, "ENGINE REJECTED NPC SPAWN" )
		return false
	}
	DispatchSpawn( npc )
	if ( !IsValid( npc ) )
	{
		TF2VRSB_Reject( player, "NPC FAILED TO DISPATCH" )
		return false
	}

	int managedId = file.nextManagedId
	file.nextManagedId++
	file.managed.append( npc )
	file.managedIds.append( managedId )
	file.managedTypes.append( npcType )
	file.managedTeams.append( team )

	TF2VRSB_ServerLog( "spawn id=" + string( managedId ) + " type=" + npcType
		+ " team=" + string( team ) + " origin=" + string( int( origin.x ) ) + ","
		+ string( int( origin.y ) ) + "," + string( int( origin.z ) )
		+ " count=" + string( file.managed.len() ) )
	SetConVarString( "tf2vrsb_result", "SPAWNED " + TF2VRSB_NpcDisplay( npcType )
		+ " #" + string( managedId ) + " (" + string( file.managed.len() ) + "/" + string( cap ) + ")" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandRemoveManaged( entity player, array<string> args )
{
	string reason = TF2VRSB_RecoveryReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()
	int wanted = GetConVarInt( "tf2vrsb_request_managed" )
	int found = -1
	for ( int i = 0; i < file.managedIds.len(); i++ )
	{
		if ( file.managedIds[ i ] == wanted )
		{
			found = i
			break
		}
	}
	if ( found == -1 )
	{
		TF2VRSB_Reject( player, "MANAGED NPC #" + string( wanted ) + " IS NOT TRACKED" )
		return false
	}

	string removedType = file.managedTypes[ found ]
	string label = TF2VRSB_NpcDisplay( removedType )
	if ( IsValid( file.managed[ found ] ) )
		file.managed[ found ].Destroy()
	TF2VRSB_RemoveManagedAt( found )

	TF2VRSB_ServerLog( "remove id=" + string( wanted ) + " type=" + removedType )
	SetConVarString( "tf2vrsb_result", "REMOVED " + label + " #" + string( wanted ) )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandClearManaged( entity player, array<string> args )
{
	string reason = TF2VRSB_RecoveryReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()
	int removed = 0
	foreach ( entity npc in file.managed )
	{
		if ( IsValid( npc ) )
		{
			npc.Destroy()
			removed++
		}
	}
	file.managed = []
	file.managedIds = []
	file.managedTypes = []
	file.managedTeams = []
	TF2VRSB_ServerLog( "clear-managed removed=" + string( removed ) )
	SetConVarString( "tf2vrsb_result", "CLEARED " + string( removed ) + " SANDBOX NPCs" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandSaveBookmark( entity player, array<string> args )
{
	string reason = TF2VRSB_SessionReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()
	file.bookmarkOrigin = player.GetOrigin()
	file.bookmarkAngles = player.GetAngles()
	file.bookmarkSet = true
	TF2VRSB_ServerLog( "bookmark-save origin=" + string( int( file.bookmarkOrigin.x ) ) + ","
		+ string( int( file.bookmarkOrigin.y ) ) + "," + string( int( file.bookmarkOrigin.z ) ) )
	SetConVarString( "tf2vrsb_result", "POSITION BOOKMARK SAVED" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandReturnBookmark( entity player, array<string> args )
{
	string reason = TF2VRSB_RecoveryReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}
	if ( !file.bookmarkSet )
	{
		TF2VRSB_Reject( player, "NO POSITION BOOKMARK IN THIS SESSION" )
		return false
	}

	TF2VRSB_SyncSession()
	float bookmarkYaw = file.bookmarkAngles.y
	player.SetOrigin( file.bookmarkOrigin )
	player.SetAngles( < 0, bookmarkYaw, 0 > )
	player.SetVelocity( < 0, 0, 0 > )
	TF2VRSB_ServerLog( "bookmark-return" )
	SetConVarString( "tf2vrsb_result", "RETURNED TO POSITION BOOKMARK" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandClearBookmark( entity player, array<string> args )
{
	file.bookmarkSet = false
	TF2VRSB_ServerLog( "bookmark-clear" )
	SetConVarString( "tf2vrsb_result", "POSITION BOOKMARK CLEARED" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandToggleFly( entity player, array<string> args )
{
	string reason = TF2VRSB_RecoveryReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()
	if ( player.IsNoclipping() )
	{
		player.SetPhysics( MOVETYPE_WALK )
		player.SetVelocity( < 0, 0, 0 > )
		SetConVarInt( "tf2vrsb_fly", 0 )
		TF2VRSB_ServerLog( "fly-off" )
		SetConVarString( "tf2vrsb_result", "FLY OFF - WALKING" )
	}
	else
	{
		player.SetPhysics( MOVETYPE_NOCLIP )
		player.SetVelocity( < 0, 0, 0 > )
		SetConVarInt( "tf2vrsb_fly", 1 )
		TF2VRSB_ServerLog( "fly-on" )
		SetConVarString( "tf2vrsb_result", "FLY ON - NOCLIP ACTIVE" )
	}

	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandLoadPreset( entity player, array<string> args )
{
	string reason = TF2VRSB_RecoveryReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()
	string currentMap = GetMapName()
	string presetMap = GetConVarString( "tf2vrsb_request_map" )
	if ( presetMap == "" || presetMap != currentMap )
	{
		TF2VRSB_Reject( player, "PRESET MAP DOES NOT MATCH CURRENT MAP" )
		return false
	}

	float x = GetConVarFloat( "tf2vrsb_request_x" )
	float y = GetConVarFloat( "tf2vrsb_request_y" )
	float z = GetConVarFloat( "tf2vrsb_request_z" )
	float yaw = GetConVarFloat( "tf2vrsb_request_yaw" )
	if ( x != x || y != y || z != z || yaw != yaw
		|| x < -1000000.0 || x > 1000000.0 || y < -1000000.0 || y > 1000000.0
		|| z < -1000000.0 || z > 1000000.0 || yaw < -3600.0 || yaw > 3600.0 )
	{
		TF2VRSB_Reject( player, "PRESET POSITION IS OUT OF RANGE" )
		return false
	}

	player.SetOrigin( < x, y, z > )
	player.SetAngles( < 0, yaw, 0 > )
	player.SetVelocity( < 0, 0, 0 > )
	TF2VRSB_ServerLog( "preset-load map=" + currentMap + " xyz=" + string( int( x ) ) + ","
		+ string( int( y ) ) + "," + string( int( z ) ) )
	SetConVarString( "tf2vrsb_result", "POSITION PRESET LOADED" )
	TF2VRSB_UpdateStatus( player )
	return true
}

////////////////////////////////////////////////////////////////////////////////
// Managed NPC state
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_RemoveManagedAt( int index )
{
	array<entity> npcs = []
	array<int> ids = []
	array<string> types = []
	array<int> teams = []
	for ( int i = 0; i < file.managed.len(); i++ )
	{
		if ( i == index )
			continue
		npcs.append( file.managed[ i ] )
		ids.append( file.managedIds[ i ] )
		types.append( file.managedTypes[ i ] )
		teams.append( file.managedTeams[ i ] )
	}
	file.managed = npcs
	file.managedIds = ids
	file.managedTypes = types
	file.managedTeams = teams
}

int function TF2VRSB_CountManagedType( string npcType )
{
	int count = 0
	foreach ( string trackedType in file.managedTypes )
	{
		if ( trackedType == npcType )
			count++
	}
	return count
}

////////////////////////////////////////////////////////////////////////////////
// Status
////////////////////////////////////////////////////////////////////////////////

void function TF2VRSB_UpdateStatus( entity player )
{
	TF2VRSB_SyncSession()
	string mapName = GetMapName()
	string mode = IsSingleplayer() ? "CAMPAIGN" : "MULTIPLAYER"
	SetConVarString( "tf2vrsb_map", mapName )
	SetConVarString( "tf2vrsb_mode", mode )

	if ( IsValid( player ) )
	{
		vector origin = player.GetOrigin()
		SetConVarString( "tf2vrsb_x", string( int( origin.x ) ) )
		SetConVarString( "tf2vrsb_y", string( int( origin.y ) ) )
		SetConVarString( "tf2vrsb_z", string( int( origin.z ) ) )
		SetConVarString( "tf2vrsb_yaw", string( int( player.GetAngles().y ) ) )
	}

	SetConVarInt( "tf2vrsb_npc_count", GetNPCArray().len() )
	SetConVarInt( "tf2vrsb_entity_count", TF2VRSB_CountEntities() )
	SetConVarInt( "tf2vrsb_managed_count", file.managed.len() )
	SetConVarInt( "tf2vrsb_selected_count", TF2VRSB_CountManagedType( GetConVarString( "tf2vrsb_request_npc" ) ) )
	SetConVarInt( "tf2vrsb_bookmark", file.bookmarkSet ? 1 : 0 )
	if ( IsValid( player ) )
		SetConVarInt( "tf2vrsb_fly", player.IsNoclipping() ? 1 : 0 )
	else
		SetConVarInt( "tf2vrsb_fly", 0 )
	TF2VRSB_PublishManagedPage()
	SetConVarInt( "tf2vrsb_ready", 1 )
}

void function TF2VRSB_PublishManagedPage()
{
	int page = GetConVarInt( "tf2vrsb_managed_page" )
	if ( page < 0 )
		page = 0
	int pages = ( file.managed.len() + TF2VRSB_MANAGED_PAGE_SIZE - 1 ) / TF2VRSB_MANAGED_PAGE_SIZE
	if ( pages < 1 )
		pages = 1
	if ( page >= pages )
		page = pages - 1
	SetConVarInt( "tf2vrsb_managed_page", page )
	SetConVarInt( "tf2vrsb_managed_pages", pages )

	for ( int slot = 0; slot < TF2VRSB_MANAGED_PAGE_SIZE; slot++ )
	{
		int index = page * TF2VRSB_MANAGED_PAGE_SIZE + slot
		SetConVarString( "tf2vrsb_managed_" + string( slot ), TF2VRSB_ManagedPageLabel( index ) )
		SetConVarInt( "tf2vrsb_managed_id_" + string( slot ), index >= 0 && index < file.managedIds.len() ? file.managedIds[ index ] : -1 )
	}
}

void function TF2VRSB_ServerLog( string message )
{
	if ( GetConVarInt( "tf2vrsb_debug" ) != 1 )
		return
	print( "[TF2VRSB][server] " + message + "\n" )
}

void function TF2VRSB_Reject( entity player, string message )
{
	SetConVarString( "tf2vrsb_result", "REJECTED: " + message )
	TF2VRSB_UpdateStatus( player )
	print( "[TF2VRSB] " + message + "\n" )
}

string function TF2VRSB_SessionReason( entity player )
{
	return TF2VRSB_CheckSession( player, true )
}

string function TF2VRSB_RecoveryReason( entity player )
{
	return TF2VRSB_CheckSession( player, false )
}

string function TF2VRSB_CheckSession( entity player, bool requireGround )
{
	if ( !IsSingleplayer() )
		return "CAMPAIGN ONLY"
	if ( GetMapName() == "" )
		return "NO ACTIVE MAP"
	if ( !IsValid( player ) )
		return "NO LOCAL PLAYER"
	if ( !IsAlive( player ) )
		return "PLAYER IS NOT ALIVE"
	if ( requireGround && !player.IsOnGround() )
		return "STAND ON SOLID GROUND FIRST"
	return ""
}

void function TF2VRSB_SyncSession()
{
	string currentMap = GetMapName()
	if ( file.mapName == currentMap )
	{
		TF2VRSB_PruneManaged()
		return
	}

	if ( file.mapName != "" )
	{
		TF2VRSB_ServerLog( "map-change from=" + file.mapName + " to=" + currentMap )
		// Level teardown invalidates handles. Do not touch the old entities.
		file.managed = []
		file.managedIds = []
		file.managedTypes = []
		file.managedTeams = []
		file.bookmarkSet = false
	}
	file.mapName = currentMap
	TF2VRSB_PruneManaged()
}

void function TF2VRSB_PruneManaged()
{
	array<entity> npcs = []
	array<int> ids = []
	array<string> types = []
	array<int> teams = []
	for ( int i = 0; i < file.managed.len(); i++ )
	{
		if ( IsValid( file.managed[ i ] ) )
		{
			npcs.append( file.managed[ i ] )
			ids.append( file.managedIds[ i ] )
			types.append( file.managedTypes[ i ] )
			teams.append( file.managedTeams[ i ] )
		}
	}
	file.managed = npcs
	file.managedIds = ids
	file.managedTypes = types
	file.managedTeams = teams
}

int function TF2VRSB_CountEntities()
{
	int count = 0
	entity ent = Entities_First()
	while ( ent != null && count < TF2VRSB_ENTITY_SCAN_LIMIT )
	{
		count++
		ent = Entities_Next( ent )
	}
	return count
}
