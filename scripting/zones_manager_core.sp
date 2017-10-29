 //Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines

#define PLUGIN_DESCRIPTION "A sourcemod plugin with rich features for dynamic zone development."
#define PLUGIN_VERSION "1.1.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

// Local Includes
#include <zones_manager>

//Forwards
Handle g_Forward_QueueEffects_Post;
Handle g_Forward_StartTouchZone;
Handle g_Forward_TouchZone;
Handle g_Forward_EndTouchZone;
Handle g_Forward_StartTouchZone_Post;
Handle g_Forward_TouchZone_Post;
Handle g_Forward_EndTouchZone_Post;

//Globals
bool bLate;
bool bShowAllZones[MAXPLAYERS + 1] =  { true, ... };
Handle g_hCookie_ShowZones;

//Engine related stuff for entities.
int iDefaultModelIndex;
int iDefaultHaloIndex;
char sErrorModel[] = "models/error.mdl";

//Entities Data
ArrayList g_hZoneEntities;
char g_sZone_Name[MAX_ENTITY_LIMIT][MAX_ZONE_NAME_LENGTH];
int g_iZone_Type[MAX_ENTITY_LIMIT];
float g_fZone_Start[MAX_ENTITY_LIMIT][3];
float g_fZone_End[MAX_ENTITY_LIMIT][3];
float g_fZoneRadius[MAX_ENTITY_LIMIT];
int g_iZoneColor[MAX_ENTITY_LIMIT][4];
StringMap g_hZoneEffects[MAX_ENTITY_LIMIT];
ArrayList g_hZonePointsData[MAX_ENTITY_LIMIT];
float g_fZoneHeight[MAX_ENTITY_LIMIT];
float g_fZonePointsDistance[MAX_ENTITY_LIMIT];
float g_fZonePointsMin[MAX_ENTITY_LIMIT][3];
float g_fZonePointsMax[MAX_ENTITY_LIMIT][3];
bool g_bZoneSpawned[MAX_ENTITY_LIMIT];
bool g_bIsZone[MAX_ENTITY_LIMIT];

//Not Box Type Zones Management
bool g_bIsInsideZone[MAX_ENTITY_LIMIT][MAX_ENTITY_LIMIT];
bool g_bIsInsideZone_Post[MAX_ENTITY_LIMIT][MAX_ENTITY_LIMIT];

//Effects Data
StringMap g_hTrie_EffectCalls;
StringMap g_hTrie_EffectKeys;
ArrayList g_hArray_EffectsList;

//Create Zones Data
ArrayList g_hClientZones[MAXPLAYERS + 1];

bool g_bHideZoneRender[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];

//Plugin Information
public Plugin myinfo = 
{
	name = "Zones-Manager-Core", 
	author = "Keith Warren (Drixevel), SM9", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("zones_manager");
	
	CreateNative("ZonesManager_RequestQueueEffects", Native_RequestQueueEffects);
	CreateNative("ZonesManager_ClearAllZones", Native_ClearAllZones);
	CreateNative("ZonesManager_IsEntityInZone", Native_IsEntityInZone);
	CreateNative("ZonesManager_AssignZone", Native_AssignZone);
	CreateNative("ZonesManager_UnAssignZone", Native_UnAssignZone);
	CreateNative("ZonesManager_HideZoneFromClient", Native_HideZoneFromClient);
	CreateNative("ZonesManager_UnHideZoneFromClient", Native_UnHideZoneFromClient);
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
	CreateNative("ZonesManager_IsVectorInsideZone", Native_IsVectorInsideZone);
	CreateNative("ZonesManager_TeleportClientToZone", Native_TeleportClientToZone);
	CreateNative("ZonesManager_GetClientLookPoint", Native_GetClientLookPoint);
	CreateNative("ZonesManager_RegisterEffect", Native_RegisterEffect);
	CreateNative("ZonesManager_RegisterEffectKey", Native_RegisterEffectKey);
	CreateNative("ZonesManager_CreateZoneAdvanced", Native_CreateZoneAdvanced);
	CreateNative("ZonesManager_CreateZoneFromKeyValuesString", Native_CreateZoneFromKeyValuesString);
	CreateNative("ZonesManager_StartZone", Native_StartZone);
	CreateNative("ZonesManager_SetZoneName", Native_SetZoneName);
	CreateNative("ZonesManager_SetZoneStart", Native_SetZoneStart);
	CreateNative("ZonesManager_SetZoneEnd", Native_SetZoneEnd);
	CreateNative("ZonesManager_SetZoneRadius", Native_SetZoneRadius);
	CreateNative("ZonesManager_SetZoneColor", Native_SetZoneColor);
	CreateNative("ZonesManager_SetZoneHeight", Native_SetZoneHeight);
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
	
	g_Forward_QueueEffects_Post = CreateGlobalForward("ZonesManager_OnQueueEffects_Post", ET_Ignore);
	g_Forward_StartTouchZone = CreateGlobalForward("ZonesManager_OnStartTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_Forward_TouchZone = CreateGlobalForward("ZonesManager_OnTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_Forward_EndTouchZone = CreateGlobalForward("ZonesManager_OnEndTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_Forward_StartTouchZone_Post = CreateGlobalForward("ZonesManager_OnStartTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_Forward_TouchZone_Post = CreateGlobalForward("ZonesManager_OnTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_Forward_EndTouchZone_Post = CreateGlobalForward("ZonesManager_OnEndTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hZoneEntities = CreateArray();
	
	g_hTrie_EffectCalls = CreateTrie();
	g_hTrie_EffectKeys = CreateTrie();
	g_hArray_EffectsList = CreateArray(ByteCountToCells(MAX_EFFECT_NAME_LENGTH));
	
	g_hCookie_ShowZones = RegClientCookie("zones_manager_show_zones", "Show zones that are configured correctly to clients.", CookieAccess_Public);
	
	CreateTimer(0.1, Timer_DisplayZones, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	iDefaultModelIndex = PrecacheModel(DEFAULT_MODELINDEX);
	iDefaultHaloIndex = PrecacheModel(DEFAULT_HALOINDEX);
	PrecacheModel(sErrorModel);
	
	LogDebug("zonesmanager", "Deleting current zones map configuration from memory.");
	
	for (int x = 1; x < MAX_ENTITY_LIMIT; x++)
	{
		ResetZoneVariables(x);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= MaxClients)
	{
		return;
	}
	
	ResetZoneVariables(entity);
}

public void OnEntityDestroyed(int entity)
{
	if (entity <= MaxClients)
	{
		return;
	}
	
	ResetZoneVariables(entity);
}

public void OnMapEnd()
{
	ClearAllZones();
	
	for (int x = 1; x < MAX_ENTITY_LIMIT; x++)
	{
		ResetZoneVariables(x);
	}
}

public void OnConfigsExecuted()
{
	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				OnClientConnected(i);
			}
			
			if (AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}
		
		bLate = false;
	}
}

public void OnAllPluginsLoaded()
{
	QueueEffects();
}

void QueueEffects(bool reset = true)
{
	if (reset)
	{
		for (int i = 0; i < GetArraySize(g_hArray_EffectsList); i++)
		{
			char sEffect[MAX_EFFECT_NAME_LENGTH];
			GetArrayString(g_hArray_EffectsList, i, sEffect, sizeof(sEffect));
			
			Handle callbacks[MAX_EFFECT_CALLBACKS];
			GetTrieArray(g_hTrie_EffectCalls, sEffect, callbacks, sizeof(callbacks));
			
			for (int x = 0; x < MAX_EFFECT_CALLBACKS; x++)
			{
				delete callbacks[x];
			}
		}
		
		ClearTrie(g_hTrie_EffectCalls);
		ClearArray(g_hArray_EffectsList);
	}
	
	Call_StartForward(g_Forward_QueueEffects_Post);
	Call_Finish();
}

public void OnPluginEnd()
{
	ClearAllZones();
}

public void OnClientConnected(int client)
{
	bShowAllZones[client] = true;
}

public void OnClientCookiesCached(int client)
{
	char sValue[12];
	GetClientCookie(client, g_hCookie_ShowZones, sValue, sizeof(sValue));
	
	if (strlen(sValue) == 0)
	{
		bShowAllZones[client] = true;
		SetClientCookie(client, g_hCookie_ShowZones, "1");
	}
	else
	{
		bShowAllZones[client] = StringToBool(sValue);
	}
}

public void OnClientPutInServer(int client)
{
	for (int i = 1; i < MAX_ENTITY_LIMIT; i++)
	{
		g_bIsInsideZone[client][i] = false;
		g_bIsInsideZone_Post[client][i] = false;
	}
	
	ResetCreateZoneVariables(client);
}

public void OnClientDisconnect(int client)
{
	for (int i = 1; i < MAX_ENTITY_LIMIT; i++)
	{
		g_bIsInsideZone[client][i] = false;
		g_bIsInsideZone_Post[client][i] = false;
		g_bHideZoneRender[client][i] = false;
	}
	
	ResetCreateZoneVariables(client);
}

void ClearAllZones()
{
	for (int i = 0; i < GetArraySize(g_hZoneEntities); i++)
	{
		int zone = EntRefToEntIndex(GetArrayCell(g_hZoneEntities, i));
		
		if (IsValidEntity(zone))
		{
			delete g_hZoneEffects[zone];
			AcceptEntityInput(zone, "Kill");
		}
	}
	
	ClearArray(g_hZoneEntities);
}

int SpawnAZoneFromKeyValues(KeyValues kv)
{
	if (kv == null)
	{
		return INVALID_ENT_INDEX;
	}
	
	KvRewind(kv);
	KvGotoFirstSubKey(kv);
	
	char name[MAX_ZONE_NAME_LENGTH]; KvGetSectionName(kv, name, sizeof(name));
	
	KvRewind(kv);
	
	if (!KvJumpToKey(kv, name))
	{
		LogError("Could not jump to key %s", name);
		delete kv;
		return INVALID_ENT_INDEX;
	}
	
	char sType[MAX_ZONE_TYPE_LENGTH];
	KvGetString(kv, "type", sType, sizeof(sType));
	int type = GetZoneNameType(sType);
	
	float vStartPosition[3];
	KvGetVector(kv, "start", vStartPosition);
	
	float vEndPosition[3];
	KvGetVector(kv, "end", vEndPosition);
	
	float fRadius = KvGetFloat(kv, "radius");
	
	int iColor[4] =  { 0, 255, 255, 255 };
	KvGetColor(kv, "color", iColor[0], iColor[1], iColor[2], iColor[3]);
	
	float height = KvGetFloat(kv, "height", 0.0);
	
	ArrayList points = CreateArray(3);
	
	if (KvJumpToKey(kv, "points"))
	{
		KvGotoFirstSubKey(kv, false);
		float coordinates[3];
		
		do
		{
			KvGetVector(kv, NULL_STRING, coordinates);
			AddZonePoint(points, coordinates);
		}
		while (KvGotoNextKey(kv, false));
		
		KvGoBack(kv);
	}
	
	StringMap effects = CreateTrie();
	if (KvJumpToKey(kv, "effects") && KvGotoFirstSubKey(kv))
	{
		char sKey[256];
		char sValue[256];
		char sEffect[256];
		StringMap effect_data;
		
		do
		{
			KvGetSectionName(kv, sEffect, sizeof(sEffect));
			
			effect_data = CreateTrie();
			
			if (KvGotoFirstSubKey(kv, false))
			{
				do
				{
					KvGetSectionName(kv, sKey, sizeof(sKey));
					KvGetString(kv, NULL_STRING, sValue, sizeof(sValue));
					
					SetTrieString(effect_data, sKey, sValue);
				}
				while (KvGotoNextKey(kv, false));
				
				KvGoBack(kv);
			}
			
			SetTrieValue(effects, sEffect, effect_data);
		}
		while (KvGotoNextKey(kv));
		
		KvGoBack(kv);
		KvGoBack(kv);
	}
	
	delete kv;
	
	return CreateZone(name, type, vStartPosition, vEndPosition, fRadius, iColor, points, height, effects);
}

public void OnGameFrame()
{
	int zone;
	float vecOrigin[3];
	Action action;
	
	int zonetype;
	
	for (int entity = 1; entity < MAX_ENTITY_LIMIT; entity++)
	{
		if (!IsValidEntity(entity))
		{
			continue;
		}
		
		if (entity <= MaxClients && entity > 0)
		{
			if (!IsClientInGame(entity))
			{
				continue;
			}
			
			if (!IsPlayerAlive(entity))
			{
				continue;
			}
			
			GetClientAbsOrigin(entity, vecOrigin);
		}
		
		else
		{
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecOrigin);
		}
		
		for (int i = 0; i < GetArraySize(g_hZoneEntities); i++)
		{
			zone = EntRefToEntIndex(GetArrayCell(g_hZoneEntities, i));
			
			if (!IsValidZone(zone))
			{
				g_hZoneEntities.Erase(i);
				continue;
			}
			
			if (zone == entity)
			{
				continue;
			}
			
			zonetype = GetZoneType(zone);
			
			if (!IsVectorInsideZone(zone, vecOrigin))
			{
				action = IsNotNearExternalZone(entity, zone, zonetype);
				
				if (action <= Plugin_Changed)
				{
					IsNotNearExternalZone_Post(entity, zone, zonetype);
				}
				
				continue;
			}
			
			action = IsNearExternalZone(entity, zone, zonetype);
			
			if (action <= Plugin_Changed)
			{
				IsNearExternalZone_Post(entity, zone, zonetype);
			}
		}
	}
}

void ResetCreateZoneVariables(int client)
{
	int zone = INVALID_ENT_INDEX;
	
	if (g_hClientZones[client] != null)
	{
		for (int i = 0; i < GetArraySize(g_hClientZones[client]); i++)
		{
			zone = GetArrayCell(g_hClientZones[client], i);
			
			if (zone == INVALID_ENT_REFERENCE)
			{
				continue;
			}
			
			zone = EntRefToEntIndex(zone);
			
			if(!IsValidZone(zone)) 
			{
				continue;
			}
			
			if(g_bZoneSpawned[zone]) 
			{
				continue;
			}
			
			AcceptEntityInput(zone, "Kill");
		}
		
		delete g_hClientZones[client];
	}
	
	g_hClientZones[client] = null;
}

void ResetZoneVariables(int zone)
{
	for (int i = 1; i < MAX_ENTITY_LIMIT; i++)
	{
		g_bIsInsideZone[zone][i] = false;
		g_bIsInsideZone[i][zone] = false;
		
		g_bIsInsideZone_Post[zone][i] = false;
		g_bIsInsideZone_Post[i][zone] = false;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bHideZoneRender[i][zone] = false;
		
		if(g_hClientZones[i] != null) 
		{
			int arraycell = FindValueInArray(g_hClientZones[i], EntIndexToEntRef(zone));
			
			if(arraycell != -1)
			{
				g_hClientZones[i].Erase(arraycell);
			}
		}
	}
	
	g_sZone_Name[zone][0] = '\0';
	g_iZone_Type[zone] = INVALID_ENT_INDEX;
	
	Array_Fill(g_fZone_Start[zone], 3, -1.0);
	Array_Fill(g_fZone_End[zone], 3, -1.0);
	
	g_fZoneRadius[zone] = -1.0;
	g_iZoneColor[zone][0] = INVALID_ENT_INDEX;
	g_iZoneColor[zone][1] = INVALID_ENT_INDEX;
	g_iZoneColor[zone][2] = INVALID_ENT_INDEX;
	g_iZoneColor[zone][3] = INVALID_ENT_INDEX;
	
	if (g_hZoneEffects[zone] != null)
	{
		if (IsValidHandle(g_hZoneEffects[zone]))
		{
			delete g_hZoneEffects[zone];
		}
		
		g_hZoneEffects[zone] = null;
	}
	
	if (g_hZonePointsData[zone] != null)
	{
		if (IsValidHandle(g_hZonePointsData[zone]))
		{
			delete g_hZonePointsData[zone];
		}
		
		g_hZonePointsData[zone] = null;
	}
	
	g_fZoneHeight[zone] = -1.0;
	g_fZonePointsDistance[zone] = -1.0;
	
	Array_Fill(g_fZonePointsMin[zone], 3, -1.0);
	Array_Fill(g_fZonePointsMax[zone], 3, -1.0);
	
	g_bIsZone[zone] = false;
	g_bZoneSpawned[zone] = false;
	g_iZone_Type[zone] = INVALID_ENT_INDEX;
}

void GetZoneTypeName(int type, char[] buffer, int size)
{
	switch (type)
	{
		case ZONE_TYPE_BOX:strcopy(buffer, size, "Standard");
		case ZONE_TYPE_CIRCLE:strcopy(buffer, size, "Radius/Circle");
		case ZONE_TYPE_POLY:strcopy(buffer, size, "Polygons");
	}
}

int GetZoneType(int entity)
{
	char sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	
	if (StrEqual(sClassname, "trigger_multiple"))
	{
		return ZONE_TYPE_BOX;
	}
	else if (StrEqual(sClassname, "info_target"))
	{
		return g_hZonePointsData[entity] != null ? ZONE_TYPE_POLY : ZONE_TYPE_CIRCLE;
	}
	
	return ZONE_TYPE_BOX;
}

int GetZoneNameType(const char[] sType)
{
	if (StrEqual(sType, "Standard"))
	{
		return ZONE_TYPE_BOX;
	}
	else if (StrEqual(sType, "Radius/Circle"))
	{
		return ZONE_TYPE_CIRCLE;
	}
	else if (StrEqual(sType, "Polygons"))
	{
		return ZONE_TYPE_POLY;
	}
	
	return ZONE_TYPE_BOX;
}

public Action Timer_DisplayZones(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowZones(i, 0.2);
		}
	}
}

