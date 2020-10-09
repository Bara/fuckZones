//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <zones_manager>

//ConVars
ConVar convar_Status;
ConVar convar_HudBitFlag;

//Globals
bool g_bLate;
int g_iCachedHud[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Zones Manager - Effect - Hide Hud",
	author = "Keith Warren (Drixevel)",
	description = "An effect for hiding the hud for clients effectively with zones.",
	version = "1.0.0",
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

	convar_Status = CreateConVar("sm_zones_effect_hidehud_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_HudBitFlag = CreateConVar("sm_zones_effect_hidehud_bitflag", "4096", "Bitflag to decimal to set on clients.", FCVAR_NOTIFY);
}

public void OnConfigsExecuted()
{
	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
		
		g_bLate = false;
	}
}

public void OnClientPutInServer(int client)
{
	g_iCachedHud[client] = 0;
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_Register_Effect("hide hud", Effect_OnEnterZone, INVALID_FUNCTION, Effect_OnLeaveZone);
	ZonesManager_Register_Effect_Key("hide hud", "status", "1");
}

public void Effect_OnEnterZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));
	
	if (!GetConVarBool(convar_Status) || StrEqual(sValue, "0"))
	{
		return;
	}
	
	g_iCachedHud[client] = GetEntProp(client, Prop_Send, "m_iHideHUD");
	
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | GetConVarInt(convar_HudBitFlag));
}

public void Effect_OnLeaveZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));
	
	if (!GetConVarBool(convar_Status) || StrEqual(sValue, "0"))
	{
		return;
	}
	
	SetEntProp(client, Prop_Send, "m_iHideHUD", g_iCachedHud[client]);
	g_iCachedHud[client] = 0;
}
