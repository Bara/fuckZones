#pragma semicolon 1
#pragma newdecls required

#define DEFAULT_MODELINDEX "sprites/laserbeam.vmt"
#define DEFAULT_HALOINDEX  "materials/sprites/halo.vmt"
#define ZONE_MODEL         "models/error.mdl"

#define MAX_ENTITY_LIMIT 4096
#define MAX_BUTTONS      25

#define TIMER_INTERVAL        1.0
#define TE_LIFE               TIMER_INTERVAL + 0.1
#define TIMER_INTERVAL_CREATE 0.1
#define TE_LIFE_CREATE        TIMER_INTERVAL_CREATE + 0.1
#define TE_DRAW_RADIUS        15.0
#define TE_STARTFRAME         0
#define TE_FRAMERATE          0
#define TE_FADELENGTH         0
#define TE_AMPLITUDE          0.0
#define TE_WIDTH              1.0
#define TE_ENDWIDTH           TE_WIDTH
#define TE_SPEED              0
#define TE_FLAGS              0

#include <autoexecconfig>
#include <clientprefs>
#include <fuckZones>
#include <multicolors>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#include "fuckZones/converter.sp"

ConVar g_cPrecisionValue      = null;
ConVar g_cRegenerateSpam      = null;
ConVar g_cDefaultHeight       = null;
ConVar g_cDefaultRadius       = null;
ConVar g_cDefaultZOffset      = null;
ConVar g_cDefaultColor        = null;
ConVar g_cDefaultDisplay      = null;
ConVar g_cEnableLogging       = null;
ConVar g_cMaxRadius           = null;
ConVar g_cMaxHeight           = null;
ConVar g_cNameRegex           = null;
ConVar g_cDisableCZZones      = null;
ConVar g_cTeleportLowestPoint = null;
ConVar g_cCheckZoneNameExist  = null;

enum struct eForwards
{
	GlobalForward OnEffectsReady;
	GlobalForward StartTouchZone;
	GlobalForward TouchZone;
	GlobalForward EndTouchZone;
	GlobalForward StartTouchZone_Post;
	GlobalForward TouchZone_Post;
	GlobalForward EndTouchZone_Post;
	GlobalForward OnZoneCreate;
	GlobalForward OnEffectUpdate;
}

eForwards Forward;

bool g_bLate;

KeyValues g_kvConfig          = null;
int       g_iRegenerationTime = -1;

ArrayList g_aColors     = null;
StringMap g_smColorData = null;

int g_iDefaultModelIndex = -1;
int g_iDefaultHaloIndex  = -1;

// Entities Data
ArrayList g_aZoneEntities = null;
ArrayList g_aUpdateZones  = null;

enum struct eEntityData
{
	float     Radius;
	int       Color[4];
	int       Display;
	bool      Trigger;
	StringMap Effects;
	ArrayList PointsData;
	float     Start[3];
	float     End[3];
	float     Teleport[3];
	float     PointsHeight;
	float     PointsDistance;
	float     PointsMin[3];
	float     PointsMax[3];
}

enum struct eUpdateData
{
	char  Name[MAX_ZONE_NAME_LENGTH];
	float Origin[3];
	float Start[3];
	float End[3];
}

eEntityData Zone[MAX_ENTITY_LIMIT];

// Effects Data
StringMap g_smEffectCalls = null;
StringMap g_smEffectKeys  = null;
ArrayList g_aEffectsList  = null;

// Create Zones Data
eCreateZone CZone[MAXPLAYERS + 1];

