#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_DESCRIPTION "A sourcemod plugin with rich features for dynamic zone development."
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_VERSION_CVAR "sm_zonesmanager_version"

#define MAX_ZONE_NAME_LENGTH 128
#define MAX_ZONE_TYPE_LENGTH 64

#define MAX_ENTITY_LIMIT 4096

#define DEFAULT_MODELINDEX "sprites/laserbeam.vmt"
#define DEFAULT_HALOINDEX "materials/sprites/halo.vmt"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <menus-stocks>

ConVar convar_Status;

bool bLate;

int iDefaultModelIndex;
int iDefaultHaloIndex;
char sErrorModel[] = "models/error.mdl";

KeyValues kZonesConfig;

enum eZoneTypes
{
	Standard,
	Radius
}

bool bIsZone[MAX_ENTITY_LIMIT];

bool bShowAllZones[MAXPLAYERS + 1];

//Create Zones Variables
char sCreateZone_Name[MAXPLAYERS + 1][MAX_ZONE_NAME_LENGTH];
eZoneTypes eCreateZone_Type[MAXPLAYERS + 1];
float fCreateZone_Start[MAXPLAYERS + 1][3];
float fCreateZone_End[MAXPLAYERS + 1][3];
float fCreateZone_Radius[MAXPLAYERS + 1];