void ShowZones(int client, float fTime = 0.1)
{
	float coordinates[3];
	float nextpoint[3];
	
	float vecStart[3];
	float vecEnd[3];
	
	float coordinates_expanded[3];
	float nextpoint_expanded[3];
	
	int index;
	int entref = INVALID_ENT_REFERENCE;
	int zone = INVALID_ENT_INDEX;
	
	int color[4] =  { 255, 0, 0, 255 };
	
	int looped = 0;
	
	if (g_hClientZones[client] != null)
	{
		for (int i = 0; i < GetArraySize(g_hClientZones[client]); i++)
		{
			entref = GetArrayCell(g_hClientZones[client], i);
			
			if (entref == INVALID_ENT_REFERENCE)
			{
				g_hClientZones[client].Erase(i);
				continue;
			}
			
			zone = EntRefToEntIndex(entref);
			
			if (!IsValidZone(zone))
			{
				g_hClientZones[client].Erase(i);
				continue;
			}
			
			if (g_bHideZoneRender[client][zone])
			{
				continue;
			}
			
			switch (GetZoneType(zone))
			{
				case ZONE_TYPE_BOX:
				{
					GetAbsBoundingBox(zone, vecStart, vecEnd);
					Effect_DrawBeamBoxToClient(client, vecStart, vecEnd, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.7, 2, 0.0, color, 0);
				}
				
				case ZONE_TYPE_CIRCLE:
				{
					TE_SetupBeamRingPoint(g_fZone_Start[zone], g_fZoneRadius[zone], g_fZoneRadius[zone] + 0.1, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.0, color, 0, 0);
					TE_SendToClient(client);
					
					CopyArrayToArray(g_fZone_Start[zone], coordinates_expanded, 3);
					coordinates_expanded[2] += g_fZoneHeight[zone];
					
					TE_SetupBeamRingPoint(coordinates_expanded, g_fZoneRadius[zone], g_fZoneRadius[zone] + 0.1, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.0, color, 0, 0);
					TE_SendToClient(client);
				}
				
				case ZONE_TYPE_POLY:
				{
					
					if(g_hZonePointsData[zone] == null) 
					{
						continue;
					}
					
					for (int y = 0; y < GetArraySize(g_hZonePointsData[zone]); y++)
					{
						GetArrayArray(g_hZonePointsData[zone], y, coordinates, sizeof(coordinates));
						
						if(y + 1 >= GetArraySize(g_hZonePointsData[zone]))
						{
							index = 0;
						}
						else
						{
							index = y + 1;
						}
						
						GetArrayArray(g_hZonePointsData[zone], index, nextpoint, sizeof(nextpoint));
						
						CopyArrayToArray(coordinates, coordinates_expanded, 3);
						coordinates_expanded[2] += g_fZoneHeight[zone];
						
						CopyArrayToArray(nextpoint, nextpoint_expanded, 3);
						nextpoint_expanded[2] += g_fZoneHeight[zone];
						
						TE_SetupBeamPoints(coordinates, nextpoint, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.7, 2, 0.0, color, 0);
						TE_SendToClient(client);
						
						TE_SetupBeamPoints(coordinates_expanded, nextpoint_expanded, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.7, 2, 0.0, color, 0);
						TE_SendToClient(client);
					}
				}
			}
			
			looped++;
		}
	}
	
	if(looped <= 0) 
	{
		if(g_hClientZones[client] != null) {
			delete g_hClientZones[client];
		}
	}
	
	bool skip = false;
	
	if (bShowAllZones[client])
	{
		for (int x = 0; x < GetArraySize(g_hZoneEntities); x++)
		{
			entref = GetArrayCell(g_hZoneEntities, x);
			
			if (entref == INVALID_ENT_REFERENCE)
			{
				g_hZoneEntities.Erase(x);
				continue;
			}
			
			zone = EntRefToEntIndex(entref);
			
			if (!IsValidZone(zone))
			{
				g_hZoneEntities.Erase(x);
				continue;
			}
			
			skip = false;
			
			if (g_hClientZones[client] != null)
			{
				skip = false;
				
				for (int y = 0; y < GetArraySize(g_hClientZones[client]); y++)
				{
					if(entref == GetArrayCell(g_hClientZones[client], y)) {
						skip = true;
						break;
					}
				}
			}
			
			if(skip) 
			{
				continue;
			}
			
			if (g_bHideZoneRender[client][zone])
			{
				continue;
			}
			
			if (g_bZoneSpawned[zone])
			{
				color[0] = g_iZoneColor[zone][0];
				color[1] = g_iZoneColor[zone][1];
				color[2] = g_iZoneColor[zone][2];
				color[3] = g_iZoneColor[zone][3];
			}
			
			switch (GetZoneType(zone))
			{
				case ZONE_TYPE_BOX:
				{
					GetAbsBoundingBox(zone, vecStart, vecEnd);
					Effect_DrawBeamBoxToClient(client, vecStart, vecEnd, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.7, 2, 0.0, color, 0);
				}
				
				case ZONE_TYPE_CIRCLE:
				{
					TE_SetupBeamRingPoint(g_fZone_Start[zone], g_fZoneRadius[zone], g_fZoneRadius[zone] + 0.1, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.0, color, 0, 0);
					TE_SendToClient(client);
				}
				
				case ZONE_TYPE_POLY:
				{
					if(g_hZonePointsData[zone] == null) 
					{
						continue;
					}
					
					for (int y = 0; y < GetArraySize(g_hZonePointsData[zone]); y++)
					{
						GetArrayArray(g_hZonePointsData[zone], y, coordinates, sizeof(coordinates));
						
						if(y + 1 >= GetArraySize(g_hZonePointsData[zone]))
						{
							index = 0;
						}
						else
						{
							index = y + 1;
						}
						
						GetArrayArray(g_hZonePointsData[zone], index, nextpoint, sizeof(nextpoint));
						
						TE_SetupBeamPoints(coordinates, nextpoint, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, fTime, 0.7, 0.7, 2, 0.0, color, 10);
						TE_SendToClient(client);
					}
				}
			}
		}
	}
}

