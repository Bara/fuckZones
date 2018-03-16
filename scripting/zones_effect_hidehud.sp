/******************************************************************************************************
	INCLUDES
*****************************************************************************************************/
#include <sourcemod>
#include <zones_manager_core>
#include <sourcemod-misc>

/****************************************************************************************************
	DEFINES
*****************************************************************************************************/
#define PLUGIN_DESCRIPTION "An effect for hiding the hud for clients effectively with zones."
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
	name = "Zones Manager - Effect - Hide Hud", 
	author = "Keith Warren (Drixevel), SM9", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://github.com/ShadersAllen/Zones-Manager"
};

/****************************************************************************************************
	HANDLES.
*****************************************************************************************************/
ConVar g_hCvarStatus;
ConVar g_hCvarHudBitFlag;

/****************************************************************************************************
	BOOLS.
*****************************************************************************************************/
bool g_bLate;

/****************************************************************************************************
	INTS.
*****************************************************************************************************/
int g_iCachedHud[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	g_hCvarStatus = CreateConVar("sm_zones_effect_hidehud_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarHudBitFlag = CreateConVar("sm_zones_effect_hidehud_bitflag", "4096", "Bitflag to decimal to set on clients.", FCVAR_NOTIFY);
	
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
	RegPluginLibrary("zones_manager_hidehud");
	
	g_bLate = bLate;
	return APLRes_Success;
}

public void OnClientPutInServer(int iClient) {
	g_iCachedHud[iClient] = 0;
}

public void OnClientDisconnect(int iClient) {
	g_iCachedHud[iClient] = 0;
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_RegisterEffect("hide hud", Effect_OnEnterZone, INVALID_FUNCTION, Effect_OnLeaveZone);
	ZonesManager_RegisterEffectKey("hide hud", "status", "1");
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
	
	g_iCachedHud[iEntity] = GetEntProp(iEntity, Prop_Send, "m_iHideHUD");
	
	SetEntProp(iEntity, Prop_Send, "m_iHideHUD", GetEntProp(iEntity, Prop_Send, "m_iHideHUD") | g_hCvarHudBitFlag.IntValue);
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
	
	SetEntProp(iEntity, Prop_Send, "m_iHideHUD", g_iCachedHud[iEntity]);
	g_iCachedHud[iEntity] = 0;
}
