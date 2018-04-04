/******************************************************************************************************x
	INCLUDES
*****************************************************************************************************/
#include <sourcemod>
#include <sourcemod-misc>
#include <sdktools>
#include <sdkhooks>
#include <zones_manager_core>

/****************************************************************************************************
	DEFINES
*****************************************************************************************************/
#define PLUGIN_DESCRIPTION "A sourcemod plugin with rich features for dynamic zone development."
#define PLUGIN_VERSION "1.2.0"

/****************************************************************************************************
	ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required;
#pragma semicolon 1;
#pragma dynamic 131072;

/****************************************************************************************************
	PLUGIN INFO.
*****************************************************************************************************/
public Plugin myinfo = 
{
	name = "Zones-Manager-Core", 
	author = "Keith Warren (Shaders Allen), SM9", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://github.com/ShadersAllen/Zones-Manager"
};

/****************************************************************************************************
	HANDLES.
*****************************************************************************************************/
Handle g_hQueueEffects_Post;
Handle g_hStartTouchZone;
Handle g_hStartTouchZone_Post;
Handle g_hTouchZone;
Handle g_hTouchZone_Post;
Handle g_hEndTouchZone;
Handle g_hEndTouchZone_Post;
Handle g_hOnZoneSpawned;

ArrayList g_alZoneEntities;
ArrayList g_alEffectList;
ArrayList g_alZonePoints[MAX_ENTITY_LIMIT];
ArrayList g_alAssignedZones[MAXPLAYERS + 1];
ArrayList g_alEntityList;
ArrayList g_alDelayedTriggerZones;

StringMap g_smZoneEffects[MAX_ENTITY_LIMIT];
StringMap g_smEffectCalls;
StringMap g_smEffectKeys;

/****************************************************************************************************
	STRINGS.
*****************************************************************************************************/
char g_szErrorModel[] = "models/error.mdl";
char g_szZoneName[MAX_ENTITY_LIMIT][MAX_ZONE_NAME_LENGTH];

/****************************************************************************************************
	BOOLS.
*****************************************************************************************************/
bool g_bLate;
bool g_bNativeKvToString = false;
bool g_bHideZoneRender[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];
bool g_bForceZoneRender[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];
bool g_bIsInsideZone[MAX_ENTITY_LIMIT][MAX_ENTITY_LIMIT];
bool g_bEntityZoneHooked[MAX_ENTITY_LIMIT][MAX_ENTITY_LIMIT];
bool g_bIsZone[MAX_ENTITY_LIMIT];
bool g_bEntitySpawned[MAX_ENTITY_LIMIT];
bool g_bEntityGlobalHooked[MAX_ENTITY_LIMIT];
bool g_bMapStarted = false;

/****************************************************************************************************
	INTS.
*****************************************************************************************************/
int g_iDefaultModelIndex;
int g_iDefaultHaloIndex;
int g_iZoneType[MAX_ENTITY_LIMIT];
int g_iZoneColor[MAX_ENTITY_LIMIT][4];
int g_iZoneDrawType[MAX_ENTITY_LIMIT];
int g_iZoningState[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];

/****************************************************************************************************
	FLOATS.
*****************************************************************************************************/
float g_vZoneStart[MAX_ENTITY_LIMIT][3];
float g_vZoneEnd[MAX_ENTITY_LIMIT][3];
float g_fZoneRadius[MAX_ENTITY_LIMIT];
float g_fZoneHeight[MAX_ENTITY_LIMIT];
float g_fZonePointsDistance[MAX_ENTITY_LIMIT];
float g_fZonePointsMin[MAX_ENTITY_LIMIT][3];
float g_fZonePointsMax[MAX_ENTITY_LIMIT][3];
float g_vEntityOrigin[MAX_ENTITY_LIMIT][3];
float g_vZoneCorners[MAX_ENTITY_LIMIT][8][3];

public void OnPluginStart()
{
	g_alEffectList = new ArrayList(ByteCountToCells(MAX_EFFECT_NAME_LENGTH));
	g_smEffectCalls = new StringMap();
	g_smEffectKeys = new StringMap();
	
	HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	g_bNativeKvToString = GetFeatureStatus(FeatureType_Native, "ExportToString") == FeatureStatus_Available;
	
	CreateTimer(0.1, Timer_DisplayZones, _, TIMER_REPEAT);
	
	if (g_bLate) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientConnected(i)) {
				continue;
			}
			
			OnClientPutInServer(i);
		}
		
		char szCurrentMap[64]; 
		
		if(GetCurrentMap(szCurrentMap, sizeof(szCurrentMap)) > 0) {
			ForceChangeLevel(szCurrentMap, "ZonesManager late load");
		}
		
		QueueEffects();
	}
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrMax)
{
	RegPluginLibrary("zones_manager_core");
	
	CreateNative("ZonesManager_RequestQueueEffects", Native_RequestQueueEffects);
	CreateNative("ZonesManager_ClearAllZones", Native_ClearAllZones);
	CreateNative("ZonesManager_IsValidZone", Native_IsValidZone);
	CreateNative("ZonesManager_IsEntityInZone", Native_IsEntityInZone);
	CreateNative("ZonesManager_AssignZone", Native_AssignZone);
	CreateNative("ZonesManager_SetZoningState", Native_SetZoningState);
	CreateNative("ZonesManager_GetZoningState", Native_GetZoningState);
	CreateNative("ZonesManager_UnAssignZone", Native_UnAssignZone);
	CreateNative("ZonesManager_HideZoneFromClient", Native_HideZoneFromClient);
	CreateNative("ZonesManager_UnHideZoneFromClient", Native_UnHideZoneFromClient);
	CreateNative("ZonesManager_ForceZoneRenderingToClient", Native_ForceZoneRenderingToClient);
	CreateNative("ZonesManager_UnForceZoneRenderingToClient", Native_UnForceZoneRenderingToClient);
	CreateNative("ZonesManager_GetAssignedZones", Native_GetAssignedZones);
	CreateNative("ZonesManager_GetZonePointsCount", Native_GetZonePointsCount);
	CreateNative("ZonesManager_GetZonePoints", Native_GetZonePoints);
	CreateNative("ZonesManager_GetZonePointHeight", Native_GetZonePointHeight);
	CreateNative("ZonesManager_GetZoneByName", Native_GetZoneByName);
	CreateNative("ZonesManager_GetZoneName", Native_GetZoneName);
	CreateNative("ZonesManager_GetZoneStart", Native_GetZoneStart);
	CreateNative("ZonesManager_GetZoneEnd", Native_GetZoneEnd);
	CreateNative("ZonesManager_GetZoneRadius", Native_GetZoneRadius);
	CreateNative("ZonesManager_GetZoneColor", Native_GetZoneColor);
	CreateNative("ZonesManager_GetZoneType", Native_GetZoneType);
	CreateNative("ZonesManager_GetZoneLowestCorner", Native_GetZoneLowestCorner);
	CreateNative("ZonesManager_GetZoneHighestCorner", Native_GetZoneHighestCorner);
	CreateNative("ZonesManager_GetZoneTeleportLocation", Native_GetZoneTeleportLocation);
	CreateNative("ZonesManager_GetZoneDrawType", Native_GetZoneDrawType);
	CreateNative("ZonesManager_GetZoneList", Native_GetZoneList);
	CreateNative("ZonesManager_GetZoneCount", Native_GetZoneCount);
	CreateNative("ZonesManager_IsZoneActive", Native_IsZoneActive);
	CreateNative("ZonesManager_DeleteZone", Native_DeleteZone);
	CreateNative("ZonesManager_IsVectorInsideZone", Native_IsVectorInsideZone);
	CreateNative("ZonesManager_TeleportClientToZone", Native_TeleportClientToZone);
	CreateNative("ZonesManager_GetClientLookPoint", Native_GetClientLookPoint);
	CreateNative("ZonesManager_RegisterEffect", Native_RegisterEffect);
	CreateNative("ZonesManager_RegisterEffectKey", Native_RegisterEffectKey);
	CreateNative("ZonesManager_CreateZoneAdvanced", Native_CreateZoneAdvanced);
	CreateNative("ZonesManager_CreateZoneFromKeyValuesString", Native_CreateZoneFromKeyValuesString);
	CreateNative("ZonesManager_RegisterTrigger", Native_RegisterTrigger);
	CreateNative("ZonesManager_StartZone", Native_StartZone);
	CreateNative("ZonesManager_SetZoneName", Native_SetZoneName);
	CreateNative("ZonesManager_SetZoneStart", Native_SetZoneStart);
	CreateNative("ZonesManager_SetZoneEnd", Native_SetZoneEnd);
	CreateNative("ZonesManager_SetZoneRadius", Native_SetZoneRadius);
	CreateNative("ZonesManager_SetZoneColor", Native_SetZoneColor);
	CreateNative("ZonesManager_SetZoneHeight", Native_SetZoneHeight);
	CreateNative("ZonesManager_SetZoneDrawType", Native_SetZoneDrawType);
	CreateNative("ZonesManager_AddZonePoint", Native_AddZonePoint);
	CreateNative("ZonesManager_AddMultipleZonePoints", Native_AddMultipleZonePoints);
	CreateNative("ZonesManager_RemoveZonePoint", Native_RemoveZonePoint);
	CreateNative("ZonesManager_RemoveLastZonePoint", Native_RemoveLastZonePoint);
	CreateNative("ZonesManager_RemoveMultipleZonePoints", Native_RemoveMultipleZonePoints);
	CreateNative("ZonesManager_RemoveAllZonePoints", Native_RemoveAllZonePoints);
	CreateNative("ZonesManager_AddZoneEffect", Native_AddZoneEffect);
	CreateNative("ZonesManager_RemoveZoneEffect", Native_RemoveZoneEffect);
	CreateNative("ZonesManager_FinishZone", Native_FinishZone);
	CreateNative("ZonesManager_GetZoneKeyValues", Native_GetZoneKeyValues);
	CreateNative("ZonesManager_GetZoneKeyValuesAsString", Native_GetZoneKeyValuesAsString);
	CreateNative("ZonesManager_Hook", Native_Hook);
	CreateNative("ZonesManager_HookGlobal", Native_HookGlobal);
	CreateNative("ZonesManager_UnHook", Native_UnHook);
	CreateNative("ZonesManager_UnHookGlobal", Native_UnHookGlobal);
	
	g_hQueueEffects_Post = CreateGlobalForward("ZonesManager_OnQueueEffects_Post", ET_Ignore);
	g_hStartTouchZone = CreateGlobalForward("ZonesManager_OnStartTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hTouchZone = CreateGlobalForward("ZonesManager_OnTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hEndTouchZone = CreateGlobalForward("ZonesManager_OnEndTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hStartTouchZone_Post = CreateGlobalForward("ZonesManager_OnStartTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hTouchZone_Post = CreateGlobalForward("ZonesManager_OnTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hEndTouchZone_Post = CreateGlobalForward("ZonesManager_OnEndTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hOnZoneSpawned = CreateGlobalForward("ZonesManager_OnZoneSpawned", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Array, Param_Array, Param_Float, Param_Float, Param_Array, Param_Cell, Param_Cell, Param_Cell);
	
	g_bLate = bLate;
	return APLRes_Success;
}

public void OnMapStart()
{
	g_iDefaultModelIndex = PrecacheModel(DEFAULT_MODELINDEX);
	g_iDefaultHaloIndex = PrecacheModel(DEFAULT_HALOINDEX);
	
	PrecacheModel(g_szErrorModel);
	
	for (int i = 1; i < MAX_ENTITY_LIMIT; i++) {
		ResetZoneVariables(i);
	}
	
	g_bMapStarted = true;
}

public void OnEntityCreated(int iEntity, const char[] szClassName)
{
	if (iEntity < INVALID_ENT_INDEX) {
		iEntity = EntRefToEntIndex(iEntity);
	}
	
	if (iEntity < 1 || iEntity >= MAX_ENTITY_LIMIT) {
		return;
	}
	
	SDKHook(iEntity, SDKHook_SpawnPost, OnEntitySpawned);
	
	if (g_alEntityList == null) {
		g_alEntityList = new ArrayList(3);
	}
	
	int iEntRef = EntIndexToEntRef(iEntity);
	
	if (g_alEntityList.FindValue(iEntRef) != INVALID_ARRAY_INDEX) {
		return;
	}
	
	if (StrContains(szClassName, "trigger_", false) != -1) {
		SetVariantString("OnStartTouch");
		AcceptEntityInput(iEntity, "AddOutput dummy");
		
		SetVariantString("OnEndTouch");
		AcceptEntityInput(iEntity, "AddOutput dummy");
		
		g_bEntityGlobalHooked[iEntity] = true;
	}
	
	g_alEntityList.Push(iEntRef);
}

public void OnClientPutInServer(int iClient)
{
	g_bEntityGlobalHooked[iClient] = true;
	
	if (g_alEntityList == null) {
		g_alEntityList = new ArrayList(3);
	}
	
	int iEntRef = EntIndexToEntRef(iClient);
	
	if (g_alEntityList.FindValue(iEntRef) != INVALID_ARRAY_INDEX) {
		return;
	}
	
	g_alEntityList.Push(iEntRef);
}

public void Event_PlayerSpawn(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (iClient < 1 || iClient > MaxClients) {
		return;
	}
	
	g_bEntitySpawned[iClient] = true;
}

public void Event_PlayerDeath(Event eEvent, char[] szEvent, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	
	if (iClient < 1 || iClient > MaxClients) {
		return;
	}
	
	g_bEntitySpawned[iClient] = false;
	FillArrayToValue(g_vEntityOrigin[iClient], 3, -1.0);
}

public void OnEntitySpawned(int iEntity)
{
	if (iEntity < INVALID_ENT_INDEX) {
		iEntity = EntRefToEntIndex(iEntity);
	}
	
	if (iEntity < 1 || iEntity >= MAX_ENTITY_LIMIT) {
		return;
	}
	
	if (iEntity > MaxClients) {
		g_bEntitySpawned[iEntity] = true;
	}
	
	char szClassName[64]; GetEntityClassname(iEntity, szClassName, sizeof(szClassName));
	
	if (StrContains(szClassName, "trigger_", false) != -1) {
		SetEntProp(iEntity, Prop_Send, "m_nSolidType", 2);
		
		int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
		iEffects |= 0x020;
		
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects);
		DelayedTriggerLoad();
	}
}

public void OnEntityDestroyed(int iEntity)
{
	if (iEntity < INVALID_ENT_INDEX) {
		iEntity = EntRefToEntIndex(iEntity);
	}
	
	if (iEntity < 1 || iEntity >= MAX_ENTITY_LIMIT) {
		return;
	}
	
	g_bEntityGlobalHooked[iEntity] = false;
	ResetZoneVariables(iEntity);
	
	if (g_alEntityList == null) {
		return;
	}
	
	int iArrayCell = g_alEntityList.FindValue(EntIndexToEntRef(iEntity));
	
	if (iArrayCell == INVALID_ARRAY_INDEX) {
		return;
	}
	
	g_alEntityList.Erase(iArrayCell);
}

public void OnMapEnd()
{
	ClearAllZones();
	
	for (int i = 1; i < MAX_ENTITY_LIMIT; i++) {
		ResetZoneVariables(i);
	}
	
	delete g_alEntityList;
	
	g_bMapStarted = false;
}

public void OnAllPluginsLoaded() {
	QueueEffects();
}

public void OnPluginEnd() {
	ClearAllZones();
}

void QueueEffects(bool bReset = true)
{
	if (bReset) {
		char szEffect[MAX_EFFECT_NAME_LENGTH];
		Handle hCallBacks[MAX_EFFECT_CALLBACKS];
		
		for (int i = 0; i < g_alEffectList.Length; i++) {
			g_alEffectList.GetString(i, szEffect, sizeof(szEffect));
			g_smEffectCalls.GetArray(szEffect, hCallBacks, sizeof(hCallBacks));
			
			for (int x = 0; x < MAX_EFFECT_CALLBACKS; x++) {
				delete hCallBacks[x];
			}
		}
		
		g_smEffectCalls.Clear();
		g_alEffectList.Clear();
	}
	
	Call_StartForward(g_hQueueEffects_Post);
	Call_Finish();
}

void DelayedTriggerLoad()
{
	if (g_alDelayedTriggerZones == null) {
		return;
	}
	
	char szBuffer[4096]; int iZoneType = INVALID_ARRAY_INDEX;
	KeyValues kvZoneKV;
	
	for (int i = 0; i < g_alDelayedTriggerZones.Length; i++) {
		g_alDelayedTriggerZones.GetString(i, szBuffer, sizeof(szBuffer));
		kvZoneKV = new KeyValues("zones_manager");
		
		if (!kvZoneKV.ImportFromString(szBuffer)) {
			g_alDelayedTriggerZones.Erase(i);
			delete kvZoneKV;
			continue;
		}
		
		if (IsValidZone(SpawnAZoneFromKeyValues(kvZoneKV, iZoneType))) {
			g_alDelayedTriggerZones.Erase(i);
		}
	}
	
	if (g_alDelayedTriggerZones.Length < 1) {
		delete g_alDelayedTriggerZones;
	}
}

public void OnClientDisconnect(int iClient)
{
	g_bEntityGlobalHooked[iClient] = false;
	ResetCreateZoneVariables(iClient);
}

void ClearAllZones()
{
	int iZone = INVALID_ENT_INDEX;
	
	if (g_alZoneEntities == null) {
		return;
	}
	
	for (int i = 0; i < g_alZoneEntities.Length; i++) {
		iZone = EntRefToEntIndex(g_alZoneEntities.Get(i));
		
		if (!IsValidEntity(iZone) || iZone <= MaxClients) {
			continue;
		}
		
		DeleteZone(iZone);
		
		if (g_alZoneEntities == null) {
			break;
		}
	}
}

bool DeleteZone(int iZone)
{
	if (!IsValidZone(iZone)) {
		return false;
	}
	
	int iEntRef = EntIndexToEntRef(iZone);
	int iArrayIndex = INVALID_ARRAY_INDEX;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (g_alAssignedZones[i] == null) {
			continue;
		}
		
		iArrayIndex = g_alAssignedZones[i].FindValue(iEntRef);
		
		if (iArrayIndex != INVALID_ARRAY_INDEX) {
			g_alAssignedZones[i].Erase(iArrayIndex);
		}
		
		if (g_alAssignedZones[i].Length < 1) {
			delete g_alAssignedZones[i];
		}
	}
	
	if (g_alZoneEntities != null) {
		iArrayIndex = g_alZoneEntities.FindValue(iEntRef);
		
		if (iArrayIndex != INVALID_ARRAY_INDEX) {
			g_alZoneEntities.Erase(iArrayIndex);
		}
		
		delete g_smZoneEffects[iZone];
		delete g_alZonePoints[iZone];
		
		if (g_alZoneEntities.Length < 1) {
			delete g_alZoneEntities;
		}
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_TRIGGER) {
		AcceptEntityInput(iZone, "Disable");
		AcceptEntityInput(iZone, "Kill");
	}
	
	g_bEntityGlobalHooked[iZone] = false;
	ResetZoneVariables(iZone);
	
	return true;
}

int SpawnAZoneFromKeyValues(KeyValues kvZoneKV, int & iZoneType = INVALID_ARRAY_INDEX)
{
	if (kvZoneKV == null) {
		return INVALID_ENT_INDEX;
	}
	
	kvZoneKV.Rewind();
	kvZoneKV.GotoFirstSubKey();
	
	char szName[MAX_ZONE_NAME_LENGTH]; kvZoneKV.GetSectionName(szName, sizeof(szName));
	
	kvZoneKV.Rewind();
	
	if (!kvZoneKV.JumpToKey(szName)) {
		LogError("Error spawning zone from KV (Could not jump to key %s)", szName);
		delete kvZoneKV;
		return INVALID_ENT_INDEX;
	}
	
	char szType[MAX_ZONE_TYPE_LENGTH]; kvZoneKV.GetString("type", szType, sizeof(szType));
	iZoneType = GetZoneNameType(szType);
	int iColor[4] =  { 0, 255, 255, 255 }; kvZoneKV.GetColor("color", iColor[0], iColor[1], iColor[2], iColor[3]);
	int iDrawType = kvZoneKV.GetNum("drawtype", ZONE_DRAW_HALF);
	
	float vStartPosition[3]; kvZoneKV.GetVector("start", vStartPosition);
	float vEndPosition[3]; kvZoneKV.GetVector("end", vEndPosition);
	float fHeight = kvZoneKV.GetFloat("height", 0.0);
	float fRadius = kvZoneKV.GetFloat("radius");
	
	ArrayList alPoints = new ArrayList(3);
	
	if (kvZoneKV.JumpToKey("points")) {
		kvZoneKV.GotoFirstSubKey(false);
		float vCoordinates[3];
		
		do {
			kvZoneKV.GetVector(NULL_STRING, vCoordinates);
			AddZonePoint(alPoints, vCoordinates);
		} while (kvZoneKV.GotoNextKey(false));
		
		kvZoneKV.GoBack();
	}
	
	StringMap smEffects = new StringMap();
	
	if (kvZoneKV.JumpToKey("effects") && kvZoneKV.GotoFirstSubKey()) {
		char szKey[256]; char szValue[256]; char szEffect[256];
		
		StringMap smEffectData;
		
		do {
			kvZoneKV.GetSectionName(szEffect, sizeof(szEffect));
			smEffectData = new StringMap();
			
			if (kvZoneKV.GotoFirstSubKey(false)) {
				do {
					kvZoneKV.GetSectionName(szKey, sizeof(szKey));
					kvZoneKV.GetString(NULL_STRING, szValue, sizeof(szValue));
					
					smEffectData.SetString(szKey, szValue);
				} while (kvZoneKV.GotoNextKey(false));
				
				kvZoneKV.GoBack();
			}
			
			smEffects.SetValue(szEffect, smEffectData);
		} while (kvZoneKV.GotoNextKey());
		
		kvZoneKV.GoBack();
		kvZoneKV.GoBack();
	}
	
	delete kvZoneKV;
	
	int iEntity = INVALID_ENT_INDEX;
	
	if (iZoneType == ZONE_TYPE_TRIGGER) {
		int iEntRef = INVALID_ENT_REFERENCE;
		char szClassName[64];
		
		float vStart[3], vEnd[3];
		
		for (int i = 0; i < g_alEntityList.Length; i++) {
			iEntRef = g_alEntityList.Get(i);
			
			if (iEntRef == INVALID_ENT_REFERENCE) {
				g_alEntityList.Erase(i);
				iEntity = INVALID_ENT_INDEX;
				continue;
			}
			
			iEntity = EntRefToEntIndex(iEntRef);
			
			if (!IsValidEntity(iEntity) || iEntity < 1) {
				g_alEntityList.Erase(i);
				iEntity = INVALID_ENT_INDEX;
				continue;
			}
			
			GetEntityClassname(iEntity, szClassName, sizeof(szClassName));
			
			if (StrContains(szClassName, "trigger_", false) == INVALID_ARRAY_INDEX) {
				iEntity = INVALID_ENT_INDEX;
				continue;
			}
			
			GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vStart);
			GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vEnd);
			
			if (!AreVectorsEqual(vStartPosition, vStart) || !AreVectorsEqual(vEndPosition, vEnd)) {
				iEntity = INVALID_ENT_INDEX;
				continue;
			}
			
			break;
		}
	}
	
	if (iEntity == INVALID_ENT_INDEX && iZoneType == ZONE_TYPE_TRIGGER) {
		return INVALID_ENT_INDEX;
	}
	
	return CreateZone(szName, iZoneType, vStartPosition, vEndPosition, fRadius, iColor, iDrawType, alPoints, fHeight, smEffects, iEntity);
}

