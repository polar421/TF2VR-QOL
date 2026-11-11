// TF2VR Campaign Sandbox - CLIENT VM.
//
// UI scripts cannot send server commands directly. They call this small
// documented bridge with RunClientScript, and this VM forwards the command
// through the local player.

global function TF2VRSB_ClientInit
global function TF2VRSB_SendCommand

void function TF2VRSB_ClientInit()
{
	print( "[TF2VRSB] client command bridge ready\n" )
}

void function TF2VRSB_SendCommand( string command )
{
	array<string> allowed = [
		"tf2vrsb_status",
		"tf2vrsb_spawn_imc_soldier",
		"tf2vrsb_spawn_imc_spectre",
		"tf2vrsb_spawn_friendly_soldier",
		"tf2vrsb_clear_managed",
		"tf2vrsb_save_bookmark",
		"tf2vrsb_return_bookmark",
		"tf2vrsb_clear_bookmark",
		"tf2vrsb_toggle_fly",
		"tf2vrsb_load_preset"
	]
	if ( allowed.find( command ) == -1 )
		return

	entity player = GetLocalClientPlayer()
	if ( player == null )
		return

	player.ClientCommand( command )
}