void GetAbsBoundingBox(int ent, float mins[3], float maxs[3])
{
	float origin[3];
	
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
	GetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);
	
	mins[0] += origin[0];
	mins[1] += origin[1];
	mins[2] += origin[2];
	
	maxs[0] += origin[0];
	maxs[1] += origin[1];
	maxs[2] += origin[2];
}

int InitZone(int type, int & arraycell)
{
	int zone = CreateEntityByName(type == ZONE_TYPE_BOX ? "trigger_multiple" : "info_target");
	g_bIsZone[zone] = true;
	
	if (!IsValidEntity(zone))
	{
		return INVALID_ENT_INDEX;
	}
	
	int pos = FindValueInArray(g_hZoneEntities, EntIndexToEntRef(zone));
	
	if (pos != -1)
	{
		return zone;
	}
	
	g_bZoneSpawned[zone] = false;
	SDKHook(zone, SDKHook_Spawn, Zone_Spawned);
	
	arraycell = PushArrayCell(g_hZoneEntities, EntIndexToEntRef(zone));
	
	return zone;
}

bool IsValidZone(int zone)
{
	if (zone <= 0)
	{
		return false;
	}
	
	if (!IsValidEntity(zone))
	{
		return false;
	}
	
	return g_bIsZone[zone];
}

int CreateZone(const char[] sName, int type, float start[3], float end[3], float radius, int color[4], ArrayList points = null, float height = 0.0, StringMap effects = null, int entity = -1)
{
	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneTypeName(type, sType, sizeof(sType));
	
	LogDebug("zonesmanager", "Spawning Zone: %s - %s - %.2f/%.2f/%.2f - %.2f/%.2f/%.2f - %.2f", sName, sType, start[0], start[1], start[2], end[0], end[1], end[2], radius);
	
	if (!IsValidEntity(entity))
	{
		int arraycell;
		entity = InitZone(type, arraycell);
	}
	
	if (entity == -1)
	{
		return INVALID_ENT_INDEX;
	}
	
	if (!g_bZoneSpawned[entity])
	{
		DispatchKeyValue(entity, "targetname", sName);
		
		switch (type)
		{
			case ZONE_TYPE_BOX:
			{
				DispatchKeyValue(entity, "spawnflags", "257");
			}
			
			case ZONE_TYPE_CIRCLE, ZONE_TYPE_POLY:
			{
				DispatchKeyValueVector(entity, "origin", start);
			}
		}
		
		if (!DispatchSpawn(entity))
		{
			AcceptEntityInput(entity, "Kill");
			return INVALID_ENT_INDEX;
		}
	}
	
	switch (type)
	{
		case ZONE_TYPE_BOX:
		{
			SetEntProp(entity, Prop_Data, "m_spawnflags", 257);
			SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
			
			int fx = GetEntProp(entity, Prop_Send, "m_fEffects");
			fx |= 0x020;
			
			SetEntProp(entity, Prop_Send, "m_fEffects", fx);
			
			SetEntityModel(entity, sErrorModel);
			
			float fMiddle[3];
			GetMiddleOfABox(start, end, fMiddle);
			
			TeleportEntity(entity, fMiddle, NULL_VECTOR, NULL_VECTOR);
			
			// Have the mins always be negative
			start[0] = start[0] - fMiddle[0];
			if (start[0] > 0.0)
				start[0] *= -1.0;
			start[1] = start[1] - fMiddle[1];
			if (start[1] > 0.0)
				start[1] *= -1.0;
			start[2] = start[2] - fMiddle[2];
			if (start[2] > 0.0)
				start[2] *= -1.0;
			
			// And the maxs always be positive
			end[0] = end[0] - fMiddle[0];
			if (end[0] < 0.0)
				end[0] *= -1.0;
			end[1] = end[1] - fMiddle[1];
			if (end[1] < 0.0)
				end[1] *= -1.0;
			end[2] = end[2] - fMiddle[2];
			if (end[2] < 0.0)
				end[2] *= -1.0;
			
			SetEntPropVector(entity, Prop_Data, "m_vecMins", start);
			SetEntPropVector(entity, Prop_Data, "m_vecMaxs", end);
			
			SDKHook(entity, SDKHook_StartTouchPost, Zones_StartTouch);
			SDKHook(entity, SDKHook_TouchPost, Zones_Touch);
			SDKHook(entity, SDKHook_EndTouchPost, Zones_EndTouch);
			SDKHook(entity, SDKHook_StartTouchPost, Zones_StartTouchPost);
			SDKHook(entity, SDKHook_TouchPost, Zones_TouchPost);
			SDKHook(entity, SDKHook_EndTouchPost, Zones_EndTouchPost);
		}
		case ZONE_TYPE_POLY:
		{
			g_hZonePointsData[entity] = points != null ? view_as<ArrayList>(CloneHandle(points)) : CreateArray(3);
			
			float tempMin[3];
			float tempMax[3];
			float greatdiff;
			
			for (int i = 0; i < GetArraySize(g_hZonePointsData[entity]); i++)
			{
				float coordinates[3];
				GetArrayArray(g_hZonePointsData[entity], i, coordinates, sizeof(coordinates));
				
				for (int j = 0; j < 3; j++)
				{
					if (tempMin[j] == 0.0 || tempMin[j] > coordinates[j])
					{
						tempMin[j] = coordinates[j];
					}
					if (tempMax[j] == 0.0 || tempMax[j] < coordinates[j])
					{
						tempMax[j] = coordinates[j];
					}
				}
				
				float coordinates2[3];
				GetArrayArray(g_hZonePointsData[entity], 0, coordinates2, sizeof(coordinates2));
				
				float diff = CalculateHorizontalDistance(coordinates2, coordinates, false);
				if (diff > greatdiff)
				{
					greatdiff = diff;
				}
			}
			
			for (int y = 0; y < 3; y++)
			{
				g_fZonePointsMin[entity][y] = tempMin[y];
				g_fZonePointsMax[entity][y] = tempMax[y];
			}
			
			g_fZonePointsDistance[entity] = greatdiff;
		}
	}
	
	delete g_hZoneEffects[entity];
	g_hZoneEffects[entity] = effects != null ? view_as<StringMap>(CloneHandle(effects)) : CreateTrie();
	
	strcopy(g_sZone_Name[entity], MAX_ZONE_NAME_LENGTH, sName);
	g_iZone_Type[entity] = type;
	CopyArrayToArray(start, g_fZone_Start[entity], 3);
	CopyArrayToArray(end, g_fZone_End[entity], 3);
	g_fZoneRadius[entity] = radius;
	g_iZoneColor[entity] = color;
	g_fZoneHeight[entity] = height;
	
	LogDebug("zonesmanager", "Zone %s has been spawned %s as a %s zone with the entity index %i.", sName, IsValidEntity(entity) ? "successfully" : "not successfully", sType, entity);
	
	delete points;
	delete effects;
	return entity;
}

Action IsNearExternalZone(int entity, int zone, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Action result = Plugin_Continue;
	
	if (!g_bIsInsideZone[entity][zone])
	{
		g_bIsInsideZone[entity][zone] = true;
		
		Call_StartForward(g_Forward_StartTouchZone);
		Call_PushCell(entity);
		Call_PushCell(zone);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish(result);
	}
	else
	{
		Call_StartForward(g_Forward_TouchZone);
		Call_PushCell(entity);
		Call_PushCell(zone);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish(result);
	}
	
	return result;
}