bool bIsViewingZone[MAXPLAYERS + 1];
bool bSettingName[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Zones-Manager",
	author = "Keith Warren (Drixevel)",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("zonesmanager.phrases");

	CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	convar_Status = CreateConVar("sm_zonesmanager_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//AutoExecConfig();

	HookEvent("teamplay_round_start", OnRoundStart);

	RegAdminCmd("sm_zones", Command_OpenZonesMenu, ADMFLAG_ROOT, "Display the zones manager menu.");

	CreateTimer(0.1, Timer_DisplayZones, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	iDefaultModelIndex = PrecacheModel(DEFAULT_MODELINDEX);
	iDefaultHaloIndex = PrecacheModel(DEFAULT_HALOINDEX);
	PrecacheModel(sErrorModel);

	LogDebug("Deleting current zones map configuration from memory.");

	SaveMapConfig();
	delete kZonesConfig;

	char sFolder[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFolder, sizeof(sFolder), "data/zones/");
	CreateDirectory(sFolder, 511);

	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/zones/%s.cfg", sMap);

	LogDebug("Creating keyvalues for the new map before pulling new map zones info.");
	kZonesConfig = CreateKeyValues("zones_manager");

	if (FileExists(sPath))
	{
		LogDebug("Config exists, retrieving the zones...");
		FileToKeyValues(kZonesConfig, sPath);
	}
	else
	{
		LogDebug("Config doesn't exist, creating new zones config for the map: %s", sMap);
		KeyValuesToFile(kZonesConfig, sPath);
	}

	LogDebug("New config successfully loaded.");
}

public void OnConfigsExecuted()
{
	if (bLate)
	{
		SpawnAllZones();
		bLate = false;
	}
}

public void OnPluginEnd()
{
	ClearAllZones();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ClearAllZones();
	SpawnAllZones();
}

void ClearAllZones()
{
	for (int i = MaxClients; i <= MAX_ENTITY_LIMIT; i++)
	{
		if (IsValidEntity(i) && bIsZone[i])
		{
			AcceptEntityInput(i, "Kill");
			bIsZone[i] = false;
		}
	}
}

void SpawnAllZones()
{
	LogDebug("Spawning all zones...");

	KvRewind(kZonesConfig);
	if (KvGotoFirstSubKey(kZonesConfig))
	{
		do
		{
			char sName[MAX_ZONE_NAME_LENGTH];
			KvGetSectionName(kZonesConfig, sName, sizeof(sName));

			char sType[MAX_ZONE_TYPE_LENGTH];
			KvGetString(kZonesConfig, "type", sType, sizeof(sType));
			eZoneTypes type = GetZoneNameType(sType);

			float vStartPosition[3];
			KvGetVector(kZonesConfig, "start", vStartPosition);

			float vEndPosition[3];
			KvGetVector(kZonesConfig, "end", vEndPosition);

			float fRadius = KvGetFloat(kZonesConfig, "radius");

			CreateZone(sName, type, vStartPosition, vEndPosition, fRadius);
		}
		while(KvGotoNextKey(kZonesConfig));
	}

	LogDebug("Zones have been spawned.");
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (bSettingName[client])
	{
		strcopy(sCreateZone_Name[client], MAX_ZONE_NAME_LENGTH, sArgs);
		bSettingName[client] = false;
		OpenCreateZonesMenu(client);
	}
}

public Action Command_OpenZonesMenu(int client, int args)
{
	if (!GetConVarBool(convar_Status))
	{
		return Plugin_Handled;
	}

	if (client == 0)
	{
		ReplyToCommand(client, "You must be in-game to use this command.");
		return Plugin_Handled;
	}

	OpenZonesMenu(client);
	return Plugin_Handled;
}

void OpenZonesMenu(int client)
{
	bool flags = CheckCommandAccess(client, "sm_zones_viewallzones", ADMFLAG_ROOT);

	Menu menu = CreateMenu(MenuHandle_ZonesMenu);
	SetMenuTitle(menu, "Zones Manager");

	AddMenuItem(menu, "manage", "Manage Zones");
	AddMenuItem(menu, "create", "Create a Zone");
	AddMenuItemFormat(menu, "viewall", flags ? ITEMDRAW_DEFAULT : ITEMDRAW_RAWLINE, "(admin) View all zones: %s", bShowAllZones[client] ? "On" : "Off");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_ZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "manage"))
			{
				OpenManageZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "create"))
			{
				OpenCreateZonesMenu(param1, true);
			}
			else if (StrEqual(sInfo, "viewall"))
			{
				bShowAllZones[param1] = !bShowAllZones[param1];
				OpenZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void OpenManageZonesMenu(int client)
{
	Menu menu = CreateMenu(MenuHandle_ManageZonesMenu);
	SetMenuTitle(menu, "Manage Zones:");

	KvRewind(kZonesConfig);
	if (KvGotoFirstSubKey(kZonesConfig))
	{
		do
		{
			char sName[MAX_ZONE_NAME_LENGTH];
			KvGetSectionName(kZonesConfig, sName, sizeof(sName));

			char sType[MAX_ZONE_TYPE_LENGTH];
			KvGetString(kZonesConfig, "type", sType, sizeof(sType));

			AddMenuItem(menu, sType, sName);
		}
		while(KvGotoNextKey(kZonesConfig));
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No Zones]", ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_ManageZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[MAX_ZONE_TYPE_LENGTH]; char sName[MAX_ZONE_NAME_LENGTH];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sName, sizeof(sName));

			eZoneTypes type = GetZoneNameType(sInfo);

			OpenEditZoneMenu(param1, sName, type);
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
			CloseHandle(menu);
		}
	}
}