bool g_bEffectKeyValue[MAXPLAYERS + 1];
int  g_iEffectKeyValue_Entity[MAXPLAYERS + 1];
char g_sEffectKeyValue_Effect[MAXPLAYERS + 1][MAX_EFFECT_NAME_LENGTH];
char g_sEffectKeyValue_EffectKey[MAXPLAYERS + 1][MAX_KEY_NAME_LENGTH];
int  g_iEditingName[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
bool g_bIsInZone[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];
bool g_bIsInsideZone[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];
bool g_bIsInsideZone_Post[MAXPLAYERS + 1][MAX_ENTITY_LIMIT];
bool g_bSelectedZone[MAX_ENTITY_LIMIT] = { false, ... };
int  g_iConfirmZone[MAXPLAYERS + 1]    = { -1, ... };
int  g_iConfirmPoint[MAXPLAYERS + 1]   = { -1, ... };
int  g_iLastButtons[MAXPLAYERS + 1]    = { 0, ... };

Handle g_coPrecision                = null;
float  g_fPrecision[MAXPLAYERS + 1] = { 0.0, ... };

StringMap g_smSites[MAXPLAYERS + 1] = { null, ... };

ArrayList g_aMapZones = null;

public Plugin myinfo =
{
	name        = "fuckZones - Core",
	author      = "Bara (Original author: Drixevel)",
	description = "A sourcemod plugin with rich features for dynamic zone development.",
	version     = "1.0.0",
	url         = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("fuckZones");

	CreateNative("fuckZones_RegisterEffect", Native_RegisterEffect);
	CreateNative("fuckZones_RegisterEffectKey", Native_RegisterEffectKey);
	CreateNative("fuckZones_ReloadEffects", Native_ReloadEffects);
	CreateNative("fuckZones_RegenerateZones", Native_RegenerateZones);
	CreateNative("fuckZones_IsClientInZone", Native_IsClientInZone);
	CreateNative("Zone_IsClientInZone", Native_BackwardsCompIsClientInZone);
	CreateNative("fuckZones_IsClientInZoneIndex", Native_IsClientInZoneIndex);
	CreateNative("fuckZones_TeleportClientToZone", Native_TeleportClientToZone);
	CreateNative("fuckZones_TeleportClientToZoneIndex", Native_TeleportClientToZoneIndex);
	CreateNative("fuckZones_GetEffectsList", Native_GetEffectsList);
	CreateNative("fuckZones_GetZoneEffects", Native_GetZoneEffects);
	CreateNative("fuckZones_GetZoneType", Native_GetZoneType);
	CreateNative("fuckZones_GetZoneName", Native_GetZoneName);
	CreateNative("fuckZones_GetColorNameByCode", Native_GetColorNameByCode);
	CreateNative("fuckZones_GetColorCodeByName", Native_GetColorCodeByName);
	CreateNative("fuckZones_GetDisplayNameByType", Native_GetDisplayNameByType);
	CreateNative("fuckZones_GetDisplayTypeByName", Native_GetDisplayTypeByName);
	CreateNative("fuckZones_GetZoneList", Native_GetZoneList);
	CreateNative("fuckZones_IsPointInZone", Native_IsPointInZone);
	CreateNative("fuckZones_GetClientZone", Native_GetClientZone);

	Forward.OnEffectsReady      = new GlobalForward("fuckZones_OnEffectsReady", ET_Ignore);
	Forward.StartTouchZone      = new GlobalForward("fuckZones_OnStartTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	Forward.TouchZone           = new GlobalForward("fuckZones_OnTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	Forward.EndTouchZone        = new GlobalForward("fuckZones_OnEndTouchZone", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	Forward.StartTouchZone_Post = new GlobalForward("fuckZones_OnStartTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	Forward.TouchZone_Post      = new GlobalForward("fuckZones_OnTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	Forward.EndTouchZone_Post   = new GlobalForward("fuckZones_OnEndTouchZone_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	Forward.OnZoneCreate        = new GlobalForward("fuckZones_OnZoneCreate", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	Forward.OnEffectUpdate      = new GlobalForward("fuckZones_OnEffectUpdate", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("fuckZones.phrases");

	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("fuckZones");
	g_cPrecisionValue      = AutoExecConfig_CreateConVar("fuckZones_precision_offset", "10.0", "Default precision value when setting a zones precision area (Default: 10.0).", _, true, 1.0);
	g_cRegenerateSpam      = AutoExecConfig_CreateConVar("fuckZones_regenerate_spam", "10", "Amount of time before zones can be regenerated again (spam protection) (0 to disable this feature, Default: 10)", _, true, 0.0);
	g_cDefaultHeight       = AutoExecConfig_CreateConVar("fuckZones_default_height", "256", "Default height (z-axis) for circles and polygons zones (Default: 256)");
	g_cDefaultRadius       = AutoExecConfig_CreateConVar("fuckZones_default_radius", "150", "Default radius for circle zones (Default: 150)");
	g_cDefaultZOffset      = AutoExecConfig_CreateConVar("fuckZones_default_z_offset", "5", "Adds a offset to the z-axis for all points. (Default: 5)");
	g_cDefaultColor        = AutoExecConfig_CreateConVar("fuckZones_default_color", "Pink", "Default zone color (Default: Pink)");
	g_cDefaultDisplay      = AutoExecConfig_CreateConVar("fuckZones_default_display", "1", "Default zone display (0 - Full, 1 - Bottom (Default), 2 - Hide)", _, true, 0.0, true, 2.0);
	g_cEnableLogging       = AutoExecConfig_CreateConVar("fuckZones_enable_logging", "1", "Enable logging? (Default: 1)", _, true, 0.0, true, 1.0);
	g_cMaxRadius           = AutoExecConfig_CreateConVar("fuckZones_max_radius", "512", "Set's the maximum radius value for circle zones. (Default: 512)");
	g_cMaxHeight           = AutoExecConfig_CreateConVar("fuckZones_max_height", "512", "Set's the maximum height value for circle/poly zones. (Default: 512)");
	g_cNameRegex           = AutoExecConfig_CreateConVar("fuckZones_name_regex", "^[a-zA-Z0-9 _]+$", "Allowed characters in zone name. (Default: \"^[a-zA-Z0-9 _]+$\"");
	g_cDisableCZZones      = AutoExecConfig_CreateConVar("fuckZones_disable_circle_polygon_zones", "0", "Disable circle and polygon zones for better performance?", _, true, 0.0, true, 1.0);
	g_cTeleportLowestPoint = AutoExecConfig_CreateConVar("fuckZones_teleport_lowest_point", "1", "Teleport the entity/client to the lowest point of a zone (from zone middle X/Y/Z based)?", _, true, 0.0, true, 1.0);
	g_cCheckZoneNameExist  = AutoExecConfig_CreateConVar("fuckZones_check_zone_name_exist", "1", "Check if a zone exist with the same name. This prevents double spawning zones", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEventEx("teamplay_round_start", Event_RoundStart);
	HookEventEx("teamplay_round_win", Event_RoundEnd);
	HookEventEx("round_start", Event_RoundStart);
	HookEventEx("round_end", Event_RoundEnd);
	HookEventEx("player_death", Event_PlayerDeath);

	RegAdminCmd("sm_zone", Command_EditZoneMenu, ADMFLAG_ROOT, "Edit a certain zone that you're standing in.");
	RegAdminCmd("sm_editzone", Command_EditZoneMenu, ADMFLAG_ROOT, "Edit a certain zone that you're standing in.");
	RegAdminCmd("sm_editzonemenu", Command_EditZoneMenu, ADMFLAG_ROOT, "Edit a certain zone that you're standing in.");
	RegAdminCmd("sm_zones", Command_OpenZonesMenu, ADMFLAG_ROOT, "Display the zones manager menu.");
	RegAdminCmd("sm_zonesmenu", Command_OpenZonesMenu, ADMFLAG_ROOT, "Display the zones manager menu.");
	RegAdminCmd("sm_teleporttozone", Command_TeleportToZone, ADMFLAG_ROOT, "Teleport to a specific zone by name or by menu.");
	RegAdminCmd("sm_regeneratezones", Command_RegenerateZones, ADMFLAG_ROOT, "Regenerate all zones on the map.");
	RegAdminCmd("sm_deleteallzones", Command_DeleteAllZones, ADMFLAG_ROOT, "Delete all zones on the map.");
	RegAdminCmd("sm_reloadeffects", Command_ReloadEffects, ADMFLAG_ROOT, "Reload all effects data and their callbacks.");
	RegAdminCmd("sm_setprecision", Command_SetPrecision, ADMFLAG_ROOT, "Set your precision value");
	RegAdminCmd("sm_zoneconvert", Command_ZonesConvert, ADMFLAG_ROOT, "Convert devZones configs to fuckZones");
	RegAdminCmd("sm_zonesconvert", Command_ZonesConvert, ADMFLAG_ROOT, "Convert devZones configs to fuckZones");

	g_aZoneEntities = new ArrayList();

	g_smEffectCalls = new StringMap();
	g_smEffectKeys  = new StringMap();
	g_aEffectsList  = new ArrayList(ByteCountToCells(MAX_EFFECT_NAME_LENGTH));

	g_aColors     = new ArrayList(ByteCountToCells(64));
	g_smColorData = new StringMap();

	g_coPrecision = RegClientCookie("fuckZones_precision", "Set client precision value", CookieAccess_Public);

	g_iRegenerationTime = -1;

	for (int i = 1; i <= MaxClients; i++)
	{
		for (int x = MaxClients; x < MAX_ENTITY_LIMIT; x++)
		{
			g_bIsInZone[i][x] = false;
		}
	}

	ReparseMapZonesConfig();

	CreateTimer(TIMER_INTERVAL, Timer_DisplayZones, _, TIMER_REPEAT);

	CSetPrefix("{darkred}[fuckZones] {default}");
}

public void OnMapStart()
{
	g_iRegenerationTime  = -1;
	g_iDefaultModelIndex = PrecacheModel(DEFAULT_MODELINDEX, true);
	g_iDefaultHaloIndex  = PrecacheModel(DEFAULT_HALOINDEX, true);
	PrecacheModel(ZONE_MODEL, true);

	ReparseMapZonesConfig();

	for (int i = 1; i <= MaxClients; i++)
	{
		for (int x = MaxClients; x < MAX_ENTITY_LIMIT; x++)
		{
			g_bIsInZone[i][x] = false;
		}
	}

	delete g_aMapZones;
	g_aMapZones = new ArrayList();

	RegenerateZones();
}

public void OnMapEnd()
{
	SaveMapConfig();
	delete g_kvConfig;
	delete g_aMapZones;
}

void ReparseMapZonesConfig(bool delete_config = false)
{
	delete g_kvConfig;

	char sFolder[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFolder, sizeof(sFolder), "data/zones/");
	CreateDirectory(sFolder, 511);

	char sMap[32];
	fuckZones_GetCurrentWorkshopMap(sMap, sizeof(sMap));

	char sFile[PLATFORM_MAX_PATH];
	Format(sFile, sizeof(sFile), "%s%s.zon", sFolder, sMap);

	if (delete_config)
	{
		DeleteFile(sFile);
	}

	g_kvConfig = new KeyValues("zones");

	if (FileExists(sFile))
	{
		g_kvConfig.ImportFromFile(sFile);
	}
	else
	{
		g_kvConfig.ExportToFile(sFile);
	}
}

public void OnConfigsExecuted()
{
	ParseColorsData();

	if (g_bLate)
	{
		SpawnAllZones();

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				OnClientConnected(i);
				OnClientPutInServer(i);
			}

			if (AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}

		g_bLate = false;
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
		for (int i = 0; i < g_aEffectsList.Length; i++)
		{
			char sEffect[MAX_EFFECT_NAME_LENGTH];
			g_aEffectsList.GetString(i, sEffect, sizeof(sEffect));

			Handle callbacks[MAX_EFFECT_CALLBACKS];
			g_smEffectCalls.GetArray(sEffect, callbacks, sizeof(callbacks));

			for (int x = 0; x < MAX_EFFECT_CALLBACKS; x++)
			{
				delete callbacks[x];
			}
		}

		g_smEffectCalls.Clear();
		g_aEffectsList.Clear();
	}

	Call_StartForward(Forward.OnEffectsReady);
	Call_Finish();
}

public void OnPluginEnd()
{
	ClearAllZones();
}

public void OnClientConnected(int client)
{
	g_fPrecision[client] = g_cPrecisionValue.FloatValue;
}

public void OnClientPutInServer(int client)
{
	g_smSites[client] = new StringMap();
}

public void OnClientCookiesCached(int client)
{
	char sValue[12];
	GetClientCookie(client, g_coPrecision, sValue, sizeof(sValue));

	if (strlen(sValue) == 0)
	{
		g_fPrecision[client] = g_cPrecisionValue.FloatValue;

		char sBuffer[12];
		g_cPrecisionValue.GetString(sBuffer, sizeof(sBuffer));
		SetClientCookie(client, g_coPrecision, sBuffer);
	}
	else
	{
		g_fPrecision[client] = StringToFloat(sValue);
	}
}

public void OnClientDisconnect(int client)
{
	g_iLastButtons[client] = 0;

	for (int i = 0; i < MAX_ENTITY_LIMIT; i++)
	{
		g_bIsInZone[client][i] = false;
	}

	delete g_smSites[client];
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Accounts for L4D2 having rounds start earlier than OnMapStart
	if (IsModelPrecached(ZONE_MODEL))
		RegenerateZones();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			CancelClientMenu(i);

			for (int zone = MaxClients; zone < MAX_ENTITY_LIMIT; zone++)
			{
				if (!g_bIsInZone[i][zone])
				{
					continue;
				}

				Zones_EndTouchPost(zone, i);
			}
		}
	}

	ClearAllZones();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
	{
		return;
	}

	for (int zone = MaxClients; zone < MAX_ENTITY_LIMIT; zone++)
	{
		if (!g_bIsInZone[client][zone])
		{
			continue;
		}

		Zones_EndTouchPost(zone, client);
	}
}

void ClearAllZones()
{
	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(zone))
		{
			StringMapSnapshot snap = Zone[zone].Effects.Snapshot();
			char              sKey[128];
			for (int j = 0; j < snap.Length; j++)
			{
				snap.GetKey(j, sKey, sizeof(sKey));

				StringMap temp = null;
				Zone[zone].Effects.GetValue(sKey, temp);
				delete temp;
			}
			delete snap;
			delete Zone[zone].Effects;
			delete Zone[zone].PointsData;

			RemoveEntity(zone);
		}
	}

	g_aZoneEntities.Clear();
}

void SpawnAllZones()
{
	if (g_kvConfig == null)
	{
		return;
	}

	if (g_cEnableLogging.BoolValue)
	{
		LogMessage("Spawning all zones...");
	}

	g_kvConfig.Rewind();
	if (g_kvConfig.GotoFirstSubKey(false))
	{
		g_aUpdateZones = new ArrayList(sizeof(eUpdateData));
		do
		{
			char sName[MAX_ZONE_NAME_LENGTH];
			g_kvConfig.GetSectionName(sName, sizeof(sName));

			SpawnZone(sName);
		}
		while (g_kvConfig.GotoNextKey(false));

		UpdateZoneData();
	}

	if (g_cEnableLogging.BoolValue)
	{
		LogMessage("Zones have been spawned.");
	}
}

int SpawnAZone(const char[] name)
{
	if (g_kvConfig == null)
	{
		return -1;
	}

	g_kvConfig.Rewind();
	if (g_kvConfig.JumpToKey(name))
	{
		return SpawnZone(name);
	}

	return -1;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (strlen(sArgs) == 0)
	{
		return Plugin_Stop;
	}

	if (StrContains(sArgs, "!cancel", true) != -1)
	{
		if (CZone[client].SetName)
		{
			CZone[client].SetName = false;
			OpenCreateZonesMenu(client);
		}
		else if (g_bEffectKeyValue[client])
		{
			g_bEffectKeyValue[client] = false;
			ListZoneEffectKeys(client, g_iEffectKeyValue_Entity[client], g_sEffectKeyValue_Effect[client]);
		}
		else if (g_iEditingName[client] != INVALID_ENT_REFERENCE)
		{
			int entity             = EntRefToEntIndex(g_iEditingName[client]);
			g_iEditingName[client] = INVALID_ENT_REFERENCE;
			OpenZonePropertiesMenu(client, entity);
		}

		return Plugin_Stop;
	}

	if (CZone[client].SetName)
	{
		if (!CheckZoneName(client, sArgs))
		{
			return Plugin_Stop;
		}

		strcopy(CZone[client].Name, MAX_ZONE_NAME_LENGTH, sArgs);
		CZone[client].SetName = false;
		OpenCreateZonesMenu(client);

		return Plugin_Stop;
	}
	else if (g_bEffectKeyValue[client])
	{
		g_bEffectKeyValue[client] = false;

		char sValue[MAX_KEY_VALUE_LENGTH];
		strcopy(sValue, sizeof(sValue), sArgs);

		bool success = UpdateZoneEffectKey(g_iEffectKeyValue_Entity[client], g_sEffectKeyValue_Effect[client], g_sEffectKeyValue_EffectKey[client], sValue);

		char sName[MAX_ZONE_NAME_LENGTH];
		GetZoneNameByIndex(g_iEffectKeyValue_Entity[client], sName, sizeof(sName));

		if (success)
		{
			CPrintToChat(client, "%T", "Chat - Effect Key Update", client, g_sEffectKeyValue_Effect[client], g_sEffectKeyValue_EffectKey[client], sName, sValue);
		}

		ListZoneEffectKeys(client, g_iEffectKeyValue_Entity[client], g_sEffectKeyValue_Effect[client]);

		return Plugin_Stop;
	}

	if (g_iEditingName[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iEditingName[client]);

		if (!CheckZoneName(client, sArgs))
		{
			return Plugin_Stop;
		}

		char sName[MAX_ZONE_NAME_LENGTH];
		GetZoneNameByIndex(entity, sName, sizeof(sName));

		entity = RemakeZoneEntity(entity);

		CPrintToChat(client, "%T", "Chat - Zone Renamed", client, sName, sArgs);
		g_iEditingName[client] = INVALID_ENT_REFERENCE;

		OpenZonePropertiesMenu(client, entity);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	// Thanks to psychonic for this
	// https://forums.alliedmods.net/showpost.php?p=1421146&postcount=1
	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);

		if ((buttons & button))
		{
			if (!(g_iLastButtons[client] & button))
			{
				OnButtonPress(client, button);
			}
		}
		/* else if ((g_iLastButtons[client] & button))
		{
		    OnButtonRelease(client, button);
		} */
	}

	g_iLastButtons[client] = buttons;

	if (IsPlayerAlive(client))
	{
		float vecPosition[3], vecEyePosition[3];
		GetClientAbsOrigin(client, vecPosition);
		GetClientEyePosition(client, vecEyePosition);

		if (!g_cDisableCZZones.BoolValue)
		{
			for (int i = 0; i < g_aZoneEntities.Length; i++)
			{
				int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

				if (IsValidEntity(zone))
				{
					switch (GetZoneTypeByIndex(zone))
					{
						case ZONE_TYPE_CIRCLE:
						{
							if (IsPointInCircle(vecPosition, vecEyePosition, zone))
							{
								Action action = IsNearExternalZone(client, zone, ZONE_TYPE_CIRCLE);

								if (action <= Plugin_Changed)
								{
									IsNearExternalZone_Post(client, zone, ZONE_TYPE_CIRCLE);
								}
							}
							else
							{
								Action action = IsNotNearExternalZone(client, zone, ZONE_TYPE_CIRCLE);

								if (action <= Plugin_Changed)
								{
									IsNotNearExternalZone_Post(client, zone, ZONE_TYPE_CIRCLE);
								}
							}
						}

						case ZONE_TYPE_POLY:
						{
							float origin[3];
							origin[0] = vecPosition[0];
							origin[1] = vecPosition[1];
							origin[2] = vecPosition[2];

							origin[2] += 42.5;

							static float offset = 16.5;
							float        clientpoints[4][3];

							clientpoints[0] = origin;
							clientpoints[0][0] -= offset;
							clientpoints[0][1] -= offset;

							clientpoints[1] = origin;
							clientpoints[1][0] += offset;
							clientpoints[1][1] -= offset;

							clientpoints[2] = origin;
							clientpoints[2][0] -= offset;
							clientpoints[2][1] += offset;

							clientpoints[3] = origin;
							clientpoints[3][0] += offset;
							clientpoints[3][1] += offset;

							bool IsInZone;
							for (int x = 0; x < 4; x++)
							{
								if (IsPointInZone(clientpoints[x], zone))
								{
									IsInZone = true;
									break;
								}
							}

							if (IsInZone)
							{
								Action action = IsNearExternalZone(client, zone, ZONE_TYPE_POLY);

								if (action <= Plugin_Changed)
								{
									IsNearExternalZone_Post(client, zone, ZONE_TYPE_POLY);
								}
							}
							else
							{
								Action action = IsNotNearExternalZone(client, zone, ZONE_TYPE_POLY);

								if (action <= Plugin_Changed)
								{
									IsNotNearExternalZone_Post(client, zone, ZONE_TYPE_POLY);
								}
							}
						}
					}
				}
			}
		}

		if (CZone[client].Show && CZone[client].Display >= 0 && CZone[client].Display < DISPLAY_TYPE_HIDE && CZone[client].Type > ZONE_TYPE_NONE)
		{
			CZone[client].Show = false;
			int iColor[4];

			iColor[0] = 255;
			iColor[1] = 20;
			iColor[2] = 147;
			iColor[3] = 255;

			if (strlen(CZone[client].Color) > 0)
			{
				g_smColorData.GetArray(CZone[client].Color, iColor, sizeof(iColor));
			}

			float fPoint[3];
			GetClientLookPoint(client, fPoint);
			fPoint[2] += g_cDefaultZOffset.FloatValue;

			switch (CZone[client].Type)
			{
				case ZONE_TYPE_CIRCLE:
				{
					if (fuckZones_IsPositionNull(CZone[client].Start))
					{
						TE_SetupBeamRingPointToClient(client, fPoint, CZone[client].Radius, CZone[client].Radius + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);

						float fStart[3], fEnd[3];
						for (int j = 0; j < 4; j++)
						{
							fStart = fPoint;
							fEnd   = fPoint;

							if (j < 2)
							{
								fStart[j] += CZone[client].Radius / 2;
								fEnd[j] += CZone[client].Radius / 2;
								fEnd[2] += CZone[client].PointsHeight;
							}
							else
							{
								fStart[j - 2] -= CZone[client].Radius / 2;
								fEnd[j - 2] -= CZone[client].Radius / 2;
								fEnd[2] += CZone[client].PointsHeight;
							}

							TE_SetupBeamPointsToClient(client, fStart, fEnd, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
						}

						float fUpper[3];
						fUpper    = fPoint;
						fUpper[2] = fPoint[2] + CZone[client].PointsHeight;
						TE_SetupBeamRingPointToClient(client, fUpper, CZone[client].Radius, CZone[client].Radius + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);
					}
				}

				case ZONE_TYPE_BOX, ZONE_TYPE_SOLID:
				{
					if ((!fuckZones_IsPositionNull(CZone[client].Start) && fuckZones_IsPositionNull(CZone[client].End)) || (fuckZones_IsPositionNull(CZone[client].Start) && !fuckZones_IsPositionNull(CZone[client].End)))
					{
						float fStart[3];

						if (!fuckZones_IsPositionNull(CZone[client].Start))
						{
							fStart = CZone[client].Start;
						}
						if (!fuckZones_IsPositionNull(CZone[client].End))
						{
							fStart = CZone[client].End;
						}

						TE_DrawBeamBoxToClient(client, fStart, fPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED, CZone[client].Display);
					}
				}

				case ZONE_TYPE_POLY:
				{
					if (CZone[client].PointsData != null && CZone[client].PointsData.Length > 0)
					{
						float fStart[3];
						float fLast[3];

						for (int x = 0; x < CZone[client].PointsData.Length; x++)
						{
							float fBottomStart[3];
							CZone[client].PointsData.GetArray(x, fBottomStart, sizeof(fBottomStart));

							if (x == 0)
							{
								CZone[client].PointsData.GetArray(x, fStart, sizeof(fStart));
							}

							CZone[client].PointsData.GetArray(x, fLast, sizeof(fLast));

							int index;

							if (x + 1 == CZone[client].PointsData.Length)
							{
								float fLastStart[3];
								fLastStart = fBottomStart;
								fLastStart[2] += CZone[client].PointsHeight;
								TE_SetupBeamPointsToClient(client, fLastStart, fBottomStart, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
							}
							else
							{
								index = x + 1;
							}

							float fBottomNext[3];
							CZone[client].PointsData.GetArray(index, fBottomNext, sizeof(fBottomNext));

							TE_SetupBeamPointsToClient(client, fBottomStart, fBottomNext, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);

							float fUpperStart[3];
							fUpperStart = fBottomStart;
							fUpperStart[2] += CZone[client].PointsHeight;

							float fUpperNext[3];
							fUpperNext = fBottomNext;
							fUpperNext[2] += CZone[client].PointsHeight;

							TE_SetupBeamPointsToClient(client, fUpperStart, fUpperNext, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
							TE_SetupBeamPointsToClient(client, fBottomStart, fUpperStart, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
						}

						iColor[0] = 255;
						iColor[1] = 255;
						iColor[2] = 0;
						iColor[3] = 255;

						TE_SetupBeamPointsToClient(client, fLast, fPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
						TE_SetupBeamPointsToClient(client, fStart, fPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);

						float fUpperLast[3];
						fUpperLast = fLast;
						fUpperLast[2] += CZone[client].PointsHeight;

						float fUpperPoint[3];
						fUpperPoint = fPoint;
						fUpperPoint[2] += CZone[client].PointsHeight;

						float fUpperStart[3];
						fUpperStart = fStart;
						fUpperStart[2] += CZone[client].PointsHeight;

						TE_SetupBeamPointsToClient(client, fUpperLast, fUpperPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
						TE_SetupBeamPointsToClient(client, fUpperStart, fUpperPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);

						TE_SetupBeamPointsToClient(client, fUpperPoint, fPoint, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE_CREATE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
					}
				}
			}

			CreateTimer(TIMER_INTERVAL_CREATE, Timer_ResetShow, GetClientUserId(client));
		}
	}

	return Plugin_Continue;
}

void OnButtonPress(int client, int button)
{
	if (button & IN_USE)
	{
		int zone = g_iConfirmZone[client];

		if (zone > 0 && IsValidEntity(zone) && g_iConfirmPoint[client] > -1)
		{
			OpenPolyPointEditMenu(client);
		}
	}
}

/* void OnButtonRelease(int client, int button)
{
    if (client && button)
    {
        // Hello.
    }
} */
public Action Timer_ResetShow(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsClientValid(client))
	{
		CZone[client].Show = true;
	}

	return Plugin_Handled;
}

public Action Command_EditZoneMenu(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}

	FindZoneToEdit(client);
	return Plugin_Handled;
}

public Action Command_OpenZonesMenu(int client, int args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}

	OpenZonesMenu(client);
	return Plugin_Handled;
}

public Action Command_TeleportToZone(int client, int args)
{
	char sArg1[65];
	GetCmdArg(1, sArg1, sizeof(sArg1));

	char sArg2[65];
	GetCmdArg(2, sArg2, sizeof(sArg2));

	switch (args)
	{
		case 0:
		{
			OpenTeleportToZoneMenu(client);
			return Plugin_Handled;
		}
		case 1:
		{
			char sCommand[64];
			GetCmdArg(0, sCommand, sizeof(sCommand));

			CReplyToCommand(client, "%T", "Command - Teleport Usage", client, sCommand);
			return Plugin_Handled;
		}
	}

	char target_name[MAX_TARGET_LENGTH];
	int  target_list[MAXPLAYERS];
	bool tn_is_ml;

	int target_count = ProcessTargetString(sArg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml);

	if (target_count <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		TeleportToZone(client, sArg2);
	}

	return Plugin_Handled;
}

public Action Command_RegenerateZones(int client, int args)
{
	RegenerateZones(client);
	return Plugin_Handled;
}

public Action Command_DeleteAllZones(int client, int args)
{
	DeleteAllZones(client);
	return Plugin_Handled;
}

public Action Command_ReloadEffects(int client, int args)
{
	QueueEffects();
	CReplyToCommand(client, "%T", "Command - Effects Reloaded", client);
	return Plugin_Handled;
}

public Action Command_SetPrecision(int client, int args)
{
	if (!IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (args != 1)
	{
		CReplyToCommand(client, "%T", "Command - Set Precision Usage", client);
		return Plugin_Handled;
	}

	char sArg[12];
	GetCmdArgString(sArg, sizeof(sArg));

	for (int i = 0; i < strlen(sArg); i++)
	{
		if (!IsCharNumeric(sArg[i]))
		{
			CReplyToCommand(client, "%T", "Command - Only Numbers", client);
			return Plugin_Handled;
		}
	}

	g_fPrecision[client] = StringToFloat(sArg);

	char sBuffer[12];
	FloatToString(g_fPrecision[client], sBuffer, sizeof(sBuffer));
	SetClientCookie(client, g_coPrecision, sBuffer);

	CReplyToCommand(client, "%T", "Command - Precision Set", client, g_fPrecision[client]);

	return Plugin_Handled;
}

public Action Command_ZonesConvert(int client, int args)
{
	int iFailedCount = ConvertZones();

	if (iFailedCount == -1)
		ReplyToCommand(client, "Could not parse devzones folder.");

	else if (iFailedCount == 0)
		ReplyToCommand(client, "Successfully converted all devZones configs to fuckZones.");

	else
		ReplyToCommand(client, "%i devZones configs were unable to convert", iFailedCount);

	ReparseMapZonesConfig();

	RegenerateZones(client);

	return Plugin_Handled;
}

void FindZoneToEdit(int client)
{
	int entity = GetEarliestTouchZone(client);

	if (entity == -1 || !IsValidEntity(entity))
	{
		CPrintToChat(client, "%T", "Chat - You are not in a Zone", client);
		return;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	OpenEditZoneMenu(client, entity);
}

int GetEarliestTouchZone(int client)
{
	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(zone) && g_bIsInZone[client][zone])
		{
			return zone;
		}
	}

	return -1;
}

void OpenZonesMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ZonesMenu);
	menu.SetTitle("%T", "Menu - Title - Zone Main", client);

	AddItemFormat(menu, "create", _, "%T", "Menu - Item - Create Zones", client);
	AddItemFormat(menu, "manage", _, "%T", "Menu - Item - Manage Zones New Line", client);
	AddItemFormat(menu, "regenerate", _, "%T", "Menu - Item - Regenerate Zones", client);
	AddItemFormat(menu, "deleteall", _, "%T", "Menu - Item - Delete All Zones", client);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "manage"))
			{
				OpenManageZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "create"))
			{
				OpenCreateZonesMenu(param1, true);
			}
			else if (StrEqual(sInfo, "regenerate"))
			{
				RegenerateZones(param1);
				OpenZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "deleteall"))
			{
				DeleteAllZones(param1, true);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenTeleportToZoneMenu(int client)
{
	Menu menu = new Menu(MenuHandler_TeleportToZoneMenu);
	menu.SetTitle("%T", "Menu - Title - Teleport To", client);

	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(zone))
		{
			char sEntity[12];
			IntToString(zone, sEntity, sizeof(sEntity));

			char sName[MAX_ZONE_NAME_LENGTH];
			GetZoneNameByIndex(zone, sName, sizeof(sName));

			menu.AddItem(sEntity, sName);
		}
	}

	if (menu.ItemCount == 0)
	{
		AddItemFormat(menu, "", ITEMDRAW_DISABLED, "%T", "Menu - Item - No Zones", client);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TeleportToZoneMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sEntity[64];
			char sName[MAX_ZONE_NAME_LENGTH];
			menu.GetItem(param2, sEntity, sizeof(sEntity), _, sName, sizeof(sName));

			TeleportToZone(param1, sName);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

bool RegenerateZones(int client = -1)
{
	if (client == -1)
	{
		g_iRegenerationTime = -1;
	}

	if (g_iRegenerationTime > 0 && GetTime() < (g_iRegenerationTime + g_cRegenerateSpam.IntValue))
	{
		if (IsClientValid(client))
		{
			CReplyToCommand(client, "%T", "Command - Active Regenerate Spam Protection", client);
		}
		else
		{
			PrintToServer("%T", "Command - Active Regenerate Spam Protection", LANG_SERVER);
		}

		return false;
	}

	g_iRegenerationTime = GetTime();

	ClearAllZones();
	SpawnAllZones();

	if (IsClientValid(client))
	{
		CReplyToCommand(client, "%T", "Command - All Zones Regenerated", client);
	}

	return false;
}

void DeleteAllZones(int client = -1, bool confirmation = true)
{
	if (!IsClientValid(client))
	{
		ClearAllZones();
		ReparseMapZonesConfig(true);
		return;
	}

	if (!confirmation)
	{
		ClearAllZones();
		ReparseMapZonesConfig(true);
		CReplyToCommand(client, "%T", "Command - All Zones Deleted", client);
		return;
	}

	Menu menu = new Menu(MenuHandler_ConfirmDeleteAllZones);
	menu.SetTitle("%T", "Menu - Title - Delete All Zones Confirmation", client);

	AddItemFormat(menu, "No", _, "%T", "Menu - Item - No", client);
	AddItemFormat(menu, "Yes", _, "%T", "Menu - Item - Yes", client);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ConfirmDeleteAllZones(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "No"))
			{
				OpenZonesMenu(param1);
				return 0;
			}

			DeleteAllZones(param1, false);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenManageZonesMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ManageZonesMenu);
	menu.SetTitle("%T", "Menu - Item - Manage Zones", client);

	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(zone))
		{
			char sEntity[12];
			IntToString(zone, sEntity, sizeof(sEntity));

			char sName[MAX_ZONE_NAME_LENGTH];
			GetZoneNameByIndex(zone, sName, sizeof(sName));

			menu.AddItem(sEntity, sName);
		}
	}

	if (menu.ItemCount == 0)
	{
		AddItemFormat(menu, "", ITEMDRAW_DISABLED, "%T", "Menu - Item - No Zones", client);
	}

	menu.ExitBackButton = true;

	int iSite;
	g_smSites[client].GetValue("OpenManageZonesMenu", iSite);
	menu.DisplayAt(client, iSite, MENU_TIME_FOREVER);
}