public void OnGameFrame() {
	CheckEntityZones();
}

void CheckEntityZones()
{
	if (g_alEntityList == null) {
		return;
	}
	
	int iEntity = INVALID_ENT_INDEX;
	int iEntRef = INVALID_ENT_REFERENCE;
	
	for (int i = 0; i < g_alEntityList.Length; i++) {
		iEntRef = g_alEntityList.Get(i);
		
		if (iEntRef == INVALID_ENT_REFERENCE) {
			g_alEntityList.Erase(i);
			continue;
		}
		
		iEntity = EntRefToEntIndex(iEntRef);
		
		if (!IsValidEntity(iEntity) || iEntity < 1) {
			g_alEntityList.Erase(i);
			continue;
		}
		
		int iZoneType = INVALID_ARRAY_INDEX;
		int iZone = INVALID_ENT_INDEX;
		float vOrigin[3];
		
		if (iEntity <= MaxClients) {
			GetClientAbsOrigin(iEntity, vOrigin);
		} else {
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOrigin);
		}
		
		if (!IsValidOrigin(vOrigin)) {
			continue;
		}
		
		bool bPlayer = IsPlayerIndex(iEntity);
		bool bSameOrigin = AreVectorsEqual(g_vEntityOrigin[iEntity], vOrigin);
		
		if (g_alZoneEntities != null) {
			for (int y = 0; y < g_alZoneEntities.Length; y++) {
				iEntRef = g_alZoneEntities.Get(y);
				
				if (iEntRef == INVALID_ENT_REFERENCE) {
					g_alZoneEntities.Erase(y);
					continue;
				}
				
				iZone = EntRefToEntIndex(iEntRef);
				
				if (!IsValidZone(iZone) || iZone <= MaxClients) {
					g_alZoneEntities.Erase(y);
					continue;
				}
				
				if (iZone == iEntity) {
					continue;
				}
				
				if (!g_bEntityZoneHooked[iEntity][iZone] && !g_bEntityGlobalHooked[iEntity] && !IsValidZone(iEntity) && !bPlayer) {
					continue;
				}
				
				iZoneType = GetZoneType(iZone);
				
				if (bSameOrigin) {
					if (g_bIsInsideZone[iEntity][iZone]) {
						Zones_StartTouch(iZone, iEntity);
					} else {
						Zones_EndTouch(iZone, iEntity);
					}
					
					continue;
				}
				
				if ((!g_bEntitySpawned[iEntity] && bPlayer)) {
					Zones_EndTouch(iZone, iEntity);
					continue;
				}
				
				if ((HasEntProp(iEntity, Prop_Send, "m_hGroundEntity") && GetEntPropEnt(iEntity, Prop_Send, "m_hGroundEntity") == iZone)) {
					Zones_StartTouch(iZone, iEntity);
					continue;
				}
				
				if (iZoneType == ZONE_TYPE_CUBE || iZoneType == ZONE_TYPE_TRIGGER) {
					continue;
				}
				
				if (IsVectorInsideZone(iZone, vOrigin)) {
					Zones_StartTouch(iZone, iEntity);
					continue;
				}
				
				Zones_EndTouch(iZone, iEntity);
			}
		}
		
		CopyArrayToArray(vOrigin, g_vEntityOrigin[iEntity], 3);
	}
}

void ResetCreateZoneVariables(int iClient)
{
	int iZone = INVALID_ENT_INDEX;
	
	if (g_alAssignedZones[iClient] == null) {
		return;
	}
	
	for (int i = 0; i < g_alAssignedZones[iClient].Length; i++) {
		iZone = g_alAssignedZones[iClient].Get(i);
		
		if (iZone == INVALID_ENT_REFERENCE) {
			continue;
		}
		
		iZone = EntRefToEntIndex(iZone);
		
		if (!IsValidZone(iZone)) {
			continue;
		}
		
		g_bHideZoneRender[i][iZone] = false;
		g_bForceZoneRender[i][iZone] = false;
		
		g_iZoningState[iClient][iZone] = ZONING_STATE_NONE;
		
		if (g_bEntitySpawned[iZone]) {
			continue;
		}
		
		DeleteZone(iZone);
	}
	
	delete g_alAssignedZones[iClient];
}

