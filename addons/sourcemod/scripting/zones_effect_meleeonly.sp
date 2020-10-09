//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zones_manager>

//ConVars
ConVar convar_Status;

//Globals
bool g_bLate;
bool g_bMeleeOnly[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Zones Manager - Effect - Melee Only",
	author = "Keith Warren (Drixevel)",
	description = "An effect for the zones manager plugin that applies melee only to clients.",
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

	convar_Status = CreateConVar("sm_zones_effect_meleeonly_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
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
	SDKHook(client, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);
	g_bMeleeOnly[client] = false;
}

public Action OnWeaponCanSwitchTo(int client, int weapon)
{
	int melee = GetPlayerWeaponSlot(client, 2);
	
	if (IsValidEntity(melee) && melee != weapon && g_bMeleeOnly[client])
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_Register_Effect("melee only", Effect_OnEnterZone, INVALID_FUNCTION, Effect_OnLeaveZone);
	ZonesManager_Register_Effect_Key("melee only", "status", "1");
}

public void Effect_OnEnterZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));
	
	if (!GetConVarBool(convar_Status) || StrEqual(sValue, "0"))
	{
		return;
	}
	
	g_bMeleeOnly[client] = true;
	
	int melee = GetPlayerWeaponSlot(client, 2);
	
	if (IsValidEntity(melee))
	{
		EquipPlayerWeapon(client, melee);
	}
}

public void Effect_OnLeaveZone(int client, int entity, StringMap values)
{
	char sValue[32];
	GetTrieString(values, "status", sValue, sizeof(sValue));
	
	if (!GetConVarBool(convar_Status) || StrEqual(sValue, "0"))
	{
		return;
	}
	
	g_bMeleeOnly[client] = false;
}