public int MenuHandler_ManageZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_smSites[param1].SetValue("OpenManageZonesMenu", menu.Selection);

			char sEntity[12];
			char sName[MAX_ZONE_NAME_LENGTH];
			menu.GetItem(param2, sEntity, sizeof(sEntity), _, sName, sizeof(sName));

			OpenEditZoneMenu(param1, StringToInt(sEntity));
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenEditZoneMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	g_bSelectedZone[entity] = true;

	Menu menu = new Menu(MenuHandler_ManageEditMenu);
	menu.SetTitle("%T", "Menu - Title - Manage Zone Name", client, sName);

	AddItemFormat(menu, "edit", _, "%T", "Menu - Item - Edit Zone", client);
	AddItemFormat(menu, "delete", _, "%T", "Menu - Item - Delete Zone", client);
	AddItemFormat(menu, "effects_add", _, "%T", "Menu - Item - Add Effect", client);

	int draw = ITEMDRAW_DISABLED;
	for (int i = 0; i < g_aEffectsList.Length; i++)
	{
		char sEffect[MAX_EFFECT_NAME_LENGTH];
		g_aEffectsList.GetString(i, sEffect, sizeof(sEffect));

		StringMap values = null;
		if (Zone[entity].Effects.GetValue(sEffect, values) && values != null)
		{
			draw = ITEMDRAW_DEFAULT;
			break;
		}
	}

	AddItemFormat(menu, "effects_edit", draw, "%T", "Menu - Item - Edit Effect", client);
	AddItemFormat(menu, "effects_remove", draw, "%T", "Menu - Item - Remove Effect", client);

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ManageEditMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int entity = GetMenuCell(menu, "entity");

			if (StrEqual(sInfo, "edit"))
			{
				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "delete"))
			{
				DisplayConfirmDeleteZoneMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "effects_add"))
			{
				if (!AddZoneEffectMenu(param1, entity))
				{
					OpenEditZoneMenu(param1, entity);
				}
			}
			else if (StrEqual(sInfo, "effects_edit"))
			{
				if (!EditZoneEffectMenu(param1, entity))
				{
					OpenEditZoneMenu(param1, entity);
				}
			}
			else if (StrEqual(sInfo, "effects_remove"))
			{
				if (!RemoveZoneEffectMenu(param1, entity))
				{
					OpenEditZoneMenu(param1, entity);
				}
			}
		}

		case MenuAction_Cancel:
		{
			g_bSelectedZone[GetMenuCell(menu, "entity")] = false;

			if (param2 == MenuCancel_ExitBack)
			{
				OpenManageZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenZonePropertiesMenu(int client, int entity)
{
	if (!IsValidEntity(entity))
	{
		CPrintToChat(client, "%T", "Chat - No Longer Valid", client);
		FindZoneToEdit(client);
		return;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	g_bSelectedZone[entity] = true;

	int iType = GetZoneTypeByIndex(entity);

	if (g_cDisableCZZones.BoolValue && (iType == ZONE_TYPE_POLY || iType == ZONE_TYPE_CIRCLE))
	{
		FindZoneToEdit(client);
		return;
	}

	char sColor[32];
	GetColorNameByCode(Zone[entity].Color, sColor, sizeof(sColor));

	Menu menu = new Menu(MenuHandler_ZonePropertiesMenu);
	menu.SetTitle("%T", "Menu - Title - Edit Zone Name", client, sName);

	int iLength = 0;

	if (iType == ZONE_TYPE_POLY)
	{
		iLength = Zone[entity].PointsData.Length;
	}

	AddZoneMenuItems(client, menu, false, iType, iLength, Zone[entity].Radius, sName, sColor, Zone[entity].Display, Zone[entity].Start, Zone[entity].End);

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;

	int iSite;
	g_smSites[client].GetValue("OpenZonePropertiesMenu", iSite);
	menu.DisplayAt(client, iSite, MENU_TIME_FOREVER);
}

public int MenuHandler_ZonePropertiesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_smSites[param1].SetValue("OpenZonePropertiesMenu", menu.Selection);

			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int entity = GetMenuCell(menu, "entity");

			char sName[MAX_ZONE_NAME_LENGTH];
			GetZoneNameByIndex(entity, sName, sizeof(sName));

			if (StrEqual(sInfo, "name"))
			{
				g_iEditingName[param1] = EntIndexToEntRef(entity);
				CPrintToChat(param1, "%T", "Chat - New Zone Name", param1, sName);
			}
			else if (StrEqual(sInfo, "type"))
			{
				OpenEditZoneTypeMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "display"))
			{
				OpenEditZoneDisplayMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "color"))
			{
				OpenEditZoneColorMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "startpoint_a"))
			{
				float vecLook[3];
				GetClientLookPoint(param1, vecLook);
				vecLook[2] += g_cDefaultZOffset.FloatValue;

				UpdateZonesConfigKeyVector(entity, "start", vecLook);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "startpoint_b"))
			{
				float vecLook[3];
				GetClientLookPoint(param1, vecLook);
				vecLook[2] += g_cDefaultZOffset.FloatValue;

				UpdateZonesConfigKeyVector(entity, "end", vecLook);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "startpoint_a_no_z"))
			{
				float vecStart[3], vecEnd[3];
				GetAbsBoundingBox(entity, vecStart, vecEnd);

				float vecLook[3];
				GetClientLookPoint(param1, vecLook);

				vecStart[0] = vecLook[0];
				vecStart[1] = vecLook[1];

				UpdateZonesConfigKeyVector(entity, "start", vecStart);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "startpoint_b_no_z"))
			{
				float vecStart[3], vecEnd[3];
				GetAbsBoundingBox(entity, vecStart, vecEnd);

				float vecLook[3];
				GetClientLookPoint(param1, vecLook);

				vecEnd[0] = vecLook[0];
				vecEnd[1] = vecLook[1];

				UpdateZonesConfigKeyVector(entity, "end", vecEnd);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "startpoint_a_precision"))
			{
				OpenEditZoneStartPointMenu(param1, entity, true);
			}
			else if (StrEqual(sInfo, "startpoint_b_precision"))
			{
				OpenEditZoneStartPointMenu(param1, entity, false);
			}
			else if (StrEqual(sInfo, "add_radius"))
			{
				Zone[entity].Radius += g_fPrecision[param1];
				Zone[entity].Radius = fuckZones_ClampCell(Zone[entity].Radius, 5.0, g_cMaxRadius.FloatValue);

				char sValue[64];
				FloatToString(Zone[entity].Radius, sValue, sizeof(sValue));
				UpdateZonesConfigKey(entity, "radius", sValue);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "remove_radius"))
			{
				Zone[entity].Radius -= g_fPrecision[param1];
				Zone[entity].Radius = fuckZones_ClampCell(Zone[entity].Radius, 5.0, g_cMaxRadius.FloatValue);

				char sValue[64];
				FloatToString(Zone[entity].Radius, sValue, sizeof(sValue));
				UpdateZonesConfigKey(entity, "radius", sValue);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "add_height"))
			{
				Zone[entity].PointsHeight += g_fPrecision[param1];
				Zone[entity].PointsHeight = fuckZones_ClampCell(Zone[entity].PointsHeight, 5.0, g_cMaxHeight.FloatValue);

				char sValue[64];
				FloatToString(Zone[entity].PointsHeight, sValue, sizeof(sValue));
				UpdateZonesConfigKey(entity, "points_height", sValue);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "remove_height"))
			{
				Zone[entity].PointsHeight -= g_fPrecision[param1];
				Zone[entity].PointsHeight = fuckZones_ClampCell(Zone[entity].PointsHeight, 5.0, g_cMaxHeight.FloatValue);

				char sValue[64];
				FloatToString(Zone[entity].PointsHeight, sValue, sizeof(sValue));
				UpdateZonesConfigKey(entity, "points_height", sValue);

				entity = RemakeZoneEntity(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "add_point"))
			{
				float vLookPoint[3];
				GetClientLookPoint(param1, vLookPoint);
				vLookPoint[2] += g_cDefaultZOffset.FloatValue;

				Zone[entity].PointsData.PushArray(vLookPoint, 3);

				SaveZonePointsData(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "edit_point"))
			{
				OpenPolyEditPointMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "remove_point"))
			{
				int size   = Zone[entity].PointsData.Length;
				int actual = size - 1;

				if (size > 0)
				{
					Zone[entity].PointsData.Resize(actual);
					SaveZonePointsData(entity);
				}

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "clear_points"))
			{
				Zone[entity].PointsData.Clear();
				SaveZonePointsData(entity);

				OpenZonePropertiesMenu(param1, entity);
			}
			else if (StrEqual(sInfo, "set_teleport"))
			{
				GetClientAbsOrigin(param1, Zone[entity].Teleport);
				UpdateZonesConfigKeyVector(entity, "teleport", Zone[entity].Teleport);

				CPrintToChat(param1, "%T", "Chat - Teleport Point Set", param1);

				OpenZonePropertiesMenu(param1, entity);
			}
			else
			{
				OpenZonePropertiesMenu(param1, entity);
			}
		}

		case MenuAction_Cancel:
		{
			g_bSelectedZone[GetMenuCell(menu, "entity")] = false;

			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenEditZoneStartPointMenu(int client, int entity, bool whichpoint, bool create = false, char[] name = "")
{
	char sName[MAX_ZONE_NAME_LENGTH];

	if (!create)
	{
		GetZoneNameByIndex(entity, sName, sizeof(sName));

		g_bSelectedZone[entity] = true;
	}
	else
	{
		strcopy(sName, sizeof(sName), name);

		if (strlen(sName) < 1)
		{
			Format(sName, sizeof(sName), "N/A");
		}
	}

	char sStarting[32], sEnding[32];
	Format(sStarting, sizeof(sStarting), "%T", "Menu - Text - Starting", client);
	Format(sEnding, sizeof(sEnding), "%T", "Menu - Text - Ending", client);

	Menu menu = new Menu(MenuHandler_ZoneEditStartPointMenu);
	menu.SetTitle("%T", "Menu - Title - Edit Zone Point Name", client, whichpoint ? sStarting : sEnding, sName);

	if (whichpoint)
	{
		menu.AddItem("a_add_x", "X +");
		menu.AddItem("a_remove_x", "X -");
		menu.AddItem("a_add_y", "Y +");
		menu.AddItem("a_remove_y", "Y -");
		menu.AddItem("a_add_z", "Z +");
		menu.AddItem("a_remove_z", "Z -");
	}
	else
	{
		menu.AddItem("b_add_x", "X +");
		menu.AddItem("b_remove_x", "X -");
		menu.AddItem("b_add_y", "Y +");
		menu.AddItem("b_remove_y", "Y -");
		menu.AddItem("b_add_z", "Z +");
		menu.AddItem("b_remove_z", "Z -");
	}

	if (!create)
	{
		PushMenuCell(menu, "entity", entity);
	}
	else
	{
		PushMenuCell(menu, "entity", -1);
		PushMenuString(menu, "name", sName);
	}

	PushMenuCell(menu, "whichpoint", whichpoint);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneEditStartPointMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int entity = GetMenuCell(menu, "entity");

			char sName[MAX_ZONE_NAME_LENGTH];
			GetMenuString(menu, "name", sName, sizeof(sName));

			bool bCreate = false;

			if (entity == -1)
			{
				bCreate = true;
			}

			bool whichpoint = view_as<bool>(GetMenuCell(menu, "whichpoint"));

			if (StrEqual(sInfo, "a_add_x"))
			{
				if (!bCreate)
				{
					float vecPointA[3];
					GetZonesVectorData(entity, "start", vecPointA);

					vecPointA[0] += g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "start", vecPointA);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].Start[0] += g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "a_add_y"))
			{
				if (!bCreate)
				{
					float vecPointA[3];
					GetZonesVectorData(entity, "start", vecPointA);

					vecPointA[1] += g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "start", vecPointA);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].Start[1] += g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "a_add_z"))
			{
				if (!bCreate)
				{
					float vecPointA[3];
					GetZonesVectorData(entity, "start", vecPointA);

					vecPointA[2] += g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "start", vecPointA);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].Start[2] += g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "a_remove_x"))
			{
				if (!bCreate)
				{
					float vecPointA[3];
					GetZonesVectorData(entity, "start", vecPointA);

					vecPointA[0] -= g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "start", vecPointA);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].Start[0] -= g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "a_remove_y"))
			{
				if (!bCreate)
				{
					float vecPointA[3];
					GetZonesVectorData(entity, "start", vecPointA);

					vecPointA[1] -= g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "start", vecPointA);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].Start[1] -= g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "a_remove_z"))
			{
				if (!bCreate)
				{
					float vecPointA[3];
					GetZonesVectorData(entity, "start", vecPointA);

					vecPointA[2] -= g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "start", vecPointA);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].Start[2] -= g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "b_add_x"))
			{
				if (!bCreate)
				{
					float vecPointB[3];
					GetZonesVectorData(entity, "end", vecPointB);

					vecPointB[0] += g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "end", vecPointB);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].End[0] += g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "b_add_y"))
			{
				if (!bCreate)
				{
					float vecPointB[3];
					GetZonesVectorData(entity, "end", vecPointB);

					vecPointB[1] += g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "end", vecPointB);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].End[1] += g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "b_add_z"))
			{
				if (!bCreate)
				{
					float vecPointB[3];
					GetZonesVectorData(entity, "end", vecPointB);

					vecPointB[2] += g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "end", vecPointB);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].End[2] += g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "b_remove_x"))
			{
				if (!bCreate)
				{
					float vecPointB[3];
					GetZonesVectorData(entity, "end", vecPointB);

					vecPointB[0] -= g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "end", vecPointB);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].End[0] -= g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "b_remove_y"))
			{
				if (!bCreate)
				{
					float vecPointB[3];
					GetZonesVectorData(entity, "end", vecPointB);

					vecPointB[1] -= g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "end", vecPointB);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].End[1] -= g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
			else if (StrEqual(sInfo, "b_remove_z"))
			{
				if (!bCreate)
				{
					float vecPointB[3];
					GetZonesVectorData(entity, "end", vecPointB);

					vecPointB[2] -= g_fPrecision[param1];

					UpdateZonesConfigKeyVector(entity, "end", vecPointB);

					entity = RemakeZoneEntity(entity);

					OpenEditZoneStartPointMenu(param1, entity, whichpoint);
				}
				else
				{
					CZone[param1].End[2] -= g_fPrecision[param1];
					OpenEditZoneStartPointMenu(param1, -1, whichpoint, true, sName);
				}
			}
		}

		case MenuAction_Cancel:
		{
			int iEntity = GetMenuCell(menu, "entity");

			if (iEntity != -1)
			{
				g_bSelectedZone[GetMenuCell(menu, "entity")] = false;
			}

			if (param2 == MenuCancel_ExitBack)
			{
				if (iEntity != -1)
				{
					OpenZonePropertiesMenu(param1, GetMenuCell(menu, "entity"));
				}
				else
				{
					OpenCreateZonesMenu(param1);
				}
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

int RemakeZoneEntity(int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	DeleteZone(entity);
	return SpawnAZone(sName);
}

void GetZonesVectorData(int entity, const char[] name, float vecdata[3])
{
	if (g_kvConfig == null)
	{
		return;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(sName))
	{
		g_kvConfig.GetVector(name, vecdata);
		g_kvConfig.Rewind();
	}
}

void UpdateZonesConfigKey(int entity, const char[] key, const char[] value)
{
	if (g_kvConfig == null)
	{
		return;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(sName))
	{
		g_kvConfig.SetString(key, value);
		g_kvConfig.Rewind();
	}

	SaveMapConfig();
}

void UpdateZonesConfigKeyVector(int entity, const char[] key, float value[3])
{
	if (g_kvConfig == null)
	{
		return;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(sName))
	{
		g_kvConfig.SetVector(key, value);
		g_kvConfig.Rewind();
	}

	SaveMapConfig();
}

void UpdateZonesConfigKeyVectorByName(const char[] name, const char[] key, float value[3])
{
	if (g_kvConfig == null)
	{
		return;
	}

	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(name))
	{
		g_kvConfig.SetVector(key, value);
		g_kvConfig.Rewind();
	}

	SaveMapConfig();
}

void SaveZonePointsData(int entity)
{
	if (g_kvConfig == null)
	{
		return;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(sName))
	{
		g_kvConfig.DeleteKey("points");

		if (g_kvConfig.JumpToKey("points", true))
		{
			for (int i = 0; i < Zone[entity].PointsData.Length; i++)
			{
				char sID[12];
				IntToString(i, sID, sizeof(sID));

				float coordinates[3];
				Zone[entity].PointsData.GetArray(i, coordinates, sizeof(coordinates));

				g_kvConfig.SetVector(sID, coordinates);
			}
		}

		g_kvConfig.Rewind();
	}

	SaveMapConfig();
}

void OpenEditZoneTypeMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_EditZoneTypeMenu);
	menu.SetTitle("%T", "Menu - Title - Choose Zone Type Name", client, sName);

	for (int i = 1; i < ZONE_TYPES; i++)
	{
		char sID[12];
		IntToString(i, sID, sizeof(sID));

		char sType[MAX_ZONE_TYPE_LENGTH];
		GetZoneNameByType(i, sType, sizeof(sType));

		if (g_cDisableCZZones.BoolValue && (i == ZONE_TYPE_CIRCLE || i == ZONE_TYPE_POLY))
		{
			continue;
		}

		menu.AddItem(sID, sType);
	}

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EditZoneTypeMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			char sType[MAX_ZONE_TYPE_LENGTH];
			menu.GetItem(param2, sID, sizeof(sID), _, sType, sizeof(sType));
			// int type = StringToInt(sID);

			int entity = GetMenuCell(menu, "entity");

			UpdateZonesConfigKey(entity, "type", sType);

			entity = RemakeZoneEntity(entity);

			OpenZonePropertiesMenu(param1, entity);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenEditZoneDisplayMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_EditZoneDisplayMenu);
	menu.SetTitle("%T", "Menu - Title - Choose Display Type Name", client, sName);

	for (int i = 0; i < DISPLAY_TYPE_TYPES; i++)
	{
		char sID[12];
		IntToString(i, sID, sizeof(sID));

		char sType[MAX_ZONE_TYPE_LENGTH];
		GetDisplayNameByType(i, sType, sizeof(sType));

		menu.AddItem(sID, sType);
	}

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EditZoneDisplayMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			char sType[MAX_ZONE_TYPE_LENGTH];
			menu.GetItem(param2, sID, sizeof(sID), _, sType, sizeof(sType));
			int type = StringToInt(sID);

			int entity = GetMenuCell(menu, "entity");

			Zone[entity].Display = type;
			UpdateZonesConfigKey(entity, "display", sType);

			OpenZonePropertiesMenu(param1, entity);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenEditZoneColorMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_EditZoneColorMenu);
	menu.SetTitle("%T", "Menu - Title - Choose Zone Color Name", client, sName);

	for (int i = 0; i < g_aColors.Length; i++)
	{
		char sColor[64];
		g_aColors.GetString(i, sColor, sizeof(sColor));

		int colors[4];
		g_smColorData.GetArray(sColor, colors, sizeof(colors));

		char sVector[64];
		FormatEx(sVector, sizeof(sVector), "%i %i %i %i", colors[0], colors[1], colors[2], colors[3]);

		menu.AddItem(sVector, sColor);
	}

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EditZoneColorMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sVector[64];
			char sColor[64];
			menu.GetItem(param2, sVector, sizeof(sVector), _, sColor, sizeof(sColor));

			int entity = GetMenuCell(menu, "entity");

			UpdateZonesConfigKey(entity, "color", sVector);

			int color[4];
			g_smColorData.GetArray(sColor, color, sizeof(color));
			Zone[entity].Color = color;

			OpenZonePropertiesMenu(param1, entity);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void DisplayConfirmDeleteZoneMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_ManageConfirmDeleteZoneMenu);
	menu.SetTitle("%T", "Menu - Title - Delete Zone Confirmation", client, sName);
	AddItemFormat(menu, "no", _, "%T", "Menu - Item - No", client);
	AddItemFormat(menu, "yes", _, "%T", "Menu - Item - Yes", client);
	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ManageConfirmDeleteZoneMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int entity = GetMenuCell(menu, "entity");

			if (StrEqual(sInfo, "no"))
			{
				OpenEditZoneMenu(param1, entity);
				return 0;
			}

			char sName[MAX_ZONE_NAME_LENGTH];
			GetZoneNameByIndex(entity, sName, sizeof(sName));

			DeleteZone(entity, true, param1);
			CPrintToChat(param1, "%T", "Chat - Zone Deleted", param1, sName);

			OpenManageZonesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenCreateZonesMenu(int client, bool reset = false)
{
	if (reset)
	{
		ResetCreateZoneVariables(client);
	}

	if (!g_cDisableCZZones.BoolValue && CZone[client].Type == ZONE_TYPE_POLY && CZone[client].PointsData == null)
	{
		CZone[client].PointsData = new ArrayList(3);
	}
	else if (CZone[client].Type != ZONE_TYPE_POLY)
	{
		delete CZone[client].PointsData;
	}

	bool bValidPoints = false;
	int  iLength      = 0;

	if (CZone[client].Type == ZONE_TYPE_POLY && CZone[client].PointsData != null)
	{
		iLength = CZone[client].PointsData.Length;

		if (CZone[client].PointsData.Length > 2)
		{
			bValidPoints = true;
		}
	}
	else if (CZone[client].Type == ZONE_TYPE_BOX || CZone[client].Type == ZONE_TYPE_SOLID)
	{
		if (!fuckZones_IsPositionNull(CZone[client].Start) && !fuckZones_IsPositionNull(CZone[client].End))
		{
			bValidPoints = true;
		}
	}
	else if (CZone[client].Type == ZONE_TYPE_TRIGGER)
	{
		if (CZone[client].Type == ZONE_TYPE_TRIGGER && IsValidEntity(CZone[client].Trigger))
		{
			bValidPoints = true;
		}
	}
	else if (CZone[client].Type == ZONE_TYPE_CIRCLE)
	{
		if (!fuckZones_IsPositionNull(CZone[client].Start))
		{
			bValidPoints = true;
		}
	}

	Menu menu = new Menu(MenuHandler_CreateZonesMenu);
	menu.SetTitle("%T", "Menu - Item - Create a Zone", client);

	AddItemFormat(menu, "create", (bValidPoints && CZone[client].Type > ZONE_TYPE_NONE && strlen(CZone[client].Name) > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Create Zone New Line", client);
	AddZoneMenuItems(client, menu, true, CZone[client].Type, iLength, CZone[client].Radius, CZone[client].Name, CZone[client].Color, CZone[client].Display, CZone[client].Start, CZone[client].End);
	menu.ExitBackButton = true;

	int iSite;
	g_smSites[client].GetValue("OpenCreateZonesMenu", iSite);
	menu.DisplayAt(client, iSite, MENU_TIME_FOREVER);
}

public int MenuHandler_CreateZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_smSites[param1].SetValue("OpenCreateZonesMenu", menu.Selection);

			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "name"))
			{
				CZone[param1].SetName = true;
				CPrintToChat(param1, "%T", "Chat - New Zone Name", param1, strlen(CZone[param1].Name) > 0 ? CZone[param1].Name : "N/A");
			}
			else if (StrEqual(sInfo, "trigger"))
			{
				OpenMapZoneList(param1);
			}
			else if (StrEqual(sInfo, "type"))
			{
				CZone[param1].Type++;

				if (CZone[param1].Type > ZONE_TYPES)
				{
					CZone[param1].Type = ZONE_TYPE_BOX;
				}

				OpenZoneTypeMenu(param1);
			}
			else if (StrEqual(sInfo, "startpoint_a"))
			{
				float vLookPoint[3];
				GetClientLookPoint(param1, vLookPoint);
				vLookPoint[2] += g_cDefaultZOffset.FloatValue;
				Array_Copy(vLookPoint, CZone[param1].Start, 3);
				// CPrintToChat(param1, "Starting point: %.2f/%.2f/%.2f", CZone[param1].Start[0], CZone[param1].Start[1], CZone[param1].Start[2]);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "startpoint_b"))
			{
				float vLookPoint[3];
				GetClientLookPoint(param1, vLookPoint);
				vLookPoint[2] += g_cDefaultZOffset.FloatValue;
				Array_Copy(vLookPoint, CZone[param1].End, 3);
				// CPrintToChat(param1, "Ending point: %.2f/%.2f/%.2f", CZone[param1].End[0], CZone[param1].End[1], CZone[param1].End[2]);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "startpoint_a_no_z"))
			{
				float vecLook[3];
				GetClientLookPoint(param1, vecLook);

				CZone[param1].Start[0] = vecLook[0];
				CZone[param1].Start[1] = vecLook[1];

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "startpoint_b_no_z"))
			{
				float vecLook[3];
				GetClientLookPoint(param1, vecLook);

				CZone[param1].End[0] = vecLook[0];
				CZone[param1].End[1] = vecLook[1];

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "startpoint_a_precision"))
			{
				OpenEditZoneStartPointMenu(param1, -1, true, true, CZone[param1].Name);
			}
			else if (StrEqual(sInfo, "startpoint_b_precision"))
			{
				OpenEditZoneStartPointMenu(param1, -1, false, true, CZone[param1].Name);
			}
			else if (StrEqual(sInfo, "add_radius"))
			{
				CZone[param1].Radius += g_fPrecision[param1];
				CZone[param1].Radius = fuckZones_ClampCell(CZone[param1].Radius, 5.0, g_cMaxRadius.FloatValue);
				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "remove_radius"))
			{
				CZone[param1].Radius -= g_fPrecision[param1];
				CZone[param1].Radius = fuckZones_ClampCell(CZone[param1].Radius, 5.0, g_cMaxRadius.FloatValue);
				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "add_height"))
			{
				CZone[param1].PointsHeight += g_fPrecision[param1];
				CZone[param1].PointsHeight = fuckZones_ClampCell(CZone[param1].PointsHeight, 5.0, g_cMaxHeight.FloatValue);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "remove_height"))
			{
				CZone[param1].PointsHeight -= g_fPrecision[param1];
				CZone[param1].PointsHeight = fuckZones_ClampCell(CZone[param1].PointsHeight, 5.0, g_cMaxHeight.FloatValue);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "add_point"))
			{
				float vLookPoint[3];
				GetClientLookPoint(param1, vLookPoint);
				vLookPoint[2] += g_cDefaultZOffset.FloatValue;

				CZone[param1].PointsData.PushArray(vLookPoint, 3);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "remove_point"))
			{
				int size = CZone[param1].PointsData.Length;

				if (size > 0)
				{
					CZone[param1].PointsData.Erase(size - 1);
				}

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "clear_points"))
			{
				CZone[param1].PointsData.Clear();

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "set_teleport"))
			{
				GetClientAbsOrigin(param1, CZone[param1].Teleport);

				CPrintToChat(param1, "%T", "Chat - Teleport Point Set", param1);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "color"))
			{
				OpenZonesColorMenu(param1);
			}
			else if (StrEqual(sInfo, "display"))
			{
				CZone[param1].Display++;

				if (CZone[param1].Display > DISPLAY_TYPE_TYPES)
				{
					CZone[param1].Display = DISPLAY_TYPE_FULL;
				}

				OpenZoneDisplayMenu(param1);
			}
			else if (StrEqual(sInfo, "create"))
			{
				CreateNewZone(param1);
				OpenZonesMenu(param1);
			}
		}

		case MenuAction_Cancel:
		{
			ResetCreateZoneVariables(param1);

			if (param2 == MenuCancel_ExitBack)
			{
				OpenZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

bool AddZoneEffectMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_AddZoneEffect);
	menu.SetTitle("%T", "Menu - Title - Add Effect Zone Name", client, sName);

	for (int i = 0; i < g_aEffectsList.Length; i++)
	{
		char sEffect[MAX_EFFECT_NAME_LENGTH];
		g_aEffectsList.GetString(i, sEffect, sizeof(sEffect));

		int draw = ITEMDRAW_DEFAULT;

		StringMap values = null;
		if (Zone[entity].Effects.GetValue(sEffect, values) && values != null)
		{
			draw = ITEMDRAW_DISABLED;
		}

		menu.AddItem(sEffect, sEffect, draw);
	}

	if (menu.ItemCount == 0)
	{
		AddItemFormat(menu, "", ITEMDRAW_DISABLED, "%T", "Menu - Item - No Effects", client);
	}

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return true;
}