void ResetZoneVariables(int iZone)
{
	int iArrayCell = INVALID_ARRAY_INDEX;
	
	for (int i = 1; i < MAX_ENTITY_LIMIT; i++) {
		g_bIsInsideZone[i][iZone] = false;
		g_bEntityZoneHooked[i][iZone] = false;
		
		if (i <= MaxClients) {
			g_bForceZoneRender[i][iZone] = false;
			g_bHideZoneRender[i][iZone] = false;
			
			if (g_alAssignedZones[i] != null) {
				iArrayCell = g_alAssignedZones[i].FindValue(EntIndexToEntRef(iZone));
				
				if (iArrayCell == INVALID_ARRAY_INDEX) {
					continue;
				}
				
				g_alAssignedZones[i].Erase(iArrayCell);
			}
		}
	}
	
	FillArrayToValue(g_vZoneStart[iZone], 3, -1.0);
	FillArrayToValue(g_vZoneEnd[iZone], 3, -1.0);
	FillArrayToValue(g_iZoneColor[iZone], 4, -1);
	FillArrayToValue(g_fZonePointsMin[iZone], 3, -1.0);
	FillArrayToValue(g_fZonePointsMax[iZone], 3, -1.0);
	FillArrayToValue(g_vEntityOrigin[iZone], 3, -1.0);
	
	g_fZoneRadius[iZone] = -1.0;
	g_fZoneHeight[iZone] = -1.0;
	g_fZonePointsDistance[iZone] = -1.0;
	
	g_bIsZone[iZone] = false;
	g_bEntitySpawned[iZone] = false;
	
	g_iZoneType[iZone] = INVALID_ARRAY_INDEX;
	g_iZoneDrawType[iZone] = ZONE_DRAW_HALF;
	g_szZoneName[iZone][0] = '\0';
	
	delete g_smZoneEffects[iZone];
	delete g_alZonePoints[iZone];
}

void GetZoneTypeName(int iZoneType, char[] szBuffer, int iSize)
{
	switch (iZoneType) {
		case ZONE_TYPE_TRIGGER: {
			strcopy(szBuffer, iSize, "Trigger");
		}
		case ZONE_TYPE_CUBE: {
			strcopy(szBuffer, iSize, "Cube");
		}
		case ZONE_TYPE_CIRCLE: {
			strcopy(szBuffer, iSize, "Circle");
		}
		case ZONE_TYPE_POLY: {
			strcopy(szBuffer, iSize, "Polygon");
		}
	}
}

int GetZoneType(int iEntity) {
	return g_iZoneType[iEntity];
}

int GetZoneNameType(const char[] szType)
{
	if (StrEqual(szType, "Trigger", false)) {
		return ZONE_TYPE_TRIGGER;
	} else if (StrEqual(szType, "Cube", false) || StrEqual(szType, "Standard", false)) {
		return ZONE_TYPE_CUBE;
	} else if (StrEqual(szType, "Circle", false) || StrEqual(szType, "Radius/Circle", false)) {
		return ZONE_TYPE_CIRCLE;
	} else if (StrEqual(szType, "Polygon", false) || StrEqual(szType, "Polygons", false)) {
		return ZONE_TYPE_POLY;
	}
	
	return -1;
}

public Action Timer_DisplayZones(Handle hTimer)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}
		
		ShowZones(i, 0.2);
	}
}

