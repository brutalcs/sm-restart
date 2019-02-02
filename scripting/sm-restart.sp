#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define MESSAGE_PREFIX "[\x02Restart\x01]"

Handle cvarEnabled = INVALID_HANDLE;
Handle cvarTime = INVALID_HANDLE;
Handle cvarBackupTime = INVALID_HANDLE;

public Plugin myinfo = {
	name = "Restart",
	author = "B3none",
	description = "Restarts servers once a day when they empty.",
	version = "1.1.1",
	url = "https://github.com/b3none",
}

public void OnPluginStart() 
{
	cvarEnabled = CreateConVar("sm_autorestart", "1", "Enable AutoRestart.");
	cvarTime = CreateConVar("sm_autorestart_time", "0500", "Time to restart server at.", _, true, 0.0, true, 2400.0);
	cvarBackupTime = CreateConVar("sm_autorestart_time_backup", "1400", "Backup time to restart server at (Must be more than cvarTime).", _, true, 0.0, true, 2400.0);
	
	if(GetConVarInt(cvarBackupTime) < GetConVarInt(cvarTime))
	{
		ThrowError("The backup restart time cannot be less than the restart time.");
	}

	CreateTimer(300.0, CheckRestart, 0, TIMER_REPEAT);
}

public Action CheckRestart(Handle timer, bool ignore) 
{
	if(!GetConVarBool(cvarEnabled)) 
	{
		return;
	}

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/lastrestart.txt");

	// Did we already restart today?
	char currentDay[8];
	FormatTime(currentDay, sizeof(currentDay), "%j");

	int lastRestart = GetFileTime(path, FileTime_LastChange);
	char lastRestartDay[8] = "";
	
	PrintToChatAll("%i", lastRestart);
	PrintToChatAll("%s", lastRestartDay);

	if(lastRestart != -1)
	{
		FormatTime(lastRestartDay, sizeof(lastRestartDay), "%j", lastRestart);
	}

	if(StrEqual(currentDay, lastRestartDay))
	{
		PrintToChatAll("The server not restarting because current day is the same as the last restart day.");
		return;
	}

	char time[8];
	FormatTime(time, sizeof(time), "%H%M");

	if(!IsServerEmpty() && StringToInt(time) == GetConVarInt(cvarBackupTime))
	{
		PrintToChatAll("Using backup time");
		
		PrintToChatAll("%s The server is restarting.", MESSAGE_PREFIX);
	}
	else if(StringToInt(time) < GetConVarInt(cvarTime)) 
	{
		PrintToChatAll("The server not restarting because current time is less than the set restart time.");
		
		return;
	}

	// Touch autorestart.txt
	Handle file = OpenFile(path, "w");
	bool written = false;

	written = WriteFileString(file, "Don't touch this file", true);

	// Don't restart endlessly if we couldn't...
	if(file == INVALID_HANDLE || !written)
	{
		LogError("Couldn't write %s.", path);
		
		return;
	}
	
	delete file;

	RestartServer();
}

void RestartServer()
{
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsValidClient(i)) 
		{
			ClientCommand(i, "retry");
		}
	}
	
	// All good
	LogMessage("Restarting...");
	ServerCommand("_restart");
}

stock bool IsServerEmpty()
{
	// Is the server empty?
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsValidClient(i)) 
		{
			return false;
		}
	}
	
	return true;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && IsClientAuthorized(client) && !IsFakeClient(client);
}