Action IsNotNearExternalZone(int entity, int zone, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Action result = Plugin_Continue;
	
	if (g_bIsInsideZone[entity][zone])
	{
		g_bIsInsideZone[entity][zone] = false;
		
		Call_StartForward(g_Forward_EndTouchZone);
		Call_PushCell(entity);
		Call_PushCell(zone);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish(result);
	}
	
	return result;
}

void IsNearExternalZone_Post(int entity, int zone, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	if (!g_bIsInsideZone_Post[entity][zone])
	{
		g_bIsInsideZone_Post[entity][zone] = true;
		g_bIsInsideZone[entity][zone] = true;
		
		CallEffectCallback(zone, entity, EFFECT_CALLBACK_ONENTERZONE);
		
		Call_StartForward(g_Forward_StartTouchZone_Post);
		Call_PushCell(entity);
		Call_PushCell(zone);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish();
	}
	else
	{
		CallEffectCallback(zone, entity, EFFECT_CALLBACK_ONACTIVEZONE);
		
		Call_StartForward(g_Forward_TouchZone_Post);
		Call_PushCell(entity);
		Call_PushCell(zone);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish();
	}
}

void IsNotNearExternalZone_Post(int entity, int zone, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
	
	if (g_bIsInsideZone_Post[entity][zone])
	{
		g_bIsInsideZone_Post[entity][zone] = false;
		g_bIsInsideZone[entity][zone] = false;
		
		CallEffectCallback(zone, entity, EFFECT_CALLBACK_ONLEAVEZONE);
		
		Call_StartForward(g_Forward_EndTouchZone_Post);
		Call_PushCell(entity);
		Call_PushCell(zone);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish();
	}
}

public Action Zone_Spawned(int entity)
{
	g_bZoneSpawned[entity] = true;
}

public Action Zones_StartTouch(int zone, int entity)
{
	g_bIsInsideZone[entity][zone] = true;
	
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Call_StartForward(g_Forward_StartTouchZone);
	Call_PushCell(entity);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(ZONE_TYPE_BOX);
	
	Action result = Plugin_Continue;
	Call_Finish(result);
	
	return result;
}

public Action Zones_Touch(int zone, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Call_StartForward(g_Forward_TouchZone);
	Call_PushCell(entity);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(ZONE_TYPE_BOX);
	
	Action result = Plugin_Continue;
	Call_Finish(result);
	
	return result;
}

public Action Zones_EndTouch(int zone, int entity)
{
	g_bIsInsideZone[entity][zone] = false;
	
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Call_StartForward(g_Forward_EndTouchZone);
	Call_PushCell(entity);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(ZONE_TYPE_BOX);
	
	Action result = Plugin_Continue;
	Call_Finish(result);
	
	return result;
}

public void Zones_StartTouchPost(int zone, int entity)
{
	CallEffectCallback(zone, entity, EFFECT_CALLBACK_ONENTERZONE);
	
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Call_StartForward(g_Forward_StartTouchZone_Post);
	Call_PushCell(entity);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(ZONE_TYPE_BOX);
	Call_Finish();
}

public void Zones_TouchPost(int zone, int entity)
{
	CallEffectCallback(zone, entity, EFFECT_CALLBACK_ONACTIVEZONE);
	
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Call_StartForward(g_Forward_TouchZone_Post);
	Call_PushCell(entity);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(ZONE_TYPE_BOX);
	Call_Finish();
}

public void Zones_EndTouchPost(int zone, int entity)
{
	CallEffectCallback(zone, entity, EFFECT_CALLBACK_ONLEAVEZONE);
	
	char sName[MAX_ZONE_NAME_LENGTH];
	GetEntPropString(zone, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Call_StartForward(g_Forward_EndTouchZone_Post);
	Call_PushCell(entity);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(ZONE_TYPE_BOX);
	Call_Finish();
}

void CallEffectCallback(int zone, int entity, int callback)
{
	if (g_hArray_EffectsList == null)
	{
		g_hArray_EffectsList = CreateArray(ByteCountToCells(MAX_EFFECT_NAME_LENGTH));
		return;
	}
	
	if (g_hTrie_EffectCalls == null)
	{
		g_hTrie_EffectCalls = CreateTrie();
		return;
	}
	
	if (g_hZoneEffects[zone] == null)
	{
		g_hZoneEffects[zone] = CreateTrie();
		return;
	}
	
	for (int i = 0; i < GetArraySize(g_hArray_EffectsList); i++)
	{
		char sEffect[MAX_EFFECT_NAME_LENGTH];
		GetArrayString(g_hArray_EffectsList, i, sEffect, sizeof(sEffect));
		
		Handle callbacks[MAX_EFFECT_CALLBACKS]; StringMap values;
		
		if (GetTrieArray(g_hTrie_EffectCalls, sEffect, callbacks, sizeof(callbacks)) && callbacks[callback] != null && GetForwardFunctionCount(callbacks[callback]) > 0 && GetTrieValue(g_hZoneEffects[zone], sEffect, values))
		{
			Call_StartForward(callbacks[callback]);
			Call_PushCell(entity);
			Call_PushCell(zone);
			Call_PushCell(values);
			Call_Finish();
		}
	}
}

void RegisterNewEffect(Handle plugin, const char[] effect_name, Function function1 = INVALID_FUNCTION, Function function2 = INVALID_FUNCTION, Function function3 = INVALID_FUNCTION)
{
	if (plugin == null || strlen(effect_name) == 0)
	{
		return;
	}
	
	Handle callbacks[MAX_EFFECT_CALLBACKS];
	int index = FindStringInArray(g_hArray_EffectsList, effect_name);
	
	if (index != INVALID_ARRAY_INDEX)
	{
		GetTrieArray(g_hTrie_EffectCalls, effect_name, callbacks, sizeof(callbacks));
		
		for (int i = 0; i < MAX_EFFECT_CALLBACKS; i++)
		{
			delete callbacks[i];
		}
		
		ClearKeys(effect_name);
		
		RemoveFromTrie(g_hTrie_EffectCalls, effect_name);
		
		g_hArray_EffectsList.Erase(index);
	}
	
	if (function1 != INVALID_FUNCTION)
	{
		callbacks[EFFECT_CALLBACK_ONENTERZONE] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(callbacks[EFFECT_CALLBACK_ONENTERZONE], plugin, function1);
	}
	
	if (function2 != INVALID_FUNCTION)
	{
		callbacks[EFFECT_CALLBACK_ONACTIVEZONE] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(callbacks[EFFECT_CALLBACK_ONACTIVEZONE], plugin, function2);
	}
	
	if (function3 != INVALID_FUNCTION)
	{
		callbacks[EFFECT_CALLBACK_ONLEAVEZONE] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(callbacks[EFFECT_CALLBACK_ONLEAVEZONE], plugin, function3);
	}
	
	SetTrieArray(g_hTrie_EffectCalls, effect_name, callbacks, sizeof(callbacks));
	PushArrayString(g_hArray_EffectsList, effect_name);
}

void RegisterNewEffectKey(const char[] effect_name, const char[] key, const char[] defaultvalue)
{
	StringMap keys;
	
	if (!GetTrieValue(g_hTrie_EffectKeys, effect_name, keys) || keys == null)
	{
		keys = CreateTrie();
	}
	
	SetTrieString(keys, key, defaultvalue);
	SetTrieValue(g_hTrie_EffectKeys, effect_name, keys);
}

void ClearKeys(const char[] effect_name)
{
	StringMap keys;
	if (GetTrieValue(g_hTrie_EffectKeys, effect_name, keys))
	{
		delete keys;
		RemoveFromTrie(g_hTrie_EffectKeys, effect_name);
	}
}

void GetMiddleOfABox(const float vec1[3], const float vec2[3], float buffer[3])
{
	float mid[3];
	MakeVectorFromPoints(vec1, vec2, mid);
	
	mid[0] /= 2.0;
	mid[1] /= 2.0;
	mid[2] /= 2.0;
	
	AddVectors(vec1, mid, buffer);
}

bool GetClientLookPoint(int client, float lookposition[3], bool beam = false)
{
	float vEyePos[3];
	GetClientEyePosition(client, vEyePos);
	
	float vEyeAng[3];
	GetClientEyeAngles(client, vEyeAng);
	
	Handle hTrace = TR_TraceRayFilterEx(vEyePos, vEyeAng, MASK_SHOT, RayType_Infinite, TraceEntityFilter_NoPlayers);
	bool bHit = TR_DidHit(hTrace);
	
	TR_GetEndPosition(lookposition, hTrace);
	
	CloseHandle(hTrace);
	
	if (beam)
	{
		TE_SetupBeamPoints(vEyePos, lookposition, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, 5.0, 5.0, 5.0, 0, 0.0, { 255, 0, 0, 255 }, 10);
		TE_SendToClient(client);
	}
	
	return bHit;
}

public bool TraceEntityFilter_NoPlayers(int entity, int contentsMask)
{
	return false;
}

void Array_Fill(any[] array, int size, any value, int start = 0)
{
	if (start < 0)
	{
		start = 0;
	}
	
	for (int i = start; i < size; i++)
	{
		array[i] = value;
	}
}

void Effect_DrawBeamBoxToClient(int client, const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] =  { 255, 0, 0, 255 }, int speed = 0)
{
	int clients[1];
	clients[0] = client;
	Effect_DrawBeamBox(clients, 1, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
}

void Effect_DrawBeamBox(int[] clients, int numClients, const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] =  { 255, 0, 0, 255 }, int speed = 0)
{
	float corners[8][3];
	
	for (int i = 0; i < 4; i++)
	{
		CopyArrayToArray(bottomCorner, corners[i], 3);
		CopyArrayToArray(upperCorner, corners[i + 4], 3);
	}
	
	corners[1][0] = upperCorner[0];
	corners[2][0] = upperCorner[0];
	corners[2][1] = upperCorner[1];
	corners[3][1] = upperCorner[1];
	corners[4][0] = bottomCorner[0];
	corners[4][1] = bottomCorner[1];
	corners[5][1] = bottomCorner[1];
	corners[7][0] = bottomCorner[0];
	
	for (int i = 0; i < 4; i++)
	{
		int j = (i == 3 ? 0 : i + 1);
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}
	
	for (int i = 4; i < 8; i++)
	{
		int j = (i == 7 ? 4 : i + 1);
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}
	
	for (int i = 0; i < 4; i++)
	{
		TE_SetupBeamPoints(corners[i], corners[i + 4], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}
}

bool TeleportToZone(int client, int zone)
{
	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return false;
	}
	
	if (!IsValidZone(zone) || !g_bZoneSpawned[zone])
	{
		return false;
	}
	
	float fMiddle[3];
	
	switch (GetZoneType(zone))
	{
		case ZONE_TYPE_BOX:
		{
			GetMiddleOfABox(g_fZone_Start[zone], g_fZone_End[zone], fMiddle);
		}
		
		case ZONE_TYPE_CIRCLE:
		{
			CopyArrayToArray(g_fZone_Start[zone], fMiddle, 3);
		}
		
		case ZONE_TYPE_POLY:
		{
			return false;
		}
	}
	
	TeleportEntity(client, fMiddle, NULL_VECTOR, NULL_VECTOR);
	
	return true;
}