void ShowZones(int iClient, float fTime = 0.2)
{
	float vCoordinates[3];
	float vNextPoint[3];
	
	float vStart[3];
	float vEnd[3];
	
	float vCoordinates_Expanded[3];
	float vNextPoint_Expanded[3];
	
	float vLookPoint[3];
	float vLookPoint_Expanded[3];
	
	int iIndex = INVALID_ARRAY_INDEX;
	int iZone = INVALID_ENT_INDEX;
	
	int iColor[4] =  { 255, 0, 0, 255 };
	int iLooped = 0;
	
	if (g_alAssignedZones[iClient] != null) {
		for (int i = 0; i < g_alAssignedZones[iClient].Length; i++) {
			iZone = g_alAssignedZones[iClient].Get(i);
			
			if (iZone == INVALID_ENT_REFERENCE) {
				g_alAssignedZones[iClient].Erase(i);
				continue;
			}
			
			iZone = EntRefToEntIndex(iZone);
			
			if (!IsValidZone(iZone)) {
				g_iZoningState[iClient][iZone] = ZONING_STATE_NONE;
				g_alAssignedZones[iClient].Erase(i);
				continue;
			}
			
			if (g_bHideZoneRender[iClient][iZone] || g_iZoningState[iClient][iZone] == ZONING_STATE_NONE) {
				continue;
			}
			
			if (g_iZoningState[iClient][iZone] == ZONING_STATE_DRAWING) {
				GetClientLookPoint(iClient, vLookPoint, false);
			}
			
			switch (GetZoneType(iZone)) {
				case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
					GetAbsBoundingBox(iZone, vStart, vEnd);
					Effect_DrawBeamBoxToClient(iClient, vStart, vEnd, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
				}
				
				case ZONE_TYPE_CIRCLE: {
					if (g_iZoningState[iClient][iZone] == ZONING_STATE_DRAWING) {
						TE_SetupBeamRingPoint(vLookPoint, g_fZoneRadius[iZone], g_fZoneRadius[iZone] + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 0.0, iColor, 0, 0);
						continue;
					}
					
					TE_SetupBeamRingPoint(g_vZoneStart[iZone], g_fZoneRadius[iZone], g_fZoneRadius[iZone] + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 0.0, iColor, 0, 0);
					TE_SendToClient(iClient);
					
					CopyArrayToArray(g_vZoneStart[iZone], vCoordinates_Expanded, 3);
					vCoordinates_Expanded[2] += g_fZoneHeight[iZone];
					
					TE_SetupBeamRingPoint(vCoordinates_Expanded, g_fZoneRadius[iZone], g_fZoneRadius[iZone] + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 0.0, iColor, 0, 0);
					TE_SendToClient(iClient);
				}
				
				case ZONE_TYPE_POLY: {
					if (g_alZonePoints[iZone] == null) {
						continue;
					}
					
					for (int y = 0; y < g_alZonePoints[iZone].Length; y++) {
						g_alZonePoints[iZone].GetArray(y, vCoordinates, sizeof(vCoordinates));
						
						if (y + 1 >= g_alZonePoints[iZone].Length) {
							iIndex = 0;
						} else {
							iIndex = y + 1;
						}
						
						g_alZonePoints[iZone].GetArray(iIndex, vNextPoint, sizeof(vNextPoint));
						
						CopyArrayToArray(vCoordinates, vCoordinates_Expanded, 3);
						vCoordinates_Expanded[2] += g_fZoneHeight[iZone];
						
						CopyArrayToArray(vNextPoint, vNextPoint_Expanded, 3);
						vNextPoint_Expanded[2] += g_fZoneHeight[iZone];
						
						if (!AreVectorsEqual(vCoordinates, vNextPoint)) {
							TE_SetupBeamPoints(vCoordinates, vNextPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
							TE_SendToClient(iClient);
							
							TE_SetupBeamPoints(vCoordinates_Expanded, vNextPoint_Expanded, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
							TE_SendToClient(iClient);
						}
						
						if (g_iZoningState[iClient][iZone] == ZONING_STATE_DRAWING && !AreVectorsEqual(vLookPoint, vNextPoint) && iIndex == g_alZonePoints[iZone].Length - 1) {
							CopyArrayToArray(vLookPoint, vLookPoint_Expanded, 3);
							vLookPoint_Expanded[2] += g_fZoneHeight[iZone];
							
							TE_SetupBeamPoints(vNextPoint, vLookPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
							TE_SendToClient(iClient);
						}
					}
				}
			}
			
			iLooped++;
		}
	}
	
	if (iLooped < 1) {
		delete g_alAssignedZones[iClient];
	}
	
	bool bSkip = false;
	
	if (g_alZoneEntities != null) {
		for (int x = 0; x < g_alZoneEntities.Length; x++) {
			iZone = g_alZoneEntities.Get(x);
			
			if (iZone == INVALID_ENT_REFERENCE) {
				g_alZoneEntities.Erase(x);
				continue;
			}
			
			iZone = EntRefToEntIndex(iZone);
			
			if (!IsValidZone(iZone)) {
				g_alZoneEntities.Erase(x);
				continue;
			}
			
			if (!g_bEntitySpawned[iZone]) {
				continue;
			}
			
			if (g_bHideZoneRender[iClient][iZone]) {
				continue;
			}
			
			if (g_iZoneDrawType[iZone] == ZONE_DRAW_NONE) {
				continue;
			}
			
			if (!g_bIsInsideZone[iClient][iZone]) {
				continue;
			}
			
			bSkip = false;
			
			if (g_alAssignedZones[iClient] != null) {
				bSkip = false;
				
				for (int y = 0; y < g_alAssignedZones[iClient].Length; y++) {
					if (EntIndexToEntRef(iZone) == g_alAssignedZones[iClient].Get(y)) {
						bSkip = true;
						break;
					}
				}
			}
			
			if (bSkip) {
				continue;
			}
			
			if (g_bEntitySpawned[iZone]) {
				CopyArrayToArray(g_iZoneColor[iZone], iColor, 4);
			}
			
			switch (GetZoneType(iZone)) {
				case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
					GetAbsBoundingBox(iZone, vStart, vEnd, g_iZoneDrawType[iZone] == ZONE_DRAW_HALF);
					Effect_DrawBeamBoxToClient(iClient, vStart, vEnd, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
				}
				case ZONE_TYPE_CIRCLE: {
					TE_SetupBeamRingPoint(g_vZoneStart[iZone], g_fZoneRadius[iZone], g_fZoneRadius[iZone] + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 0.0, iColor, 0, 0);
					TE_SendToClient(iClient);
					
					if (g_iZoneDrawType[iZone] == ZONE_DRAW_FULL) {
						CopyArrayToArray(g_vZoneStart[iZone], vCoordinates_Expanded, 3);
						vCoordinates_Expanded[2] += g_fZoneHeight[iZone];
						
						TE_SetupBeamRingPoint(vCoordinates_Expanded, g_fZoneRadius[iZone], g_fZoneRadius[iZone] + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 0.0, iColor, 0, 0);
						TE_SendToClient(iClient);
					}
				}
				
				case ZONE_TYPE_POLY: {
					if (g_alZonePoints[iZone] == null) {
						continue;
					}
					
					for (int y = 0; y < g_alZonePoints[iZone].Length; y++) {
						g_alZonePoints[iZone].GetArray(y, vCoordinates, sizeof(vCoordinates));
						
						if (y + 1 >= g_alZonePoints[iZone].Length) {
							iIndex = 0;
						} else {
							iIndex = y + 1;
						}
						
						g_alZonePoints[iZone].GetArray(iIndex, vNextPoint, sizeof(vNextPoint));
						
						if (!AreVectorsEqual(vCoordinates, vNextPoint)) {
							TE_SetupBeamPoints(vCoordinates, vNextPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
							TE_SendToClient(iClient);
							
							if (g_iZoneDrawType[iZone] == ZONE_DRAW_FULL) {
								CopyArrayToArray(vCoordinates, vCoordinates_Expanded, 3);
								vCoordinates_Expanded[2] += g_fZoneHeight[iZone];
								
								CopyArrayToArray(vNextPoint, vNextPoint_Expanded, 3);
								vNextPoint_Expanded[2] += g_fZoneHeight[iZone];
								
								TE_SetupBeamPoints(vCoordinates_Expanded, vNextPoint_Expanded, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, fTime, 1.0, 1.0, 0, 0.0, iColor, 0);
								TE_SendToClient(iClient);
							}
						}
					}
				}
			}
		}
	}
}

stock int InitZone(int iZoneType, int & iArrayCell, int iZone = INVALID_ENT_INDEX)
{
	bool bTrigger = false;
	char szClassName[64];
	
	if (IsValidEntity(iZone) && iZone > MaxClients) {
		GetEntityClassname(iZone, szClassName, sizeof(szClassName));
		
		if (StrContains(szClassName, "trigger_", false) == INVALID_ARRAY_INDEX) {
			ThrowError("You can only register an existing trigger_* entity as a zone");
			return INVALID_ENT_INDEX;
		}
		
		bTrigger = true;
	}
	
	if (iZoneType == ZONE_TYPE_TRIGGER && !bTrigger) {
		ThrowError("Entity %d is not a valid trigger", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (!bTrigger || iZone <= MaxClients) {
		iZone = CreateEntityByName(iZoneType == ZONE_TYPE_CUBE ? "trigger_multiple" : "info_target");
		
		if (iZone > MaxClients) {
			ResetZoneVariables(iZone);
		}
	}
	
	if (!IsValidEntity(iZone) || iZone <= MaxClients) {
		return INVALID_ENT_INDEX;
	}
	
	if (g_alZoneEntities == null) {
		g_alZoneEntities = new ArrayList();
	}
	
	g_bIsZone[iZone] = true;
	iArrayCell = g_alZoneEntities.FindValue(EntIndexToEntRef(iZone));
	
	if (iArrayCell != INVALID_ARRAY_INDEX) {
		return iZone;
	}
	
	iArrayCell = g_alZoneEntities.Push(EntIndexToEntRef(iZone));
	
	return iZone;
}

bool IsValidZone(int iZone)
{
	if (iZone <= MaxClients) {
		return false;
	}
	
	if (!IsValidEntity(iZone)) {
		return false;
	}
	
	return g_bIsZone[iZone];
}

int CreateZone(const char[] szName, int iType, float vStart[3], float vEnd[3], float fRadius, int iColor[4], int iDrawType = ZONE_DRAW_HALF, ArrayList alPoints = null, float fHeight = 0.0, StringMap smEffects = null, int iEntity = INVALID_ENT_INDEX)
{
	char szType[MAX_ZONE_TYPE_LENGTH]; GetZoneTypeName(iType, szType, sizeof(szType));
	
	LogDebug("zonesmanager", "%s %s Zone: %s - %.2f/%.2f/%.2f - %.2f/%.2f/%.2f - %.2f", iType == ZONE_TYPE_TRIGGER ? "Hooking" : "Spawning", szType, szName, vStart[0], vStart[1], vStart[2], vEnd[0], vEnd[1], vEnd[2], fRadius);
	
	int iArrayCell = INVALID_ARRAY_INDEX;
	iEntity = InitZone(iType, iArrayCell, iEntity);
	
	if (iEntity == INVALID_ENT_INDEX || iArrayCell == INVALID_ARRAY_INDEX) {
		if (IsValidEntity(iEntity) && iEntity > MaxClients) {
			DeleteZone(iEntity);
		}
		
		return INVALID_ENT_INDEX;
	}
	
	if (!g_bEntitySpawned[iEntity]) {
		DispatchKeyValue(iEntity, "targetname", szName);
		
		switch (iType) {
			case ZONE_TYPE_CUBE: {
				DispatchKeyValue(iEntity, "spawnflags", "257");
				DispatchKeyValue(iEntity, "StartDisabled", "0");
				DispatchKeyValue(iEntity, "wait", "0");
			}
			case ZONE_TYPE_CIRCLE, ZONE_TYPE_POLY: {
				DispatchKeyValueVector(iEntity, "origin", vStart);
			}
		}
		
		if (!DispatchSpawn(iEntity)) {
			DeleteZone(iEntity);
			return INVALID_ENT_INDEX;
		}
		
		AcceptEntityInput(iEntity, "Enable");
		ActivateEntity(iEntity);
	}
	
	switch (iType) {
		case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
			SetEntProp(iEntity, Prop_Data, "m_spawnflags", 257);
			
			if (iType != ZONE_TYPE_TRIGGER) {
				SetEntityModel(iEntity, g_szErrorModel);
				InitCubeVector(iEntity, vStart, vEnd);
			}
		}
		
		case ZONE_TYPE_POLY: {
			g_alZonePoints[iEntity] = alPoints != null ? view_as<ArrayList>(CloneHandle(alPoints)) : new ArrayList(3);
			
			float vTempMin[3];
			float vTempMax[3];
			float fDiff;
			float fGreaterDiff;
			float vCoordinates[3];
			float vCoordinates2[3];
			
			for (int i = 0; i < g_alZonePoints[iEntity].Length; i++) {
				g_alZonePoints[iEntity].GetArray(i, vCoordinates, sizeof(vCoordinates));
				
				for (int j = 0; j < 3; j++) {
					if (vTempMin[j] == 0.0 || vTempMin[j] > vCoordinates[j]) {
						vTempMin[j] = vCoordinates[j];
					}
					if (vTempMax[j] == 0.0 || vTempMax[j] < vCoordinates[j]) {
						vTempMax[j] = vCoordinates[j];
					}
				}
				
				g_alZonePoints[iEntity].GetArray(0, vCoordinates2, sizeof(vCoordinates2));
				fDiff = CalculateHorizontalDistance(vCoordinates2, vCoordinates, false);
				
				if (fDiff > fGreaterDiff) {
					fGreaterDiff = fDiff;
				}
			}
			
			for (int y = 0; y < 3; y++) {
				g_fZonePointsMin[iEntity][y] = vTempMin[y];
				g_fZonePointsMax[iEntity][y] = vTempMax[y];
			}
			
			g_fZonePointsDistance[iEntity] = fGreaterDiff;
		}
	}
	
	delete g_smZoneEffects[iEntity];
	g_smZoneEffects[iEntity] = smEffects != null ? view_as<StringMap>(CloneHandle(smEffects)) : new StringMap();
	
	CopyArrayToArray(vStart, g_vZoneStart[iEntity], 3);
	CopyArrayToArray(vEnd, g_vZoneEnd[iEntity], 3);
	
	g_iZoneType[iEntity] = iType;
	g_fZoneRadius[iEntity] = fRadius;
	g_iZoneColor[iEntity] = iColor;
	g_fZoneHeight[iEntity] = fHeight;
	g_iZoneDrawType[iEntity] = iDrawType;
	
	strcopy(g_szZoneName[iEntity], MAX_ZONE_NAME_LENGTH, szName);
	
	LogDebug("zonesmanager", "%s Zone %s has been %s successfully with the entity index %i.", szType, szName, iType == ZONE_TYPE_TRIGGER ? "hooked" : "spawned", iEntity);
	
	SDKHookEx(iEntity, SDKHook_Touch, Zones_StartTouch);
	SDKHookEx(iEntity, SDKHook_EndTouch, Zones_EndTouch);
	
	int iAssignedIndex = INVALID_ARRAY_INDEX;
	int iEntRef = EntIndexToEntRef(iEntity);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}
		
		if (g_alAssignedZones[i] == null) {
			continue;
		}
		
		iAssignedIndex = g_alAssignedZones[i].FindValue(iEntRef);
		
		if (iAssignedIndex == INVALID_ARRAY_INDEX) {
			continue;
		}
		
		g_iZoningState[i][iEntity] = ZONING_STATE_NONE;
		g_alAssignedZones[i].Erase(iAssignedIndex);
	}
	
	delete alPoints;
	delete smEffects;
	
	Call_StartForward(g_hOnZoneSpawned);
	Call_PushCell(iEntity);
	Call_PushCell(iType);
	Call_PushString(szName);
	Call_PushArray(vStart, 3);
	Call_PushArray(vEnd, 3);
	Call_PushFloat(fRadius);
	Call_PushFloat(fHeight);
	Call_PushArray(iColor, 4);
	Call_PushCell(iDrawType);
	Call_PushCell(view_as<int>(g_alZonePoints[iEntity]));
	Call_PushCell(view_as<int>(g_smZoneEffects[iEntity]));
	Call_Finish();
	
	return iEntity;
}

Action IsNearExternalZone(int iEntity, int iZone, int iType)
{
	Action aResult = Plugin_Continue;
	
	if (!g_bIsInsideZone[iEntity][iZone]) {
		Call_StartForward(g_hStartTouchZone);
		Call_PushCell(iEntity);
		Call_PushCell(iZone);
		Call_PushString(g_szZoneName[iEntity]);
		Call_PushCell(iType);
		Call_Finish(aResult);
	}
	
	if (aResult <= Plugin_Changed) {
		Call_StartForward(g_hTouchZone);
		Call_PushCell(iEntity);
		Call_PushCell(iZone);
		Call_PushString(g_szZoneName[iEntity]);
		Call_PushCell(iType);
		Call_Finish(aResult);
	}
	
	return aResult;
}

Action IsNotNearExternalZone(int iEntity, int iZone, int iType)
{
	Action aResult = Plugin_Continue;
	
	if (g_bIsInsideZone[iEntity][iZone]) {
		Call_StartForward(g_hEndTouchZone);
		Call_PushCell(iEntity);
		Call_PushCell(iZone);
		Call_PushString(g_szZoneName[iEntity]);
		Call_PushCell(iType);
		Call_Finish(aResult);
	}
	
	return aResult;
}

void IsNearExternalZone_Post(int iEntity, int iZone, int iType)
{
	if (!g_bIsInsideZone[iEntity][iZone]) {
		g_bIsInsideZone[iEntity][iZone] = true;
		
		CallEffectCallback(iZone, iEntity, EFFECT_CALLBACK_ONENTERZONE);
		Call_StartForward(g_hStartTouchZone_Post);
		Call_PushCell(iEntity);
		Call_PushCell(iZone);
		Call_PushString(g_szZoneName[iEntity]);
		Call_PushCell(iType);
		Call_Finish();
	}
	
	CallEffectCallback(iZone, iEntity, EFFECT_CALLBACK_ONACTIVEZONE);
	Call_StartForward(g_hTouchZone_Post);
	Call_PushCell(iEntity);
	Call_PushCell(iZone);
	Call_PushString(g_szZoneName[iEntity]);
	Call_PushCell(iType);
	Call_Finish();
}

void IsNotNearExternalZone_Post(int iEntity, int iZone, int iType)
{
	if (g_bIsInsideZone[iEntity][iZone]) {
		g_bIsInsideZone[iEntity][iZone] = false;
		
		CallEffectCallback(iZone, iEntity, EFFECT_CALLBACK_ONLEAVEZONE);
		Call_StartForward(g_hEndTouchZone_Post);
		Call_PushCell(iEntity);
		Call_PushCell(iZone);
		Call_PushString(g_szZoneName[iEntity]);
		Call_PushCell(iType);
		Call_Finish();
	}
}

public Action Zones_StartTouch(int iZone, int iEntity)
{
	if (!g_bEntityZoneHooked[iEntity][iZone] && !g_bEntityGlobalHooked[iEntity] && !IsValidZone(iEntity) && !IsPlayerIndex(iEntity)) {
		return Plugin_Handled;
	}
	
	int iZoneType = GetZoneType(iZone);
	Action aAction = IsNearExternalZone(iEntity, iZone, iZone);
	
	if (aAction <= Plugin_Changed) {
		IsNearExternalZone_Post(iEntity, iZone, iZoneType);
	}
	
	return aAction;
}

public Action Zones_EndTouch(int iZone, int iEntity)
{
	if (!g_bEntityZoneHooked[iEntity][iZone] && !g_bEntityGlobalHooked[iEntity] && !IsValidZone(iEntity) && !IsPlayerIndex(iEntity)) {
		return Plugin_Handled;
	}
	
	int iZoneType = GetZoneType(iZone);
	Action aAction = IsNotNearExternalZone(iEntity, iZone, iZoneType);
	
	if (aAction <= Plugin_Changed) {
		IsNotNearExternalZone_Post(iEntity, iZone, iZoneType);
	}
	
	return aAction;
}

void CallEffectCallback(int iZone, int iEntity, int iCallBack)
{
	if (g_alEffectList == null) {
		g_alEffectList = new ArrayList(ByteCountToCells(MAX_EFFECT_NAME_LENGTH));
		return;
	}
	
	if (g_smEffectCalls == null) {
		g_smEffectCalls = new StringMap();
		return;
	}
	
	if (g_smZoneEffects[iZone] == null) {
		g_smZoneEffects[iZone] = new StringMap();
		return;
	}
	
	char szEffect[MAX_EFFECT_NAME_LENGTH];
	Handle hCallBacks[MAX_EFFECT_CALLBACKS];
	StringMap smValues;
	
	for (int i = 0; i < g_alEffectList.Length; i++) {
		g_alEffectList.GetString(i, szEffect, sizeof(szEffect));
		
		if (g_smEffectCalls.GetArray(szEffect, hCallBacks, sizeof(hCallBacks)) && hCallBacks[iCallBack] != null && GetForwardFunctionCount(hCallBacks[iCallBack]) > 0 && g_smZoneEffects[iZone].GetValue(szEffect, smValues)) {
			Call_StartForward(hCallBacks[iCallBack]);
			Call_PushCell(iEntity);
			Call_PushCell(iZone);
			Call_PushCell(smValues);
			Call_Finish();
		}
	}
}

void RegisterNewEffect(Handle hPlugin, const char[] szEffectName, Function fFunction1 = INVALID_FUNCTION, Function fFunction2 = INVALID_FUNCTION, Function fFunction3 = INVALID_FUNCTION)
{
	if (hPlugin == null || strlen(szEffectName) == 0) {
		return;
	}
	
	Handle hCallBacks[MAX_EFFECT_CALLBACKS];
	int iIndex = g_alEffectList.FindString(szEffectName);
	
	if (iIndex != INVALID_ARRAY_INDEX) {
		g_smEffectCalls.GetArray(szEffectName, hCallBacks, sizeof(hCallBacks));
		
		for (int i = 0; i < MAX_EFFECT_CALLBACKS; i++) {
			delete hCallBacks[i];
		}
		
		ClearKeys(szEffectName);
		
		g_smEffectCalls.Remove(szEffectName);
		g_alEffectList.Erase(iIndex);
	}
	
	if (fFunction1 != INVALID_FUNCTION) {
		hCallBacks[EFFECT_CALLBACK_ONENTERZONE] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(hCallBacks[EFFECT_CALLBACK_ONENTERZONE], hPlugin, fFunction1);
	}
	
	if (fFunction2 != INVALID_FUNCTION) {
		hCallBacks[EFFECT_CALLBACK_ONACTIVEZONE] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(hCallBacks[EFFECT_CALLBACK_ONACTIVEZONE], hPlugin, fFunction2);
	}
	
	if (fFunction3 != INVALID_FUNCTION) {
		hCallBacks[EFFECT_CALLBACK_ONLEAVEZONE] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(hCallBacks[EFFECT_CALLBACK_ONLEAVEZONE], hPlugin, fFunction3);
	}
	
	g_smEffectCalls.SetArray(szEffectName, hCallBacks, sizeof(hCallBacks));
	g_alEffectList.PushString(szEffectName);
}

void RegisterNewEffectKey(const char[] szEffectName, const char[] szKey, const char[] szDefaultValue)
{
	StringMap smKeys;
	
	if (!g_smEffectKeys.GetValue(szEffectName, smKeys) || smKeys == null) {
		smKeys = new StringMap();
	}
	
	smKeys.SetString(szKey, szDefaultValue);
	g_smEffectKeys.SetValue(szEffectName, smKeys);
}

void ClearKeys(const char[] szEffectName)
{
	StringMap smKeys;
	
	if (!g_smEffectKeys.GetValue(szEffectName, smKeys)) {
		return;
	}
	
	delete smKeys;
	g_smEffectKeys.Remove(szEffectName);
}

void GetMiddleOfABox(const float vMins[3], const float vMaxs[3], float vBuffer[3])
{
	float vMid[3]; MakeVectorFromPoints(vMins, vMaxs, vMid);
	
	vMid[0] /= 2.0;
	vMid[1] /= 2.0;
	vMid[2] /= 2.0;
	
	AddVectors(vMins, vMid, vBuffer);
}

bool GetClientLookPoint(int iClient, float vLookPosition[3], bool bBeam = false)
{
	float vEyePos[3]; GetClientEyePosition(iClient, vEyePos);
	float vEyeAng[3]; GetClientEyeAngles(iClient, vEyeAng);
	
	Handle hTrace = TR_TraceRayFilterEx(vEyePos, vEyeAng, MASK_SHOT, RayType_Infinite, TraceEntityFilter_NoPlayers);
	
	bool bHit = TR_DidHit(hTrace);
	
	TR_GetEndPosition(vLookPosition, hTrace);
	delete hTrace;
	
	if (bBeam) {
		TE_SetupBeamPoints(vEyePos, vLookPosition, g_iDefaultModelIndex, g_iDefaultHaloIndex, 0, 30, 0.2, 1.0, 1.0, 0, 0.0, { 255, 0, 0, 255 }, 0);
		TE_SendToClient(iClient);
	}
	
	return bHit;
}

public bool TraceEntityFilter_NoPlayers(int iEntity, int iContentsMask) {
	return false;
}

bool TeleportToZone(int iClient, int iZone)
{
	if (!IsPlayerIndex(iClient) || !IsClientInGame(iClient) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	float vLocation[3];
	
	if (!GetZoneTeleportLocation(iZone, vLocation)) {
		return false;
	}
	
	TeleportEntity(iClient, vLocation, NULL_VECTOR, NULL_VECTOR);
	return true;
}

bool GetZoneTeleportLocation(int iZone, float vLocation[3])
{
	if (!IsValidZone(iZone)) {
		return false;
	}
	
	switch (GetZoneType(iZone)) {
		case ZONE_TYPE_TRIGGER, ZONE_TYPE_CUBE: {
			CopyArrayToArray(g_vEntityOrigin[iZone], vLocation, 3);
		}
		
		case ZONE_TYPE_CIRCLE: {
			CopyArrayToArray(g_vZoneStart[iZone], vLocation, 3);
		}
		case ZONE_TYPE_POLY: {
			GetPolygonCenter(iZone, vLocation);
		}
	}
	
	vLocation[2] = GetLowestCorner(iZone);
	
	FindGround(vLocation);
	
	// So our feet don't get stuck in the ground.
	vLocation[2] += 0.5;
	
	if (TR_PointOutsideWorld(vLocation) || !IsValidOrigin(vLocation)) {
		switch (GetZoneType(iZone)) {
			case ZONE_TYPE_TRIGGER, ZONE_TYPE_CUBE: {
				CopyArrayToArray(g_vEntityOrigin[iZone], vLocation, 3);
				
				if(TR_PointOutsideWorld(vLocation) || !IsValidOrigin(vLocation)) {
					return false;
				}
				
				return true;
			}
		}
		
		return false;
	}
	
	return true;
}

int GetZoneByName(const char[] szName)
{
	if (g_alZoneEntities == null) {
		return INVALID_ENT_INDEX;
	}
	
	int iEntity = INVALID_ENT_INDEX;
	
	for (int i = 0; i < g_alZoneEntities.Length; i++) {
		iEntity = g_alZoneEntities.Get(i);
		
		if (iEntity == INVALID_ENT_REFERENCE) {
			continue;
		}
		
		iEntity = EntRefToEntIndex(iEntity);
		
		if (!IsValidZone(iEntity)) {
			continue;
		}
		
		if (!StrEqual(szName, g_szZoneName[iEntity])) {
			continue;
		}
		
		return iEntity;
	}
	
	return INVALID_ENT_INDEX;
}

bool AddZonePoint(ArrayList alPoints, float fPoint[3])
{
	if (alPoints == null) {
		return false;
	}
	
	if (alPoints.FindValue(fPoint[0], 0) != INVALID_ARRAY_INDEX && alPoints.FindValue(fPoint[1], 1) != INVALID_ARRAY_INDEX && alPoints.FindValue(fPoint[2], 2) != INVALID_ARRAY_INDEX) {
		return false;
	}
	
	int iSize = 0;
	int iActual = 0;
	
	iSize = alPoints.Length;
	iActual = iSize + 1;
	
	alPoints.Resize(iActual);
	alPoints.Set(iSize, fPoint[0], 0);
	alPoints.Set(iSize, fPoint[1], 1);
	alPoints.Set(iSize, fPoint[2], 2);
	
	return true;
}

bool RemoveZonePoint(int iZone, float fPoint[3])
{
	if (g_alZonePoints[iZone] == null) {
		return false;
	}
	
	float fBuffer[3];
	
	for (int i = 0; i < g_alZonePoints[iZone].Length; i++) {
		g_alZonePoints[iZone].GetArray(i, fBuffer);
		
		if (!AreVectorsEqual(fPoint, fBuffer)) {
			continue;
		}
		
		g_alZonePoints[iZone].Erase(i);
		return true;
	}
	
	return false;
}

KeyValues CreateZoneKeyValues(int iZone)
{
	if (!IsValidZone(iZone)) {
		ThrowError("Entity %d is not a valid zone", iZone);
		return null;
	}
	
	if (!strlen(g_szZoneName[iZone])) {
		ThrowError("Name for zone %d is undefined", iZone);
		return null;
	}
	
	if (g_iZoneType[iZone] == INVALID_ENT_INDEX) {
		ThrowError("Type for zone %d is undefined", iZone);
		return null;
	}
	
	if (!IsValidOrigin(g_vZoneStart[iZone])) {
		ThrowError("Start point for zone %d is undefined", iZone);
		return null;
	}
	
	if (!IsValidOrigin(g_vZoneEnd[iZone]) && (g_iZoneType[iZone] == ZONE_TYPE_CUBE || g_iZoneType[iZone] == ZONE_TYPE_TRIGGER)) {
		ThrowError("End point for zone %d is undefined", iZone);
		return null;
	}
	
	if (g_fZoneRadius[iZone] == -1.0 && g_iZoneType[iZone] == ZONE_TYPE_CIRCLE) {
		ThrowError("Radius for zone %d is undefined", iZone);
		return null;
	}
	
	if (g_iZoneColor[iZone][0] == INVALID_ARRAY_INDEX || g_iZoneColor[iZone][1] == INVALID_ARRAY_INDEX || g_iZoneColor[iZone][2] == INVALID_ARRAY_INDEX || g_iZoneColor[iZone][3] == INVALID_ARRAY_INDEX) {
		ThrowError("Color (%d, %d, %d, %d) for zone %d is undefined or invalid", g_iZoneColor[iZone][0], g_iZoneColor[iZone][1], g_iZoneColor[iZone][2], g_iZoneColor[iZone][3], iZone);
		return null;
	}
	
	if (g_iZoneDrawType[iZone] < ZONE_DRAW_HALF || g_iZoneDrawType[iZone] > ZONE_DRAW_NONE) {
		ThrowError("Draw Type for zone %d is undefined or invalid", iZone);
		return null;
	}
	
	if (g_alZonePoints[iZone] == null && g_iZoneType[iZone] == ZONE_TYPE_POLY) {
		ThrowError("Point list for zone %d is undefined", iZone);
		return null;
	}
	
	if (g_iZoneType[iZone] == ZONE_TYPE_POLY && !g_alZonePoints[iZone].Length) {
		ThrowError("Point list for zone %d is empty", iZone);
		return null;
	}
	
	if (g_fZoneHeight[iZone] == -1.0 && (g_iZoneType[iZone] == ZONE_TYPE_POLY || g_iZoneType[iZone] == ZONE_TYPE_CIRCLE)) {
		ThrowError("Height for zone %d is undefined", iZone);
		return null;
	}
	
	KeyValues kvZoneKV = new KeyValues("zones_manager");
	
	kvZoneKV.JumpToKey(g_szZoneName[iZone], true);
	
	char szType[MAX_ZONE_TYPE_LENGTH]; GetZoneTypeName(g_iZoneType[iZone], szType, sizeof(szType));
	kvZoneKV.SetString("type", szType);
	
	char szColor[64]; FormatEx(szColor, sizeof(szColor), "%i %i %i %i", g_iZoneColor[iZone][0], g_iZoneColor[iZone][1], g_iZoneColor[iZone][2], g_iZoneColor[iZone][3]);
	kvZoneKV.SetString("color", szColor);
	kvZoneKV.SetNum("drawtype", g_iZoneDrawType[iZone]);
	
	switch (g_iZoneType[iZone]) {
		case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
			kvZoneKV.SetVector("start", g_vZoneStart[iZone]);
			kvZoneKV.SetVector("end", g_vZoneEnd[iZone]);
		}
		case ZONE_TYPE_CIRCLE: {
			kvZoneKV.SetVector("start", g_vZoneStart[iZone]);
			kvZoneKV.SetFloat("radius", g_fZoneRadius[iZone]);
			kvZoneKV.SetFloat("height", g_fZoneHeight[iZone]);
		}
		case ZONE_TYPE_POLY: {
			kvZoneKV.SetVector("start", g_vZoneStart[iZone]);
			kvZoneKV.SetFloat("height", g_fZoneHeight[iZone]);
			
			if (kvZoneKV.JumpToKey("points", true)) {
				char szId[12]; float vCoordinates[3];
				
				for (int i = 0; i < g_alZonePoints[iZone].Length; i++) {
					IntToString(i, szId, sizeof(szId));
					g_alZonePoints[iZone].GetArray(i, vCoordinates, sizeof(vCoordinates));
					kvZoneKV.SetVector(szId, vCoordinates);
				}
			}
		}
	}
	
	kvZoneKV.Rewind();
	return kvZoneKV;
}

bool IsValidOrigin(float vOrigin[3])
{
	float vNull[3] =  { 0.0, 0.0, 0.0 };
	float vInvalid[3] =  { -1.0, -1.0, -1.0 };
	
	if (AreVectorsEqual(vOrigin, vInvalid) || AreVectorsEqual(vOrigin, vNull)) {
		return false;
	}
	
	return true;
}

bool GetZoneKeyValuesAsString(int iZone, char[] szBuffer, int iSize)
{
	KeyValues kvZoneKV = CreateZoneKeyValues(iZone);
	
	if (kvZoneKV == null) {
		return false;
	}
	
	// Hacky workaround for older SM versions.
	if (!g_bNativeKvToString) {
		char szPath[PLATFORM_MAX_PATH]; BuildPath(Path_SM, szPath, sizeof(szPath), "data/zones/%d.temp", GetSomeWhatDecentRandom());
		
		if (!kvZoneKV.ExportToFile(szPath)) {
			delete kvZoneKV;
			return false;
		}
		
		delete kvZoneKV;
		
		if (!FileExists(szPath)) {
			DeleteFile(szPath);
			return false;
		}
		
		File fFile = OpenFile(szPath, "r");
		
		if (fFile == null) {
			DeleteFile(szPath);
			return false;
		}
		
		if (fFile.ReadString(szBuffer, iSize) <= 0) {
			delete fFile;
			DeleteFile(szPath);
			return false;
		}
		
		delete fFile;
		DeleteFile(szPath);
		return true;
	}
	
	if (kvZoneKV.ExportToString(szBuffer, iSize) <= 0) {
		delete kvZoneKV;
		return false;
	}
	
	return true;
}

int GetSomeWhatDecentRandom()
{
	int iWaiter = 0;
	
	while (iWaiter < 10) {
		iWaiter++;
	}
	
	return RoundToNearest(GetGameTime() + GetURandomFloat() + GetRandomFloat(1.0, 638490753.0));
}

float GetLowestCorner(int iZone)
{
	if (!IsValidZone(iZone)) {
		return -1.0;
	}
	
	float fLowest = -1.0;
	
	switch (GetZoneType(iZone)) {
		case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
			float vStart[3], vEnd[3]; GetAbsBoundingBox(iZone, vStart, vEnd);
			fLowest = vStart[2] > vEnd[2] ? vEnd[2] : vStart[2];
		}
		case ZONE_TYPE_CIRCLE: {
			fLowest = g_vZoneStart[iZone][2];
		}
		
		case ZONE_TYPE_POLY: {
			float vPoint[3];
			
			for (int i = 0; i < g_alZonePoints[iZone].Length; i++) {
				g_alZonePoints[iZone].GetArray(i, vPoint);
				
				if (vPoint[2] < fLowest || fLowest == -1.0) {
					fLowest = vPoint[2];
				}
			}
		}
	}
	
	return fLowest;
}

float GetHighestCorner(int iZone)
{
	if (!IsValidZone(iZone)) {
		return -1.0;
	}
	
	float fHighest = -1.0;
	
	switch (GetZoneType(iZone)) {
		case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
			float vStart[3], vEnd[3]; GetAbsBoundingBox(iZone, vStart, vEnd);
			fHighest = vStart[2] < vEnd[2] ? vEnd[2] : vStart[2];
		}
		case ZONE_TYPE_CIRCLE: {
			fHighest = g_vZoneStart[iZone][2] + g_fZoneHeight[iZone];
		}
		case ZONE_TYPE_POLY: {
			float vPoint[3];
			
			for (int i = 0; i < g_alZonePoints[iZone].Length; i++) {
				g_alZonePoints[iZone].GetArray(i, vPoint);
				
				if (vPoint[2] > fHighest || fHighest == -1.0) {
					fHighest = vPoint[2];
				}
			}
		}
	}
	
	return fHighest;
}

bool IsVectorInsideZone(int iZone, float vOrigin[3])
{
	switch (GetZoneType(iZone)) {
		case ZONE_TYPE_CUBE, ZONE_TYPE_TRIGGER: {
			float vTemp[3]; CopyArrayToArray(vOrigin, vTemp, 3); vTemp[2] += 5.0;
			
			int iCheck = 0;
			
			for (int i = 0; i < 3; i++) {
				if ((g_vZoneCorners[iZone][7][i] >= g_vZoneCorners[iZone][0][i] && (vTemp[i] <= (g_vZoneCorners[iZone][7][i]) && vTemp[i] >= (g_vZoneCorners[iZone][0][i]))) || 
					(g_vZoneCorners[iZone][0][i] >= g_vZoneCorners[iZone][7][i] && (vTemp[i] <= (g_vZoneCorners[iZone][0][i]) && vTemp[i] >= (g_vZoneCorners[iZone][7][i])))) {
					iCheck++;
				}
				
				if (iCheck < 3) {
					continue;
				}
				
				return true;
			}
			
			return false;
		}
		
		case ZONE_TYPE_CIRCLE: {
			return GetVectorDistance(vOrigin, g_vEntityOrigin[iZone]) <= (g_fZoneRadius[iZone] / 2.0);
		}
		
		case ZONE_TYPE_POLY: {
			float vNewOrigin[3];
			float vEntityPoints[4][3];
			static float fOffset = 16.5;
			
			vNewOrigin[0] = vOrigin[0];
			vNewOrigin[1] = vOrigin[1];
			vNewOrigin[2] = vOrigin[2];
			vNewOrigin[2] += 42.5;
			vEntityPoints[0] = vNewOrigin;
			vEntityPoints[0][0] -= fOffset;
			vEntityPoints[0][1] -= fOffset;
			vEntityPoints[1] = vNewOrigin;
			vEntityPoints[1][0] += fOffset;
			vEntityPoints[1][1] -= fOffset;
			vEntityPoints[2] = vNewOrigin;
			vEntityPoints[2][0] -= fOffset;
			vEntityPoints[2][1] += fOffset;
			vEntityPoints[3] = vNewOrigin;
			vEntityPoints[3][0] += fOffset;
			vEntityPoints[3][1] += fOffset;
			
			for (int x = 0; x < 4; x++) {
				if (!IsPointInZone(vEntityPoints[x], iZone)) {
					continue;
				}
				
				return true;
			}
			
			return false;
		}
	}
	
	return false;
}

void InitCubeVector(int iEntity, float vStart[3], float vEnd[3])
{
	float vMiddle[3]; GetMiddleOfABox(vStart, vEnd, vMiddle);
	TeleportEntity(iEntity, vMiddle, NULL_VECTOR, NULL_VECTOR);
	SetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vMiddle);
	
	// Count zone corners
	// https://forums.alliedmods.net/showpost.php?p=2006539&postcount=8
	for (int i = 0; i < 3; i++) {
		g_vZoneCorners[iEntity][0][i] = vStart[i];
		g_vZoneCorners[iEntity][7][i] = vEnd[i];
	}
	
	for (int i = 1; i < 7; i++) {
		for (int j = 0; j < 3; j++) {
			g_vZoneCorners[iEntity][i][j] = g_vZoneCorners[iEntity][((i >> (2 - j)) & 1) * 7][j];
		}
	}
	
	// Have the mins always be negative
	vStart[0] = vStart[0] - vMiddle[0];
	
	if (vStart[0] > 0.0) {
		vStart[0] *= -1.0;
	}
	
	vStart[1] = vStart[1] - vMiddle[1];
	
	if (vStart[1] > 0.0) {
		vStart[1] *= -1.0;
	}
	
	vStart[2] = vStart[2] - vMiddle[2];
	if (vStart[2] > 0.0) {
		vStart[2] *= -1.0;
	}
	
	// And the maxs always be positive
	vEnd[0] = vEnd[0] - vMiddle[0];
	
	if (vEnd[0] < 0.0) {
		vEnd[0] *= -1.0;
	}
	
	vEnd[1] = vEnd[1] - vMiddle[1];
	
	if (vEnd[1] < 0.0) {
		vEnd[1] *= -1.0;
	}
	
	vEnd[2] = vEnd[2] - vMiddle[2];
	
	if (vEnd[2] < 0.0) {
		vEnd[2] *= -1.0;
	}
	
	SetEntPropVector(iEntity, Prop_Data, "m_vecMins", vStart);
	SetEntPropVector(iEntity, Prop_Data, "m_vecMaxs", vEnd);
}

