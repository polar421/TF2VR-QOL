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
global function TF2VRSB_ToggleLayoutOverlay

const string TF2VRSB_LAYOUT_OVERLAY = "tf2vrsb_overlay"

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
	if ( menu == null )
	{
		file.activeLayoutMenu = null
		print( "[TF2VRSB][layout] page=" + page + " menu=NULL\n" )
		return
	}

	// Keep the overlay independent of the nslog switch: it is useful on its
	// own, and the debug page can turn logging off while bounds stay visible.
	file.activeLayoutPage = page
	file.activeLayoutMenu = menu
	TF2VRSB_DrawLayoutOverlay( page, menu )

	if ( !TF2VRSB_DebugEnabled() )
		return

	print( "[TF2VRSB][layout] page=" + page
		+ " screen=" + string( GetScreenSize()[ 0 ] ) + "x"
		+ string( GetScreenSize()[ 1 ] ) + "\n" )
	print( "[TF2VRSB][layout] menu " + TF2VRSB_HudDescription( menu ) + "\n" )

	for ( int i = 0; i < names.len(); i++ )
		TF2VRSB_LogControl( menu, names[ i ] )

	TF2VRSB_LogState( "layout:" + page )
}

array<string> function TF2VRSB_LayoutOverlayNames( string page )
{
	array<string> names = []
	if ( page == "root" )
	{
		for ( int i = 0; i < 6; i++ )
			names.append( "Row" + string( i ) )
		names.append( "FooterButtons" )
		return names
	}
	if ( page == "maps" )
	{
		for ( int i = 0; i < 13; i++ )
			names.append( "Map" + string( i ) )
		names.append( "FooterButtons" )
		return names
	}
	if ( page == "npcs" )
	{
		names.append( "SpawnHostileSoldier" )
		names.append( "SpawnHostileSpectre" )
		names.append( "SpawnFriendlySoldier" )
		names.append( "ClearManaged" )
		names.append( "SwitchNpcCap" )
		names.append( "SwitchSpawnDistance" )
		names.append( "BtnBack" )
		names.append( "FooterButtons" )
		return names
	}
	if ( page == "player" )
	{
		names.append( "SaveBookmark" )
		names.append( "ReturnBookmark" )
		names.append( "ClearBookmark" )
		names.append( "ToggleFly" )
		names.append( "BtnBack" )
		names.append( "FooterButtons" )
		return names
	}
	if ( page == "presets" )
	{
		names.append( "Save1" )
		names.append( "Load1" )
		names.append( "Save2" )
		names.append( "Load2" )
		names.append( "Save3" )
		names.append( "Load3" )
		names.append( "BtnBack" )
		names.append( "FooterButtons" )
		return names
	}
	if ( page == "developer" )
	{
		names.append( "LogLayout" )
		names.append( "Refresh" )
		names.append( "SwitchDebug" )
		names.append( "BtnBack" )
		names.append( "FooterButtons" )
	}
	return names
}

bool function TF2VRSB_PlaceLayoutBox( var menu, string boxName, var target )
{
	if ( menu == null || target == null || !Hud_IsVisible( target ) )
		return false

	var box = Hud_GetChild( menu, boxName )
	int width = Hud_GetWidth( target )
	int height = Hud_GetHeight( target )
	if ( box == null || width <= 0 || height <= 0 )
		return false

	Hud_SetPos( box, Hud_GetAbsX( target ) - Hud_GetAbsX( menu ),
		Hud_GetAbsY( target ) - Hud_GetAbsY( menu ) )
	Hud_SetSize( box, width, height )
	Hud_Show( box )
	return true
}

void function TF2VRSB_DrawLayoutOverlay( string page, var menu )
{
	file.activeLayoutPage = page
	file.activeLayoutMenu = menu
	if ( menu == null )
		return

	for ( int i = 0; i < 15; i++ )
	{
		var box = Hud_GetChild( menu, "Debug" + string( i ) )
		if ( box != null )
			Hud_Hide( box )
	}

	var menuBox = Hud_GetChild( menu, "DebugMenu" )
	var legend = Hud_GetChild( menu, "DebugLegend" )
	if ( menuBox != null )
		Hud_Hide( menuBox )
	if ( legend != null )
		Hud_Hide( legend )

	if ( GetConVarInt( TF2VRSB_LAYOUT_OVERLAY ) != 1 )
		return

	int drawn = 0
	if ( TF2VRSB_PlaceLayoutBox( menu, "DebugMenu", Hud_GetChild( menu, "Panel" ) ) )
		drawn++

	array<string> names = TF2VRSB_LayoutOverlayNames( page )
	for ( int i = 0; i < names.len() && i < 15; i++ )
	{
		if ( TF2VRSB_PlaceLayoutBox( menu, "Debug" + string( i ), Hud_GetChild( menu, names[ i ] ) ) )
			drawn++
	}

	if ( drawn > 0 && legend != null )
		Hud_Show( legend )
	if ( TF2VRSB_DebugEnabled() )
		print( "[TF2VRSB][overlay] page=" + page + " visible=1 boxes=" + string( drawn ) + "\n" )
}

void function TF2VRSB_ToggleLayoutOverlay( var button )
{
	int enabled = GetConVarInt( TF2VRSB_LAYOUT_OVERLAY ) == 1 ? 0 : 1
	SetConVarInt( TF2VRSB_LAYOUT_OVERLAY, enabled )
	TF2VRSB_DrawLayoutOverlay( file.activeLayoutPage, file.activeLayoutMenu )
	if ( TF2VRSB_DebugEnabled() )
		print( "[TF2VRSB][overlay] visible=" + string( enabled ) + "\n" )
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