int GetZoneByName(const char[] name)
{
	int entity = INVALID_ENT_INDEX;
	char buffer[MAX_ZONE_NAME_LENGTH];
	
	for (int i = 0; i < GetArraySize(g_hZoneEntities); i++)
	{
		entity = EntRefToEntIndex(GetArrayCell(g_hZoneEntities, i));
		
		if (IsValidZone(entity))
		{
			GetEntPropString(entity, Prop_Send, "m_iName", buffer, sizeof(buffer));
			
			if (StrEqual(buffer, name) || StrEqual(buffer, g_sZone_Name[entity]))
			{
				return entity;
			}
		}
	}
	
	return INVALID_ENT_INDEX;
}

bool AddZonePoint(ArrayList points, float fPoints[3])
{
	if (points == null)
	{
		return false;
	}
	
	int size = 0;
	int actual = 0;
	
	size = GetArraySize(points);
	actual = size + 1;
	
	ResizeArray(points, actual);
	SetArrayCell(points, size, fPoints[0], 0);
	SetArrayCell(points, size, fPoints[1], 1);
	SetArrayCell(points, size, fPoints[2], 2);
	
	return true;
}

bool RemoveZonePoint(ArrayList points, float point[3])
{
	if (points == null)
	{
		return false;
	}
	
	float buffer[3];
	
	for (int i = 0; i < GetArraySize(points); i++)
	{
		GetArrayArray(points, i, buffer);
		
		if (!AreVectorsEqual(point, buffer))
		{
			continue;
		}
		
		points.Erase(i);
		return true;
	}
	
	return false;
}

KeyValues CreateZoneKeyValues(int zone)
{
	if (!IsValidZone(zone))
	{
		ThrowError("Entity %d is not a valid zone", zone);
		return null;
	}
	
	if (!strlen(g_sZone_Name[zone]))
	{
		ThrowError("Name for zone %d is undefined", zone);
		return null;
	}
	
	if (g_iZone_Type[zone] == INVALID_ENT_INDEX)
	{
		ThrowError("Type for zone %d is undefined", zone);
		return null;
	}
	
	if (g_fZone_Start[zone][0] == -1.0 && g_fZone_Start[zone][1] == -1.0 && g_fZone_Start[zone][2] == -1.0)
	{
		ThrowError("Start point for zone %d is undefined", zone);
		return null;
	}
	
	if (g_fZone_End[zone][0] == -1.0 && g_fZone_End[zone][1] == -1.0 && g_fZone_End[zone][2] == -1.0 && g_iZone_Type[zone] == ZONE_TYPE_BOX)
	{
		ThrowError("End point for zone %d is undefined", zone);
		return null;
	}
	
	if (g_fZoneRadius[zone] == -1.0 && g_iZone_Type[zone] == ZONE_TYPE_CIRCLE)
	{
		ThrowError("Radius for zone %d is undefined", zone);
		return null;
	}
	
	if (g_iZoneColor[zone][0] == -1 || g_iZoneColor[zone][1] == -1 || g_iZoneColor[zone][2] == -1 || g_iZoneColor[zone][3] == -1)
	{
		ThrowError("Color (%d, %d, %d, %d) for zone %d is undefined or invalid", g_iZoneColor[zone][0], g_iZoneColor[zone][1], g_iZoneColor[zone][2], g_iZoneColor[zone][3], zone);
		return null;
	}
	
	if (g_hZonePointsData[zone] == null && g_iZone_Type[zone] == ZONE_TYPE_POLY)
	{
		ThrowError("Point list for zone %d is undefined", zone);
		return null;
	}
	
	if (g_iZone_Type[zone] == ZONE_TYPE_POLY && !GetArraySize(g_hZonePointsData[zone])) {
		ThrowError("Point list for zone %d is empty", zone);
		return null;
	}
	
	if (g_fZoneHeight[zone] == -1.0 && (g_iZone_Type[zone] == ZONE_TYPE_POLY || g_iZone_Type[zone] == ZONE_TYPE_CIRCLE))
	{
		ThrowError("Height for zone %d is undefined", zone);
		return null;
	}
	
	KeyValues kv = CreateKeyValues("zones_manager");
	
	KvJumpToKey(kv, g_sZone_Name[zone], true);
	
	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneTypeName(g_iZone_Type[zone], sType, sizeof(sType));
	KvSetString(kv, "type", sType);
	
	char sColor[64];
	FormatEx(sColor, sizeof(sColor), "%i %i %i %i", g_iZoneColor[zone][0], g_iZoneColor[zone][1], g_iZoneColor[zone][2], g_iZoneColor[zone][3]);
	KvSetString(kv, "color", sColor);
	
	switch (g_iZone_Type[zone])
	{
		case ZONE_TYPE_BOX:
		{
			KvSetVector(kv, "start", g_fZone_Start[zone]);
			KvSetVector(kv, "end", g_fZone_End[zone]);
		}
		
		case ZONE_TYPE_CIRCLE:
		{
			KvSetVector(kv, "start", g_fZone_Start[zone]);
			KvSetFloat(kv, "radius", g_fZoneRadius[zone]);
			KvSetFloat(kv, "height", g_fZoneHeight[zone]);
		}
		
		case ZONE_TYPE_POLY:
		{
			KvSetVector(kv, "start", g_fZone_Start[zone]);
			KvSetFloat(kv, "height", g_fZoneHeight[zone]);
			
			if (KvJumpToKey(kv, "points", true))
			{
				char sID[12]; float coordinates[3];
				
				for (int i = 0; i < GetArraySize(g_hZonePointsData[zone]); i++)
				{
					IntToString(i, sID, sizeof(sID));
					GetArrayArray(g_hZonePointsData[zone], i, coordinates, sizeof(coordinates));
					KvSetVector(kv, sID, coordinates);
				}
			}
		}
	}
	
	KvRewind(kv);
	return kv;
}

bool GetZoneKeyValuesAsString(int zone, char[] sBuffer, int size)
{
	KeyValues kv = CreateZoneKeyValues(zone);
	
	if (kv == null)
	{
		return false;
	}
	
	char sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/zones/%d.temp", GetSomeWhatDecentRandom());
	
	if (!KeyValuesToFile(kv, sPath))
	{
		delete kv;
		return false;
	}
	
	delete kv;
	
	if (!FileExists(sPath))
	{
		return false;
	}
	
	File file = OpenFile(sPath, "r");
	
	if (file == null)
	{
		return false;
	}
	
	if (!ReadFileString(file, sBuffer, size))
	{
		delete file;
		DeleteFile(sPath);
		return false;
	}
	
	delete file;
	DeleteFile(sPath);
	
	return true;
}

int GetSomeWhatDecentRandom()
{
	int iWaiter = 0;
	
	while (iWaiter < 10)
	{
		iWaiter++;
	}
	
	return RoundToNearest(GetGameTime() + GetURandomFloat() + GetRandomFloat(1.0, 638490753.0));
}

float GetLowestCorner(int zone)
{
	if (!IsValidZone(zone))
	{
		return -1.0;
	}
	
	float fLowest = -1.0;
	
	switch (GetZoneType(zone))
	{
		case ZONE_TYPE_BOX:
		{
			fLowest = g_fZone_Start[zone][2] > g_fZone_End[zone][2] ? g_fZone_End[zone][2] : g_fZone_Start[zone][2];
		}
		
		case ZONE_TYPE_CIRCLE:
		{
			fLowest = g_fZone_Start[zone][2];
		}
		
		case ZONE_TYPE_POLY:
		{
			float vPoint[3];
			
			for (int i = 0; i < GetArraySize(g_hZonePointsData[zone]); i++)
			{
				GetArrayArray(g_hZonePointsData[zone], i, vPoint);
				
				if (vPoint[2] < fLowest || fLowest == -1.0)
				{
					fLowest = vPoint[2];
				}
			}
		}
	}
	
	return fLowest;
}

float GetHighestCorner(int zone)
{
	if (!IsValidZone(zone))
	{
		return -1.0;
	}
	
	float fHighest = -1.0;
	
	switch (GetZoneType(zone))
	{
		case ZONE_TYPE_BOX:
		{
			fHighest = g_fZone_Start[zone][2] < g_fZone_End[zone][2] ? g_fZone_End[zone][2] : g_fZone_Start[zone][2];
		}
		
		case ZONE_TYPE_CIRCLE:
		{
			fHighest = g_fZone_Start[zone][2] + g_fZoneRadius[zone]; // Is this even right? fuck circles..
		}
		
		case ZONE_TYPE_POLY:
		{
			float vPoint[3];
			
			for (int i = 0; i < GetArraySize(g_hZonePointsData[zone]); i++)
			{
				GetArrayArray(g_hZonePointsData[zone], i, vPoint);
				
				if (vPoint[2] > fHighest)
				{
					fHighest = vPoint[2];
				}
			}
		}
	}
	
	return fHighest;
}

