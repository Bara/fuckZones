//Pragma
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>

#define EFFECT_NAME "Timer"

float g_fTime[MAXPLAYERS + 1] = 0.0;

public Plugin myinfo =
{
	name = "fuckZones - Test Times",
	author = "Bara",
	description = "A simple plugin to test the zones manager plugin and its API interface.",
	version = "1.1.0",
	url = "github.com/Bara"
};

public void fuckZones_OnQueueEffects_Post()
{
	fuckZones_RegisterEffect(EFFECT_NAME, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION);

	/*
		Start/End Zone: 0 = Disabled, 1 = 1st Start Zone, 2 = 2nd Start Zone (for Bonus)
		Misc Zone: 0 = Disabled, 1 = Type X, 2 = Type Y, ...
		Stage/Checkpoint Zone: 0 = Disabled, 1 = Stage/Checkpoint 1, 2 = Stage/Checkpoint 2, ...
		Bonus: 0 = Disabled, 1 = Enabled
	*/

	fuckZones_RegisterEffectKey(EFFECT_NAME, "Start Zone", "1");
	fuckZones_RegisterEffectKey(EFFECT_NAME, "End Zone", "1");

	fuckZones_RegisterEffectKey(EFFECT_NAME, "Misc Zone", "0");

	fuckZones_RegisterEffectKey(EFFECT_NAME, "Stage", "0");
	fuckZones_RegisterEffectKey(EFFECT_NAME, "Checkpoint", "0");

	fuckZones_RegisterEffectKey(EFFECT_NAME, "Bonus", "0");
}

public Action fuckZones_OnStartTouchZone(int client, int entity, const char[] zone_name, int type)
{
	char sName[MAX_ZONE_NAME_LENGTH];
	fuckZones_GetZoneName(entity, sName, sizeof(sName));

	int iType = fuckZones_GetZoneType(entity);

	PrintToChat(client, "StartTouch: Entity: %i - Name: %s (%s) - Type: %i (%d)", entity, zone_name, sName, type, iType);

	ArrayList aEffects = fuckZones_GetEffectsList();
	char sEffect[MAX_EFFECT_NAME_LENGTH];
	StringMap smEffect = null;
	StringMap smKeys = null;
	StringMapSnapshot keys = null;

	for (int i = 0; i < aEffects.Length; i++)
	{
		aEffects.GetString(i, sEffect, sizeof(sEffect));
		smEffect = fuckZones_GetZoneEffects(entity);
		
		if (smEffect != null)
		{
			smEffect.GetValue(sEffect, smKeys);

			if (smKeys != null)
			{
				keys = smKeys.Snapshot();
				for (int x = 0; x < keys.Length; x++)
				{
					char sKey[MAX_KEY_NAME_LENGTH];
					keys.GetKey(x, sKey, sizeof(sKey));

					char sValue[MAX_KEY_VALUE_LENGTH];
					smKeys.GetString(sKey, sValue, sizeof(sValue));
					
					PrintToChat(client, "Effect: %s, Key: %s, Value: %s", sEffect, sKey, sValue);
				}
				delete keys;
			}
		}
	}

	if (g_fTime[client] > 0.0 && StrContains(zone_name, "End", false) != -1)
	{
		PrintToChat(client, "Time: %f", (GetGameTime() - g_fTime[client]));
		g_fTime[client] = 0.0;
	}

	return Plugin_Continue;
}

public Action fuckZones_OnEndTouchZone(int client, int entity, const char[] zone_name, int type)
{
	PrintToChat(client, "EndTouch: Entity: %i - Name: %s - Type: %i", entity, zone_name, type);

	if (StrContains(zone_name, "Start", false) != -1)
	{
		g_fTime[client] = GetGameTime();
	}

	return Plugin_Continue;
}