// Thanks rio (https://steamcommunity.com/id/rio_/)
void FindGround(float vOrigin[3])
{
	float fDirection[] =  { 0.0, 0.0, -1.0 };
	
	TR_TraceRayFilter(vOrigin, fDirection, MASK_NPCSOLID, RayType_Infinite, TraceFilterIgnorePlayers);
	
	if (TR_DidHit()) {
		float vHitPos[3]; TR_GetEndPosition(vHitPos);
		
		vOrigin[2] = vHitPos[2];
	}
}

public bool TraceFilterIgnorePlayers(int iEntity, int iContentsMask, any anything)
{
	if (1 <= iEntity <= MaxClients) {
		return false;
	}
	
	return true;
}

//Down to just above the natives, these functions are made by 'Deathknife' and repurposed by me for this plugin.
//Fucker can maths
//by Deathknife

public void GetPolygonCenter(int iZone, float vPos[3])
{
	//needs to have atleast one point..
	float vFirst[3];
	float vLast[3];
	
	int iSize = g_alZonePoints[iZone].Length;
	g_alZonePoints[iZone].GetArray(0, vFirst, sizeof(vFirst));
	g_alZonePoints[iZone].GetArray(iSize - 1, vLast, sizeof(vLast));
	
	bool bPA = false;
	
	if (vFirst[0] != vLast[0] || vFirst[1] != vLast[1]) {
		g_alZonePoints[iZone].PushArray(vFirst);
		iSize += 1;
		bPA = true;
	}
	
	float fArea = 0.0;
	float x, y, f;
	
	float vP1[3];
	float vP2[3];
	
	for (int i = 0, j = iSize - 1; i < iSize; j = i++) {
		g_alZonePoints[iZone].GetArray(i, vP1, sizeof(vP1));
		g_alZonePoints[iZone].GetArray(j, vP2, sizeof(vP2));
		f = (vP1[0] * vP2[1]) - (vP2[0] * vP1[1]);
		fArea += f;
		x += (vP1[0] + vP2[0]) * f;
		y += (vP1[1] + vP2[1]) * f;
	}
	
	f = fArea * 3;
	vPos[0] = x / f;
	vPos[1] = y / f;
	
	if (bPA) {
		g_alZonePoints[iZone].Resize(iSize - 1);
	}
}

