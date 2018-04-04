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
#define PLUGIN_DESCRIPTION "A simple plugin to test the zones manager plugin and its API interface."
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
	name = "Zones Manager - Effect - Test Zones", 
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

/****************************************************************************************************
	INTS.
*****************************************************************************************************/
int g_iPrintCap[MAXPLAYERS + 1];
int g_iPrintCap_Post[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	g_hCvarStatus = CreateConVar("sm_zones_effect_testzones_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
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
	RegPluginLibrary("zones_manager_testzones");
	
	g_bLate = bLate;
	return APLRes_Success;
}

public void OnClientPutInServer(int iClient)
{
	g_iPrintCap[iClient] = 0;
	g_iPrintCap_Post[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
	g_iPrintCap[iClient] = 0;
	g_iPrintCap_Post[iClient] = 0;
}

public void ZonesManager_OnQueueEffects_Post()
{
	ZonesManager_RegisterEffect("test zones", Effect_OnEnterZone, Effect_OnActiveZone, Effect_OnLeaveZone);
	ZonesManager_RegisterEffectKey("test zones", "status", "1");
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

public Action ZonesManager_OnStartTouchZone(int iEntity, int iZone, const char[] szZoneName, int iZoneType)
{
	if (!g_hCvarStatus.BoolValue || !IsPlayerIndex(iEntity)) {
		return Plugin_Continue;
	}
	
	PrintToChat(iEntity, "StartTouch: Zone: %i - Name: %s - Type: %i", iZone, szZoneName, iZoneType);
	return Plugin_Continue;
}

public Action ZonesManager_OnTouchZone(int iEntity, int iZone, const char[] szZoneName, int iZoneType)
{
	if (!g_hCvarStatus.BoolValue || !IsPlayerIndex(iEntity)) {
		return Plugin_Continue;
	}
	
	if (g_iPrintCap[iEntity] <= 5)
	{
		g_iPrintCap[iEntity]++;
		PrintToChat(iEntity, "Touch: Entity: Zone: %i - Name: %s - Type: %i", iZone, szZoneName, iZoneType);
	}
	
	return Plugin_Continue;
}

public Action ZonesManager_OnEndTouchZone(int iEntity, int iZone, const char[] szZoneName, int iZoneType)
{
	if (!g_hCvarStatus.BoolValue || !IsPlayerIndex(iEntity)) {
		return Plugin_Continue;
	}
	
	PrintToChat(iEntity, "EndTouch: Entity: Zone: %i - Name: %s - Type: %i", iZone, szZoneName, iZoneType);
	g_iPrintCap[iEntity] = 0;
	return Plugin_Continue;
}

public void ZonesManager_OnStartTouchZone_Post(int iEntity, int iZone, const char[] szZoneName, int iZoneType)
{
	if (!g_hCvarStatus.BoolValue || !IsPlayerIndex(iEntity)) {
		return;
	}
	
	PrintToChat(iEntity, "StartTouch_Post: Zone: Zone: %i - Name: %s - Type: %i", iZone, szZoneName, iZoneType);
}

public void ZonesManager_OnTouchZone_Post(int iEntity, int iZone, const char[] szZoneName, int iZoneType)
{
	if (!g_hCvarStatus.BoolValue || !IsPlayerIndex(iEntity)) {
		return;
	}
	
	if (g_iPrintCap_Post[iEntity] <= 5) {
		g_iPrintCap_Post[iEntity]++;
		PrintToChat(iEntity, "Touch_Post: Entity: Zone: %i - Name: %s - Type: %i", iZone, szZoneName, iZoneType);
	}
}

public void ZonesManager_OnEndTouchZone_Post(int iEntity, int iZone, const char[] szZoneName, int iZoneType)
{
	if (!g_hCvarStatus.BoolValue || !IsPlayerIndex(iEntity)) {
		return;
	}
	
	PrintToChat(iEntity, "EndTouch_Post: Entity: Zone: %i - Name: %s - Type: %i", iZone, szZoneName, iZoneType);
	g_iPrintCap_Post[iEntity] = 0;
}