void OpenEditZoneMenu(int client, const char[] name, eZoneTypes type)
{
	Menu menu = CreateMenu(MenuHandle_ManageEditMenu);
	SetMenuTitle(menu, "Manage Zone '%s':", name);

	AddMenuItem(menu, "edit", "Edit Zone");
	AddMenuItem(menu, "delete", "Delete Zone");

	PushMenuString(menu, "name", name);
	PushMenuCell(menu, "type", type);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_ManageEditMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			char sName[MAX_ZONE_NAME_LENGTH];
			GetMenuString(menu, "name", sName, sizeof(sName));

			eZoneTypes type = view_as<eZoneTypes>(GetMenuCell(menu, "type"));

			if (StrEqual(sInfo, "edit"))
			{
				OpenZonePropertiesMenu(param1, sName, type);
			}
			else if (StrEqual(sInfo, "delete"))
			{
				DisplayConfirmDeleteZoneMenu(param1, sName, type);
			}
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				OpenManageZonesMenu(param1);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void OpenZonePropertiesMenu(int client, const char[] name, eZoneTypes type)
{
	Menu menu = CreateMenu(MenuHandle_ZonePropertiesMenu);
	SetMenuTitle(menu, "Edit properties for zone '%s':", name);

	AddMenuItem(menu, "kappa", "Kappa");

	PushMenuString(menu, "name", name);
	PushMenuCell(menu, "type", type);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_ZonePropertiesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			char sName[MAX_ZONE_NAME_LENGTH];
			GetMenuString(menu, "name", sName, sizeof(sName));

			eZoneTypes type = view_as<eZoneTypes>(GetMenuCell(menu, "type"));

			OpenZonePropertiesMenu(param1, sName, type);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sName[MAX_ZONE_NAME_LENGTH];
				GetMenuString(menu, "name", sName, sizeof(sName));

				eZoneTypes type = view_as<eZoneTypes>(GetMenuCell(menu, "type"));

				OpenEditZoneMenu(param1, sName, type);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void DisplayConfirmDeleteZoneMenu(int client, const char[] name, eZoneTypes type)
{
	Menu menu = CreateMenu(MenuHandle_ManageConfirmDeleteZoneMenu);
	SetMenuTitle(menu, "Are you sure you want to delete '%s':", name);

	AddMenuItem(menu, "yes", "Yes");
	AddMenuItem(menu, "no", "No");

	PushMenuString(menu, "name", name);
	PushMenuCell(menu, "type", type);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_ManageConfirmDeleteZoneMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			char sName[MAX_ZONE_NAME_LENGTH];
			GetMenuString(menu, "name", sName, sizeof(sName));

			eZoneTypes type = view_as<eZoneTypes>(GetMenuCell(menu, "type"));

			if (StrEqual(sInfo, "no"))
			{
				OpenEditZoneMenu(param1, sName, type);
				return;
			}

			DeleteZone(sName, type);
			PrintToChat(param1, "You have deleted the zone '%s'.", sName);
			OpenManageZonesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sName[MAX_ZONE_NAME_LENGTH];
				GetMenuString(menu, "name", sName, sizeof(sName));

				eZoneTypes type = view_as<eZoneTypes>(GetMenuCell(menu, "type"));

				OpenEditZoneMenu(param1, sName, type);
			}
		}

		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void OpenCreateZonesMenu(int client, bool reset = false)
{
	if (reset)
	{
		ResetCreateZoneVariables(client);
	}

	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneTypeName(eCreateZone_Type[client], sType, sizeof(sType));

	Menu menu = CreateMenu(MenuHandle_CreateZonesMenu);
	SetMenuTitle(menu, "Create a Zone:");

	AddMenuItemFormat(menu, "name", ITEMDRAW_DEFAULT, "Name: %s", strlen(sCreateZone_Name[client]) > 0 ? sCreateZone_Name[client] : "N/A");
	AddMenuItemFormat(menu, "type", ITEMDRAW_DEFAULT, "Type: %s", sType);

	switch (eCreateZone_Type[client])
	{
		case Standard:
		{
			AddMenuItem(menu, "start", "Set Starting Point", ITEMDRAW_DEFAULT);
			AddMenuItem(menu, "end", "Set Ending Point", ITEMDRAW_DEFAULT);
		}

		case Radius:
		{
			AddMenuItem(menu, "start", "Set Starting Point", ITEMDRAW_DEFAULT);
			AddMenuItemFormat(menu, "radius", ITEMDRAW_DEFAULT, "Set Radius: %.2f", fCreateZone_Radius[client]);
		}
	}

	AddMenuItemFormat(menu, "view", ITEMDRAW_DEFAULT, "View Zone: %s", bIsViewingZone[client] ? "On" : "Off");
	AddMenuItem(menu, "", "---", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "create", "Create Zone", ITEMDRAW_DEFAULT);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_CreateZonesMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "name"))
			{
				bSettingName[param1] = true;
				PrintToChat(param1, "Type the name of this new zone in chat:");
			}
			else if (StrEqual(sInfo, "type"))
			{
				eCreateZone_Type[param1] = eCreateZone_Type[param1] == Standard ? Radius : Standard;
				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "start"))
			{
				float vLookPoint[3];
				GetClientLookPoint(param1, vLookPoint);
				Array_Copy(vLookPoint, fCreateZone_Start[param1], 3);
				PrintToChat(param1, "Starting point: %.2f/%.2f/%.2f", fCreateZone_Start[param1][0], fCreateZone_Start[param1][1], fCreateZone_Start[param1][2]);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "end"))
			{
				float vLookPoint[3];
				GetClientLookPoint(param1, vLookPoint);
				Array_Copy(vLookPoint, fCreateZone_End[param1], 3);
				PrintToChat(param1, "Ending point: %.2f/%.2f/%.2f", fCreateZone_End[param1][0], fCreateZone_End[param1][1], fCreateZone_End[param1][2]);

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "radius"))
			{
				fCreateZone_Radius[param1] += 5.0;

				if (fCreateZone_Radius[param1] > 500.0)
				{
					fCreateZone_Radius[param1] = 0.0;
				}

				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "view"))
			{
				bIsViewingZone[param1] = !bIsViewingZone[param1];
				OpenCreateZonesMenu(param1);
			}
			else if (StrEqual(sInfo, "create"))
			{
				CreateNewZone(param1);
				OpenZonesMenu(param1);
			}
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
			CloseHandle(menu);
		}
	}
}

