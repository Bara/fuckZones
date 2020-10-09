//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <zones_manager>

//ConVars
ConVar convar_Status;

//Globals
bool g_bLate;
int g_iPrintCap[MAXPLAYERS + 1];
int g_iPrintCap_Post[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Zones Manager - Effect - Test Zones",
	author = "Keith Warren (Drixevel)",
	description = "A simple plugin to test the zones manager plugin and its API interface.",
	version = "1.0.1",
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_zones_effect_testzones_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public void OnConfigsExecuted()
{
	if (g_bLate)
	{
		ZonesManager_Request_QueueEffects();
		g_bLate = false;
	}
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_Register_Effect("test zones", Effect_OnEnterZone, Effect_OnActiveZone, Effect_OnLeaveZone);
	ZonesManager_Register_Effect_Key("test zones", "status", "1");
}

public void Effect_OnEnterZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));

	if (StrEqual(sValue, "0"))
	{
		return;
	}

	PrintToChat(client, "You have entered this zone.");
}

public void Effect_OnActiveZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));

	if (StrEqual(sValue, "0"))
	{
		return;
	}

	PrintToChat(client, "You are sitting in this zone.");
}

public void Effect_OnLeaveZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));

	if (StrEqual(sValue, "0"))
	{
		return;
	}

	PrintToChat(client, "You have left this zone.");
}

public void OnClientDisconnect(int client)
{
	g_iPrintCap[client] = 0;
	g_iPrintCap_Post[client] = 0;
}

public Action ZonesManager_OnStartTouchZone(int client, int entity, const char[] zone_name, int type)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	PrintToChat(client, "StartTouch: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);
	return Plugin_Continue;
}

public Action ZonesManager_OnTouchZone(int client, int entity, const char[] zone_name, int type)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	if (g_iPrintCap[client] <= 5)
	{
		g_iPrintCap[client]++;
		PrintToChat(client, "Touch: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);
	}

	return Plugin_Continue;
}

public Action ZonesManager_OnEndTouchZone(int client, int entity, const char[] zone_name, int type)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Continue;
	}

	PrintToChat(client, "EndTouch: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);
	g_iPrintCap[client] = 0;
	return Plugin_Continue;
}

public void ZonesManager_OnStartTouchZone_Post(int client, int entity, const char[] zone_name, int type)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	PrintToChat(client, "StartTouch_Post: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);
}

public void ZonesManager_OnTouchZone_Post(int client, int entity, const char[] zone_name, int type)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (g_iPrintCap_Post[client] <= 5)
	{
		g_iPrintCap_Post[client]++;
		PrintToChat(client, "Touch_Post: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);
	}
}

public void ZonesManager_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	PrintToChat(client, "EndTouch_Post: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);
	g_iPrintCap_Post[client] = 0;
}