bool IsVectorInsideZone(int zone, float origin[3])
{
	if (!IsValidZone(zone))
	{
		return false;
	}
	
	float zoneOrigin[3]; float zoneOrigin2[3];
	float origin2[3];
	
	switch (GetZoneType(zone))
	{
		case ZONE_TYPE_BOX:
		{
			// Count zone corners
			// https://forums.alliedmods.net/showpost.php?p=2006539&postcount=8
			float fCorners[8][3];
			
			for (int i = 0; i < 3; i++)
			{
				fCorners[0][i] = g_fZone_Start[zone][i];
				fCorners[7][i] = g_fZone_End[zone][i];
			}
			
			for (int i = 1; i < 7; i++)
			{
				for (int j = 0; j < 3; j++)
				{
					fCorners[i][j] = fCorners[((i >> (2 - j)) & 1) * 7][j];
				}
			}
			
			int iCheck = 0;
			
			float tmpOrigin[3]; CopyArrayToArray(origin, tmpOrigin, 3); tmpOrigin[2] += 5.0;
			
			for (int i = 0; i < 3; i++)
			{
				if ((fCorners[7][i] >= fCorners[0][i] && (tmpOrigin[i] <= (fCorners[7][i]) && tmpOrigin[i] >= (fCorners[0][i]))) || 
					(fCorners[0][i] >= fCorners[7][i] && (tmpOrigin[i] <= (fCorners[0][i]) && tmpOrigin[i] >= (fCorners[7][i]))))
				{
					iCheck++;
				}
				
				if (iCheck == 3)
				{
					return true;
				}
			}
			
			return false;
		}
		
		case ZONE_TYPE_CIRCLE:
		{
			GetEntPropVector(zone, Prop_Data, "m_vecOrigin", zoneOrigin);
			
			if(FloatAbs(zoneOrigin[2] - origin[2]) > g_fZoneHeight[zone]) 
			{
				return false;
			}
			
			CopyArrayToArray(zoneOrigin, zoneOrigin2, 3);
			CopyArrayToArray(origin, origin2, 3);
			
			zoneOrigin2[2] = 0.0;
			origin2[2] = 0.0;
			
			return GetVectorDistance(origin2, zoneOrigin2) <= (g_fZoneRadius[zone] / 2.0);
		}
		
		case ZONE_TYPE_POLY:
		{
			float newOrigin[3];
			float entityPoints[4][3];
			static float offset = 16.5;
			
			newOrigin[0] = origin[0];
			newOrigin[1] = origin[1];
			newOrigin[2] = origin[2];
			
			newOrigin[2] += 42.5;
			
			entityPoints[0] = newOrigin;
			entityPoints[0][0] -= offset;
			entityPoints[0][1] -= offset;
			
			entityPoints[1] = newOrigin;
			entityPoints[1][0] += offset;
			entityPoints[1][1] -= offset;
			
			entityPoints[2] = newOrigin;
			entityPoints[2][0] -= offset;
			entityPoints[2][1] += offset;
			
			entityPoints[3] = newOrigin;
			entityPoints[3][0] += offset;
			entityPoints[3][1] += offset;
			
			for (int x = 0; x < 4; x++)
			{
				if (IsPointInZone(entityPoints[x], zone))
				{
					return true;
				}
			}
			
			return false;
		}
	}
	
	return false;
}

//Down to just above the natives, these functions are made by 'Deathknife' and repurposed by me for this plugin.
//Fucker can maths
//by Deathknife
bool IsPointInZone(float point[3], int zone)
{
	//Check if point is in the zone
	if (!IsOriginInBox(point, zone))
	{
		return false;
	}
	
	//Get a ray outside of the polygon
	float ray[3];
	ray = point;
	ray[1] += g_fZonePointsDistance[zone] + 50.0;
	ray[2] = point[2];
	
	//Store the x and y intersections of where the ray hits the line
	float xint;
	float yint;
	
	//Intersections for base bottom and top(2)
	float baseY;
	float baseZ;
	float baseY2;
	float baseZ2;
	
	//Calculate equation for x + y
	float eq[2];
	eq[0] = point[0] - ray[0];
	eq[1] = point[2] - ray[2];
	
	//This is for checking if the line intersected the base
	//The method is messy, came up with it myself, and might not work 100% of the time.
	//Should work though.
	
	//Bottom
	int lIntersected[64];
	float fIntersect[64][3];
	
	//Top
	int lIntersectedT[64];
	float fIntersectT[64][3];
	
	//Count amount of intersetcions
	int intersections = 0;
	
	//Count amount of intersection for BASE
	int lIntNum = 0;
	int lIntNumT = 0;
	
	//Get slope
	float lSlope = (ray[2] - point[2]) / (ray[1] - point[1]);
	float lEq = (lSlope & ray[0]) - ray[2];
	lEq = -lEq;
	
	//Get second slope
	//float lSlope2 = (ray[1] - point[1]) / (ray[0] - point[0]);
	//float lEq2 = (lSlope2 * point[0]) - point[1];
	//lEq2 = -lEq2;
	
	//Loop through every point of the zone
	int size = GetArraySize(g_hZonePointsData[zone]);
	
	for (int i = 0; i < size; i++)
	{
		//Get current & next point
		float currentpoint[3];
		GetArrayArray(g_hZonePointsData[zone], i, currentpoint, sizeof(currentpoint));
		
		float nextpoint[3];
		
		//Check if its the last point, if it is, join it with the first
		if (size == i + 1)
		{
			GetArrayArray(g_hZonePointsData[zone], 0, nextpoint, sizeof(nextpoint));
		}
		else
		{
			GetArrayArray(g_hZonePointsData[zone], i + 1, nextpoint, sizeof(nextpoint));
		}
		
		//Check if the ray intersects the point
		//Ignore the height parameter as we will check against that later
		bool didinter = get_line_intersection(ray[0], ray[1], point[0], point[1], currentpoint[0], currentpoint[1], nextpoint[0], nextpoint[1], xint, yint);
		
		//Get intersections of the bottom
		bool baseInter = get_line_intersection(ray[1], ray[2], point[1], point[2], currentpoint[1], currentpoint[2], nextpoint[1], nextpoint[2], baseY, baseZ);
		
		//Get intersections of the top
		bool baseInter2 = get_line_intersection(ray[1], ray[2], point[1], point[2], currentpoint[1] + g_fZoneHeight[zone], currentpoint[2] + g_fZoneHeight[zone], nextpoint[1] + g_fZoneHeight[zone], nextpoint[2] + g_fZoneHeight[zone], baseY2, baseZ2);
		
		//If base intersected, store the line for later
		if (baseInter && lIntNum < sizeof(fIntersect))
		{
			lIntersected[lIntNum] = i;
			fIntersect[lIntNum][1] = baseY;
			fIntersect[lIntNum][2] = baseZ;
			lIntNum++;
		}
		
		if (baseInter2 && lIntNumT < sizeof(fIntersectT))
		{
			lIntersectedT[lIntNumT] = i;
			fIntersectT[lIntNumT][1] = baseY2;
			fIntersectT[lIntNum][2] = baseZ2;
			lIntNumT++;
		}
		
		//If ray intersected line, check against height
		if (didinter)
		{
			//Get the height of intersection
			
			//Get slope of line it hit
			float m1 = (nextpoint[2] - currentpoint[2]) / (nextpoint[0] - currentpoint[0]);
			
			//Equation y = mx + c | mx - y = -c
			float l1 = (m1 * currentpoint[0]) - currentpoint[2];
			l1 = -l1;
			
			float y2 = (m1 * xint) + l1;
			
			//Get slope of ray
			float y = (lSlope * xint) + lEq;
			
			if (y > y2 && y < y2 + 128.0 + g_fZoneHeight[zone])
			{
				//The ray intersected the line and is within the height
				intersections++;
			}
		}
	}
	
	//Now we check for base hitting
	//This method is weird, but works most of the time
	for (int k = 0; k < lIntNum; k++)
	{
		for (int l = k + 1; l < lIntNum; l++)
		{
			if (l == k)
			{
				continue;
			}
			
			int i = lIntersected[k];
			int j = lIntersected[l];
			
			if (i == j)
			{
				continue;
			}
			
			float currentpoint[2][3];
			float nextpoint[2][3];
			
			if (GetArraySize(g_hZonePointsData[zone]) == i + 1)
			{
				GetArrayArray(g_hZonePointsData[zone], i, currentpoint[0], 3);
				GetArrayArray(g_hZonePointsData[zone], 0, nextpoint[0], 3);
			}
			else
			{
				GetArrayArray(g_hZonePointsData[zone], i, currentpoint[0], 3);
				GetArrayArray(g_hZonePointsData[zone], i + 1, nextpoint[0], 3);
			}
			
			if (GetArraySize(g_hZonePointsData[zone]) == j + 1)
			{
				GetArrayArray(g_hZonePointsData[zone], j, currentpoint[1], 3);
				GetArrayArray(g_hZonePointsData[zone], 0, nextpoint[1], 3);
			}
			else
			{
				GetArrayArray(g_hZonePointsData[zone], j, currentpoint[1], 3);
				GetArrayArray(g_hZonePointsData[zone], j + 1, nextpoint[1], 3);
			}
			
			//Get equation of both lines then find slope of them
			float m1 = (nextpoint[0][1] - currentpoint[0][1]) / (nextpoint[0][0] - currentpoint[0][0]);
			float m2 = (nextpoint[1][1] - currentpoint[1][1]) / (nextpoint[1][0] - currentpoint[1][0]);
			float lEq1 = (m1 * currentpoint[0][0]) - currentpoint[0][1];
			float lEq2 = (m2 * currentpoint[1][0]) - currentpoint[1][1];
			lEq1 = -lEq1;
			lEq2 = -lEq2;
			
			//Get x point of intersection
			float xPoint1 = ((fIntersect[k][1] - lEq1) / m1);
			float xPoint2 = ((fIntersect[l][1] - lEq2 / m2));
			
			if (xPoint1 > point[0] > xPoint2 || xPoint1 < point[0] < xPoint2)
			{
				intersections++;
			}
		}
	}
	
	for (int k = 0; k < lIntNumT; k++)
	{
		for (int l = k + 1; l < lIntNumT; l++)
		{
			if (l == k)
			{
				continue;
			}
			
			int i = lIntersectedT[k];
			int j = lIntersectedT[l];
			
			if (i == j)
			{
				continue;
			}
			
			float currentpoint[2][3];
			float nextpoint[2][3];
			
			if (GetArraySize(g_hZonePointsData[zone]) == i + 1)
			{
				GetArrayArray(g_hZonePointsData[zone], i, currentpoint[0], 3);
				GetArrayArray(g_hZonePointsData[zone], 0, nextpoint[0], 3);
			}
			else
			{
				GetArrayArray(g_hZonePointsData[zone], i, currentpoint[0], 3);
				GetArrayArray(g_hZonePointsData[zone], i + 1, nextpoint[0], 3);
			}
			
			if (GetArraySize(g_hZonePointsData[zone]) == j + 1)
			{
				GetArrayArray(g_hZonePointsData[zone], j, currentpoint[1], 3);
				GetArrayArray(g_hZonePointsData[zone], 0, nextpoint[1], 3);
			}
			else
			{
				GetArrayArray(g_hZonePointsData[zone], j, currentpoint[1], 3);
				GetArrayArray(g_hZonePointsData[zone], j + 1, nextpoint[1], 3);
			}
			
			//Get equation of both lines then find slope of them
			float m1 = (nextpoint[0][1] - currentpoint[0][1]) / (nextpoint[0][0] - currentpoint[0][0]);
			float m2 = (nextpoint[1][1] - currentpoint[1][1]) / (nextpoint[1][0] - currentpoint[1][0]);
			float lEq1 = (m1 * currentpoint[0][0]) - currentpoint[0][1];
			float lEq2 = (m2 * currentpoint[1][0]) - currentpoint[1][1];
			lEq1 = -lEq1;
			lEq2 = -lEq2;
			
			//Get x point of intersection
			float xPoint1 = ((fIntersectT[k][1] - lEq1) / m1);
			float xPoint2 = ((fIntersectT[l][1] - lEq2 / m2));
			
			if (xPoint1 > point[0] > xPoint2 || xPoint1 < point[0] < xPoint2)
			{
				intersections++;
			}
		}
	}
	
	if (intersections <= 0 || intersections % 2 == 0)
	{
		return false;
	}
	
	return true;
}