bool IsPointInZone(float vPoint[3], int iZone)
{
	//Check if point is in the zone
	if (!IsOriginInBox(vPoint, iZone)) {
		return false;
	}
	
	//Get a ray outside of the polygon
	float vRay[3];
	vRay = vPoint;
	vRay[1] += g_fZonePointsDistance[iZone] + 50.0;
	vRay[2] = vPoint[2];
	
	//Store the x and y intersections of where the ray hits the line
	float vXint;
	float vYint;
	
	//Intersections for base bottom and top(2)
	float vBaseY;
	float vBaseZ;
	float vBaseY2;
	float vBaseZ2;
	
	//Calculate equation for x + y
	float fEquation[2];
	fEquation[0] = vPoint[0] - vRay[0];
	fEquation[1] = vPoint[2] - vRay[2];
	
	//This is for checking if the line intersected the base
	//The method is messy, came up with it myself, and might not work 100% of the time.
	//Should work though.
	
	//Bottom
	int iLintersected[64];
	float fIntersect[64][3];
	
	//Top
	int iLintersectedT[64];
	float fIntersectT[64][3];
	
	//Count amount of intersetcions
	int iIntersections = 0;
	
	//Count amount of intersection for BASE
	int iLIntNum = 0;
	int iLIntNumT = 0;
	
	//Get slope
	float iLslope = (vRay[2] - vPoint[2]) / (vRay[1] - vPoint[1]);
	float iLeq = (iLslope & vRay[0]) - vRay[2];
	iLeq = -iLeq;
	
	//Get second slope
	float vCurrentPoint[3];
	float vNextPoint[3];
	bool bDidInter;
	bool bBaseInter;
	bool bBaseInter2;
	
	//Loop through every point of the zone
	float fM1;
	float fM2;
	float fL1;
	float fY2;
	float fY;
	float fLeq1;
	float fLeq2;
	float fXpoint1;
	float fXpoint2;
	
	int iSize = g_alZonePoints[iZone].Length;
	
	for (int i = 0; i < iSize; i++) {
		//Get current & next point
		g_alZonePoints[iZone].GetArray(i, vCurrentPoint, sizeof(vCurrentPoint));
		
		//Check if its the last point, if it is, join it with the first
		if (iSize == i + 1) {
			g_alZonePoints[iZone].GetArray(0, vNextPoint, sizeof(vNextPoint));
		} else {
			g_alZonePoints[iZone].GetArray(i + 1, vNextPoint, sizeof(vNextPoint));
		}
		
		//Check if the ray intersects the point
		//Ignore the height parameter as we will check against that later
		bDidInter = GetLineIntersection(vRay[0], vRay[1], vPoint[0], vPoint[1], vCurrentPoint[0], vCurrentPoint[1], vNextPoint[0], vNextPoint[1], vXint, vYint);
		
		//Get intersections of the bottom
		bBaseInter = GetLineIntersection(vRay[1], vRay[2], vPoint[1], vPoint[2], vCurrentPoint[1], vCurrentPoint[2], vNextPoint[1], vNextPoint[2], vBaseY, vBaseZ);
		
		//Get intersections of the top
		bBaseInter2 = GetLineIntersection(vRay[1], vRay[2], vPoint[1], vPoint[2], vCurrentPoint[1] + g_fZoneHeight[iZone], vCurrentPoint[2] + g_fZoneHeight[iZone], vNextPoint[1] + g_fZoneHeight[iZone], vNextPoint[2] + g_fZoneHeight[iZone], vBaseY2, vBaseZ2);
		
		//If base intersected, store the line for later
		if (bBaseInter && iLIntNum < sizeof(fIntersect)) {
			iLintersected[iLIntNum] = i;
			fIntersect[iLIntNum][1] = vBaseY;
			fIntersect[iLIntNum][2] = vBaseZ;
			iLIntNum++;
		}
		
		if (bBaseInter2 && iLIntNumT < sizeof(fIntersectT)) {
			iLintersectedT[iLIntNumT] = i;
			fIntersectT[iLIntNumT][1] = vBaseY2;
			fIntersectT[iLIntNumT][2] = vBaseZ2;
			iLIntNumT++;
		}
		
		//If ray intersected line, check against height
		if (bDidInter) {
			//Get the height of intersection
			
			//Get slope of line it hit
			fM1 = (vNextPoint[2] - vCurrentPoint[2]) / (vNextPoint[0] - vCurrentPoint[0]);
			
			//Equation y = mx + c | mx - y = -c
			fL1 = (fM1 * vCurrentPoint[0]) - vCurrentPoint[2]; fL1 = -fL1;
			fY2 = (fM1 * vXint) + fL1;
			
			//Get slope of ray
			fY = (iLslope * vXint) + iLeq;
			
			if (fY > fY2 && fY < fY2 + 128.0 + g_fZoneHeight[iZone]) {
				//The ray intersected the line and is within the height
				iIntersections++;
			}
		}
	}
	
	int i;
	int j;
	
	float vCurrentPoint2[2][3];
	float vNextPoint2[2][3];
	
	//Now we check for base hitting
	//This method is weird, but works most of the time
	for (int k = 0; k < iLIntNum; k++) {
		for (int l = k + 1; l < iLIntNum; l++) {
			if (l == k) {
				continue;
			}
			
			i = iLintersected[k];
			j = iLintersected[l];
			
			if (i == j) {
				continue;
			}
			
			if (g_alZonePoints[iZone].Length == i + 1) {
				g_alZonePoints[iZone].GetArray(i, vCurrentPoint2[0], 3);
				g_alZonePoints[iZone].GetArray(0, vNextPoint2[0], 3);
			} else {
				g_alZonePoints[iZone].GetArray(i, vCurrentPoint2[0], 3);
				g_alZonePoints[iZone].GetArray(i + 1, vNextPoint2[0], 3);
			}
			
			if (g_alZonePoints[iZone].Length == j + 1) {
				g_alZonePoints[iZone].GetArray(j, vCurrentPoint2[1], 3);
				g_alZonePoints[iZone].GetArray(0, vNextPoint2[1], 3);
			} else {
				g_alZonePoints[iZone].GetArray(j, vCurrentPoint2[1], 3);
				g_alZonePoints[iZone].GetArray(j + 1, vNextPoint2[1], 3);
			}
			
			//Get equation of both lines then find slope of them
			fM1 = (vNextPoint2[0][1] - vCurrentPoint2[0][1]) / (vNextPoint2[0][0] - vCurrentPoint2[0][0]);
			fM2 = (vNextPoint2[1][1] - vCurrentPoint2[1][1]) / (vNextPoint2[1][0] - vCurrentPoint2[1][0]);
			fLeq1 = (fM1 * vCurrentPoint2[0][0]) - vCurrentPoint2[0][1];
			fLeq2 = (fM2 * vCurrentPoint2[1][0]) - vCurrentPoint2[1][1];
			fLeq1 = -fLeq1;
			fLeq2 = -fLeq2;
			
			//Get x point of intersection
			fXpoint1 = ((fIntersect[k][1] - fLeq1) / fM1);
			fXpoint2 = ((fIntersect[l][1] - fLeq2) / fM2);
			
			if (fXpoint1 > vPoint[0] > fXpoint2 || fXpoint1 < vPoint[0] < fXpoint2) {
				iIntersections++;
			}
		}
	}
	
	for (int k = 0; k < iLIntNumT; k++) {
		for (int l = k + 1; l < iLIntNumT; l++) {
			if (l == k) {
				continue;
			}
			
			i = iLintersectedT[k];
			j = iLintersectedT[l];
			
			if (i == j) {
				continue;
			}
			
			if (g_alZonePoints[iZone].Length == i + 1) {
				g_alZonePoints[iZone].GetArray(i, vCurrentPoint2[0], 3);
				g_alZonePoints[iZone].GetArray(0, vNextPoint2[0], 3);
			} else {
				g_alZonePoints[iZone].GetArray(i, vCurrentPoint2[0], 3);
				g_alZonePoints[iZone].GetArray(i + 1, vNextPoint2[0], 3);
			}
			
			if (g_alZonePoints[iZone].Length == j + 1) {
				g_alZonePoints[iZone].GetArray(j, vCurrentPoint2[1], 3);
				g_alZonePoints[iZone].GetArray(0, vNextPoint2[1], 3);
			} else {
				g_alZonePoints[iZone].GetArray(j, vCurrentPoint2[1], 3);
				g_alZonePoints[iZone].GetArray(j + 1, vNextPoint2[1], 3);
			}
			
			//Get equation of both lines then find slope of them
			fM1 = (vNextPoint2[0][1] - vCurrentPoint2[0][1]) / (vNextPoint2[0][0] - vCurrentPoint2[0][0]);
			fM2 = (vNextPoint2[1][1] - vCurrentPoint2[1][1]) / (vNextPoint2[1][0] - vCurrentPoint2[1][0]);
			fLeq1 = (fM1 * vCurrentPoint2[0][0]) - vCurrentPoint2[0][1];
			fLeq2 = (fM2 * vCurrentPoint2[1][0]) - vCurrentPoint2[1][1];
			fLeq1 = -fLeq1;
			fLeq2 = -fLeq2;
			
			//Get x point of intersection
			fXpoint1 = ((fIntersectT[k][1] - fLeq1) / fM1);
			fXpoint2 = ((fIntersectT[l][1] - fLeq2) / fM2);
			
			if (fXpoint1 > vPoint[0] > fXpoint2 || fXpoint1 < vPoint[0] < fXpoint2) {
				iIntersections++;
			}
		}
	}
	
	if (iIntersections <= 0 || iIntersections % 2 == 0) {
		return false;
	}
	
	return true;
}

bool IsOriginInBox(float vOrigin[3], int iZone)
{
	if (vOrigin[0] >= g_fZonePointsMin[iZone][0] && vOrigin[1] >= g_fZonePointsMin[iZone][1] && vOrigin[2] >= g_fZonePointsMin[iZone][2] && vOrigin[0] <= g_fZonePointsMax[iZone][0] + g_fZoneHeight[iZone] && vOrigin[1] <= g_fZonePointsMax[iZone][1] + g_fZoneHeight[iZone] && vOrigin[2] <= g_fZonePointsMax[iZone][2] + g_fZoneHeight[iZone]) {
		return true;
	}
	
	return false;
}

bool GetLineIntersection(float p0_x, float p0_y, float p1_x, float p1_y, float p2_x, float p2_y, float p3_x, float p3_y, float &i_x, float &i_y)
{
	float s1_x = p1_x - p0_x;
	float s1_y = p1_y - p0_y;
	float s2_x = p3_x - p2_x;
	float s2_y = p3_y - p2_y;
	
	float s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
	float t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);
	
	if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
		// Collision detected
		i_x = p0_x + (t * s1_x);
		i_y = p0_y + (t * s1_y);
		
		return true;
	}
	
	return false; // No collision
}