void CreateNewZone(int client)
{
	if (strlen(sCreateZone_Name[client]) == 0)
	{
		PrintToChat(client, "You must set a zone name in order to create it.");
		OpenCreateZonesMenu(client);
		return;
	}

	KvRewind(kZonesConfig);

	if (KvJumpToKey(kZonesConfig, sCreateZone_Name[client]))
	{
		KvRewind(kZonesConfig);
		PrintToChat(client, "Zone already exists, please pick a different name.");
		OpenCreateZonesMenu(client);
		return;
	}

	KvJumpToKey(kZonesConfig, sCreateZone_Name[client], true);

	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneTypeName(eCreateZone_Type[client], sType, sizeof(sType));
	KvSetString(kZonesConfig, "type", sType);

	switch (eCreateZone_Type[client])
	{
		case Standard:
		{
			KvSetVector(kZonesConfig, "start", fCreateZone_Start[client]);
			KvSetVector(kZonesConfig, "end", fCreateZone_End[client]);
		}

		case Radius:
		{
			KvSetVector(kZonesConfig, "start", fCreateZone_Start[client]);
			KvSetFloat(kZonesConfig, "radius", fCreateZone_Radius[client]);
		}
	}

	SaveMapConfig();

	CreateZone(sCreateZone_Name[client], eCreateZone_Type[client], fCreateZone_Start[client], fCreateZone_End[client], fCreateZone_Radius[client]);
	PrintToChat(client, "Zone '%s' has been created successfully.", sCreateZone_Name[client]);
	bIsViewingZone[client] = false;
}

void ResetCreateZoneVariables(int client)
{
	sCreateZone_Name[client][0] = '\0';
	eCreateZone_Type[client] = Standard;
	Array_Fill(fCreateZone_Start[client], 3, 0.0);
	Array_Fill(fCreateZone_End[client], 3, 0.0);
	fCreateZone_Radius[client] = 0.0;

	bIsViewingZone[client] = false;
	bSettingName[client] = false;
}

void GetZoneTypeName(eZoneTypes type, char[] buffer, int size)
{
	switch (type)
	{
		case Standard: strcopy(buffer, size, "Standard");
		case Radius: strcopy(buffer, size, "Radius");
	}
}

eZoneTypes GetZoneNameType(const char[] sType)
{
	if (StrEqual(sType, "Standard"))
	{
		return Standard;
	}
	else if (StrEqual(sType, "Radius"))
	{
		return Radius;
	}

	return Standard;
}