bool IsOriginInBox(float origin[3], int zone)
{
	if (origin[0] >= g_fZonePointsMin[zone][0] && origin[1] >= g_fZonePointsMin[zone][1] && origin[2] >= g_fZonePointsMin[zone][2] && origin[0] <= g_fZonePointsMax[zone][0] + g_fZoneHeight[zone] && origin[1] <= g_fZonePointsMax[zone][1] + g_fZoneHeight[zone] && origin[2] <= g_fZonePointsMax[zone][2] + g_fZoneHeight[zone])
	{
		return true;
	}
	
	return false;
}

bool get_line_intersection(float p0_x, float p0_y, float p1_x, float p1_y, float p2_x, float p2_y, float p3_x, float p3_y, float &i_x, float &i_y)
{
	float s1_x = p1_x - p0_x;
	float s1_y = p1_y - p0_y;
	float s2_x = p3_x - p2_x;
	float s2_y = p3_y - p2_y;
	
	float s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
	float t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);
	
	if (s >= 0 && s <= 1 && t >= 0 && t <= 1)
	{
		// Collision detected
		i_x = p0_x + (t * s1_x);
		i_y = p0_y + (t * s1_y);
		
		return true;
	}
	
	return false; // No collision
}

float CalculateHorizontalDistance(float vec1[3], float vec2[3], bool squared = false)
{
	if (squared)
	{
		if (vec1[0] < 0.0)
		{
			vec1[0] *= -1;
		}
		
		if (vec1[1] < 0.0)
		{
			vec1[1] *= -1;
		}
		
		vec1[0] = SquareRoot(vec1[0]);
		vec1[1] = SquareRoot(vec1[1]);
		
		if (vec2[0] < 0.0)
		{
			vec2[0] *= -1;
		}
		
		if (vec2[1] < 0.0)
		{
			vec2[1] *= -1;
		}
		
		vec2[0] = SquareRoot(vec2[0]);
		vec2[1] = SquareRoot(vec2[1]);
	}
	
	return SquareRoot(Pow((vec1[0] - vec2[0]), 2.0) + Pow((vec1[1] - vec2[1]), 2.0));
}

//Natives
public int Native_RegisterEffect(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);
	
	char[] sEffect = new char[size + 1];
	GetNativeString(1, sEffect, size + 1);
	
	Function function1 = GetNativeFunction(2);
	Function function2 = GetNativeFunction(3);
	Function function3 = GetNativeFunction(4);
	
	RegisterNewEffect(plugin, sEffect, function1, function2, function3);
}

public int Native_RegisterEffectKey(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);
	
	char[] sEffect = new char[size + 1];
	GetNativeString(1, sEffect, size + 1);
	
	size = 0;
	GetNativeStringLength(2, size);
	
	char[] sKey = new char[size + 1];
	GetNativeString(2, sKey, size + 1);
	
	size = 0;
	GetNativeStringLength(3, size);
	
	char[] sDefaultValue = new char[size + 1];
	GetNativeString(3, sDefaultValue, size + 1);
	
	RegisterNewEffectKey(sEffect, sKey, sDefaultValue);
}

public int Native_RequestQueueEffects(Handle plugin, int numParams)
{
	QueueEffects();
}
public int Native_ClearAllZones(Handle plugin, int numParams)
{
	ClearAllZones();
}

public int Native_IsEntityInZone(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	int zone = GetNativeCell(2);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return g_bIsInsideZone[entity][zone];
}

public int Native_AssignZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int zone = GetNativeCell(2);
	
	if (!IsPlayerIndex(client))
	{
		return false;
	}
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (g_hClientZones[client] == null)
	{
		g_hClientZones[client] = CreateArray();
	}
	
	int entref = EntIndexToEntRef(zone);
	
	if (FindValueInArray(g_hClientZones[client], entref) == -1)
	{
		PushArrayCell(g_hClientZones[client], entref);
	}
	
	return true;
}

public int Native_UnAssignZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int zone = GetNativeCell(2);
	
	if (!IsPlayerIndex(client))
	{
		return false;
	}
	
	if (!IsValidZone(zone))
	{
		return false;
	}
	
	if (g_hClientZones[client] == null)
	{
		return false;
	}
	
	int entref = EntIndexToEntRef(zone);
	int arraycell = FindValueInArray(g_hClientZones[client], entref);
	
	if (arraycell != -1)
	{
		g_hClientZones[client].Erase(arraycell);
		
		if (!g_bZoneSpawned[zone])
		{
			AcceptEntityInput(zone, "Kill");
		}
		
		return true;
	}
	
	if(GetArraySize(g_hClientZones[client]) <= 0) 
	{
		delete g_hClientZones[client];
		g_hClientZones[client] = null;
	}
	
	return false;
}

public int Native_GetAssignedZones(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!IsPlayerIndex(client))
	{
		return false;
	}
	
	if(g_hClientZones[client] == null) 
	{
		return view_as<int>(INVALID_HANDLE);
	}
	
	if(!GetArraySize(g_hClientZones[client])) 
	{
		delete g_hClientZones[client];
		return view_as<int>(INVALID_HANDLE);
	}
	
	return view_as<int>(g_hClientZones[client]);
}

public int Native_GetZonePointsCount(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return INVALID_ENT_INDEX;
	}
	
	return GetArraySize(g_hZonePointsData[zone]);
}

public int Native_GetZonePoints(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return INVALID_ENT_INDEX;
	}
	
	return view_as<int>(g_hZonePointsData[zone]);
}

public int Native_GetZonePointHeight(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return view_as<int>(-1.0);
	}
	
	int type = GetZoneType(zone);
	
	if (type != ZONE_TYPE_POLY && type != ZONE_TYPE_CIRCLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return view_as<int>(-1.0);
	}
	
	return view_as<int>(g_fZoneHeight[zone]);
}

public int Native_TeleportClientToZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int zone = GetNativeCell(2);
	
	if (!IsPlayerIndex(client) || !IsPlayerAlive(client))
	{
		return false;
	}
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return TeleportToZone(client, zone);
}

public int Native_GetClientLookPoint(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!IsPlayerIndex(client) || !IsPlayerAlive(client))
	{
		return false;
	}
	
	float point[3]; GetClientLookPoint(client, point);
	
	return SetNativeArray(2, point, 3) == SP_ERROR_NONE;
}

public int Native_GetZoneByName(Handle plugin, int numParams)
{
	char sZone[MAX_ZONE_NAME_LENGTH]; GetNativeString(1, sZone, sizeof(sZone));
	
	return GetZoneByName(sZone);
}

public int Native_GetZoneName(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return SetNativeString(2, g_sZone_Name[zone], GetNativeCell(3)) == SP_ERROR_NONE;
}

public int Native_GetZoneStart(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return SetNativeArray(2, g_fZone_Start[zone], 3) == SP_ERROR_NONE;
}

public int Native_GetZoneEnd(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_BOX)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a box", zone);
		return false;
	}
	
	return SetNativeArray(2, g_fZone_End[zone], 3) == SP_ERROR_NONE;
}

public int Native_GetZoneRadius(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_CIRCLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a circle", zone);
		return false;
	}
	
	return view_as<int>(g_fZoneRadius[zone]);
}

public int Native_GetZoneColor(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return SetNativeArray(2, g_iZoneColor[zone], 3) == SP_ERROR_NONE;
}

public int Native_GetZoneType(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return GetZoneType(zone);
}

public int Native_GetZoneLowestCorner(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return view_as<int>(GetLowestCorner(zone));
}

public int Native_GetZoneHighestCorner(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return view_as<int>(GetHighestCorner(zone));
}

public int Native_IsVectorInsideZone(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float origin[3]; GetNativeArray(2, origin, 3);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	return IsVectorInsideZone(zone, origin);
}

public int Native_CreateZoneAdvanced(Handle plugin, int numParams)
{
	int type = GetNativeCell(1);
	char sName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, sName, sizeof(sName));
	
	float start[3]; GetNativeArray(3, start, 3);
	float end[3]; GetNativeArray(4, end, 3);
	float radius = view_as<float>(GetNativeCell(5));
	int color[4]; GetNativeArray(6, color, 4);
	ArrayList points = view_as<ArrayList>(GetNativeCell(7));
	float height = view_as<float>(GetNativeCell(8));
	StringMap effects = view_as<StringMap>(GetNativeCell(9));
	
	int zone = CreateZone(sName, type, start, end, radius, color, points, height, effects);
	
	if (!IsValidZone(zone))
	{
		return INVALID_ENT_INDEX;
	}
	
	return zone;
}

public int Native_CreateZoneFromKeyValuesString(Handle plugin, int numParams)
{
	char sBuffer[4096]; GetNativeString(1, sBuffer, sizeof(sBuffer));
	
	KeyValues kv = CreateKeyValues("zones_manager");
	
	if (!StringToKeyValues(kv, sBuffer))
	{
		return INVALID_ENT_INDEX;
	}
	
	int zone = SpawnAZoneFromKeyValues(kv);
	
	if (!IsValidZone(zone))
	{
		return INVALID_ENT_INDEX;
	}
	
	return zone;
}