public int MenuHandler_AddZoneEffect(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sEffect[MAX_EFFECT_NAME_LENGTH];
			menu.GetItem(param2, sEffect, sizeof(sEffect));

			int entity = GetMenuCell(menu, "entity");

			AddEffectToZone(entity, sEffect);

			OpenEditZoneMenu(param1, entity);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

bool EditZoneEffectMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_EditZoneEffect);
	menu.SetTitle("%T", "Menu - Title - Pick Effect To Edit", client, sName);

	for (int i = 0; i < g_aEffectsList.Length; i++)
	{
		char sEffect[MAX_EFFECT_NAME_LENGTH];
		g_aEffectsList.GetString(i, sEffect, sizeof(sEffect));

		StringMap values = null;
		if (Zone[entity].Effects.GetValue(sEffect, values) && values != null)
		{
			menu.AddItem(sEffect, sEffect);
		}
	}

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return true;
}

public int MenuHandler_EditZoneEffect(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sEffect[MAX_EFFECT_NAME_LENGTH];
			menu.GetItem(param2, sEffect, sizeof(sEffect));

			int entity = GetMenuCell(menu, "entity");

			ListZoneEffectKeys(param1, entity, sEffect);

			// OpenEditZoneMenu(param1, entity);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
			else if (param2 == MenuCancel_Exit)
			{
				g_bSelectedZone[GetMenuCell(menu, "entity")] = false;
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

bool ListZoneEffectKeys(int client, int entity, const char[] effect)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_EditZoneEffectKeyVaue);
	menu.SetTitle("%T", "Menu - Title - Pick Effet Key To Edit", client, sName);

	StringMap smEffects = null;
	Zone[entity].Effects.GetValue(effect, smEffects);

	if (smEffects != null)
	{
		StringMapSnapshot keys = smEffects.Snapshot();
		for (int i = 0; i < keys.Length; i++)
		{
			char sKey[MAX_KEY_NAME_LENGTH];
			keys.GetKey(i, sKey, sizeof(sKey));

			char sValue[MAX_KEY_VALUE_LENGTH];
			smEffects.GetString(sKey, sValue, sizeof(sValue));

			AddItemFormat(menu, sKey, _, "%T", "Menu - Item - List Effect Key Value", client, sKey, sValue);
		}
		delete keys;

		if (menu.ItemCount == 0)
		{
			delete menu;
			return false;
		}
	}
	else
	{
		delete menu;
		return false;
	}

	PushMenuCell(menu, "entity", entity);
	PushMenuString(menu, "effect", effect);

	g_iEffectKeyValue_Entity[client]       = -1;
	g_sEffectKeyValue_Effect[client][0]    = '\0';
	g_sEffectKeyValue_EffectKey[client][0] = '\0';

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_EditZoneEffectKeyVaue(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iEffectKeyValue_Entity[param1] = GetMenuCell(menu, "entity");
			GetMenuString(menu, "effect", g_sEffectKeyValue_Effect[param1], sizeof(g_sEffectKeyValue_Effect[]));
			menu.GetItem(param2, g_sEffectKeyValue_EffectKey[param1], sizeof(g_sEffectKeyValue_EffectKey[]));

			char sName[MAX_ZONE_NAME_LENGTH];
			GetZoneNameByIndex(g_iEffectKeyValue_Entity[param1], sName, sizeof(sName));

			g_bEffectKeyValue[param1] = true;

			CPrintToChat(param1, "%T", "Chat - Type New Effect Key Value In Chat", param1, g_sEffectKeyValue_Effect[param1], g_sEffectKeyValue_EffectKey[param1], sName);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				EditZoneEffectMenu(param1, GetMenuCell(menu, "entity"));
			}
			else if (param2 == MenuCancel_Exit)
			{
				g_bSelectedZone[GetMenuCell(menu, "entity")] = false;
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

bool AddEffectToZone(int entity, const char[] effect)
{
	if (g_kvConfig == null)
	{
		return false;
	}

	g_kvConfig.Rewind();

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	if (!g_kvConfig.JumpToKey(sName))
	{
		return false;
	}

	if (!g_kvConfig.JumpToKey("effects", true))
	{
		return false;
	}

	if (!g_kvConfig.JumpToKey(effect, true))
	{
		return false;
	}

	StringMap keys = null;
	g_smEffectKeys.GetValue(effect, keys);

	if (keys != null)
	{
		StringMap smKeys = view_as<StringMap>(CloneHandle(keys));
		Zone[entity].Effects.SetValue(effect, smKeys);

		StringMapSnapshot map = smKeys.Snapshot();

		for (int i = 0; i < map.Length; i++)
		{
			char sKey[MAX_KEY_NAME_LENGTH];
			map.GetKey(i, sKey, sizeof(sKey));

			char sValue[MAX_KEY_VALUE_LENGTH];
			smKeys.GetString(sKey, sValue, sizeof(sValue));

			g_kvConfig.SetString(sKey, sValue);
		}

		delete map;
	}

	g_kvConfig.Rewind();

	SaveMapConfig();
	CallZoneEffectUpdate(entity);

	return true;
}

bool UpdateZoneEffectKey(int entity, const char[] effect_name, const char[] key, char[] value)
{
	if (g_kvConfig == null)
	{
		return false;
	}

	g_kvConfig.Rewind();

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	if (!g_kvConfig.JumpToKey(sName))
	{
		return false;
	}

	if (!g_kvConfig.JumpToKey("effects"))
	{
		return false;
	}

	if (!g_kvConfig.JumpToKey(effect_name))
	{
		return false;
	}

	if (strlen(value) == 0)
	{
		StringMap keys = null;
		g_smEffectKeys.GetValue(effect_name, keys);

		keys.GetString(key, value, MAX_KEY_VALUE_LENGTH);
	}

	g_kvConfig.SetString(key, value);
	g_kvConfig.Rewind();

	StringMap smEffects = null;
	Zone[entity].Effects.GetValue(effect_name, smEffects);

	StringMapSnapshot smKeys = smEffects.Snapshot();
	for (int i = 0; i < smKeys.Length; i++)
	{
		char sKey[MAX_KEY_NAME_LENGTH];
		smKeys.GetKey(i, sKey, sizeof(sKey));

		if (StrEqual(sKey, key, false))
		{
			smEffects.SetString(key, value);
			break;
		}
	}

	delete smKeys;

	SaveMapConfig();
	CallZoneEffectUpdate(entity);

	return true;
}

bool RemoveZoneEffectMenu(int client, int entity)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_RemoveZoneEffect);
	menu.SetTitle("%T", "Menu - Title - Pick Effect To Remove", client, sName);

	for (int i = 0; i < g_aEffectsList.Length; i++)
	{
		char sEffect[MAX_EFFECT_NAME_LENGTH];
		g_aEffectsList.GetString(i, sEffect, sizeof(sEffect));

		int draw = ITEMDRAW_DEFAULT;

		StringMap values = null;
		if (!Zone[entity].Effects.GetValue(sEffect, values))
		{
			draw = ITEMDRAW_DISABLED;
		}

		menu.AddItem(sEffect, sEffect, draw);
	}

	PushMenuCell(menu, "entity", entity);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return true;
}

public int MenuHandler_RemoveZoneEffect(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sEffect[MAX_EFFECT_NAME_LENGTH];
			menu.GetItem(param2, sEffect, sizeof(sEffect));

			int entity = GetMenuCell(menu, "entity");

			RemoveEffectFromZone(entity, sEffect);

			OpenEditZoneMenu(param1, entity);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenEditZoneMenu(param1, GetMenuCell(menu, "entity"));
			}
			else if (param2 == MenuCancel_Exit)
			{
				g_bSelectedZone[GetMenuCell(menu, "entity")] = false;
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

bool RemoveEffectFromZone(int entity, const char[] effect)
{
	if (g_kvConfig == null)
	{
		return false;
	}

	g_kvConfig.Rewind();

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	StringMap values = null;
	if (Zone[entity].Effects.GetValue(effect, values))
	{
		delete values;
		Zone[entity].Effects.Remove(effect);
	}

	if (!g_kvConfig.JumpToKey(sName))
	{
		return false;
	}

	if (!g_kvConfig.JumpToKey("effects"))
	{
		return false;
	}

	if (!g_kvConfig.JumpToKey(effect))
	{
		return false;
	}

	g_kvConfig.DeleteThis();
	g_kvConfig.Rewind();

	SaveMapConfig();
	CallZoneEffectUpdate(entity);

	return true;
}

void OpenZoneTypeMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ZoneTypeMenu);
	menu.SetTitle("%T", "Menu - Title - Choose Zone Type Name", client, strlen(CZone[client].Name) > 0 ? CZone[client].Name : "N/A");

	for (int i = 1; i < ZONE_TYPES; i++)
	{
		char sID[12];
		IntToString(i, sID, sizeof(sID));

		char sType[MAX_ZONE_TYPE_LENGTH];
		GetZoneNameByType(i, sType, sizeof(sType));

		if (g_cDisableCZZones.BoolValue && (i == ZONE_TYPE_CIRCLE || i == ZONE_TYPE_POLY))
		{
			continue;
		}

		menu.AddItem(sID, sType);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneTypeMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			char sType[MAX_ZONE_TYPE_LENGTH];
			menu.GetItem(param2, sID, sizeof(sID), _, sType, sizeof(sType));
			int type = StringToInt(sID);

			char sAddendum[256];
			FormatEx(sAddendum, sizeof(sAddendum), " for %s", strlen(CZone[param1].Name) > 0 ? CZone[param1].Name : "N/A");

			CZone[param1].Type = type;
			CPrintToChat(param1, "Zone type%s set to {green}%s{default}.", sAddendum, sType);
			OpenCreateZonesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenCreateZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenZoneDisplayMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ZoneDisplayMenu);
	menu.SetTitle("%T", "Menu - Title - Choose Display Type Name", client, strlen(CZone[client].Name) > 0 ? CZone[client].Name : "N/A");

	for (int i = 0; i < DISPLAY_TYPE_TYPES; i++)
	{
		char sID[12];
		IntToString(i, sID, sizeof(sID));

		char sType[MAX_ZONE_TYPE_LENGTH];
		GetDisplayNameByType(i, sType, sizeof(sType));

		menu.AddItem(sID, sType);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneDisplayMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			char sType[MAX_ZONE_TYPE_LENGTH];
			menu.GetItem(param2, sID, sizeof(sID), _, sType, sizeof(sType));
			int type = StringToInt(sID);

			char sAddendum[256];
			FormatEx(sAddendum, sizeof(sAddendum), " for %s", strlen(CZone[param1].Name) > 0 ? CZone[param1].Name : "N/A");

			CZone[param1].Display = type;
			CPrintToChat(param1, "Display type%s set to {green}%s{default}.", sAddendum, sType);
			OpenCreateZonesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenCreateZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenZonesColorMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ZoneColorMenu);
	menu.SetTitle("%T", "Menu - Title - Choose Zone Color Name", client, strlen(CZone[client].Name) > 0 ? CZone[client].Name : "N/A");

	for (int i = 0; i < g_aColors.Length; i++)
	{
		char sColor[64];
		g_aColors.GetString(i, sColor, sizeof(sColor));
		menu.AddItem(sColor, sColor);
	}

	menu.ExitBackButton = true;
	menu.ExitButton     = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneColorMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			menu.GetItem(param2, CZone[param1].Color, sizeof(eCreateZone::Color));
			CPrintToChat(param1, "%T", "Chat - Color Set To", param1, CZone[param1].Color);
			OpenCreateZonesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenCreateZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void CreateNewZone(int client)
{
	if (strlen(CZone[client].Name) == 0)
	{
		CPrintToChat(client, "%T", "Chat - Zone Name Required", client);
		OpenCreateZonesMenu(client);
		return;
	}

	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(CZone[client].Name))
	{
		g_kvConfig.Rewind();
		CPrintToChat(client, "%T", "Chat - Zone Name Exists", client);
		OpenCreateZonesMenu(client);
		return;
	}

	g_kvConfig.JumpToKey(CZone[client].Name, true);

	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneNameByType(CZone[client].Type, sType, sizeof(sType));
	g_kvConfig.SetString("type", sType);

	CZone[client].iColors[0] = 255;
	CZone[client].iColors[1] = 20;
	CZone[client].iColors[2] = 147;
	CZone[client].iColors[3] = 255;

	if (strlen(CZone[client].Color) > 0)
	{
		g_smColorData.GetArray(CZone[client].Color, CZone[client].iColors, sizeof(eCreateZone::iColors));
	}

	char sColor[64];
	FormatEx(sColor, sizeof(sColor), "%i %i %i %i", CZone[client].iColors[0], CZone[client].iColors[1], CZone[client].iColors[2], CZone[client].iColors[3]);
	g_kvConfig.SetString("color", sColor);

	GetDisplayNameByType(CZone[client].Display, sType, sizeof(sType));
	g_kvConfig.SetString("display", sType);

	g_kvConfig.SetVector("teleport", CZone[client].Teleport);

	switch (CZone[client].Type)
	{
		case ZONE_TYPE_BOX, ZONE_TYPE_SOLID:
		{
			g_kvConfig.SetVector("start", CZone[client].Start);
			g_kvConfig.SetVector("end", CZone[client].End);
		}

		case ZONE_TYPE_TRIGGER:
		{
			g_kvConfig.SetVector("start", CZone[client].Start);
			g_kvConfig.SetVector("end", CZone[client].End);

			float fOrigin[3];
			GetEntPropVector(CZone[client].Trigger, Prop_Data, "m_vecOrigin", fOrigin);
			g_kvConfig.SetVector("origin", fOrigin);
			CZone[client].Origin = fOrigin;
		}

		case ZONE_TYPE_CIRCLE:
		{
			g_kvConfig.SetVector("start", CZone[client].Start);
			g_kvConfig.SetFloat("radius", CZone[client].Radius);
			g_kvConfig.SetFloat("points_height", CZone[client].PointsHeight);
		}

		case ZONE_TYPE_POLY:
		{
			g_kvConfig.SetFloat("points_height", CZone[client].PointsHeight);

			if (g_kvConfig.JumpToKey("points", true))
			{
				for (int i = 0; i < CZone[client].PointsData.Length; i++)
				{
					char sID[12];
					IntToString(i, sID, sizeof(sID));

					float coordinates[3];
					CZone[client].PointsData.GetArray(i, coordinates, sizeof(coordinates));
					g_kvConfig.SetVector(sID, coordinates);
				}
			}
		}
	}

	SaveMapConfig();

	CreateZone(CZone[client], true);
	CPrintToChat(client, "%T", "Chat - Zone Created", client, CZone[client].Name);
	ResetCreateZoneVariables(client);
}