float CalculateHorizontalDistance(float vOrigin1[3], float vOrigin2[3], bool bSquared = false)
{
	if (bSquared) {
		if (vOrigin1[0] < 0.0) {
			vOrigin1[0] *= -1;
		}
		
		if (vOrigin1[1] < 0.0) {
			vOrigin1[1] *= -1;
		}
		
		vOrigin1[0] = SquareRoot(vOrigin1[0]);
		vOrigin1[1] = SquareRoot(vOrigin1[1]);
		
		if (vOrigin2[0] < 0.0) {
			vOrigin2[0] *= -1;
		}
		
		if (vOrigin2[1] < 0.0) {
			vOrigin2[1] *= -1;
		}
		
		vOrigin2[0] = SquareRoot(vOrigin2[0]);
		vOrigin2[1] = SquareRoot(vOrigin2[1]);
	}
	
	return SquareRoot(Pow((vOrigin1[0] - vOrigin2[0]), 2.0) + Pow((vOrigin1[1] - vOrigin2[1]), 2.0));
}

//Natives
public int Native_RegisterEffect(Handle hPlugin, int iNumParams)
{
	int iSize; GetNativeStringLength(1, iSize);
	char[] szEffect = new char[iSize + 1]; GetNativeString(1, szEffect, iSize + 1);
	
	Function fFunction1 = GetNativeFunction(2);
	Function fFunction2 = GetNativeFunction(3);
	Function fFunction3 = GetNativeFunction(4);
	
	RegisterNewEffect(hPlugin, szEffect, fFunction1, fFunction2, fFunction3);
}

public int Native_RegisterEffectKey(Handle hPlugin, int iNumParams)
{
	int iSize; GetNativeStringLength(1, iSize);
	char[] szEffect = new char[iSize + 1]; GetNativeString(1, szEffect, iSize + 1);
	
	iSize = 0; GetNativeStringLength(2, iSize);
	char[] szKey = new char[iSize + 1]; GetNativeString(2, szKey, iSize + 1);
	
	iSize = 0; GetNativeStringLength(3, iSize);
	
	char[] szDefaultValue = new char[iSize + 1]; GetNativeString(3, szDefaultValue, iSize + 1);
	RegisterNewEffectKey(szEffect, szKey, szDefaultValue);
}

public int Native_RequestQueueEffects(Handle hPlugin, int iNumParams) {
	QueueEffects();
}

public int Native_ClearAllZones(Handle hPlugin, int iNumParams) {
	ClearAllZones();
}

public int Native_IsValidZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	return IsValidZone(GetNativeCell(1));
}

public int Native_IsEntityInZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iEntity = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return g_bIsInsideZone[iEntity][iZone];
}

public int Native_AssignZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	int iEntRef = EntIndexToEntRef(iZone);
	int iAssignedIndex = INVALID_ARRAY_INDEX;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || i == iClient) {
			continue;
		}
		
		if (g_alAssignedZones[i] == null) {
			continue;
		}
		
		iAssignedIndex = g_alAssignedZones[i].FindValue(iEntRef);
		
		if (iAssignedIndex == INVALID_ARRAY_INDEX) {
			continue;
		}
		
		ThrowNativeError(SP_ERROR_NATIVE, "This zone is already assigned to %N (%d)", iClient, iClient);
		return false;
	}
	
	if (g_alAssignedZones[iClient] == null) {
		g_alAssignedZones[iClient] = new ArrayList();
	}
	
	if (g_alAssignedZones[iClient].FindValue(iEntRef) == INVALID_ENT_INDEX) {
		g_alAssignedZones[iClient].Push(iEntRef);
		g_iZoningState[iClient][iZone] = ZONING_STATE_IDLE;
	}
	
	return true;
}

public int Native_UnAssignZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		return false;
	}
	
	if (g_alAssignedZones[iClient] == null) {
		return false;
	}
	
	int iEntRef = EntIndexToEntRef(iZone);
	int iArrayCell = g_alAssignedZones[iClient].FindValue(iEntRef);
	
	if (iArrayCell != INVALID_ARRAY_INDEX) {
		g_alAssignedZones[iClient].Erase(iArrayCell);
		g_iZoningState[iClient][iZone] = ZONING_STATE_NONE;
		
		if (!g_bEntitySpawned[iZone]) {
			DeleteZone(iZone);
		}
		
		return true;
	}
	
	if (g_alAssignedZones[iClient].Length < 1) {
		delete g_alAssignedZones[iClient];
	}
	
	return false;
}

public int Native_SetZoningState(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	int iZoningState = GetNativeCell(3);
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		return false;
	}
	
	int iEntRef = EntIndexToEntRef(iZone);
	int iAssignedIndex = INVALID_ARRAY_INDEX;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || i == iClient) {
			continue;
		}
		
		if (g_alAssignedZones[i] == null) {
			continue;
		}
		
		iAssignedIndex = g_alAssignedZones[i].FindValue(iEntRef);
		
		if (iAssignedIndex == INVALID_ARRAY_INDEX) {
			continue;
		}
		
		ThrowNativeError(SP_ERROR_NATIVE, "This zone is already assigned to %N (%d)", iClient, iClient);
		return false;
	}
	
	if (g_alAssignedZones[iClient] == null) {
		g_alAssignedZones[iClient] = new ArrayList();
	}
	
	if (g_alAssignedZones[iClient].FindValue(iEntRef) == INVALID_ENT_INDEX) {
		g_alAssignedZones[iClient].Push(iEntRef);
		g_iZoningState[iClient][iZone] = ZONING_STATE_IDLE;
	}
	
	if (iZoningState < ZONING_STATE_NONE || iZoningState > ZONING_STATE_DRAWING) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zoning state %d", iZoningState);
		return false;
	}
	
	g_iZoningState[iClient][iZone] = iZoningState;
	
	return g_iZoningState[iClient][iZone] == iZoningState;
}

public int Native_GetZoningState(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return ZONING_STATE_NONE;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsPlayerIndex(iClient)) {
		return ZONING_STATE_NONE;
	}
	
	if (!IsValidZone(iZone)) {
		return ZONING_STATE_NONE;
	}
	
	return g_iZoningState[iClient][iZone];
}

public int Native_GetAssignedZones(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(INVALID_HANDLE);
	}
	
	int iClient = GetNativeCell(1);
	
	if (!IsPlayerIndex(iClient)) {
		return view_as<int>(INVALID_HANDLE);
	}
	
	if (g_alAssignedZones[iClient] == null) {
		return view_as<int>(INVALID_HANDLE);
	}
	
	if (!g_alAssignedZones[iClient].Length) {
		delete g_alAssignedZones[iClient];
	}
	
	return view_as<int>(g_alAssignedZones[iClient]);
}

public int Native_GetZonePointsCount(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ARRAY_INDEX;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return INVALID_ARRAY_INDEX;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return INVALID_ARRAY_INDEX;
	}
	
	return g_alZonePoints[iZone].Length;
}

public int Native_GetZonePoints(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(INVALID_HANDLE);
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return view_as<int>(INVALID_HANDLE);
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return view_as<int>(INVALID_HANDLE);
	}
	
	return view_as<int>(g_alZonePoints[iZone]);
}

public int Native_GetZonePointHeight(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(-1.0);
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return view_as<int>(-1.0);
	}
	
	int iZoneType = GetZoneType(iZone);
	
	if (iZoneType != ZONE_TYPE_POLY && iZoneType != ZONE_TYPE_CIRCLE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon or a circle", iZone);
		return view_as<int>(-1.0);
	}
	
	return view_as<int>(g_fZoneHeight[iZone]);
}

public int Native_TeleportClientToZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsPlayerIndex(iClient) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return TeleportToZone(iClient, iZone);
}

public int Native_GetClientLookPoint(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	bool bBeam = view_as<bool>(GetNativeCell(2));
	
	if (!IsPlayerIndex(iClient) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	float vPoint[3]; GetClientLookPoint(iClient, vPoint, bBeam);
	return SetNativeArray(3, vPoint, 3) == SP_ERROR_NONE;
}

public int Native_GetZoneByName(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ENT_INDEX;
	}
	
	char szZone[MAX_ZONE_NAME_LENGTH]; GetNativeString(1, szZone, sizeof(szZone));
	
	return GetZoneByName(szZone);
}

public int Native_GetZoneName(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return SetNativeString(2, g_szZoneName[iZone], GetNativeCell(3)) == SP_ERROR_NONE;
}

public int Native_GetZoneStart(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return SetNativeArray(2, g_vZoneStart[iZone], 3) == SP_ERROR_NONE;
}

public int Native_GetZoneEnd(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	int iZoneType = GetZoneType(iZone);
	
	if (iZoneType != ZONE_TYPE_CUBE && iZoneType != ZONE_TYPE_TRIGGER) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a cube or a trigger", iZone);
		return false;
	}
	
	return SetNativeArray(2, g_vZoneEnd[iZone], 3) == SP_ERROR_NONE;
}

public int Native_GetZoneRadius(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(-1.0);
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return view_as<int>(-1.0);
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_CIRCLE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a circle", iZone);
		return view_as<int>(-1.0);
	}
	
	return view_as<int>(g_fZoneRadius[iZone]);
}

public int Native_GetZoneColor(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return SetNativeArray(2, g_iZoneColor[iZone], 3) == SP_ERROR_NONE;
}

public int Native_GetZoneDrawType(Handle hPlugin, int iNumParams)
{
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return g_iZoneDrawType[iZone];
}

public int Native_GetZoneList(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(INVALID_HANDLE);
	}
	
	return view_as<int>(g_alZoneEntities);
}

public int Native_GetZoneCount(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return 0;
	}
	
	if (g_alZoneEntities == null) {
		return 0;
	}
	
	return g_alZoneEntities.Length;
}

public int Native_IsZoneActive(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return g_bEntitySpawned[iZone];
}

public int Native_DeleteZone(Handle hPlugin, int iNumParams)
{
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return DeleteZone(iZone);
}

public int Native_GetZoneType(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ARRAY_INDEX;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return INVALID_ARRAY_INDEX;
	}
	
	return GetZoneType(iZone);
}

public int Native_GetZoneLowestCorner(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(-1.0);
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return view_as<int>(-1.0);
	}
	
	return view_as<int>(GetLowestCorner(iZone));
}

public int Native_GetZoneHighestCorner(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(-1.0);
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return view_as<int>(-1.0);
	}
	
	return view_as<int>(GetHighestCorner(iZone));
}

public int Native_GetZoneTeleportLocation(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	float vLocation[3];
	
	if (!GetZoneTeleportLocation(iZone, vLocation)) {
		return false;
	}
	
	return SetNativeArray(2, vLocation, 3) == SP_ERROR_NONE;
}

public int Native_IsVectorInsideZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float vOrigin[3]; GetNativeArray(2, vOrigin, 3);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	return IsVectorInsideZone(iZone, vOrigin);
}

public int Native_CreateZoneAdvanced(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ENT_INDEX;
	}
	
	int iZoneType = GetNativeCell(1);
	
	if (iZoneType == ZONE_TYPE_TRIGGER) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't hook an existing trigger using this native, use ZonesManager_RegisterTrigger and ZonesMananger_FinishZone instead.");
		return INVALID_ENT_INDEX;
	}
	
	char szName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, szName, sizeof(szName));
	float vStart[3]; GetNativeArray(3, vStart, 3);
	float vEnd[3]; GetNativeArray(4, vEnd, 3);
	float fRadius = view_as<float>(GetNativeCell(5));
	int iColor[4]; GetNativeArray(6, iColor, 4);
	int iDrawType = GetNativeCell(7);
	ArrayList alPoints = view_as<ArrayList>(GetNativeCell(8));
	float fHeight = view_as<float>(GetNativeCell(9));
	StringMap smEffects = view_as<StringMap>(GetNativeCell(10));
	
	int iZone = CreateZone(szName, iZoneType, vStart, vEnd, fRadius, iColor, iDrawType, alPoints, fHeight, smEffects);
	
	if (!IsValidZone(iZone)) {
		return INVALID_ENT_INDEX;
	}
	
	return iZone;
}

public int Native_CreateZoneFromKeyValuesString(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ENT_INDEX;
	}
	
	char szBuffer[MAX_ENTITY_LIMIT]; GetNativeString(1, szBuffer, sizeof(szBuffer));
	KeyValues kvZoneKV = new KeyValues("zones_manager");
	
	if (!kvZoneKV.ImportFromString(szBuffer)) {
		delete kvZoneKV;
		return INVALID_ENT_INDEX;
	}
	
	int iZoneType = -1;
	int iZone = SpawnAZoneFromKeyValues(kvZoneKV, iZoneType);
	
	if (!IsValidZone(iZone)) {
		if (iZoneType == ZONE_TYPE_TRIGGER) {
			if (g_alDelayedTriggerZones == null) {
				g_alDelayedTriggerZones = new ArrayList(ByteCountToCells(4096));
			}
			
			if (g_alDelayedTriggerZones.FindString(szBuffer) == INVALID_ARRAY_INDEX) {
				g_alDelayedTriggerZones.PushString(szBuffer);
			}
		}
		
		return INVALID_ENT_INDEX;
	}
	
	return iZone;
}

public int Native_StartZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ENT_INDEX;
	}
	
	int iZoneType = GetNativeCell(1);
	char szName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, szName, sizeof(szName));
	
	if (iZoneType < ZONE_TYPE_TRIGGER || iZoneType > ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone type %d", iZoneType);
		return INVALID_ENT_INDEX;
	}
	
	if (iZoneType == ZONE_TYPE_TRIGGER) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't hook an existing trigger using this native, use ZonesManager_RegisterTrigger and ZonesMananger_FinishZone instead.");
		return INVALID_ENT_INDEX;
	}
	
	if (!strlen(szName)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone name '%s'", szName);
		return INVALID_ENT_INDEX;
	}
	
	int iArrayIndex = INVALID_ARRAY_INDEX;
	int iZone = InitZone(iZoneType, iArrayIndex, INVALID_ENT_INDEX);
	
	if (!IsValidZone(iZone) || iArrayIndex == INVALID_ARRAY_INDEX) {
		return INVALID_ENT_INDEX;
	}
	
	if (iZoneType == ZONE_TYPE_POLY && g_alZonePoints[iZone] == null) {
		g_alZonePoints[iZone] = new ArrayList(3);
	}
	
	g_iZoneType[iZone] = iZoneType;
	g_szZoneName[iZone] = szName;
	return iZone;
}

