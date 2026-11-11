// TF2VR Campaign Sandbox - UI layout and state diagnostics.
//
// Enabled by tf2vrsb_debug=1 (the default). Every sandbox page open writes a
// geometry dump to the Northstar log, and state/action events are logged as
// they happen. This module is UI-only; the SERVER VM has its own action log.

global function TF2VRSB_DebugInit
global function TF2VRSB_LogRootLayout
global function TF2VRSB_LogMapsLayout
global function TF2VRSB_LogNpcsLayout
global function TF2VRSB_LogPlayerLayout
global function TF2VRSB_LogPresetsLayout
global function TF2VRSB_LogDeveloperLayout
global function TF2VRSB_LogState
global function TF2VRSB_LogEvent

void function TF2VRSB_DebugInit()
{
	print( "[TF2VRSB] layout/state diagnostics ready (tf2vrsb_debug=1 enables)\n" )
}

bool function TF2VRSB_DebugEnabled()
{
	return GetConVarInt( "tf2vrsb_debug" ) == 1
}

void function TF2VRSB_LogEvent( string kind, string detail )
{
	if ( !TF2VRSB_DebugEnabled() )
		return
	print( "[TF2VRSB][event] " + kind + " " + detail + "\n" )
}

void function TF2VRSB_LogState( string source )
{
	if ( !TF2VRSB_DebugEnabled() )
		return

	print( "[TF2VRSB][state] source=" + source
		+ " map=" + GetConVarString( "tf2vrsb_map" )
		+ " mode=" + GetConVarString( "tf2vrsb_mode" )
		+ " ready=" + string( GetConVarInt( "tf2vrsb_ready" ) )
		+ " pos=" + GetConVarString( "tf2vrsb_x" ) + ","
		+ GetConVarString( "tf2vrsb_y" ) + ","
		+ GetConVarString( "tf2vrsb_z" )
		+ " yaw=" + GetConVarString( "tf2vrsb_yaw" )
		+ " npcs=" + GetConVarString( "tf2vrsb_npc_count" )
		+ " managed=" + GetConVarString( "tf2vrsb_managed_count" )
		+ " bookmark=" + string( GetConVarInt( "tf2vrsb_bookmark" ) )
		+ " fly=" + string( GetConVarInt( "tf2vrsb_fly" ) )
		+ " result=\"" + GetConVarString( "tf2vrsb_result" ) + "\"\n" )
}

string function TF2VRSB_HudDescription( var hud )
{
	var parentHud = Hud_GetParent( hud )
	string parentText = "parent=NULL"
	if ( parentHud != null )
	{
		parentText = "parentAbs=(" + string( Hud_GetAbsX( parentHud ) ) + ","
			+ string( Hud_GetAbsY( parentHud ) ) + ")"
			+ " parentSize=(" + string( Hud_GetWidth( parentHud ) ) + "x"
			+ string( Hud_GetHeight( parentHud ) ) + ")"
	}

	return "rel=(" + string( Hud_GetX( hud ) ) + "," + string( Hud_GetY( hud ) ) + ")"
		+ " abs=(" + string( Hud_GetAbsX( hud ) ) + "," + string( Hud_GetAbsY( hud ) ) + ")"
		+ " size=(" + string( Hud_GetWidth( hud ) ) + "x" + string( Hud_GetHeight( hud ) ) + ")"
		+ " visible=" + ( Hud_IsVisible( hud ) ? "1" : "0" )
		+ " enabled=" + ( Hud_IsEnabled( hud ) ? "1" : "0" )
		+ " scriptID=" + Hud_GetScriptID( hud )
		+ " " + parentText
}

void function TF2VRSB_LogControl( var menu, string name )
{
	if ( !TF2VRSB_DebugEnabled() )
		return
	var hud = Hud_GetChild( menu, name )
	if ( hud == null )
	{
		print( "[TF2VRSB][layout] " + name + "=NULL\n" )
		return
	}

	print( "[TF2VRSB][layout] " + name + " " + TF2VRSB_HudDescription( hud )
		+ " text=\"" + Hud_GetUTF8Text( hud ) + "\"\n" )
}

void function TF2VRSB_LogPage( string page, var menu, array<string> names )
{
	if ( !TF2VRSB_DebugEnabled() )
		return
	if ( menu == null )
	{
		print( "[TF2VRSB][layout] page=" + page + " menu=NULL\n" )
		return
	}

	print( "[TF2VRSB][layout] page=" + page
		+ " screen=" + string( GetScreenSize()[ 0 ] ) + "x"
		+ string( GetScreenSize()[ 1 ] ) + "\n" )
	print( "[TF2VRSB][layout] menu " + TF2VRSB_HudDescription( menu ) + "\n" )

	for ( int i = 0; i < names.len(); i++ )
		TF2VRSB_LogControl( menu, names[ i ] )

	TF2VRSB_LogState( "layout:" + page )
}

void function TF2VRSB_LogRootLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"SessionValue", "MapValue", "CountValue",
		"Row0", "Row1", "Row2", "Row3", "Row4", "Row5",
		"HintText", "Status", "FooterButtons"
	]
	TF2VRSB_LogPage( "root", menu, names )
}

void function TF2VRSB_LogMapsLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"CurrentMapValue",
		"Map0", "Map1", "Map2", "Map3", "Map4", "Map5", "Map6",
		"Map7", "Map8", "Map9", "Map10", "Map11", "Map12",
		"MapDetails", "MapStatus", "FooterButtons"
	]
	TF2VRSB_LogPage( "maps", menu, names )
}

void function TF2VRSB_LogNpcsLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"ManagedValue", "SpawnHostileSoldier", "SpawnHostileSpectre",
		"SpawnFriendlySoldier", "ClearManaged", "SwitchNpcCap",
		"SwitchSpawnDistance", "BtnBack", "NpcStatus", "FooterButtons"
	]
	TF2VRSB_LogPage( "npcs", menu, names )
}

void function TF2VRSB_LogPlayerLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"BookmarkValue", "PositionValue", "SaveBookmark", "ReturnBookmark",
		"ClearBookmark", "ToggleFly", "BtnBack", "Status", "HintText",
		"FooterButtons"
	]
	TF2VRSB_LogPage( "player", menu, names )
}

void function TF2VRSB_LogPresetsLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"Slot0Status", "Slot1Status", "Slot2Status",
		"Save1", "Save2", "Save3", "Load1", "Load2", "Load3",
		"BtnBack", "PresetStatus", "FooterButtons"
	]
	TF2VRSB_LogPage( "presets", menu, names )
}

void function TF2VRSB_LogDeveloperLayout( var menu )
{
	WaitFrame()
	WaitFrame()
	array<string> names = [
		"Panel", "AccentTop", "PanelHeader", "HeaderRule", "SubHeader",
		"MapValue", "ModeValue", "PositionValue", "CountsValue", "CapValue",
		"LimitsValue", "LogLayout", "Refresh", "SwitchDebug", "BtnBack",
		"FooterButtons"
	]
	TF2VRSB_LogPage( "developer", menu, names )
}
