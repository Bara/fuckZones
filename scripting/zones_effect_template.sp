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
#define PLUGIN_DESCRIPTION "A template plugin to edit for effects for zones manager."
#define PLUGIN_VERSION "1.0.1"

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
	name = "Zones Manager - Effect - Template", 
	author = "Keith Warren (Shaders Allen), SM9", 
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

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	g_hCvarStatus = CreateConVar("sm_zones_effect_template_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	if (g_bLate) {
		ZonesManager_RequestQueueEffects();
	}
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrMax)
{
	RegPluginLibrary("zones_manager_template");
	
	g_bLate = bLate;
	return APLRes_Success;
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_RegisterEffect("template zone", Effect_OnEnterZone, Effect_OnActiveZone, Effect_OnLeaveZone);
	ZonesManager_RegisterEffectKey("template zone", "status", "1");
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
	
	PrintToChat(iEntity, "You have entered this zone.");
}

public void Effect_OnActiveZone(int iEntity, int iZone, StringMap smValues)
{
	if (!IsPlayerIndex(iEntity)) {
		return;
	}
	
	char szValue[32]; smValues.GetString("status", szValue, sizeof(szValue));
	
	if (!g_hCvarStatus.BoolValue || StrEqual(szValue, "0")) {
		return;
	}
	
	PrintToChat(iEntity, "You are sitting in this zone.");
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
	
	PrintToChat(iEntity, "You have left this zone.");
} 