public int Native_RegisterTrigger(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iTriggerIndex = GetNativeCell(1);
	char szName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, szName, sizeof(szName));
	
	if (!strlen(szName)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone name '%s'", szName);
		return false;
	}
	
	if (!IsValidEntity(iTriggerIndex) || iTriggerIndex <= MaxClients) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid trigger index %d", iTriggerIndex);
		return false;
	}
	
	char szClassName[64]; GetEntityClassname(iTriggerIndex, szClassName, sizeof(szClassName));
	
	if (StrContains(szClassName, "trigger_", false) == INVALID_ARRAY_INDEX) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can only register an existing trigger_* entity as a zone");
		return false;
	}
	
	int iArrayIndex = INVALID_ARRAY_INDEX;
	iTriggerIndex = InitZone(ZONE_TYPE_TRIGGER, iArrayIndex, iTriggerIndex);
	
	if (!IsValidZone(iTriggerIndex) || iArrayIndex == INVALID_ARRAY_INDEX) {
		return false;
	}
	
	GetEntPropVector(iTriggerIndex, Prop_Data, "m_vecMins", g_vZoneStart[iTriggerIndex]);
	GetEntPropVector(iTriggerIndex, Prop_Data, "m_vecMaxs", g_vZoneEnd[iTriggerIndex]);
	GetEntPropVector(iTriggerIndex, Prop_Data, "m_vecOrigin", g_vEntityOrigin[iTriggerIndex]);
	
	g_iZoneType[iTriggerIndex] = ZONE_TYPE_TRIGGER;
	g_szZoneName[iTriggerIndex] = szName;
	
	return true;
}

public int Native_SetZoneName(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	char szName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, szName, sizeof(szName));
	
	if (!strlen(szName)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone name '%s'", szName);
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	g_szZoneName[iZone] = szName;
	
	return true;
}

public int Native_SetZoneStart(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float vStart[3]; GetNativeArray(2, vStart, 3);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	int iZoneType = GetZoneType(iZone);
	
	if (iZoneType == ZONE_TYPE_TRIGGER) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't set the zone start on existing trigger_* entities");
		return INVALID_ENT_INDEX;
	}
	
	CopyArrayToArray(vStart, g_vZoneStart[iZone], 3);
	
	if (g_bEntitySpawned[iZone] && IsValidOrigin(vStart) && IsValidOrigin(g_vZoneEnd[iZone])) {
		InitCubeVector(iZone, vStart, g_vZoneEnd[iZone]);
	}
	
	return true;
}

public int Native_SetZoneEnd(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float vEnd[3]; GetNativeArray(2, vEnd, 3);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	int iZoneType = GetZoneType(iZone);
	
	if (iZoneType != ZONE_TYPE_CUBE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a cube", iZone);
		return false;
	}
	
	CopyArrayToArray(vEnd, g_vZoneEnd[iZone], 3);
	
	if (g_bEntitySpawned[iZone] && IsValidOrigin(vEnd) && IsValidOrigin(g_vZoneStart[iZone])) {
		InitCubeVector(iZone, g_vZoneStart[iZone], vEnd);
	}
	
	return true;
}

public int Native_SetZoneRadius(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float fRadius = view_as<float>(GetNativeCell(2));
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_CIRCLE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a circle", iZone);
		return false;
	}
	
	g_fZoneRadius[iZone] = fRadius;
	
	return true;
}

public int Native_SetZoneColor(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	int iColor[4]; GetNativeArray(2, iColor, 4);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	g_iZoneColor[iZone][0] = iColor[0];
	g_iZoneColor[iZone][1] = iColor[1];
	g_iZoneColor[iZone][2] = iColor[2];
	g_iZoneColor[iZone][3] = iColor[3];
	
	return true;
}

public int Native_SetZoneDrawType(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	int iDrawType = GetNativeCell(2);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	g_iZoneDrawType[iZone] = iDrawType;
	
	return true;
}

public int Native_SetZoneHeight(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float fHeight = view_as<float>(GetNativeCell(2));
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	int iZoneType = GetZoneType(iZone);
	
	if (iZoneType != ZONE_TYPE_POLY && iZoneType != ZONE_TYPE_CIRCLE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon or circle", iZone);
		return false;
	}
	
	g_fZoneHeight[iZone] = fHeight;
	
	return true;
}

public int Native_AddZonePoint(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float vPoint[3]; GetNativeArray(2, vPoint, 3);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return false;
	}
	
	if (!IsValidOrigin(g_vZoneStart[iZone])) {
		CopyArrayToArray(vPoint, g_vZoneStart[iZone], 3);
	}
	
	return AddZonePoint(g_alZonePoints[iZone], vPoint);
}

public int Native_AddMultipleZonePoints(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	ArrayList alPoints = view_as<ArrayList>(GetNativeCell(2));
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return false;
	}
	
	float vBuffer[3];
	int iAdded = 0;
	
	for (int i = 0; i < alPoints.Length; i++) {
		alPoints.GetArray(i, vBuffer);
		
		if (!IsValidOrigin(g_vZoneStart[iZone])) {
			CopyArrayToArray(vBuffer, g_vZoneStart[iZone], 3);
		}
		
		if (AddZonePoint(g_alZonePoints[iZone], vBuffer)) {
			iAdded++;
		}
	}
	
	return alPoints.Length == iAdded;
}

public int Native_RemoveZonePoint(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	float vPoint[3]; GetNativeArray(2, vPoint, 3);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return false;
	}
	
	return RemoveZonePoint(iZone, vPoint);
}

public int Native_RemoveLastZonePoint(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return false;
	}
	
	int iSize = g_alZonePoints[iZone].Length;
	
	if (!iSize) {
		return false;
	}
	
	float vPoint[3]; g_alZonePoints[iZone].GetArray(iSize - 1, vPoint);
	
	return RemoveZonePoint(iZone, vPoint);
}

public int Native_RemoveMultipleZonePoints(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	ArrayList alPoints = view_as<ArrayList>(GetNativeCell(2));
	
	if (alPoints == null) {
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid points array");
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return false;
	}
	
	float vBuffer[3];
	int iRemoved = 0;
	
	for (int i = 0; i < alPoints.Length; i++) {
		alPoints.GetArray(i, vBuffer);
		
		if (RemoveZonePoint(iZone, vBuffer)) {
			iRemoved++;
		}
	}
	
	return iRemoved == alPoints.Length;
}

public int Native_RemoveAllZonePoints(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (GetZoneType(iZone) != ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", iZone);
		return false;
	}
	
	g_alZonePoints[iZone].Clear();
	
	return true;
}

public int Native_AddZoneEffect(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	char szEffect[MAX_EFFECT_NAME_LENGTH]; GetNativeString(2, szEffect, sizeof(szEffect));
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (!g_bEntitySpawned[iZone]) {
		ThrowNativeError(SP_ERROR_NATIVE, "You must finish the zone before you can add effects");
		return false;
	}
	
	if (g_alEffectList.FindString(szEffect) == INVALID_ENT_INDEX) {
		ThrowNativeError(SP_ERROR_NATIVE, "The specified effect '%s' does not exist", szEffect);
		return false;
	}
	
	StringMap smKeys;
	
	if (!g_smEffectKeys.GetValue(szEffect, smKeys) || smKeys == null) {
		ThrowNativeError(SP_ERROR_NATIVE, "Unable to retrieve key for effect '%s'", szEffect);
		return false;
	}
	
	StringMap smValues;
	
	if (g_smZoneEffects[iZone].GetValue(szEffect, smValues) && smValues != null) {
		ThrowNativeError(SP_ERROR_NATIVE, "Effect '%s' already exists on zone %d", szEffect, iZone);
		return false;
	}
	
	return g_smZoneEffects[iZone].SetValue(szEffect, CloneHandle(smKeys));
}

public int Native_RemoveZoneEffect(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	char szEffect[MAX_EFFECT_NAME_LENGTH]; GetNativeString(2, szEffect, sizeof(szEffect));
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (!g_bEntitySpawned[iZone]) {
		ThrowNativeError(SP_ERROR_NATIVE, "You must finish the zone before you can remove effects");
		return false;
	}
	
	if (g_alEffectList.FindString(szEffect) == INVALID_ENT_INDEX) {
		ThrowNativeError(SP_ERROR_NATIVE, "The specified effect '%s' does not exist", szEffect);
		return false;
	}
	
	StringMap smValues;
	
	if (!g_smZoneEffects[iZone].GetValue(szEffect, smValues) || smValues == null) {
		ThrowNativeError(SP_ERROR_NATIVE, "Effect '%s' does not exist on zone %d", szEffect, iZone);
		return false;
	}
	
	delete smValues;
	return g_smZoneEffects[iZone].Remove(szEffect);
}

public int Native_GetZoneKeyValues(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return view_as<int>(INVALID_HANDLE);
	}
	
	int iZone = GetNativeCell(1);
	
	return view_as<int>(CreateZoneKeyValues(iZone));
}

public int Native_GetZoneKeyValuesAsString(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iZone = GetNativeCell(1);
	char szBuffer[MAX_ENTITY_LIMIT];
	
	if (!GetZoneKeyValuesAsString(iZone, szBuffer, sizeof(szBuffer))) {
		return false;
	}
	
	return SetNativeString(2, szBuffer, sizeof(szBuffer)) == SP_ERROR_NONE;
}

public int Native_FinishZone(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return INVALID_ENT_INDEX;
	}
	
	int iZone = GetNativeCell(1);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (!strlen(g_szZoneName[iZone])) {
		ThrowNativeError(SP_ERROR_NATIVE, "Name for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZoneType[iZone] == INVALID_ENT_INDEX) {
		ThrowNativeError(SP_ERROR_NATIVE, "Type for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (!IsValidOrigin(g_vZoneStart[iZone])) {
		ThrowNativeError(SP_ERROR_NATIVE, "Start point for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (!IsValidOrigin(g_vZoneEnd[iZone]) && (g_iZoneType[iZone] == ZONE_TYPE_CUBE || g_iZoneType[iZone] == ZONE_TYPE_TRIGGER)) {
		ThrowNativeError(SP_ERROR_NATIVE, "End point for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_fZoneRadius[iZone] == -1.0 && g_iZoneType[iZone] == ZONE_TYPE_CIRCLE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Radius for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZoneColor[iZone][0] == INVALID_ARRAY_INDEX || g_iZoneColor[iZone][1] == INVALID_ARRAY_INDEX || g_iZoneColor[iZone][2] == INVALID_ARRAY_INDEX || g_iZoneColor[iZone][3] == INVALID_ARRAY_INDEX) {
		ThrowNativeError(SP_ERROR_NATIVE, "Color (%d, %d, %d, %d) for zone %d is undefined or invalid", g_iZoneColor[iZone][0], g_iZoneColor[iZone][1], g_iZoneColor[iZone][2], g_iZoneColor[iZone][3], iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZoneDrawType[iZone] < ZONE_DRAW_HALF || g_iZoneDrawType[iZone] > ZONE_DRAW_NONE) {
		ThrowNativeError(SP_ERROR_NATIVE, "Draw Type for zone %d is undefined or invalid", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_alZonePoints[iZone] == null && g_iZoneType[iZone] == ZONE_TYPE_POLY) {
		ThrowNativeError(SP_ERROR_NATIVE, "Point list for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZoneType[iZone] == ZONE_TYPE_POLY && !g_alZonePoints[iZone].Length) {
		ThrowNativeError(SP_ERROR_NATIVE, "Point list for zone %d is empty", iZone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_fZoneHeight[iZone] == -1.0 && (g_iZoneType[iZone] == ZONE_TYPE_POLY || g_iZoneType[iZone] == ZONE_TYPE_CIRCLE)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Height for zone %d is undefined", iZone);
		return INVALID_ENT_INDEX;
	}
	
	return CreateZone(g_szZoneName[iZone], g_iZoneType[iZone], g_vZoneStart[iZone], g_vZoneEnd[iZone], g_fZoneRadius[iZone], g_iZoneColor[iZone], g_iZoneDrawType[iZone], g_alZonePoints[iZone], g_fZoneHeight[iZone], g_smZoneEffects[iZone], iZone);
}

public int Native_HideZoneFromClient(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	g_bHideZoneRender[iClient][iZone] = true;
	return true;
}

public int Native_UnHideZoneFromClient(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	g_bHideZoneRender[iClient][iZone] = false;
	return true;
}

public int Native_ForceZoneRenderingToClient(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	g_bForceZoneRender[iClient][iZone] = true;
	return true;
}

public int Native_UnForceZoneRenderingToClient(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iClient = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	if (!IsPlayerIndex(iClient)) {
		return false;
	}
	
	g_bForceZoneRender[iClient][iZone] = false;
	return true;
}

public int Native_Hook(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iEntity = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (IsValidZone(iEntity)) {
		return true;
	}
	
	if (!IsValidEntity(iEntity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Index %d is not a valid entity", iZone);
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iEntity);
		return false;
	}
	
	g_bEntityZoneHooked[iEntity][iZone] = true;
	return true;
}

public int Native_HookGlobal(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iEntity = GetNativeCell(1);
	
	if (IsValidZone(iEntity)) {
		return true;
	}
	
	if (!IsValidEntity(iEntity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Index %d is not a valid entity", iEntity);
		return false;
	}
	
	g_bEntityGlobalHooked[iEntity] = true;
	return true;
}

public int Native_UnHook(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iEntity = GetNativeCell(1);
	int iZone = GetNativeCell(2);
	
	if (IsValidZone(iEntity)) {
		return true;
	}
	
	if (!IsValidEntity(iEntity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Index %d is not a valid entity", iEntity);
		return false;
	}
	
	if (!IsValidZone(iZone)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", iZone);
		return false;
	}
	
	g_bEntityZoneHooked[iEntity][iZone] = false;
	return true;
}

public int Native_UnHookGlobal(Handle hPlugin, int iNumParams)
{
	if (!g_bMapStarted) {
		ThrowNativeError(SP_ERROR_NATIVE, "You can't call this before the map has started");
		return false;
	}
	
	int iEntity = GetNativeCell(1);
	
	if (IsValidZone(iEntity)) {
		return true;
	}
	
	if (!IsValidEntity(iEntity)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Index %d is not a valid entity", iEntity);
		return false;
	}
	
	g_bEntityGlobalHooked[iEntity] = false;
	return true;
} 