void SaveMapConfig()
{
	if (kZonesConfig == null)
	{
		return;
	}

	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/zones/%s.cfg", sMap);

	KvRewind(kZonesConfig);
	KeyValuesToFile(kZonesConfig, sPath);
}

public Action Timer_DisplayZones(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && bIsViewingZone[i])
		{
			switch (eCreateZone_Type[i])
			{
				case Standard: Effect_DrawBeamBoxToClient(i, fCreateZone_Start[i], fCreateZone_End[i], iDefaultModelIndex, iDefaultHaloIndex, 0, 30, 0.2, 5.0, 5.0, 2, 1.0, {255, 0, 0, 255}, 0);
				case Radius:
				{
					TE_SetupBeamRingPoint(fCreateZone_Start[i], fCreateZone_Radius[i], fCreateZone_Radius[i] + 4.0, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, 0.2, 5.0, 0.0, {255, 0, 0, 255}, 0, 0);
					TE_SendToClient(i, 0.0);
				}
			}
		}

		if (IsClientInGame(i) && bShowAllZones[i])
		{
			for (int x = 0; x < MAX_ENTITY_LIMIT; x++)
			{
				if (IsValidEntity(x) && bIsZone[x])
				{
					float start[3]; float end[3];
					GetAbsBoundingBox(x, start, end);

					Effect_DrawBeamBoxToClient(i, start, end, iDefaultModelIndex, iDefaultHaloIndex, 0, 30, 0.2, 5.0, 5.0, 2, 1.0, {255, 255, 0, 255}, 0);
				}
			}
		}
	}
}

stock void GetAbsBoundingBox(int ent, float mins[3], float maxs[3])
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

void CreateZone(const char[] sName, eZoneTypes type, float start[3], float end[3], float radius)
{
	char sType[MAX_ZONE_TYPE_LENGTH];
	GetZoneTypeName(type, sType, sizeof(sType));

	LogDebug("Spawning Zone: %s - %s - %.2f/%.2f/%.2f - %.2f/%.2f/%.2f - %.2f", sName, sType, start[0], start[1], start[2], end[0], end[1], end[2], radius);

	int entity = CreateEntityByName("trigger_multiple");

	if (IsValidEntity(entity))
	{
		DispatchKeyValue(entity, "targetname", sName);
		DispatchKeyValue(entity, "spawnflags", "64");
		DispatchSpawn(entity);
		SetEntProp(entity, Prop_Data, "m_spawnflags", 64);

		float fMiddle[3];
		GetMiddleOfABox(start, end, fMiddle);

		TeleportEntity(entity, fMiddle, NULL_VECTOR, NULL_VECTOR);
		SetEntityModel(entity, sErrorModel);

		// Have the mins always be negative
		start[0] = start[0] - fMiddle[0];
		if(start[0] > 0.0)
			start[0] *= -1.0;
		start[1] = start[1] - fMiddle[1];
		if(start[1] > 0.0)
			start[1] *= -1.0;
		start[2] = start[2] - fMiddle[2];
		if(start[2] > 0.0)
			start[2] *= -1.0;

		// And the maxs always be positive
		end[0] = end[0] - fMiddle[0];
		if(end[0] < 0.0)
			end[0] *= -1.0;
		end[1] = end[1] - fMiddle[1];
		if(end[1] < 0.0)
			end[1] *= -1.0;
		end[2] = end[2] - fMiddle[2];
		if(end[2] < 0.0)
			end[2] *= -1.0;

		SetEntPropVector(entity, Prop_Data, "m_vecMins", start);
		SetEntPropVector(entity, Prop_Data, "m_vecMaxs", end);
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);

		SDKHook(entity, SDKHook_StartTouchPost, StartTouchPost);
		SDKHook(entity, SDKHook_TouchPost, TouchPost);
		SDKHook(entity, SDKHook_EndTouchPost, EndTouchPost);

		bIsZone[entity] = true;
	}

	LogDebug("Zone %s has been spawned %s with ID %i.", sName, IsValidEntity(entity) ? "successfully" : "not successfully", entity);
}

