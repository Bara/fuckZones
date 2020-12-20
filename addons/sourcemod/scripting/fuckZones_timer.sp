//Pragma
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <intmap>
#include <fuckZones>

#define EFFECT_NAME "fuck"

enum struct PlayerData {
	float Time;
	IntMap StageTimes;
}

PlayerData Player[MAXPLAYERS + 1];

IntMap g_imStages = null;
int g_iStartZone = -1;

public Plugin myinfo =
{
	name = "fuck",
	author = "Bara",
	description = "",
	version = "0.0.0",
	url = "github.com/Bara"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_r", Command_Restart);

	g_imStages = new IntMap();

	for (int i = 1; i <= MaxClients; i++)
	{
		OnClientDisconnect(i);
		OnClientPutInServer(i);
	}
}

public void OnMapStart()
{
	g_imStages.Clear();
}

public void OnClientPutInServer(int client)
{
	Player[client].StageTimes = new IntMap();
}

public void OnClientDisconnect(int client)
{
	delete Player[client].StageTimes;
}

public Action Command_Restart(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	PrintToChat(client, "In Zone: %d", fuckZones_IsClientInZoneIndex(client, g_iStartZone));

	fuckZones_TeleportClientToZoneIndex(client, g_iStartZone);

	return Plugin_Handled;
}

public void fuckZones_OnZoneCreate(int zone, const char[] name, int type)
{
	StringMap smEffects = fuckZones_GetZoneEffects(zone);

	StringMap smValues = null;
	smEffects.GetValue(EFFECT_NAME, smValues);

	if (IsStartZone(smValues))
	{
		g_iStartZone = zone;
	}

	int iStage = GetStageNumber(smValues);

	if (iStage > 0)
	{
		g_imStages.SetValue(iStage, EntIndexToEntRef(zone));
	}
}

public void fuckZones_OnEffectsReady()
{
	fuckZones_RegisterEffect(EFFECT_NAME, OneZoneStartTouch, INVALID_FUNCTION, OnZoneEndTouch);

	fuckZones_RegisterEffectKey(EFFECT_NAME, "StartZone", "0");
	fuckZones_RegisterEffectKey(EFFECT_NAME, "EndZone", "0");

	fuckZones_RegisterEffectKey(EFFECT_NAME, "MiscZone", "0");

	fuckZones_RegisterEffectKey(EFFECT_NAME, "Stage", "0");
	fuckZones_RegisterEffectKey(EFFECT_NAME, "Checkpoint", "0");

	fuckZones_RegisterEffectKey(EFFECT_NAME, "Bonus", "0");
}

public Action fuckZones_OnStartTouchZone(int client, int entity, const char[] zone_name, int type)
{
	PrintToChat(client, "fuckZones_OnStartTouchZone->%s", zone_name);
}

public Action fuckZones_OnEndTouchZone(int client, int entity, const char[] zone_name, int type)
{
	PrintToChat(client, "fuckZones_OnEndTouchZone->%s", zone_name);
}

public void OneZoneStartTouch(int client, int entity, StringMap values)
{
	if (IsEndZone(values))
	{
		if (Player[client].Time > 0.0)
		{
			PrintToChat(client, "Time: %.3f", GetGameTime()-Player[client].Time);
		}
	}

	int iStage = GetStageNumber(values);

	if (iStage > 1)
	{
		float fTime = GetGameTime();
		Player[client].StageTimes.SetValue(iStage, fTime);

		float fPrevTime;
		if (Player[client].StageTimes.GetValue(iStage-1, fPrevTime))
		{
			PrintToChat(client, "Time for Stage %d to Stage %d: %.3f", iStage-1, iStage, fTime-fPrevTime);
		}
	}
}

public void OnZoneEndTouch(int client, int entity, StringMap values)
{
	if (IsStartZone(values))
	{
		Player[client].Time = GetGameTime();
	}

	int iStage = GetStageNumber(values);
	if (iStage > 0)
	{
		Player[client].StageTimes.SetValue(iStage, GetGameTime());
	}
}

bool IsStartZone(StringMap values)
{
	char sValue[MAX_KEY_VALUE_LENGTH];
	if (GetZoneValue(values, "StartZone", sValue, sizeof(sValue)))
	{
		return view_as<bool>(StringToInt(sValue));
	}
	return false;
}

bool IsEndZone(StringMap values)
{
	char sValue[MAX_KEY_VALUE_LENGTH];
	if (GetZoneValue(values, "EndZone", sValue, sizeof(sValue)))
	{
		return view_as<bool>(StringToInt(sValue));
	}
	return false;
}

int GetStageNumber(StringMap values)
{
	char sValue[MAX_KEY_VALUE_LENGTH];
	if (GetZoneValue(values, "Stage", sValue, sizeof(sValue)))
	{
		return StringToInt(sValue);
	}
	return -1;
}

bool GetZoneValue(StringMap values, const char[] key, char[] value, int length)
{
	char sKey[MAX_KEY_NAME_LENGTH];
	StringMapSnapshot keys = values.Snapshot();

	for (int x = 0; x < keys.Length; x++)
	{
		keys.GetKey(x, sKey, sizeof(sKey));

		if (strcmp(sKey, key, false) == 0)
		{
			values.GetString(sKey, value, length);

			delete keys;
			return true;
		}
	}

	delete keys;
	return false;
}