public int Native_StartZone(Handle plugin, int numParams)
{
	int type = GetNativeCell(1);
	char sName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, sName, sizeof(sName));
	
	if (type < ZONE_TYPE_BOX || type > ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone type %d", type);
		return INVALID_ENT_INDEX;
	}
	
	if (!strlen(sName))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone name '%s'", sName);
		return INVALID_ENT_INDEX;
	}
	
	int arrayindex = INVALID_ENT_INDEX;
	int zone = InitZone(type, arrayindex);
	
	if (!IsValidZone(zone) || arrayindex == INVALID_ENT_INDEX)
	{
		return INVALID_ENT_INDEX;
	}
	
	if (type == ZONE_TYPE_POLY && g_hZonePointsData[zone] == null)
	{
		g_hZonePointsData[zone] = CreateArray(3);
	}
	
	g_iZone_Type[zone] = type;
	g_sZone_Name[zone] = sName;
	
	return zone;
}

public int Native_SetZoneName(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	char sName[MAX_ZONE_NAME_LENGTH]; GetNativeString(2, sName, sizeof(sName));
	
	if (!strlen(sName))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid zone name '%s'", sName);
		return false;
	}
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	g_sZone_Name[zone] = sName;
	
	if (g_bZoneSpawned[zone])
	{
		SetEntPropString(zone, Prop_Data, "m_iName", sName);
	}
	
	return true;
}

public int Native_SetZoneStart(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float start[3]; GetNativeArray(2, start, 3);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	CopyArrayToArray(start, g_fZone_Start[zone], 3);
	
	if (g_bZoneSpawned[zone])
	{
		SetEntPropVector(zone, Prop_Data, "m_vecMins", start);
	}
	return true;
}

public int Native_SetZoneEnd(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float end[3]; GetNativeArray(2, end, 3);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_BOX)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a box", zone);
		return false;
	}
	
	CopyArrayToArray(end, g_fZone_End[zone], 3);
	
	if (g_bZoneSpawned[zone])
	{
		SetEntPropVector(zone, Prop_Data, "m_vecMaxs", end);
	}
	
	return true;
}

public int Native_SetZoneRadius(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float radius = view_as<float>(GetNativeCell(2));
	
	if (!IsValidEntity(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_CIRCLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a circle", zone);
		return INVALID_ENT_INDEX;
	}
	
	g_fZoneRadius[zone] = radius;
	
	return true;
}

public int Native_SetZoneColor(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	int color[4]; GetNativeArray(2, color, 4);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	g_iZoneColor[zone][0] = color[0];
	g_iZoneColor[zone][1] = color[1];
	g_iZoneColor[zone][2] = color[2];
	g_iZoneColor[zone][3] = color[3];
	
	return true;
}

public int Native_SetZoneHeight(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float height = view_as<float>(GetNativeCell(2));
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	int type = GetZoneType(zone);
	
	if (type != ZONE_TYPE_POLY && type != ZONE_TYPE_CIRCLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon or circle", zone);
		return INVALID_ENT_INDEX;
	}
	
	g_fZoneHeight[zone] = height;
	
	return true;
}

public int Native_AddZonePoint(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float point[3]; GetNativeArray(2, point, 3);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return false;
	}
	
	if (g_fZone_Start[zone][0] == -1.0 && g_fZone_Start[zone][1] == -1.0 && g_fZone_Start[zone][2] == -1.0)
	{
		CopyArrayToArray(point, g_fZone_Start[zone], 3);
	}
	
	AddZonePoint(g_hZonePointsData[zone], point);
	
	return true;
}
public int Native_AddMultipleZonePoints(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	ArrayList points = view_as<ArrayList>(GetNativeCell(2));
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return false;
	}
	
	float buffer[3];
	
	for (int i = 0; i < GetArraySize(points); i++)
	{
		GetArrayArray(points, i, buffer);
		
		if (g_fZone_Start[zone][0] == -1.0 && g_fZone_Start[zone][1] == -1.0 && g_fZone_Start[zone][2] == -1.0)
		{
			CopyArrayToArray(buffer, g_fZone_Start[zone], 3);
		}
		
		AddZonePoint(g_hZonePointsData[zone], buffer);
	}
	
	return true;
}

public int Native_RemoveZonePoint(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	float point[3]; GetNativeArray(2, point, 3);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return INVALID_ENT_INDEX;
	}
	
	RemoveZonePoint(g_hZonePointsData[zone], point);
	
	return true;
}

public int Native_RemoveLastZonePoint(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return INVALID_ENT_INDEX;
	}
	
	int size = GetArraySize(g_hZonePointsData[zone]);
	
	if (!size)
	{
		return false;
	}
	
	float point[3]; GetArrayArray(g_hZonePointsData[zone], size - 1, point);
	
	RemoveZonePoint(g_hZonePointsData[zone], point);
	
	return true;
}

public int Native_RemoveMultipleZonePoints(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	ArrayList points = view_as<ArrayList>(GetNativeCell(2));
	
	if (points == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid points array");
		return false;
	}
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return INVALID_ENT_INDEX;
	}
	
	float buffer[3];
	
	for (int i = 0; i < GetArraySize(points); i++)
	{
		GetArrayArray(points, i, buffer);
		RemoveZonePoint(g_hZonePointsData[zone], buffer);
	}
	
	return true;
}

public int Native_RemoveAllZonePoints(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (GetZoneType(zone) != ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Zone %d is not a polygon", zone);
		return INVALID_ENT_INDEX;
	}
	
	ClearArray(g_hZonePointsData[zone]);
	
	return true;
}

public int Native_AddZoneEffect(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	char sEffect[MAX_EFFECT_NAME_LENGTH]; GetNativeString(2, sEffect, sizeof(sEffect));
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (!g_bZoneSpawned[zone])
	{
		ThrowNativeError(SP_ERROR_NATIVE, "You must finish the zone before you can add effects");
		return false;
	}
	
	if (FindStringInArray(g_hArray_EffectsList, sEffect) == -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "The specified effect '%s' does not exist (Array Size %d)", sEffect, GetArraySize(g_hArray_EffectsList));
		return false;
	}
	
	StringMap keys;
	
	if (!GetTrieValue(g_hTrie_EffectKeys, sEffect, keys) || keys == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Unable to retrieve key for effect '%s'", sEffect);
		return false;
	}
	
	StringMap values;
	
	if (GetTrieValue(g_hZoneEffects[zone], sEffect, values) && values != null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Effect '%s' already exists on zone %d", sEffect, zone);
		return false;
	}
	
	return SetTrieValue(g_hZoneEffects[zone], sEffect, CloneHandle(keys));
}

public int Native_RemoveZoneEffect(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	char sEffect[MAX_EFFECT_NAME_LENGTH]; GetNativeString(2, sEffect, sizeof(sEffect));
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (!g_bZoneSpawned[zone])
	{
		ThrowNativeError(SP_ERROR_NATIVE, "You must finish the zone before you can remove effects");
		return false;
	}
	
	if (FindStringInArray(g_hArray_EffectsList, sEffect) == -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "The specified effect '%s' does not exist (Array Size %d)", sEffect, GetArraySize(g_hArray_EffectsList));
		return false;
	}
	
	StringMap values;
	
	if (!GetTrieValue(g_hZoneEffects[zone], sEffect, values) || values == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Effect '%s' does not exist on zone %d", sEffect, zone);
		return false;
	}
	
	delete values;
	
	return RemoveFromTrie(g_hZoneEffects[zone], sEffect);
}

public int Native_GetZoneKeyValues(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	return view_as<int>(CreateZoneKeyValues(zone));
}

public int Native_GetZoneKeyValuesAsString(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	char sBuffer[4096];
	
	if (!GetZoneKeyValuesAsString(zone, sBuffer, sizeof(sBuffer)))
	{
		return false;
	}
	
	return SetNativeString(2, sBuffer, sizeof(sBuffer)) == SP_ERROR_NONE;
}

public int Native_FinishZone(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (!strlen(g_sZone_Name[zone]))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Name for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZone_Type[zone] == INVALID_ENT_INDEX)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Type for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_fZone_Start[zone][0] == -1.0 && g_fZone_Start[zone][1] == -1.0 && g_fZone_Start[zone][2] == -1.0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Start point for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_fZone_End[zone][0] == -1.0 && g_fZone_End[zone][1] == -1.0 && g_fZone_End[zone][2] == -1.0 && g_iZone_Type[zone] == ZONE_TYPE_BOX)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "End point for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_fZoneRadius[zone] == -1.0 && g_iZone_Type[zone] == ZONE_TYPE_CIRCLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Radius for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZoneColor[zone][0] == -1 || g_iZoneColor[zone][1] == -1 || g_iZoneColor[zone][2] == -1 || g_iZoneColor[zone][3] == -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Color (%d, %d, %d, %d) for zone %d is undefined or invalid", g_iZoneColor[zone][0], g_iZoneColor[zone][1], g_iZoneColor[zone][2], g_iZoneColor[zone][3], zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_hZonePointsData[zone] == null && g_iZone_Type[zone] == ZONE_TYPE_POLY)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Point list for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_iZone_Type[zone] == ZONE_TYPE_POLY && !GetArraySize(g_hZonePointsData[zone]))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Point list for zone %d is empty", zone);
		return INVALID_ENT_INDEX;
	}
	
	if (g_fZoneHeight[zone] == -1.0 && (g_iZone_Type[zone] == ZONE_TYPE_POLY || g_iZone_Type[zone] == ZONE_TYPE_CIRCLE))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Height for zone %d is undefined", zone);
		return INVALID_ENT_INDEX;
	}
	
	return CreateZone(g_sZone_Name[zone], g_iZone_Type[zone], g_fZone_Start[zone], g_fZone_End[zone], g_fZoneRadius[zone], g_iZoneColor[zone], g_hZonePointsData[zone], g_fZoneHeight[zone], g_hZoneEffects[zone], zone);
}

public int Native_HideZoneFromClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int zone = GetNativeCell(2);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (!IsPlayerIndex(client))
	{
		return false;
	}
	
	g_bHideZoneRender[client][zone] = true;
	
	return true;
}

public int Native_UnHideZoneFromClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int zone = GetNativeCell(2);
	
	if (!IsValidZone(zone))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid zone", zone);
		return false;
	}
	
	if (!IsPlayerIndex(client))
	{
		return false;
	}
	
	g_bHideZoneRender[client][zone] = false;
	
	return true;
} 