void ResetCreateZoneVariables(int client)
{
	CZone[client].Name[0]   = '\0';
	CZone[client].Color[0]  = '\0';
	CZone[client].Type      = ZONE_TYPE_NONE;
	CZone[client].Start[0]  = 0.0;
	CZone[client].Start[1]  = 0.0;
	CZone[client].Start[2]  = 0.0;
	CZone[client].End[0]    = 0.0;
	CZone[client].End[1]    = 0.0;
	CZone[client].End[2]    = 0.0;
	CZone[client].Origin[0] = 0.0;
	CZone[client].Origin[1] = 0.0;
	CZone[client].Origin[2] = 0.0;
	CZone[client].Radius    = g_cDefaultRadius.FloatValue;
	delete CZone[client].PointsData;
	CZone[client].PointsHeight = g_cDefaultHeight.FloatValue;
	CZone[client].SetName      = false;
	CZone[client].Display      = g_cDefaultDisplay.IntValue;
	CZone[client].Show         = true;
	CZone[client].Trigger      = -1;
}

void GetZoneNameByType(int type, char[] buffer, int size)
{
	switch (type)
	{
		case ZONE_TYPE_NONE: strcopy(buffer, size, "N/A");
		case ZONE_TYPE_BOX: strcopy(buffer, size, "Box");
		case ZONE_TYPE_CIRCLE: strcopy(buffer, size, "Circle");
		case ZONE_TYPE_POLY: strcopy(buffer, size, "Polygon");
		case ZONE_TYPE_TRIGGER: strcopy(buffer, size, "Trigger");
		case ZONE_TYPE_SOLID: strcopy(buffer, size, "Solid");
	}
}

int GetZoneTypeByIndex(int entity)
{
	char sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "trigger_multiple"))
	{
		if (!Zone[entity].Trigger)
		{
			return ZONE_TYPE_BOX;
		}
		else
		{
			return ZONE_TYPE_TRIGGER;
		}
	}
	else if (StrEqual(sClassname, "info_target"))
	{
		return Zone[entity].PointsData != null ? ZONE_TYPE_POLY : ZONE_TYPE_CIRCLE;
	}
	else if (StrEqual(sClassname, "func_brush"))
	{
		return ZONE_TYPE_SOLID;
	}

	return ZONE_TYPE_BOX;
}

int GetZoneTypeByName(const char[] sType)
{
	if (StrEqual(sType, "Box"))
	{
		return ZONE_TYPE_BOX;
	}
	else if (StrEqual(sType, "Circle"))
	{
		return ZONE_TYPE_CIRCLE;
	}
	else if (StrEqual(sType, "Polygon"))
	{
		return ZONE_TYPE_POLY;
	}
	else if (StrEqual(sType, "Trigger"))
	{
		return ZONE_TYPE_TRIGGER;
	}
	else if (StrEqual(sType, "Solid"))
	{
		return ZONE_TYPE_SOLID;
	}

	return ZONE_TYPE_BOX;
}

void GetDisplayNameByType(int type, char[] buffer, int size)
{
	switch (type)
	{
		case DISPLAY_TYPE_HIDE: strcopy(buffer, size, "Hide");
		case DISPLAY_TYPE_BOTTOM: strcopy(buffer, size, "Bottom");
		case DISPLAY_TYPE_FULL: strcopy(buffer, size, "Full");
	}
}

int GetDisplayTypeByName(const char[] sType)
{
	if (StrEqual(sType, "Hide"))
	{
		return DISPLAY_TYPE_HIDE;
	}
	else if (StrEqual(sType, "Bottom"))
	{
		return DISPLAY_TYPE_BOTTOM;
	}
	else if (StrEqual(sType, "Full"))
	{
		return DISPLAY_TYPE_FULL;
	}

	return DISPLAY_TYPE_HIDE;
}

void SaveMapConfig()
{
	if (g_kvConfig == null)
	{
		return;
	}

	char sMap[32];
	fuckZones_GetCurrentWorkshopMap(sMap, sizeof(sMap));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/zones/%s.zon", sMap);

	g_kvConfig.Rewind();
	g_kvConfig.ExportToFile(sPath);
}

