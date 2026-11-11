// TF2VR Campaign Sandbox - SERVER VM.
//
// All world state changes happen here. UI commands are intentionally narrow
// and every action validates the local campaign session and sandbox limits.
// Only NPCs created by this file are ever destroyed by Clear Managed NPCs.

global function TF2VRSB_ServerInit

const int TF2VRSB_MAX_NPC_CAP = 20
const int TF2VRSB_MAX_SPAWN_DISTANCE = 512
const int TF2VRSB_ENTITY_SCAN_LIMIT = 50000

struct
{
	array<entity> managed
	string mapName
	bool bookmarkSet
	vector bookmarkOrigin
	vector bookmarkAngles
} file

void function TF2VRSB_ServerInit()
{
	file.managed = []
	file.mapName = ""
	file.bookmarkSet = false
	file.bookmarkOrigin = < 0, 0, 0 >
	file.bookmarkAngles = < 0, 0, 0 >

	AddClientCommandCallback( "tf2vrsb_status", TF2VRSB_CommandStatus )
	AddClientCommandCallback( "tf2vrsb_spawn_imc_soldier", TF2VRSB_CommandSpawnImcSoldier )
	AddClientCommandCallback( "tf2vrsb_spawn_imc_spectre", TF2VRSB_CommandSpawnImcSpectre )
	AddClientCommandCallback( "tf2vrsb_spawn_friendly_soldier", TF2VRSB_CommandSpawnFriendlySoldier )
	AddClientCommandCallback( "tf2vrsb_clear_managed", TF2VRSB_CommandClearManaged )
	AddClientCommandCallback( "tf2vrsb_save_bookmark", TF2VRSB_CommandSaveBookmark )
	AddClientCommandCallback( "tf2vrsb_return_bookmark", TF2VRSB_CommandReturnBookmark )
	AddClientCommandCallback( "tf2vrsb_clear_bookmark", TF2VRSB_CommandClearBookmark )
	AddClientCommandCallback( "tf2vrsb_load_preset", TF2VRSB_CommandLoadPreset )

	print( "[TF2VRSB] server sandbox commands registered\n" )
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

bool function TF2VRSB_CommandSpawnImcSoldier( entity player, array<string> args )
{
	return TF2VRSB_SpawnManagedNpc( player, "npc_soldier", true, "HOSTILE SOLDIER" )
}

bool function TF2VRSB_CommandSpawnImcSpectre( entity player, array<string> args )
{
	return TF2VRSB_SpawnManagedNpc( player, "npc_spectre", true, "HOSTILE SPECTRE" )
}

bool function TF2VRSB_CommandSpawnFriendlySoldier( entity player, array<string> args )
{
	return TF2VRSB_SpawnManagedNpc( player, "npc_soldier", false, "FRIENDLY SOLDIER" )
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
	SetConVarString( "tf2vrsb_result", "RETURNED TO POSITION BOOKMARK" )
	TF2VRSB_UpdateStatus( player )
	return true
}

bool function TF2VRSB_CommandClearBookmark( entity player, array<string> args )
{
	file.bookmarkSet = false
	SetConVarString( "tf2vrsb_result", "POSITION BOOKMARK CLEARED" )
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
	SetConVarString( "tf2vrsb_result", "POSITION PRESET LOADED" )
	TF2VRSB_UpdateStatus( player )
	return true
}

////////////////////////////////////////////////////////////////////////////////
// NPC operations
////////////////////////////////////////////////////////////////////////////////

bool function TF2VRSB_SpawnManagedNpc( entity player, string className, bool hostile, string label )
{
	string reason = TF2VRSB_SessionReason( player )
	if ( reason != "" )
	{
		TF2VRSB_Reject( player, reason )
		return false
	}

	TF2VRSB_SyncSession()
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

	int friendlyTeam = player.GetTeam()
	int team = hostile ? ( friendlyTeam == TEAM_IMC ? TEAM_MILITIA : TEAM_IMC ) : friendlyTeam
	entity npc = CreateNPC( className, team, origin, player.GetAngles() )
	if ( !IsValid( npc ) )
	{
		TF2VRSB_Reject( player, "ENGINE REJECTED NPC SPAWN" )
		return false
	}
	DispatchSpawn( npc )
	file.managed.append( npc )
	SetConVarString( "tf2vrsb_result", "SPAWNED " + label + " (" + string( file.managed.len() ) + "/" + string( cap ) + ")" )
	TF2VRSB_UpdateStatus( player )
	return true
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
	SetConVarInt( "tf2vrsb_bookmark", file.bookmarkSet ? 1 : 0 )
	SetConVarInt( "tf2vrsb_ready", 1 )
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
		// Level teardown invalidates handles. Do not touch the old entities.
		file.managed = []
		file.bookmarkSet = false
	}
	file.mapName = currentMap
	TF2VRSB_PruneManaged()
}

void function TF2VRSB_PruneManaged()
{
	array<entity> validNpcs = []
	foreach ( entity npc in file.managed )
	{
		if ( IsValid( npc ) )
			validNpcs.append( npc )
	}
	file.managed = validNpcs
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
