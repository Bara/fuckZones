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
	name = "Zones Manager - Effect - Template",
	author = "Keith Warren (Drixevel)",
	description = "A template plugin to edit for effects for zones manager.",
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

	convar_Status = CreateConVar("sm_zones_effect_template_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
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
	ZonesManager_Register_Effect("template zone", Effect_OnEnterZone, Effect_OnActiveZone, Effect_OnLeaveZone);
	ZonesManager_Register_Effect_Key("template zone", "status", "1");
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