public Action Timer_DisplayZones(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		g_iConfirmPoint[i] = -1;

		int zone = g_iConfirmZone[i];

		if (zone > 0 && IsValidEntity(zone))
		{
			float fDistance = -1.0;
			float fPoint[3];

			int   index    = -1;
			float fNearest = -1.0;
			float fNearestPoint[3];

			float fAimPoint[3];
			GetClientLookPoint(i, fAimPoint);

			for (int x = 0; x < Zone[zone].PointsData.Length; x++)
			{
				Zone[zone].PointsData.GetArray(x, fPoint, sizeof(fPoint));
				fDistance = GetVectorDistance(fAimPoint, fPoint);

				if (fDistance < 20.0 && (fDistance < fNearest || fNearest == -1.0))
				{
					index         = x;
					fNearestPoint = fPoint;
					fNearest      = fDistance;
				}
			}

			g_iConfirmPoint[i] = index;

			int iColor[4];
			iColor[0] = 255;
			iColor[1] = 120;
			iColor[2] = 0;
			iColor[3] = 255;

			TE_SetupBeamRingPointToClient(i, fNearestPoint, 15.0, 15.0 + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);
		}

		if (CZone[i].Display != DISPLAY_TYPE_HIDE)
		{
			int iColor[4];

			iColor[0] = 255;
			iColor[1] = 20;
			iColor[2] = 147;
			iColor[3] = 255;

			if (strlen(CZone[i].Color) > 0)
			{
				g_smColorData.GetArray(CZone[i].Color, iColor, sizeof(iColor));
			}

			switch (CZone[i].Type)
			{
				case ZONE_TYPE_BOX, ZONE_TYPE_TRIGGER, ZONE_TYPE_SOLID:
				{
					if (!fuckZones_IsPositionNull(CZone[i].Start) && !fuckZones_IsPositionNull(CZone[i].End))
					{
						TE_DrawBeamBoxToClient(i, CZone[i].Start, CZone[i].End, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED, CZone[i].Display);
					}
				}

				case ZONE_TYPE_CIRCLE:
				{
					if (!g_cDisableCZZones.BoolValue && !fuckZones_IsPositionNull(CZone[i].Start))
					{
						TE_SetupBeamRingPointToClient(i, CZone[i].Start, CZone[i].Radius, CZone[i].Radius + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);

						float fStart[3], fEnd[3];
						for (int j = 0; j < 4; j++)
						{
							fStart = CZone[i].Start;
							fEnd   = CZone[i].Start;

							if (j < 2)
							{
								fStart[j] += CZone[i].Radius / 2;
								fEnd[j] += CZone[i].Radius / 2;
								fEnd[2] += CZone[i].PointsHeight;
							}
							else
							{
								fStart[j - 2] -= CZone[i].Radius / 2;
								fEnd[j - 2] -= CZone[i].Radius / 2;
								fEnd[2] += CZone[i].PointsHeight;
							}

							TE_SetupBeamPointsToClient(i, fStart, fEnd, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
						}

						float fUpper[3];
						fUpper    = CZone[i].Start;
						fUpper[2] = CZone[i].Start[2] + CZone[i].PointsHeight;
						TE_SetupBeamRingPointToClient(i, fUpper, CZone[i].Radius, CZone[i].Radius + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);
					}
				}
			}
		}
	}

	float vecOrigin[3];
	float vecStart[3];
	float vecEnd[3];

	for (int x = 0; x < g_aZoneEntities.Length; x++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(x));

		if (IsValidEntity(zone) && Zone[zone].Display >= 0 && Zone[zone].Display < DISPLAY_TYPE_HIDE)
		{
			GetEntPropVector(zone, Prop_Data, "m_vecOrigin", vecOrigin);

			int iColor[4];
			iColor = Zone[zone].Color;

			if (g_bSelectedZone[zone])
			{
				iColor[0] = 255;
				iColor[1] = 120;
				iColor[2] = 0;
				iColor[3] = 255;
			}

			switch (GetZoneTypeByIndex(zone))
			{
				case ZONE_TYPE_BOX, ZONE_TYPE_TRIGGER, ZONE_TYPE_SOLID:
				{
					GetAbsBoundingBox(zone, vecStart, vecEnd);
					TE_DrawBeamBoxToAll(vecStart, vecEnd, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED, Zone[zone].Display);
				}

				case ZONE_TYPE_CIRCLE:
				{
					if (g_cDisableCZZones.BoolValue)
					{
						continue;
					}

					TE_SetupBeamRingPoint(vecOrigin, Zone[zone].Radius, Zone[zone].Radius + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);
					TE_SendToAll();

					if (Zone[zone].Display == DISPLAY_TYPE_FULL)
					{
						float fStart[3], fEnd[3];
						for (int j = 0; j < 4; j++)
						{
							fStart = Zone[zone].Start;
							fEnd   = Zone[zone].Start;

							if (j < 2)
							{
								fStart[j] += Zone[zone].Radius / 2;
								fEnd[j] += Zone[zone].Radius / 2;
								fEnd[2] += Zone[zone].PointsHeight;
							}
							else
							{
								fStart[j - 2] -= Zone[zone].Radius / 2;
								fEnd[j - 2] -= Zone[zone].Radius / 2;
								fEnd[2] += Zone[zone].PointsHeight;
							}

							TE_SetupBeamPoints(fStart, fEnd, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
							TE_SendToAll();
						}

						float fUpper[3];
						fUpper    = Zone[zone].Start;
						fUpper[2] = Zone[zone].Start[2] + Zone[zone].PointsHeight;
						TE_SetupBeamRingPoint(fUpper, Zone[zone].Radius, Zone[zone].Radius + 0.1, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_AMPLITUDE, iColor, TE_SPEED, TE_FLAGS);
						TE_SendToAll();
					}
				}

				case ZONE_TYPE_POLY:
				{
					if (!g_cDisableCZZones.BoolValue && Zone[zone].PointsData != null && Zone[zone].PointsData.Length > 0)
					{
						for (int y = 0; y < Zone[zone].PointsData.Length; y++)
						{
							float fBottomStart[3];
							Zone[zone].PointsData.GetArray(y, fBottomStart, sizeof(fBottomStart));

							int index;

							if (y + 1 == Zone[zone].PointsData.Length)
							{
								index = 0;
							}
							else
							{
								index = y + 1;
							}

							float fBottomNext[3];
							Zone[zone].PointsData.GetArray(index, fBottomNext, sizeof(fBottomNext));

							TE_SetupBeamPoints(fBottomStart, fBottomNext, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
							TE_SendToAll();

							if (Zone[zone].Display == DISPLAY_TYPE_FULL)
							{
								float fUpperStart[3];
								fUpperStart = fBottomStart;
								fUpperStart[2] += Zone[zone].PointsHeight;

								float fUpperNext[3];
								fUpperNext = fBottomNext;
								fUpperNext[2] += Zone[zone].PointsHeight;

								TE_SetupBeamPoints(fUpperStart, fUpperNext, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
								TE_SendToAll();
								TE_SetupBeamPoints(fBottomStart, fUpperStart, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
								TE_SendToAll();
							}
						}
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

void GetAbsBoundingBox(int entity, float mins[3], float maxs[3])
{
	float origin[3];

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

	mins[0] += origin[0];
	mins[1] += origin[1];
	mins[2] += origin[2];

	maxs[0] += origin[0];
	maxs[1] += origin[1];
	maxs[2] += origin[2];
}

int CreateZone(eCreateZone Data, bool create)
{
	char sType[MAX_ZONE_TYPE_LENGTH], sDType[MAX_ZONE_TYPE_LENGTH];
	GetZoneNameByType(Data.Type, sType, sizeof(sType));
	GetDisplayNameByType(Data.Display, sDType, sizeof(sDType));

	if (g_cDisableCZZones.BoolValue && (Data.Type == ZONE_TYPE_CIRCLE || Data.Type == ZONE_TYPE_POLY))
	{
		return -1;
	}

	if (g_cEnableLogging.BoolValue)
	{
		if (Data.Type == ZONE_TYPE_BOX || Data.Type == ZONE_TYPE_TRIGGER || Data.Type == ZONE_TYPE_SOLID)
		{
			LogMessage("Spawning Zone: %s, Type: %s, Display: %s, Color: {%d,%d,%d,%d}, Start: %.2f/%.2f/%.2f, End: %.2f/%.2f/%.2f", Data.Name, sType, sDType, Data.iColors[0], Data.iColors[1], Data.iColors[2], Data.iColors[3], Data.Start[0], Data.Start[1], Data.Start[2], Data.End[0], Data.End[1], Data.End[2]);
		}
		else if (Data.Type == ZONE_TYPE_CIRCLE)
		{
			LogMessage("Spawning Zone: %s, Type: %s, Display: %s, Color: {%d,%d,%d,%d}, Center Point: %.2f/%.2f/%.2f, Radius: %.1f, Height: %.1f", Data.Name, sType, sDType, Data.iColors[0], Data.iColors[1], Data.iColors[2], Data.iColors[3], Data.Start[0], Data.Start[1], Data.Start[2], Data.Radius, Data.PointsHeight);
		}
		else if (Data.Type == ZONE_TYPE_POLY)
		{
			LogMessage("Spawning Zone: %s, Type: %s, Display: %s, Color: {%d,%d,%d,%d}, Center Point: %.2f/%.2f/%.2f, Points: %d, Height: %.1f", Data.Name, sType, sDType, Data.iColors[0], Data.iColors[1], Data.iColors[2], Data.iColors[3], Data.Start[0], Data.Start[1], Data.Start[2], Data.PointsData.Length, Data.PointsHeight);
		}
	}

	int entity = -1;
	switch (Data.Type)
	{
		case ZONE_TYPE_BOX, ZONE_TYPE_TRIGGER, ZONE_TYPE_SOLID:
		{
			if (Data.Type == ZONE_TYPE_TRIGGER)
			{
				if (!create)
				{
					if (fuckZones_IsPositionNull(Data.Origin) && strlen(Data.OriginName) > 1)
					{
						Data.Trigger = FindEntityByName(Data.OriginName, "trigger_multiple");
					}

					if (!IsValidEntity(Data.Trigger))
					{
						Data.Trigger = GetNearestEntity(Data.Origin, "trigger_multiple");
					}
				}

				if (Data.Trigger > 0 && IsValidEntity(Data.Trigger))
				{
					eUpdateData update;
					strcopy(update.Name, sizeof(eUpdateData::Name), Data.Name);

					update.Origin = view_as<float>({ 0.0, 0.0, 0.0 });
					update.Start  = view_as<float>({ 0.0, 0.0, 0.0 });
					update.End    = view_as<float>({ 0.0, 0.0, 0.0 });

					if (fuckZones_IsPositionNull(Data.Origin))
					{
						GetEntPropVector(Data.Trigger, Prop_Data, "m_vecOrigin", Data.Origin);
						update.Origin = Data.Origin;
					}

					if (fuckZones_IsPositionNull(Data.Start) || fuckZones_IsPositionNull(Data.End))
					{
						GetAbsBoundingBox(Data.Trigger, Data.Start, Data.End);
						update.Start = Data.Start;
						update.End   = Data.End;
					}

					g_aUpdateZones.PushArray(update, sizeof(update));

					RemoveEntity(Data.Trigger);
				}
			}

			bool bSolid = Data.Type == ZONE_TYPE_SOLID;

			if (bSolid)
				entity = CreateEntityByName("func_brush");

			else
				entity = CreateEntityByName("trigger_multiple");

			if (IsValidEntity(entity))
			{
				SetEntityModel(entity, ZONE_MODEL);

				DispatchKeyValue(entity, "targetname", Data.Name);

				if (!bSolid)
				{
					DispatchKeyValue(entity, "spawnflags", "257");
					DispatchKeyValue(entity, "StartDisabled", "0");
					DispatchKeyValue(entity, "wait", "0");
				}

				DispatchSpawn(entity);

				if (!bSolid)
				{
					SetEntProp(entity, Prop_Data, "m_spawnflags", 257);
				}

				SetEntProp(entity, Prop_Data, "m_nSolidType", 2);
				SetEntProp(entity, Prop_Data, "m_fEffects", 32);

				float fMiddle[3];
				GetMiddleOfABox(Data.Start, Data.End, fMiddle);
				TeleportEntity(entity, fMiddle, NULL_VECTOR, NULL_VECTOR);

				// Have the mins always be negative
				for (int i = 0; i < 3; i++)
				{
					Data.Start[i] = Data.Start[i] - fMiddle[i];
					if (Data.Start[i] > 0.0)
					{
						Data.Start[i] *= -1.0;
					}
				}

				// And the maxs always be positive
				for (int i = 0; i < 3; i++)
				{
					Data.End[i] = Data.End[i] - fMiddle[i];
					if (Data.End[i] < 0.0)
					{
						Data.End[i] *= -1.0;
					}
				}

				SetEntPropVector(entity, Prop_Data, "m_vecMins", Data.Start);
				SetEntPropVector(entity, Prop_Data, "m_vecMaxs", Data.End);

				SDKHook(entity, SDKHook_StartTouch, Zones_StartTouch);
				SDKHook(entity, SDKHook_Touch, Zones_Touch);
				SDKHook(entity, SDKHook_EndTouch, Zones_EndTouch);
				SDKHook(entity, SDKHook_StartTouchPost, Zones_StartTouchPost);
				SDKHook(entity, SDKHook_TouchPost, Zones_TouchPost);
				SDKHook(entity, SDKHook_EndTouchPost, Zones_EndTouchPost);
			}
		}
		case ZONE_TYPE_CIRCLE:
		{
			entity = CreateEntityByName("info_target");

			if (IsValidEntity(entity))
			{
				DispatchKeyValue(entity, "targetname", Data.Name);
				DispatchKeyValueVector(entity, "origin", Data.Start);
				DispatchSpawn(entity);
			}
		}

		case ZONE_TYPE_POLY:
		{
			entity = CreateEntityByName("info_target");

			if (IsValidEntity(entity))
			{
				DispatchKeyValue(entity, "targetname", Data.Name);
				DispatchKeyValueVector(entity, "origin", Data.Start);
				DispatchSpawn(entity);

				delete Zone[entity].PointsData;

				if (Data.PointsData != null)
				{
					Zone[entity].PointsData = view_as<ArrayList>(CloneHandle(Data.PointsData));
				}
				else
				{
					Zone[entity].PointsData = new ArrayList(3);
				}

				Zone[entity].PointsHeight = Data.PointsHeight;

				float tempMin[3];
				float tempMax[3];
				float greatdiff;

				for (int i = 0; i < Zone[entity].PointsData.Length; i++)
				{
					float coordinates[3];
					Zone[entity].PointsData.GetArray(i, coordinates, sizeof(coordinates));

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
					Zone[entity].PointsData.GetArray(0, coordinates2, sizeof(coordinates2));

					float diff = CalculateHorizontalDistance(coordinates2, coordinates, false);
					if (diff > greatdiff)
					{
						greatdiff = diff;
					}
				}

				for (int y = 0; y < 3; y++)
				{
					Zone[entity].PointsMin[y] = tempMin[y];
					Zone[entity].PointsMax[y] = tempMax[y];
				}

				Zone[entity].PointsDistance = greatdiff;
			}
		}
	}

	if (IsValidEntity(entity))
	{
		g_aZoneEntities.Push(EntIndexToEntRef(entity));

		Zone[entity].Start        = Data.Start;
		Zone[entity].End          = Data.End;
		Zone[entity].Radius       = Data.Radius;
		Zone[entity].PointsHeight = Data.PointsHeight;
		Zone[entity].Display      = Data.Display;
		Zone[entity].Teleport     = Data.Teleport;

		if (Data.Type == ZONE_TYPE_TRIGGER)
		{
			Zone[entity].Trigger = true;
		}

		if (Zone[entity].Effects != null)
		{
			StringMapSnapshot snap = Zone[entity].Effects.Snapshot();
			char              sKey[128];
			for (int j = 0; j < snap.Length; j++)
			{
				snap.GetKey(j, sKey, sizeof(sKey));

				StringMap temp = null;
				Zone[entity].Effects.GetValue(sKey, temp);
				delete temp;
			}
			delete snap;
		}

		delete Zone[entity].Effects;

		if (Data.Effects != null)
		{
			Zone[entity].Effects = Data.Effects;
		}
		else
		{
			Zone[entity].Effects = new StringMap();
		}

		Zone[entity].Color = Data.iColors;
	}

	if (g_cEnableLogging.BoolValue)
	{
		LogMessage("Zone %s has been spawned %s as a %s zone with the entity index %i.", Data.Name, IsValidEntity(entity) ? "successfully" : "not successfully", sType, entity);
	}

	Call_StartForward(Forward.OnZoneCreate);
	Call_PushCell(entity);
	Call_PushString(Data.Name);
	Call_PushCell(Data.Type);
	Call_Finish();

	return entity;
}

Action IsNearExternalZone(int client, int entity, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Action result = Plugin_Continue;

	if (!g_bIsInsideZone[client][entity])
	{
		Call_StartForward(Forward.StartTouchZone);
		Call_PushCell(client);
		Call_PushCell(entity);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish(result);

		g_bIsInsideZone[client][entity] = true;
	}
	else
	{
		Call_StartForward(Forward.TouchZone);
		Call_PushCell(client);
		Call_PushCell(entity);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish(result);
	}

	return result;
}

Action IsNotNearExternalZone(int client, int entity, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Action result = Plugin_Continue;

	if (g_bIsInsideZone[client][entity])
	{
		Call_StartForward(Forward.EndTouchZone);
		Call_PushCell(client);
		Call_PushCell(entity);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish(result);

		g_bIsInsideZone[client][entity] = false;
	}

	return result;
}

void IsNearExternalZone_Post(int client, int entity, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	if (!g_bIsInsideZone_Post[client][entity])
	{
		CallEffectCallback(entity, client, EFFECT_CALLBACK_ONENTERZONE);

		Call_StartForward(Forward.StartTouchZone_Post);
		Call_PushCell(client);
		Call_PushCell(entity);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish();

		g_bIsInsideZone_Post[client][entity] = true;

		g_bIsInZone[client][entity] = true;
	}
	else
	{
		CallEffectCallback(entity, client, EFFECT_CALLBACK_ONACTIVEZONE);

		Call_StartForward(Forward.TouchZone_Post);
		Call_PushCell(client);
		Call_PushCell(entity);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish();
	}
}

void IsNotNearExternalZone_Post(int client, int entity, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	if (g_bIsInsideZone_Post[client][entity])
	{
		CallEffectCallback(entity, client, EFFECT_CALLBACK_ONLEAVEZONE);

		Call_StartForward(Forward.EndTouchZone_Post);
		Call_PushCell(client);
		Call_PushCell(entity);
		Call_PushString(sName);
		Call_PushCell(type);
		Call_Finish();

		g_bIsInsideZone_Post[client][entity] = false;

		g_bIsInZone[client][entity] = false;
	}
}

public Action Zones_StartTouch(int entity, int other)
{
	int client = other;

	if (!IsClientValid(client))
	{
		return Plugin_Continue;
	}

	g_bIsInZone[client][entity] = true;

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Call_StartForward(Forward.StartTouchZone);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_PushString(sName);
	Call_PushCell(GetZoneTypeByIndex(entity));

	Action result = Plugin_Continue;
	Call_Finish(result);

	return result;
}

public Action Zones_Touch(int entity, int other)
{
	int client = other;

	if (!IsClientValid(client))
	{
		return Plugin_Continue;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	if (!g_bIsInZone[client][entity])
	{
		Zones_StartTouch(entity, client);
		Zones_StartTouchPost(entity, client);
	}

	Call_StartForward(Forward.TouchZone);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_PushString(sName);
	Call_PushCell(GetZoneTypeByIndex(entity));

	Action result = Plugin_Continue;
	Call_Finish(result);

	return result;
}

public Action Zones_EndTouch(int entity, int other)
{
	int client = other;

	if (!IsClientValid(client))
	{
		return Plugin_Continue;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Call_StartForward(Forward.EndTouchZone);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_PushString(sName);
	Call_PushCell(GetZoneTypeByIndex(entity));

	Action result = Plugin_Continue;
	Call_Finish(result);

	return result;
}

public void Zones_StartTouchPost(int entity, int other)
{
	int client = other;

	if (!IsClientValid(client))
	{
		return;
	}

	CallEffectCallback(entity, client, EFFECT_CALLBACK_ONENTERZONE);

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Call_StartForward(Forward.StartTouchZone_Post);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_PushString(sName);
	Call_PushCell(GetZoneTypeByIndex(entity));
	Call_Finish();
}

public void Zones_TouchPost(int entity, int other)
{
	int client = other;

	if (!IsClientValid(client))
	{
		return;
	}

	CallEffectCallback(entity, client, EFFECT_CALLBACK_ONACTIVEZONE);

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Call_StartForward(Forward.TouchZone_Post);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_PushString(sName);
	Call_PushCell(GetZoneTypeByIndex(entity));
	Call_Finish();
}

public void Zones_EndTouchPost(int entity, int other)
{
	int client = other;

	if (!IsClientValid(client))
	{
		return;
	}

	if (g_bIsInZone[client][entity])
	{
		CallEffectCallback(entity, client, EFFECT_CALLBACK_ONLEAVEZONE);
	}

	g_bIsInZone[client][entity] = false;

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	Call_StartForward(Forward.EndTouchZone_Post);
	Call_PushCell(client);
	Call_PushCell(entity);
	Call_PushString(sName);
	Call_PushCell(GetZoneTypeByIndex(entity));
	Call_Finish();
}

void CallEffectCallback(int entity, int client, int callback)
{
	if ((fuckZones_GetZoneType(entity) != ZONE_TYPE_BOX && fuckZones_GetZoneType(entity) != ZONE_TYPE_TRIGGER))
	{
		return;
	}

	char      sEffect[MAX_EFFECT_NAME_LENGTH];
	Handle    callbacks[MAX_EFFECT_CALLBACKS];
	StringMap values = null;
	bool      bCBSuccess;
	bool      bVSuccess;

	for (int i = 0; i < g_aEffectsList.Length; i++)
	{
		g_aEffectsList.GetString(i, sEffect, sizeof(sEffect));

		for (int j = 0; j < MAX_EFFECT_CALLBACKS; j++)
		{
			callbacks[j] = null;
		}

		values = null;

		bCBSuccess = g_smEffectCalls.GetArray(sEffect, callbacks, sizeof(callbacks));
		bVSuccess  = Zone[entity].Effects.GetValue(sEffect, values);

		if (bCBSuccess && bVSuccess && callbacks[callback] != null && GetForwardFunctionCount(callbacks[callback]) > 0)
		{
			Call_StartForward(callbacks[callback]);
			Call_PushCell(client);
			Call_PushCell(entity);
			Call_PushCell(values);
			Call_Finish();
		}
	}
}

void DeleteZone(int entity, bool permanent = false, int client = -1)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(entity, sName, sizeof(sName));

	int index = g_aZoneEntities.FindValue(EntIndexToEntRef(entity));
	g_aZoneEntities.Erase(index);

	StringMapSnapshot snap1 = Zone[entity].Effects.Snapshot();
	char              sKey[128];
	for (int j = 0; j < snap1.Length; j++)
	{
		snap1.GetKey(j, sKey, sizeof(sKey));

		StringMap temp = null;
		Zone[entity].Effects.GetValue(sKey, temp);
		delete temp;
	}
	delete snap1;

	delete Zone[entity].Effects;
	delete Zone[entity].PointsData;

	if (permanent && Zone[entity].Trigger && IsClientInGame(client))
	{
		CPrintToChat(client, "Deleted trigger zones will be available again within the next round, map change or server restart.");
	}

	RemoveEntity(entity);

	if (permanent)
	{
		g_kvConfig.Rewind();
		if (g_kvConfig.JumpToKey(sName))
		{
			g_kvConfig.DeleteThis();
		}

		SaveMapConfig();
	}
}

void RegisterNewEffect(Handle plugin, const char[] effect_name, Function function1 = INVALID_FUNCTION, Function function2 = INVALID_FUNCTION, Function function3 = INVALID_FUNCTION)
{
	if (plugin == null || strlen(effect_name) == 0)
	{
		return;
	}

	Handle callbacks[MAX_EFFECT_CALLBACKS];
	int    index = g_aEffectsList.FindString(effect_name);

	if (index != -1)
	{
		g_smEffectCalls.GetArray(effect_name, callbacks, sizeof(callbacks));

		for (int i = 0; i < MAX_EFFECT_CALLBACKS; i++)
		{
			delete callbacks[i];
		}

		ClearKeys(effect_name);

		g_smEffectCalls.Remove(effect_name);
		g_aEffectsList.Erase(index);
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

	g_smEffectCalls.SetArray(effect_name, callbacks, sizeof(callbacks));
	g_aEffectsList.PushString(effect_name);
}

void RegisterNewEffectKey(const char[] effect_name, const char[] key, const char[] defaultvalue)
{
	StringMap keys = null;

	if (!g_smEffectKeys.GetValue(effect_name, keys) || keys == null)
	{
		keys = new StringMap();
	}

	keys.SetString(key, defaultvalue);
	g_smEffectKeys.SetValue(effect_name, keys);
}

void ClearKeys(const char[] effect_name)
{
	StringMap keys = null;
	if (g_smEffectKeys.GetValue(effect_name, keys))
	{
		delete keys;
		g_smEffectKeys.Remove(effect_name);
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
	bool   bHit   = TR_DidHit(hTrace);

	TR_GetEndPosition(lookposition, hTrace);

	delete hTrace;

	if (beam && !IsNullVector(lookposition) && !IsNullVector(vEyePos))
	{
		int iColor[4];

		iColor[0] = 255;
		iColor[1] = 20;
		iColor[2] = 147;
		iColor[3] = 255;

		if (strlen(CZone[client].Color) > 0)
		{
			g_smColorData.GetArray(CZone[client].Color, iColor, sizeof(iColor));
		}

		TE_SetupBeamPointsToClient(client, vEyePos, lookposition, g_iDefaultModelIndex, g_iDefaultHaloIndex, TE_STARTFRAME, TE_FRAMERATE, TE_LIFE, TE_WIDTH, TE_ENDWIDTH, TE_FADELENGTH, TE_AMPLITUDE, iColor, TE_SPEED);
	}

	return bHit;
}

public bool TraceEntityFilter_NoPlayers(int entity, int contentsMask)
{
	return false;
}

void Array_Copy(const any[] array, any[] newArray, int size)
{
	for (int i = 0; i < size; i++)
	{
		newArray[i] = array[i];
	}
}

void TE_DrawBeamBoxToClient(int client, float bottomCorner[3], float upperCorner[3], int modelIndex, int haloIndex, int startFrame, int frameRate, float life, float width, float endWidth, int fadeLength, float amplitude, const int color[4], int speed, int displayType)
{
	int clients[1];
	clients[0] = client;
	TE_DrawBeamBox(clients, 1, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed, displayType);
}

stock void TE_DrawBeamBoxToAll(float bottomCorner[3], float upperCorner[3], int modelIndex, int haloIndex, int startFrame, int frameRate, float life, float width, float endWidth, int fadeLength, float amplitude, const int color[4], int speed, int displayType)
{
	int[] clients = new int[MaxClients];
	int numClients;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			clients[numClients++] = i;
		}
	}

	TE_DrawBeamBox(clients, numClients, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed, displayType);
}

void TE_DrawBeamBox(int[] clients, int numClients, float bottomCorner[3], float upperCorner[3], int modelIndex, int haloIndex, int startFrame, int frameRate, float life, float width, float endWidth, int fadeLength, float amplitude, const int color[4], int speed, int displayType)
{
	float corners[8][3];

	if (upperCorner[2] < bottomCorner[2])
	{
		float buffer[3];
		buffer       = bottomCorner;
		bottomCorner = upperCorner;
		upperCorner  = buffer;
	}

	for (int i = 0; i < 4; i++)
	{
		Array_Copy(bottomCorner, corners[i], 3);
		Array_Copy(upperCorner, corners[i + 4], 3);
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

	if (displayType == DISPLAY_TYPE_FULL)
	{
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
}

void TE_SetupBeamRingPointToClient(int client, const float center[3], float Start_Radius, float End_Radius, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float Amplitude, const int Color[4], int Speed, int Flags)
{
	TE_SetupBeamRingPoint(center, Start_Radius, End_Radius, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, Color, Speed, Flags);
	TE_SendToClient(client);
}

void TE_SetupBeamPointsToClient(int client, const float start[3], const float end[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed)
{
	TE_SetupBeamPoints(start, end, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
}

void ParseColorsData()
{
	g_aColors.Clear();
	g_smColorData.Clear();

	char sFolder[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFolder, sizeof(sFolder), "configs/fuckZones/");
	CreateDirectory(sFolder, 511);

	char sFile[PLATFORM_MAX_PATH];
	Format(sFile, sizeof(sFile), "%scolors.cfg", sFolder);

	KeyValues kv = new KeyValues("colors");

	int  color[4];
	char sBuffer[64];

	if (FileExists(sFile))
	{
		if (kv.ImportFromFile(sFile) && kv.GotoFirstSubKey(false))
		{
			do
			{
				char sColor[64];
				kv.GetSectionName(sColor, sizeof(sColor));

				kv.GetColor(NULL_STRING, color[0], color[1], color[2], color[3]);

				g_aColors.PushString(sColor);
				g_smColorData.SetArray(sColor, color, sizeof(color));
			}
			while (kv.GotoNextKey(false));
		}
	}
	else
	{
		g_aColors.PushString("Clear");
		color = { 255, 255, 255, 0 };
		g_smColorData.SetArray("Clear", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("Clear", sBuffer);

		g_aColors.PushString("Red");
		color = { 255, 0, 0, 255 };
		g_smColorData.SetArray("Red", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("Red", sBuffer);

		g_aColors.PushString("Green");
		color = { 0, 255, 0, 255 };
		g_smColorData.SetArray("Green", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("Green", sBuffer);

		g_aColors.PushString("Blue");
		color = { 0, 0, 255, 255 };
		g_smColorData.SetArray("Blue", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("Blue", sBuffer);

		g_aColors.PushString("Yellow");
		color = { 255, 255, 0, 255 };
		g_smColorData.SetArray("Yellow", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("Yellow", sBuffer);

		g_aColors.PushString("White");
		color = { 255, 255, 255, 255 };
		g_smColorData.SetArray("White", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("White", sBuffer);

		g_aColors.PushString("Pink");
		color = { 255, 20, 147, 255 };
		g_smColorData.SetArray("Pink", color, sizeof(color));
		FormatEx(sBuffer, sizeof(sBuffer), "%i %i %i %i", color[0], color[1], color[2], color[3]);
		kv.SetString("Pink", sBuffer);

		kv.ExportToFile(sFile);
	}

	delete kv;
	if (g_cEnableLogging.BoolValue)
	{
		LogMessage("Successfully parsed %i colors for zones.", g_aColors.Length);
	}
}

bool TeleportToZone(int client, const char[] zone)
{
	if (!IsClientValid(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	int  entity = -1;
	char sName[MAX_ZONE_NAME_LENGTH];
	bool bFound = false;
	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		entity = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(entity))
		{
			GetZoneNameByIndex(entity, sName, sizeof(sName));

			if (StrContains(sName, zone, false) != -1)
			{
				bFound = true;
				break;
			}
		}
	}

	if (!bFound)
	{
		CPrintToChat(client, "%T", "Chat - Zone Not Found To Teleport", client, zone);
		return false;
	}

	float fMiddle[3];
	int   iType = GetZoneTypeByIndex(entity);

	if (g_cDisableCZZones.BoolValue && (iType == ZONE_TYPE_POLY || iType == ZONE_TYPE_CIRCLE))
	{
		return false;
	}

	switch (iType)
	{
		case ZONE_TYPE_BOX, ZONE_TYPE_TRIGGER:
		{
			if (fuckZones_IsPositionNull(Zone[entity].Teleport))
			{
				float fStart[3], fEnd[3];
				GetAbsBoundingBox(entity, fStart, fEnd);
				GetMiddleOfABox(fStart, fEnd, fMiddle);
			}
			else
			{
				fMiddle = Zone[entity].Teleport;
			}
		}

		case ZONE_TYPE_SOLID:
		{
			bool bNoclip = GetEntityMoveType(client) == MOVETYPE_NOCLIP;

			if (fuckZones_IsPositionNull(Zone[entity].Teleport))
			{
				if (bNoclip)
				{
					float fStart[3], fEnd[3];
					GetAbsBoundingBox(entity, fStart, fEnd);
					GetMiddleOfABox(fStart, fEnd, fMiddle);
				}
				else
				{
					CPrintToChat(client, "%T", "Chat - Teleport - Solid Not Supported", client);
					return false;
				}
			}

			else
				fMiddle = Zone[entity].Teleport;
		}

		case ZONE_TYPE_CIRCLE:
		{
			if (fuckZones_IsPositionNull(Zone[entity].Teleport))
			{
				fMiddle = Zone[entity].Start;
			}
			else
			{
				fMiddle = Zone[entity].Teleport;
			}
		}

		case ZONE_TYPE_POLY:
		{
			if (fuckZones_IsPositionNull(Zone[entity].Teleport))
			{
				CPrintToChat(client, "%T", "Chat - Teleport - Polygons Not Supported", client);
				return false;
			}

			fMiddle = Zone[entity].Teleport;
		}
	}

	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int iZone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(iZone))
		{
			if (iType == ZONE_TYPE_POLY || iType == ZONE_TYPE_CIRCLE)
			{
				if (g_bIsInsideZone[client][iZone])
				{
					IsNotNearExternalZone(client, iZone, GetZoneTypeByIndex(entity));
				}

				if (g_bIsInsideZone_Post[client][iZone] || g_bIsInZone[client][iZone])
				{
					IsNotNearExternalZone_Post(client, iZone, GetZoneTypeByIndex(iZone));
				}
			}
			else
			{
				if (g_bIsInZone[client][iZone])
				{
					Zones_EndTouch(iZone, client);
					Zones_EndTouchPost(iZone, client);
				}
			}
		}
	}

	if (g_cTeleportLowestPoint.BoolValue)
	{
		TR_TraceRayFilter(fMiddle, view_as<float>({ 90.0, 0.0, 0.0 }), MASK_PLAYERSOLID, RayType_Infinite, TraceRayFilter);
		TR_GetEndPosition(fMiddle);
	}

	TeleportEntity(client, fMiddle, NULL_VECTOR, NULL_VECTOR);
	CPrintToChat(client, "%T", "Chat - Teleported To Zone", client, sName);

	return true;
}

bool TraceRayFilter(int entity, int mask, any data)
{
	if (entity != 0)
		return false;
	return true;
}

// Down to just above the natives, these functions are made by 'Deathknife' and repurposed by me for this plugin.
// Fucker can maths
// by Deathknife
bool IsPointInZone(float point[3], int zone)
{
	// Check if point is in the zone
	if (!IsOriginInBox(point, zone))
	{
		return false;
	}

	// Get a ray outside of the polygon
	float ray[3];
	ray = point;
	ray[1] += Zone[zone].PointsDistance + 50.0;
	ray[2] = point[2];

	// Store the x and y intersections of where the ray hits the line
	float xint;
	float yint;

	// Intersections for base bottom and top(2)
	float baseY;
	float baseZ;
	float baseY2;
	float baseZ2;

	// Calculate equation for x + y
	float eq[2];
	eq[0] = point[0] - ray[0];
	eq[1] = point[2] - ray[2];

	// This is for checking if the line intersected the base
	// The method is messy, came up with it myself, and might not work 100% of the time.
	// Should work though.

	// Bottom
	int   lIntersected[64];
	float fIntersect[64][3];

	// Top
	int   lIntersectedT[64];
	float fIntersectT[64][3];

	// Count amount of intersetcions
	int intersections = 0;

	// Count amount of intersection for BASE
	int lIntNum  = 0;
	int lIntNumT = 0;

	// Get slope
	float lSlope = (ray[2] - point[2]) / (ray[1] - point[1]);
	float lEq    = (lSlope & ray[0]) - ray[2];
	lEq          = -lEq;

	// Get second slope
	// float lSlope2 = (ray[1] - point[1]) / (ray[0] - point[0]);
	// float lEq2 = (lSlope2 * point[0]) - point[1];
	// lEq2 = -lEq2;

	// Prevent error spam, but do we break something here? We'll see.
	if (Zone[zone].PointsData == null || Zone[zone].PointsData.Length < 3)
	{
		return false;
	}

	// Loop through every point of the zone
	int size = Zone[zone].PointsData.Length;

	for (int i = 0; i < size; i++)
	{
		// Get current & next point
		float currentpoint[3];
		Zone[zone].PointsData.GetArray(i, currentpoint, sizeof(currentpoint));

		float nextpoint[3];

		// Check if its the last point, if it is, join it with the first
		if (size == i + 1)
		{
			Zone[zone].PointsData.GetArray(0, nextpoint, sizeof(nextpoint));
		}
		else
		{
			Zone[zone].PointsData.GetArray(i + 1, nextpoint, sizeof(nextpoint));
		}

		// Check if the ray intersects the point
		// Ignore the height parameter as we will check against that later
		bool didinter = get_line_intersection(ray[0], ray[1], point[0], point[1], currentpoint[0], currentpoint[1], nextpoint[0], nextpoint[1], xint, yint);

		// Get intersections of the bottom
		bool baseInter = get_line_intersection(ray[1], ray[2], point[1], point[2], currentpoint[1], currentpoint[2], nextpoint[1], nextpoint[2], baseY, baseZ);

		// Get intersections of the top
		bool baseInter2 = get_line_intersection(ray[1], ray[2], point[1], point[2], currentpoint[1] + Zone[zone].PointsHeight, currentpoint[2] + Zone[zone].PointsHeight, nextpoint[1] + Zone[zone].PointsHeight, nextpoint[2] + Zone[zone].PointsHeight, baseY2, baseZ2);

		// If base intersected, store the line for later
		if (baseInter && lIntNum < sizeof(fIntersect))
		{
			lIntersected[lIntNum]  = i;
			fIntersect[lIntNum][1] = baseY;
			fIntersect[lIntNum][2] = baseZ;
			lIntNum++;
		}

		if (baseInter2 && lIntNumT < sizeof(fIntersectT))
		{
			lIntersectedT[lIntNumT]  = i;
			fIntersectT[lIntNumT][1] = baseY2;
			fIntersectT[lIntNum][2]  = baseZ2;
			lIntNumT++;
		}

		// If ray intersected line, check against height
		if (didinter)
		{
			// Get the height of intersection

			// Get slope of line it hit
			float m1 = (nextpoint[2] - currentpoint[2]) / (nextpoint[0] - currentpoint[0]);

			// Equation y = mx + c | mx - y = -c
			float l1 = (m1 * currentpoint[0]) - currentpoint[2];
			l1       = -l1;

			float y2 = (m1 * xint) + l1;

			// Get slope of ray
			float y = (lSlope * xint) + lEq;

			if (y > y2 && y < y2 + 128.0 + Zone[zone].PointsHeight)
			{
				// The ray intersected the line and is within the height
				intersections++;
			}
		}
	}

	// Now we check for base hitting
	// This method is weird, but works most of the time
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

			if (Zone[zone].PointsData.Length == i + 1)
			{
				Zone[zone].PointsData.GetArray(i, currentpoint[0], 3);
				Zone[zone].PointsData.GetArray(0, nextpoint[0], 3);
			}
			else
			{
				Zone[zone].PointsData.GetArray(i, currentpoint[0], 3);
				Zone[zone].PointsData.GetArray(i + 1, nextpoint[0], 3);
			}

			if (Zone[zone].PointsData.Length == j + 1)
			{
				Zone[zone].PointsData.GetArray(j, currentpoint[1], 3);
				Zone[zone].PointsData.GetArray(0, nextpoint[1], 3);
			}
			else
			{
				Zone[zone].PointsData.GetArray(j, currentpoint[1], 3);
				Zone[zone].PointsData.GetArray(j + 1, nextpoint[1], 3);
			}

			// Get equation of both lines then find slope of them
			float m1   = (nextpoint[0][1] - currentpoint[0][1]) / (nextpoint[0][0] - currentpoint[0][0]);
			float m2   = (nextpoint[1][1] - currentpoint[1][1]) / (nextpoint[1][0] - currentpoint[1][0]);
			float lEq1 = (m1 * currentpoint[0][0]) - currentpoint[0][1];
			float lEq2 = (m2 * currentpoint[1][0]) - currentpoint[1][1];
			lEq1       = -lEq1;
			lEq2       = -lEq2;

			// Get x point of intersection
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

			if (Zone[zone].PointsData.Length == i + 1)
			{
				Zone[zone].PointsData.GetArray(i, currentpoint[0], 3);
				Zone[zone].PointsData.GetArray(0, nextpoint[0], 3);
			}
			else
			{
				Zone[zone].PointsData.GetArray(i, currentpoint[0], 3);
				Zone[zone].PointsData.GetArray(i + 1, nextpoint[0], 3);
			}

			if (Zone[zone].PointsData.Length == j + 1)
			{
				Zone[zone].PointsData.GetArray(j, currentpoint[1], 3);
				Zone[zone].PointsData.GetArray(0, nextpoint[1], 3);
			}
			else
			{
				Zone[zone].PointsData.GetArray(j, currentpoint[1], 3);
				Zone[zone].PointsData.GetArray(j + 1, nextpoint[1], 3);
			}

			// Get equation of both lines then find slope of them
			float m1   = (nextpoint[0][1] - currentpoint[0][1]) / (nextpoint[0][0] - currentpoint[0][0]);
			float m2   = (nextpoint[1][1] - currentpoint[1][1]) / (nextpoint[1][0] - currentpoint[1][0]);
			float lEq1 = (m1 * currentpoint[0][0]) - currentpoint[0][1];
			float lEq2 = (m2 * currentpoint[1][0]) - currentpoint[1][1];
			lEq1       = -lEq1;
			lEq2       = -lEq2;

			// Get x point of intersection
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
	if (origin[0] >= Zone[zone].PointsMin[0] && origin[1] >= Zone[zone].PointsMin[1] && origin[2] >= Zone[zone].PointsMin[2] && origin[0] <= Zone[zone].PointsMax[0] + Zone[zone].PointsHeight && origin[1] <= Zone[zone].PointsMax[1] + Zone[zone].PointsHeight && origin[2] <= Zone[zone].PointsMax[2] + Zone[zone].PointsHeight)
	{
		return true;
	}

	return false;
}

bool IsPointInCircle(float origin[3], float origin2[3] = { 0.0, 0.0, 0.0 }, int zone)
{
	float fDisX = FloatAbs((origin[0]) - Zone[zone].Start[0]);
	float fDisY = FloatAbs((origin[1]) - Zone[zone].Start[1]);
	float fRad  = (Zone[zone].Radius / 2.0) + 10.0;

	float fLowest  = Zone[zone].Start[2] - 10.0;
	float fHighest = Zone[zone].Start[2] + Zone[zone].PointsHeight;

	if ((((fDisX * fDisX) + (fDisY * fDisY)) <= fRad * fRad) && ((origin[2] >= fLowest || ((origin2[0] == 0.0 && origin2[1] == 0.0 && origin2[2] == 0.0) || origin2[2] >= fLowest)) && origin[2] <= fHighest))
	{
		return true;
	}

	return false;
}

bool get_line_intersection(float p0_x, float p0_y, float p1_x, float p1_y, float p2_x, float p2_y, float p3_x, float p3_y, float& i_x, float& i_y)
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

	return false;    // No collision
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

// Natives
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

	return 0;
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

	return 0;
}

public int Native_ReloadEffects(Handle plugin, int numParams)
{
	QueueEffects();

	return 0;
}

public int Native_RegenerateZones(Handle plugin, int numParams)
{
	RegenerateZones();

	return 0;
}

public int Native_IsClientInZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return false;
	}

	int size;
	GetNativeStringLength(2, size);

	char[] sName = new char[size + 1];
	GetNativeString(2, sName, size + 1);

	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(zone))
		{
			char sName2[64];
			GetZoneNameByIndex(zone, sName2, sizeof(sName2));

			if (StrEqual(sName, sName2))
			{
				return g_bIsInZone[client][zone];
			}
		}
	}

	return false;
}


public int Native_BackwardsCompIsClientInZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return false;
	}

	int size;
	GetNativeStringLength(2, size);

	char[] sName = new char[size + 1];
	GetNativeString(2, sName, size + 1);
	
	bool equals = GetNativeCell(3);
	bool caseSensitive = GetNativeCell(4);

	for (int i = 0; i < g_aZoneEntities.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aZoneEntities.Get(i));

		if (IsValidEntity(zone))
		{
			char sName2[64];
			GetZoneNameByIndex(zone, sName2, sizeof(sName2));
			
			if ((equals && StrEqual(sName2, sName, caseSensitive)) || StrContains(sName2, sName, caseSensitive) != -1)
			{
				return g_bIsInZone[client][zone];
			}
		}
	}

	return false;
}

public int Native_IsClientInZoneIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return false;
	}

	int zone = GetNativeCell(2);

	if (zone < 1 || g_aZoneEntities.FindValue(EntIndexToEntRef(zone)) == -1)
	{
		return false;
	}

	if (IsValidEntity(zone))
	{
		return g_bIsInZone[client][zone];
	}

	return false;
}

public int Native_GetClientZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return -1;
	}

	for (int zone = MaxClients; zone < MAX_ENTITY_LIMIT; zone++)
	{
		if (!g_bIsInZone[client][zone])
		{
			continue;
		}

		return zone;
	}

	return -1;
}

public int Native_TeleportClientToZone(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	int size;
	GetNativeStringLength(2, size);

	char[] sName = new char[size + 1];
	GetNativeString(2, sName, size + 1);

	return TeleportToZone(client, sName);
}

public int Native_TeleportClientToZoneIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	int zone = GetNativeCell(2);
	if (!IsValidEntity(zone) || (g_aZoneEntities.FindValue(EntIndexToEntRef(zone)) == -1))
	{
		return false;
	}

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(zone, sName, sizeof(sName));

	return TeleportToZone(client, sName);
}

public int Native_GetEffectsList(Handle plugin, int numParams)
{
	if (g_aEffectsList != null)
	{
		return view_as<int>(g_aEffectsList);
	}

	return -1;
}

public int Native_GetZoneEffects(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);

	if (zone < 1 || !IsValidEntity(zone))
	{
		return -1;
	}

	if (g_aZoneEntities.FindValue(EntIndexToEntRef(zone)) == -1)
	{
		return -1;
	}

	return view_as<int>(Zone[zone].Effects);
}

public int Native_GetZoneType(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);

	if (zone < 1 || !IsValidEntity(zone))
	{
		return -1;
	}

	if (g_aZoneEntities.FindValue(EntIndexToEntRef(zone)) == -1)
	{
		return -1;
	}

	return GetZoneTypeByIndex(zone);
}

public int Native_GetZoneName(Handle plugin, int numParams)
{
	int zone = GetNativeCell(1);

	if (zone < 1 || !IsValidEntity(zone))
	{
		return false;
	}

	if (g_aZoneEntities.FindValue(EntIndexToEntRef(zone)) == -1)
	{
		return false;
	}

	int length = GetNativeCell(3);

	char[] name = new char[length];
	GetZoneNameByIndex(zone, name, length);

	if (SetNativeString(2, name, length) == SP_ERROR_NONE)
	{
		return true;
	}

	return false;
}

public int Native_GetColorNameByCode(Handle plugin, int numParams)
{
	int iColor[4];
	GetNativeArray(1, iColor, sizeof(iColor));

	int iLength   = GetNativeCell(3);
	char[] sColor = new char[iLength];

	bool success = GetColorNameByCode(iColor, sColor, iLength);

	SetNativeString(2, sColor, iLength);

	return success;
}

public int Native_GetColorCodeByName(Handle plugin, int numParams)
{
	char sColor[64];
	GetNativeString(1, sColor, sizeof(sColor));

	int  iColor[4];
	bool success = g_smColorData.GetArray(sColor, iColor, sizeof(iColor));
	SetNativeArray(2, iColor, sizeof(iColor));

	return success;
}

public int Native_GetDisplayNameByType(Handle plugin, int numParams)
{
	int iType = GetNativeCell(1);

	int iLength  = GetNativeCell(3);
	char[] sType = new char[iLength];

	GetDisplayNameByType(iType, sType, iLength);

	SetNativeString(2, sType, iLength);

	return (strlen(sType) > 2);
}

public int Native_GetDisplayTypeByName(Handle plugin, int numParams)
{
	char sType[12];
	GetNativeString(1, sType, sizeof(sType));
	return GetDisplayTypeByName(sType);
}

public int Native_GetZoneList(Handle plugin, int numParams)
{
	if (g_aZoneEntities == null)
	{
		return -1;
	}

	return view_as<int>(CloneHandle(g_aZoneEntities));
}

public int Native_IsPointInZone(Handle plugin, int numParams)
{
	int iZone = GetNativeCell(1);

	float fPoint[3];
	GetNativeArray(2, fPoint, 3);

	int iType = GetZoneTypeByIndex(iZone);

	if (iType == ZONE_TYPE_BOX || iType == ZONE_TYPE_TRIGGER || iType == ZONE_TYPE_SOLID)
	{
		float fMins[3];
		float fMaxs[3];

		GetAbsBoundingBox(iZone, fMins, fMaxs);

		return IsInsideBox(fPoint, fMins, fMaxs);
	}
	else if (iType == ZONE_TYPE_CIRCLE)
	{
		return IsPointInCircle(fPoint, _, iZone);
	}
	else if (iType == ZONE_TYPE_POLY)
	{
		return IsPointInZone(fPoint, iZone);
	}

	return false;
}

bool AddItemFormat(Menu& menu, const char[] info, int style = ITEMDRAW_DEFAULT, const char[] format, any...)
{
	char display[128];
	VFormat(display, sizeof(display), format, 5);

	return menu.AddItem(info, display, style);
}

bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}

	return false;
}

void PushMenuCell(Menu hndl, const char[] id, int data)
{
	char DataString[64];
	IntToString(data, DataString, sizeof(DataString));
	hndl.AddItem(id, DataString, ITEMDRAW_IGNORE);
}

void PushMenuString(Menu hndl, const char[] id, const char[] data)
{
	hndl.AddItem(id, data, ITEMDRAW_IGNORE);
}

int GetMenuCell(Menu hndl, const char[] id, int DefaultValue = 0)
{
	int  ItemCount = hndl.ItemCount;
	char info[64];
	char data[64];

	for (int i = 0; i < ItemCount; i++)
	{
		if (hndl.GetItem(i, info, sizeof(info), _, data, sizeof(data)))
		{
			if (StrEqual(info, id))
				return StringToInt(data);
		}
	}
	return DefaultValue;
}

bool GetMenuString(Menu hndl, const char[] id, char[] Buffer, int size)
{
	int  ItemCount = hndl.ItemCount;
	char info[64];
	char data[64];

	for (int i = 0; i < ItemCount; i++)
	{
		if (hndl.GetItem(i, info, sizeof(info), _, data, sizeof(data)))
		{
			if (StrEqual(info, id))
			{
				strcopy(Buffer, size, data);
				return true;
			}
		}
	}
	return false;
}

int SpawnZone(const char[] name)
{
	if (g_cCheckZoneNameExist.BoolValue && CheckZoneNameExist(name))
	{
		return -1;
	}

	char sType[MAX_ZONE_TYPE_LENGTH];
	g_kvConfig.GetString("type", sType, sizeof(sType));
	int type = GetZoneTypeByName(sType);

	float vStartPosition[3];
	g_kvConfig.GetVector("start", vStartPosition);

	float vEndPosition[3];
	g_kvConfig.GetVector("end", vEndPosition);

	float vOrigin[3];
	g_kvConfig.GetVector("origin", vOrigin);

	char sOriginName[MAX_ZONE_NAME_LENGTH];
	g_kvConfig.GetString("origin_name", sOriginName, sizeof(sOriginName));

	float vTeleport[3];
	g_kvConfig.GetVector("teleport", vTeleport);

	g_kvConfig.GetString("display", sType, sizeof(sType));
	int display = GetDisplayTypeByName(sType);

	float fRadius = g_kvConfig.GetFloat("radius");

	if (fRadius < 5.0)
	{
		fRadius = g_cDefaultRadius.FloatValue;
		g_kvConfig.SetFloat("radius", fRadius);
	}

	int iColor[4] = { 0, 255, 255, 255 };
	g_kvConfig.GetColor("color", iColor[0], iColor[1], iColor[2], iColor[3]);

	float points_height = g_kvConfig.GetFloat("points_height", g_cDefaultHeight.FloatValue);

	ArrayList points = null;
	if (g_kvConfig.JumpToKey("points") && g_kvConfig.GotoFirstSubKey(false))
	{
		points = new ArrayList(3);
		do
		{
			float coordinates[3];
			g_kvConfig.GetVector(NULL_STRING, coordinates);

			points.PushArray(coordinates, 3);
		}
		while (g_kvConfig.GotoNextKey(false));

		g_kvConfig.GoBack();
		g_kvConfig.GoBack();
	}

	StringMap effects = null;
	if (g_kvConfig.JumpToKey("effects") && g_kvConfig.GotoFirstSubKey(false))
	{
		effects = new StringMap();
		do
		{
			char sEffect[256];
			g_kvConfig.GetSectionName(sEffect, sizeof(sEffect));

			StringMap effect_data = null;

			if (g_kvConfig.GotoFirstSubKey(false))
			{
				effect_data = new StringMap();

				do
				{
					char sKey[256];
					g_kvConfig.GetSectionName(sKey, sizeof(sKey));

					char sValue[256];
					g_kvConfig.GetString(NULL_STRING, sValue, sizeof(sValue));

					effect_data.SetString(sKey, sValue);
				}
				while (g_kvConfig.GotoNextKey(false));

				g_kvConfig.GoBack();
			}

			effects.SetValue(sEffect, effect_data);
		}
		while (g_kvConfig.GotoNextKey(false));

		g_kvConfig.GoBack();
		g_kvConfig.GoBack();
	}

	eCreateZone zone;
	strcopy(zone.Name, sizeof(eCreateZone::Name), name);
	zone.Type   = type;
	zone.Start  = vStartPosition;
	zone.End    = vEndPosition;
	zone.Origin = vOrigin;
	strcopy(zone.OriginName, sizeof(eCreateZone::OriginName), sOriginName);
	zone.Radius       = fRadius;
	zone.iColors      = iColor;
	zone.PointsData   = points;
	zone.PointsHeight = points_height;
	zone.Effects      = effects;
	zone.Display      = display;
	zone.Teleport     = vTeleport;

	int iEntity = CreateZone(zone, false);

	delete points;

	if (iEntity == -1)
	{
		LogStackTrace("Zone \"%s\" (CreateZone return: %d) can not be spawned.", zone.Name, iEntity);
		return -1;
	}

	g_bSelectedZone[iEntity] = false;

	return iEntity;
}

bool GetColorNameByCode(int iColor[4], char[] color, int maxlen)
{
	StringMapSnapshot snap = g_smColorData.Snapshot();

	char sBuffer[32];
	int  iBuffer[4];

	for (int i = 0; i < snap.Length; i++)
	{
		snap.GetKey(i, sBuffer, sizeof(sBuffer));
		g_smColorData.GetArray(sBuffer, iBuffer, sizeof(iBuffer));

		if (iBuffer[0] == iColor[0] && iBuffer[1] == iColor[1] && iBuffer[2] == iColor[2] && iBuffer[3] == iColor[3])
		{
			strcopy(color, maxlen, sBuffer);
			delete snap;
			return true;
		}
	}

	delete snap;
	return false;
}

void AddZoneMenuItems(int client, Menu menu, bool create, int type, int pointsLength, float radius, char[] name, char[] color, int display, float start[3], float end[3])
{
	char sBuffer[256];
	if (type == ZONE_TYPE_POLY)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu - Item - Points", client, pointsLength);
	}
	else if (type == ZONE_TYPE_CIRCLE)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu - Item - Radius", client, radius);
	}

	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneNameByType(type, sType, sizeof(sType));

	AddItemFormat(menu, "type", _, "%T", "Menu - Item - Type", client, sType);

	if (type != ZONE_TYPE_TRIGGER)
	{
		AddItemFormat(menu, "name", _, "%T", "Menu - Item - Name", client, strlen(name) > 0 ? name : "N/A");
	}
	else
	{
		AddItemFormat(menu, "trigger", g_aMapZones.Length > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Trigger", client, strlen(name) > 0 ? name : "N/A");
	}

	char sColor[32];
	g_cDefaultColor.GetString(sColor, sizeof(sColor));
	AddItemFormat(menu, "color", _, "%T", "Menu - Item - Color", client, (strlen(color) > 0) ? color : sColor);

	GetDisplayNameByType(display, sType, sizeof(sType));
	AddItemFormat(menu, "display", _, "%T", "Menu - Item - Display", client, sType, sBuffer);

	if (type == ZONE_TYPE_TRIGGER && create)
	{
		return;
	}

	switch (type)
	{
		case ZONE_TYPE_BOX, ZONE_TYPE_TRIGGER, ZONE_TYPE_SOLID:
		{
			AddItemFormat(menu, "startpoint_a", _, "%T", "Menu - Item - Set Starting Point", client);
			AddItemFormat(menu, "startpoint_a_no_z", fuckZones_IsPositionNull(start) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Set Starting Point (Ignore Z/Height)", client);
			AddItemFormat(menu, "startpoint_a_precision", fuckZones_IsPositionNull(start) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Edit Starting Point (Precision)", client);
			AddItemFormat(menu, "startpoint_b", _, "%T", "Menu - Item - Set Ending Point", client);
			AddItemFormat(menu, "startpoint_b_no_z", fuckZones_IsPositionNull(end) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Set Ending Point (Ignore Z/Height)", client);
			AddItemFormat(menu, "startpoint_b_precision", fuckZones_IsPositionNull(end) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Edit Ending Point (Precision)", client);
			AddItemFormat(menu, "set_teleport", (fuckZones_IsPositionNull(start) || fuckZones_IsPositionNull(end)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Set Teleport Point", client);
		}

		case ZONE_TYPE_CIRCLE:
		{
			AddItemFormat(menu, "startpoint_a", _, "%T", "Menu - Item - Set Center Point", client);
			AddItemFormat(menu, "startpoint_a_precision", fuckZones_IsPositionNull(start) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Edit Center Point (Precision)", client);
			AddItemFormat(menu, "add_radius", _, "%T", "Menu - Item - Radius +", client);
			AddItemFormat(menu, "remove_radius", _, "%T", "Menu - Item - Radius -", client);
			AddItemFormat(menu, "add_height", _, "%T", "Menu - Item - Height +", client);
			AddItemFormat(menu, "remove_height", _, "%T", "Menu - Item - Height -", client);
			AddItemFormat(menu, "set_teleport", fuckZones_IsPositionNull(start) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "%T", "Menu - Item - Set Teleport Point", client);
		}

		case ZONE_TYPE_POLY:
		{
			AddItemFormat(menu, "add_point", _, "%T", "Menu - Item - Add a Point", client);

			if (!create)
			{
				AddItemFormat(menu, "edit_point", (pointsLength > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Edit a Point", client);
			}

			AddItemFormat(menu, "remove_point", (pointsLength > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Remove last Point", client);
			AddItemFormat(menu, "clear_points", (pointsLength > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Clear all Points", client);
			AddItemFormat(menu, "add_height", (pointsLength > 2) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Height +", client);
			AddItemFormat(menu, "remove_height", (pointsLength > 2) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Height -", client);
			AddItemFormat(menu, "set_teleport", (pointsLength > 2) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "%T", "Menu - Item - Set Teleport Point", client);
		}
	}
}

bool CheckZoneName(int client, const char[] name)
{
	g_kvConfig.Rewind();

	if (g_kvConfig.JumpToKey(name))
	{
		g_kvConfig.Rewind();
		CPrintToChat(client, "%T", "Chat - Zone Already Exist", client);
		return false;
	}

	char sRegex[128];
	g_cNameRegex.GetString(sRegex, sizeof(sRegex));
	Regex rRegex = new Regex(sRegex);

	if (rRegex.Match(name) != 1)
	{
		CPrintToChat(client, "%T", "Chat - Invalid Zone Name", client);
		return false;
	}

	delete rRegex;

	return true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "trigger_multiple", false) == 0)
	{
		RequestFrame(Frame_OnEntityCreated, EntIndexToEntRef(entity));
	}
}

public void Frame_OnEntityCreated(int ref)
{
	int entity = EntRefToEntIndex(ref);

	if (IsValidEntity(entity))
	{
		float fOrigin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fOrigin);

		char sName[MAX_ZONE_NAME_LENGTH];
		GetZoneNameByIndex(entity, sName, sizeof(sName));

		if (g_cEnableLogging.BoolValue)
		{
			LogMessage("(LoadMapZones) Zone: %s (Index: %d, Position: %.3f / %.3f / %.3f)", strlen(sName) > 0 ? sName : "N/A", entity, fOrigin[0], fOrigin[1], fOrigin[2]);
		}

		g_aMapZones.Push(EntIndexToEntRef(entity));
	}
}

void OpenMapZoneList(int client)
{
	Menu menu = new Menu(MenuHandler_MapZoneListMenu);
	menu.SetTitle("%T", "Menu - Title - Select Map Zone", client);

	char sName[MAX_ZONE_NAME_LENGTH];
	char sRef[12];

	for (int i = 0; i < g_aMapZones.Length; i++)
	{
		int zone = EntRefToEntIndex(g_aMapZones.Get(i));

		if (IsValidEntity(zone))
		{
			IntToString(g_aMapZones.Get(i), sRef, sizeof(sRef));
			GetZoneNameByIndex(zone, sName, sizeof(sName));
			menu.AddItem(sRef, sName);
		}
	}

	menu.ExitBackButton = true;

	int iSite;
	g_smSites[client].GetValue("OpenMapZoneList", iSite);
	menu.DisplayAt(client, iSite, MENU_TIME_FOREVER);
}

public int MenuHandler_MapZoneListMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_smSites[param1].SetValue("OpenMapZoneList", menu.Selection);

			char sRef[12];
			menu.GetItem(param2, sRef, sizeof(sRef));

			CZone[param1].Trigger = EntRefToEntIndex(StringToInt(sRef));
			GetZoneNameByIndex(CZone[param1].Trigger, CZone[param1].Name, sizeof(eCreateZone::Name));
			strcopy(CZone[param1].OriginName, sizeof(eCreateZone::OriginName), CZone[param1].Name);
			GetAbsBoundingBox(CZone[param1].Trigger, CZone[param1].Start, CZone[param1].End);

			OpenCreateZonesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenCreateZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

int GetNearestEntity(float origin[3], char[] classname)
{
	int   iEntity = -1;
	float fEntOrigin[3];
	float fDistance, fNearestDistance = -1.0;
	int   iTempEntity = -1;

	while ((iTempEntity = FindEntityByClassname(iTempEntity, classname)) != -1)
	{
		GetEntPropVector(iTempEntity, Prop_Data, "m_vecOrigin", fEntOrigin);
		fDistance = GetVectorDistance(origin, fEntOrigin);

		if (fDistance < 10.0 && (fDistance < fNearestDistance || fNearestDistance == -1.0))
		{
			iEntity          = iTempEntity;
			fNearestDistance = fDistance;
		}
	}

	return iEntity;
}

void OpenPolyEditPointMenu(int client, int zone)
{
	g_iConfirmZone[client] = zone;

	Menu menu = new Menu(MenuHandler_OpenPolyEditPointMenu);
	menu.SetTitle("%T", "Menu - Title - Info To Edit Poly Point", client);
	AddItemFormat(menu, "", ITEMDRAW_DISABLED, "%T", "Menu - Item - Info To Edit Poly Point", client);
	PushMenuCell(menu, "entity", zone);
	menu.ExitBackButton = true;
	menu.ExitButton     = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_OpenPolyEditPointMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_iConfirmZone[param1]  = -1;
				g_iConfirmPoint[param1] = -1;
				OpenZonePropertiesMenu(param1, GetMenuCell(menu, "entity"));
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void OpenPolyPointEditMenu(int client)
{
	int zone       = g_iConfirmZone[client];
	int pointIndex = g_iConfirmPoint[client];

	g_iConfirmZone[client]  = -1;
	g_iConfirmPoint[client] = -1;
	CancelClientMenu(client);

	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(zone, sName, sizeof(sName));

	Menu menu = new Menu(MenuHandler_OpenPolyPointEditMenu);
	menu.SetTitle("%T", "Menu - Title - Edit Poly Point Name", client, pointIndex + 1, sName);

	menu.AddItem("point_add_x", "X +");
	menu.AddItem("point_remove_x", "X -");
	menu.AddItem("point_add_y", "Y +");
	menu.AddItem("point_remove_y", "Y -");
	menu.AddItem("point_add_z", "Z +");
	menu.AddItem("point_remove_z", "Z -");

	PushMenuCell(menu, "entity", zone);
	PushMenuCell(menu, "pointIndex", pointIndex);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_OpenPolyPointEditMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int entity     = GetMenuCell(menu, "entity");
			int pointIndex = GetMenuCell(menu, "pointIndex");

			float fPoint[3];
			Zone[entity].PointsData.GetArray(pointIndex, fPoint, 3);

			if (StrEqual(sInfo, "point_add_x"))
			{
				fPoint[0] += g_fPrecision[param1];
			}
			else if (StrEqual(sInfo, "point_remove_x"))
			{
				fPoint[0] -= g_fPrecision[param1];
			}
			else if (StrEqual(sInfo, "point_add_y"))
			{
				fPoint[1] += g_fPrecision[param1];
			}
			else if (StrEqual(sInfo, "point_remove_y"))
			{
				fPoint[1] -= g_fPrecision[param1];
			}
			else if (StrEqual(sInfo, "point_add_z"))
			{
				fPoint[2] += g_fPrecision[param1];
			}
			else if (StrEqual(sInfo, "point_remove_z"))
			{
				fPoint[2] -= g_fPrecision[param1];
			}

			Zone[entity].PointsData.SetArray(pointIndex, fPoint, 3);
			SaveZonePointsData(entity);

			g_bSelectedZone[entity] = false;
			entity                  = RemakeZoneEntity(entity);
			g_bSelectedZone[entity] = true;

			g_iConfirmZone[param1]  = entity;
			g_iConfirmPoint[param1] = pointIndex;

			OpenPolyPointEditMenu(param1);
		}

		case MenuAction_Cancel:
		{
			int iEntity = GetMenuCell(menu, "entity");

			g_bSelectedZone[iEntity] = false;

			if (param2 == MenuCancel_ExitBack)
			{
				g_iConfirmZone[param1]  = iEntity;
				g_iConfirmPoint[param1] = -1;

				OpenPolyEditPointMenu(param1, iEntity);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void GetZoneNameByIndex(int zone, char[] name, int length)
{
	GetEntPropString(zone, Prop_Data, "m_iName", name, length);
}

void CallZoneEffectUpdate(int zone)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	GetZoneNameByIndex(zone, sName, sizeof(sName));

	int iType = GetZoneTypeByIndex(zone);

	Call_StartForward(Forward.OnEffectUpdate);
	Call_PushCell(zone);
	Call_PushString(sName);
	Call_PushCell(iType);
	Call_PushCell(view_as<int>(Zone[zone].Effects));
	Call_Finish();
}

int FindEntityByName(const char[] name, const char[] classname)
{
	int  iEntity = -1;
	char sName[MAX_ZONE_NAME_LENGTH];

	while ((iEntity = FindEntityByClassname(iEntity, classname)) != -1)
	{
		GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrEqual(sName, name, false))
		{
			return iEntity;
		}
	}

	return -1;
}

void UpdateZoneData()
{
	eUpdateData update;
	for (int i = 0; i < g_aUpdateZones.Length; i++)
	{
		g_aUpdateZones.GetArray(i, update, sizeof(update));

		if (!fuckZones_IsPositionNull(update.Origin))
		{
			UpdateZonesConfigKeyVectorByName(update.Name, "origin", update.Origin);
		}

		if (!fuckZones_IsPositionNull(update.Start))
		{
			UpdateZonesConfigKeyVectorByName(update.Name, "start", update.Start);
		}

		if (!fuckZones_IsPositionNull(update.End))
		{
			UpdateZonesConfigKeyVectorByName(update.Name, "end", update.End);
		}
	}

	delete g_aUpdateZones;
}

bool IsInsideBox(float point[3], float mins[3], float maxs[3])
{
	if (mins[0] <= point[0] <= maxs[0] && mins[1] <= point[1] <= maxs[1] && mins[2] <= point[2] <= maxs[2])
	{
		return true;
	}

	return false;
}

bool CheckZoneNameExist(const char[] name)
{
	for (int entity = MaxClients; entity < MAX_ENTITY_LIMIT; entity++)
	{
		if (!IsValidEntity(entity))
		{
			continue;
		}

		char sClassname[64];
		GetEntityClassname(entity, sClassname, sizeof(sClassname));

		if (!StrEqual(sClassname, "trigger_multiple", false))
		{
			continue;
		}

		char sName[MAX_ZONE_NAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (!StrEqual(sName, name, false))
		{
			continue;
		}

		return true;
	}

	return false;
}
