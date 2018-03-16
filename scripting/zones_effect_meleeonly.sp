/******************************************************************************************************
	INCLUDES
*****************************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zones_manager_core>
#include <sourcemod-misc>

/****************************************************************************************************
	DEFINES
*****************************************************************************************************/
#define PLUGIN_DESCRIPTION "An effect for the zones manager plugin that applies melee only to clients."
#define PLUGIN_VERSION "1.0.0"

/****************************************************************************************************
	ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required;
#pragma semicolon 1;

/****************************************************************************************************
	PLUGIN INFO.
*****************************************************************************************************/
public Plugin myinfo = 
{
	name = "Zones Manager - Effect - Melee Only", 
	author = "Keith Warren (Drixevel), SM9", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://github.com/ShadersAllen/Zones-Manager"
};

/****************************************************************************************************
	HANDLES.
*****************************************************************************************************/
ConVar g_hCvarStatus;

/****************************************************************************************************
	BOOLS.
*****************************************************************************************************/
bool g_bLate;
bool g_bMeleeOnly[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	g_hCvarStatus = CreateConVar("sm_zones_effect_meleeonly_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	if (g_bLate) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientConnected(i)) {
				continue;
			}
			
			OnClientPutInServer(i);
		}
		
		ZonesManager_RequestQueueEffects();
	}
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrMax)
{
	RegPluginLibrary("zones_manager_meleeonly");
	
	g_bLate = bLate;
	return APLRes_Success;
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);
	g_bMeleeOnly[iClient] = false;
}

public void OnClientDisconnect(int iClient) {
	g_bMeleeOnly[iClient] = false;
}

public Action OnWeaponCanSwitchTo(int iClient, int iWeapon)
{
	int iMelee = GetPlayerWeaponSlot(iClient, 2);
	
	if (IsValidEntity(iMelee) && iMelee != iWeapon && g_bMeleeOnly[iClient]) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_RegisterEffect("melee only", Effect_OnEnterZone, INVALID_FUNCTION, Effect_OnLeaveZone);
	ZonesManager_RegisterEffectKey("melee only", "status", "1");
}

public void Effect_OnEnterZone(int iEntity, int iZone, StringMap smValues)
{
	if (!IsPlayerIndex(iEntity)) {
		return;
	}
	
	char szValue[32]; smValues.GetString("status", szValue, sizeof(szValue));
	
	if (!g_hCvarStatus.BoolValue || StrEqual(szValue, "0")) {
		return;
	}
	
	g_bMeleeOnly[iEntity] = true;
	
	int iMelee = GetPlayerWeaponSlot(iEntity, 2);
	
	if (IsValidEntity(iMelee)) {
		EquipPlayerWeapon(iEntity, iMelee);
	}
}

public void Effect_OnLeaveZone(int iEntity, int iZone, StringMap smValues)
{
	if (!IsPlayerIndex(iEntity)) {
		return;
	}
	
	char szValue[32]; smValues.GetString("status", szValue, sizeof(szValue));
	
	if (!g_hCvarStatus.BoolValue || StrEqual(szValue, "0")) {
		return;
	}
	
	g_bMeleeOnly[iEntity] = false;
}