public void StartTouchPost(int entity, int other)
{

}

public void TouchPost(int entity, int other)
{

}

public void EndTouchPost(int entity, int other)
{

}

void DeleteZone(const char[] sName, eZoneTypes type)
{
	if (type == Standard)
	{

	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "trigger_multiple")) != -1)
	{
		char sLookup[MAX_ZONE_NAME_LENGTH];
		GetEntPropString(entity, Prop_Data, "m_iName", sLookup, sizeof(sLookup));

		if (StrEqual(sLookup, sName))
		{
			AcceptEntityInput(entity, "Kill");
			bIsZone[entity] = false;
		}
	}

	KvRewind(kZonesConfig);
	if (KvJumpToKey(kZonesConfig, sName))
	{
		KvDeleteThis(kZonesConfig);
	}

	SaveMapConfig();
}

//STOCKS STOCKS STOCKS STOCKS NOT SANTA
stock void PogChamp(float fMins[3], float fMiddle[3])
{
	fMins[0] = fMins[0] - fMiddle[0];
	if(fMins[0] > 0.0)
		fMins[0] *= -1.0;
	fMins[1] = fMins[1] - fMiddle[1];
	if(fMins[1] > 0.0)
		fMins[1] *= -1.0;
	fMins[2] = fMins[2] - fMiddle[2];
	if(fMins[2] > 0.0)
		fMins[2] *= -1.0;
}

void GetMiddleOfABox(const float vec1[3], const float vec2[3], float buffer[3])
{
	float mid[3];
	MakeVectorFromPoints(vec1, vec2, mid);
	mid[0] = mid[0] / 2.0;
	mid[1] = mid[1] / 2.0;
	mid[2] = mid[2] / 2.0;
	AddVectors(vec1, mid, buffer);
}

bool GetClientLookPoint(int client, float lookposition[3])
{
	float vEyePos[3];
	GetClientEyePosition(client, vEyePos);

	float vEyeAng[3];
	GetClientEyeAngles(client, vEyeAng);

	Handle hTrace = TR_TraceRayFilterEx(vEyePos, vEyeAng, MASK_SHOT, RayType_Infinite, TraceEntityFilter_NoPlayers);
	bool bHit = TR_DidHit(hTrace);

	TR_GetEndPosition(lookposition, hTrace);

	CloseHandle(hTrace);
	return bHit;
}

public bool TraceEntityFilter_NoPlayers(int entity, int contentsMask)
{
	return false;
}

stock void Array_Fill(any[] array, int size, any value, int start = 0)
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

stock void Array_Copy(const any[] array, any[] newArray, int size)
{
	for (int i = 0; i < size; i++)
	{
		newArray[i] = array[i];
	}
}

void LogDebug(const char[] format, any ...)
{
	char sBuffer[255];
	VFormat(sBuffer, sizeof(sBuffer), format, 2);

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/zonesmanager.debugs.log");

	LogToFile(sPath, sBuffer);
}

stock void Effect_DrawBeamBoxToClient(int client, const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] = {255, 0, 0, 255}, int speed = 0)
{
    int clients[1];
    clients[0] = client;
    Effect_DrawBeamBox(clients, 1, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
}

stock void Effect_DrawBeamBoxToAll(const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] = {255, 0, 0, 255}, int speed = 0)
{
	int clients[MaxClients];
	int numClients;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			clients[numClients++] = i;
		}
	}

	Effect_DrawBeamBox(clients, numClients, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
}

stock void Effect_DrawBeamBox(int[] clients,int numClients, const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] = {255, 0, 0, 255}, int speed = 0)
{
	float corners[8][3];

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
		int j = ( i == 3 ? 0 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}

	for (int i = 4; i < 8; i++)
	{
		int j = ( i == 7 ? 4 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}

	for (int i = 0; i < 4; i++)
	{
		TE_SetupBeamPoints(corners[i], corners[i+4], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}
}
