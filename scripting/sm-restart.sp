#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

Handle cvarEnabled = INVALID_HANDLE;
Handle cvarTime = INVALID_HANDLE;

public Plugin myinfo = {
	name = "AutoRestart",
	author = "B3none, MikeJS",
	description = "Restarts servers once a day when they empty.",
	version = "1.0.0",
	url = "https://github.com/b3none",
}

public void OnPluginStart() {
	cvarEnabled = CreateConVar("sm_autorestart", "1", "Enable AutoRestart.");
	cvarTime = CreateConVar("sm_autorestart_time", "0500", "Time to restart server at.", _, true, 0.0, true, 2400.0);

	CreateTimer(300.0, CheckRestart, 0, TIMER_REPEAT);
}

public Action CheckRestart(Handle timer, bool ignore) {
	if(!GetConVarBool(cvarEnabled)) 
	{
		return;
	}

	// Is the server empty?
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientConnected(i) && !IsFakeClient(i)) 
		{
			return;
		}
	}

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/lastrestart.txt");

	// Did we already restart today?
	char currentDay[8];
	FormatTime(currentDay, sizeof(currentDay), "%j");

	new const lastRestart = GetFileTime( path, FileTime_LastChange );
	char lastRestartDay[8] = "";

	if(lastRestart != -1)
	{
		FormatTime(lastRestartDay, sizeof(lastRestartDay), "%j", lastRestart);
	}

	if(StrEqual(currentDay, lastRestartDay))
	{
		return;
	}

	char time[8];
	FormatTime(time, sizeof(time), "%H%M");

	// Is it too early to restart?
	if(StringToInt(time) < GetConVarInt(cvarTime)) 
	{
		return;
	}

	// Touch autorestart.txt
	Handle file = OpenFile(path, "w");
	bool written = false;
	bool closed = false;

	if(file != INVALID_HANDLE)
	{
		written = WriteFileString(file, "Don't touch this file", true);
		closed = CloseHandle(file);
	}

	// Don't restart endlessly if we couldn't...
	if(file == INVALID_HANDLE || !written || !closed) {
		LogError("Couldn't write %s.", path);
		return;
	}

	// All good
	LogMessage("Restarting...");
	ServerCommand("_restart");
}
