#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define MESSAGE_PREFIX "[\x02Restart\x01]"

Handle cvarEnabled = INVALID_HANDLE;
Handle cvarTime = INVALID_HANDLE;
Handle cvarBackupTime = INVALID_HANDLE;

float CheckInterval = 300.0;

public Plugin myinfo = {
	name = "Restart",
	author = "B3none",
	description = "Restarts servers once a day when they empty.",
	version = "1.2.1",
	url = "https://github.com/b3none",
}

public void OnPluginStart() 
{
	cvarEnabled = CreateConVar("sm_restart_enabled", "1", "Enable AutoRestart.");
	cvarTime = CreateConVar("sm_restart_time", "0500", "Time to restart server at.", _, true, 0.0, true, 2400.0);
	cvarBackupTime = CreateConVar("sm_restart_time_backup", "1400", "Backup time to restart server at (Must be more than cvarTime).", _, true, 0.0, true, 2400.0);
	
	if(GetConVarInt(cvarBackupTime) < GetConVarInt(cvarTime))
	{
		ThrowError("The backup restart time cannot be less than the restart time.");
	}

	CreateTimer(CheckInterval, CheckRestart, 0, TIMER_REPEAT);
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

	if(lastRestart != -1)
	{
		FormatTime(lastRestartDay, sizeof(lastRestartDay), "%j", lastRestart);
	}

	// If the server was restarted in the last day, return.
	if(StrEqual(currentDay, lastRestartDay))
	{
		return;
	}

	char time[8];
	FormatTime(time, sizeof(time), "%H%M");

	
	if(IsInRange(StringToInt(time), GetConVarInt(cvarBackupTime)))
	{
		PrintToChatAll("%s The server is restarting in the next minute.", MESSAGE_PREFIX);
	}
	else if(!IsServerEmpty() || !IsInRange(StringToInt(time), GetConVarInt(cvarTime))) 
	{
		return;
	}
	
	// Touch autorestart.txt
	Handle file = OpenFile(path, "w");
	bool written = WriteFileString(file, "Don't touch this file\nRuthless plug: https://github.com/b3none", true);

	// Don't restart endlessly if we couldn't...
	if(file == INVALID_HANDLE || !written)
	{
		LogError("Couldn't write %s.", path);
		
		return;
	}
	
	delete file;

	CreateTimer(60.0, RestartServer);
}

public Action RestartServer(Handle timer)
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

stock bool IsInRange(int CurrentTime, int ConVarTime)
{
	int Difference = CurrentTime - ConVarTime;
	int Range = RoundFloat(CheckInterval) / 60;
	
	return Difference > 0 && Difference <= Range;
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
