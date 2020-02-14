/*
    SourceMod Anti-Cheat
    Copyright (C) 2011-2016 SMAC Development Team 
    Copyright (C) 2007-2011 CodingDirect LLC
   
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <smac>

public Plugin myinfo = 
{
	name = "SMAC Status Protect", 
	author = SMAC_AUTHOR, 
	description = "Prevents flooding spam and ping commands", 
	version = SMAC_VERSION, 
	url = SMAC_URL
};

Handle g_hTimersFlood[MAXPLAYERS + 1];

ConVar  
g_hCvarStatusShow = null, 
g_hCvarPingShow = null, 
g_hCvarSelfShow = null, 
g_hCvarAdminShow = null;

bool g_bCvarStatusShow, 
g_bCvarPingShow, 
g_bCvarSelfShow, 
g_bCvarAdminShow;

int g_iSpamLimit[MAXPLAYERS + 1];



public void OnPluginStart()
{
	RegConsoleCmd("status", StatusCmd);
	RegConsoleCmd("ping", PingCmd);
	RegConsoleCmd("sm_status", StatusCmd);
	RegConsoleCmd("sm_ping", PingCmd);
	
	g_hCvarStatusShow = SMAC_CreateConVar("smac_status_show", "1", "Hide(0) or show (1) status command.", 0, true, 0.0, true, 1.0);
	g_hCvarPingShow = SMAC_CreateConVar("smac_ping_show", "1", "Hide(0) or show (1) ping command.", 0, true, 0.0, true, 1.0);
	g_hCvarSelfShow = SMAC_CreateConVar("smac_status_self_show", "1", "Print into status: only self (0) or all players (1) to non-admin clients.", 0, true, 0.0, true, 1.0);
	g_hCvarAdminShow = SMAC_CreateConVar("smac_status_admin_show", "1", "Print into status: only self (0) or all players (1) to admins.", 0, true, 0.0, true, 1.0);
	
	HookConVarChange(g_hCvarStatusShow, OnCvarChanged);
	HookConVarChange(g_hCvarPingShow, OnCvarChanged);
	HookConVarChange(g_hCvarSelfShow, OnCvarChanged);
	HookConVarChange(g_hCvarAdminShow, OnCvarChanged);
	
}

public void OnCvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	bool bNewValue = GetConVarBool(convar);
	if (convar == g_hCvarStatusShow)g_bCvarStatusShow = bNewValue;
	else if (convar == g_hCvarPingShow)g_bCvarPingShow = bNewValue;
	else if (convar == g_hCvarSelfShow)g_bCvarSelfShow = bNewValue;
	else g_bCvarAdminShow = bNewValue;
}

public Action StatusCmd(int client, int args)
{
	if (g_hTimersFlood[client] == null)g_hTimersFlood[client] = CreateTimer(5.0, Timer_Func, client);
	
	if (++g_iSpamLimit[client] >= 5 && client != 0 && GetUserAdmin(client) == INVALID_ADMIN_ID)
	{
		g_iSpamLimit[client] = 0;
		SMAC_Ban(client, "Command Spam: Status");
	}
	
	if (!g_bCvarStatusShow)
	{
		DisplayStatus(client);
		ForStatusCmd(client);
	}
	else if (client == 0)
	{
		DisplayStatus(client);
		ForStatusCmd(client);
	}
	
	return Plugin_Handled;
}

public Action Timer_Func(Handle timer, any client) {
	g_iSpamLimit[client] = 0;
	g_hTimersFlood[client] = null;
	return Plugin_Continue;
}

public void DisplayStatus(int client) {
	
	int
	g_iClientInServer = GetClientCount(), 
	g_iServerPort = GetConVarInt(FindConVar("hostport")), 
	g_iHostIp = GetConVarInt(FindConVar("hostip"));
	
	bool
	tv_enable = GetConVarBool(FindConVar("tv_enable"));
	
	
	char
	g_sHostName[64], 
	g_sCurrentMap[32], 
	g_sServerIpHost[32];
	
	Handle hostname = FindConVar("hostname");
	
	GetConVarString(hostname, g_sHostName, sizeof(g_sHostName));
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	
	FormatEx(g_sServerIpHost, sizeof(g_sServerIpHost), "%u.%u.%u.%u:%i", g_iHostIp >>> 24 & 255, g_iHostIp >>> 16 & 255, g_iHostIp >>> 8 & 255, g_iHostIp & 255, g_iServerPort);
	
	PrintToConsole(client, "hostname:  %s", g_sHostName);
	PrintToConsole(client, "version : 1.0.0.34/7 4100 insecure");
	PrintToConsole(client, "udp/ip  :  %s", g_sServerIpHost);
	PrintToConsole(client, "map     :  %s at: 0 x, 0 y, 0 z", g_sCurrentMap);
	if (tv_enable)
		PrintToConsole(client, "sourcetv:  port %i, delay %.1fs", GetConVarInt(FindConVar("tv_port")), GetConVarFloat(FindConVar("tv_delay")));
	PrintToConsole(client, "players :  %d (%d max)\n", g_iClientInServer, MaxClients);
	PrintToConsole(client, "# userid name uniqueid connected ping loss state adr");
}

public void ForStatusCmd(int client)
{
	if (client == 0 || g_bCvarSelfShow || (g_bCvarAdminShow && GetUserAdmin(client) != INVALID_ADMIN_ID))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i))continue;
			static char g_sAuthID[64];
			char g_sIP[28], g_sStatus[12], g_sClientTime[12];
			int g_iLatency = (!IsFakeClient(i) && IsClientInGame(i)) ? RoundToNearest(GetClientAvgLatency(i, NetFlow_Both) * 1000.0) : -1;
			int g_iUserID = GetClientUserId(i);
			if (!GetClientIP(i, g_sIP, sizeof(g_sIP), false))strcopy(g_sIP, sizeof(g_sIP), "Unknown");
			strcopy(g_sStatus, sizeof(g_sStatus), (!IsFakeClient(i) && !IsClientInGame(i)) ? "spawning" : "active");
			//if (!GetClientAuthString(i, g_sAuthID, sizeof(g_sAuthID))) strcopy(g_sAuthID, sizeof(g_sAuthID), "Unknown"); //old
			if (!GetClientAuthId(i, AuthId_Steam2, g_sAuthID, sizeof(g_sAuthID)))strcopy(g_sAuthID, sizeof(g_sAuthID), "Unknown"); //new
			
			int connected = (!IsFakeClient(i) && IsClientInGame(i)) ? RoundToZero(GetClientTime(i)) : 0;
			//new days = connected / 86400;
			int hrs = (connected / 3600) % 24;
			int mins = (connected / 60) % 60;
			int sec = connected % 60;
			FormatEx(g_sClientTime, sizeof(g_sClientTime), "%02i:%02i", mins, sec);
			if (hrs > 0)Format(g_sClientTime, sizeof(g_sClientTime), " %i:%s", hrs, g_sClientTime);
			
			if (IsFakeClient(i))PrintToConsole(client, "# %i \"%N\" BOT active", g_iUserID, i);
			else PrintToConsole(client, "# %i \"%N\" %s %s %i 0 %s %s", g_iUserID, i, g_sAuthID, g_sClientTime, g_iLatency, g_sStatus, g_sIP);
		}
	}
	else
	{
		static char g_sAuthID[64];
		char g_sIP[28], g_sStatus[12], g_sClientTime[12];
		if (!GetClientIP(client, g_sIP, sizeof(g_sIP), false))strcopy(g_sIP, sizeof(g_sIP), "Unknown");
		strcopy(g_sStatus, sizeof(g_sStatus), (!IsFakeClient(client) && !IsClientInGame(client)) ? "spawning" : "active");
		//if (!GetClientAuthString(client, g_sAuthID, sizeof(g_sAuthID))) strcopy(g_sAuthID, sizeof(g_sAuthID), "Unknown"); //old
		if (!GetClientAuthId(client, AuthId_Steam2, g_sAuthID, sizeof(g_sAuthID)))strcopy(g_sAuthID, sizeof(g_sAuthID), "Unknown"); //new
		int connected = (!IsFakeClient(client) && IsClientInGame(client)) ? RoundToZero(GetClientTime(client)) : 0;
		FormatEx(g_sClientTime, sizeof(g_sClientTime), "%02i:%02i", (connected / 60) % 60, connected % 60);
		if ((connected / 3600) % 24 > 0)Format(g_sClientTime, sizeof(g_sClientTime), " %i:%s", (connected / 3600) % 24, g_sClientTime);
		if (IsFakeClient(client))PrintToConsole(client, "# %i \"%N\" BOT active", GetClientUserId(client), client);
		else PrintToConsole(client, "# %i \"%N\" %s %s %i 0 %s %s", GetClientUserId(client), client, g_sAuthID, g_sClientTime, (!IsFakeClient(client) && IsClientInGame(client)) ? RoundToNearest(GetClientAvgLatency(client, NetFlow_Both) * 1000.0) : -1, g_sStatus, g_sIP);
		PrintToConsole(client, "\n");
	}
}

public Action PingCmd(int client, int args)
{
	if (g_hTimersFlood[client] == null)g_hTimersFlood[client] = CreateTimer(5.0, Timer_Func, client);
	g_iSpamLimit[client]++;
	if (g_iSpamLimit[client] >= 5 && (client != 0) && GetUserAdmin(client) == INVALID_ADMIN_ID)
	{
		g_iSpamLimit[client] = 0;
		SMAC_Ban(client, "Command Spam: Ping");
	}
	
	
	if (client == 0)
	{
		PrintToConsole(client, "Client ping times:");
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				PrintToConsole(client, "%4d ms : %N", RoundToZero(GetClientLatency(i, NetFlow_Outgoing) * 1024), i);
			}
		}
	}
	else if (g_bCvarPingShow)
	{
		PrintToConsole(client, "Client ping times:");
		PrintToConsole(client, " PING | AVG PING | NAME");
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				PrintToConsole(client, "%5i |  %5i   | %N", RoundToZero(GetClientLatency(i, NetFlow_Outgoing) * 1024), RoundToZero(GetClientAvgLatency(i, NetFlow_Outgoing) * 1024), i);
			}
		}
	}
	return Plugin_Handled;
} 
