#if defined _fuckZones_included
  #endinput
#endif
#define _fuckZones_included

#define MAX_ZONE_NAME_LENGTH 32
#define MAX_ZONE_TYPE_LENGTH 24
#define MAX_EFFECT_NAME_LENGTH 32
#define MAX_KEY_NAME_LENGTH 32
#define MAX_KEY_VALUE_LENGTH 128

#define MAX_EFFECT_CALLBACKS 3
#define EFFECT_CALLBACK_ONENTERZONE 0
#define EFFECT_CALLBACK_ONACTIVEZONE 1
#define EFFECT_CALLBACK_ONLEAVEZONE 2

#define ZONE_TYPES 5
#define ZONE_TYPE_NONE 0
#define ZONE_TYPE_BOX 1
#define ZONE_TYPE_CIRCLE 2
#define ZONE_TYPE_POLY 3
#define ZONE_TYPE_TRIGGER 4

#define DISPLAY_TYPE_TYPES 3
#define DISPLAY_TYPE_FULL 0
#define DISPLAY_TYPE_BOTTOM 1
#define DISPLAY_TYPE_HIDE 2

typedef fuckZones_Effect_OnEnterZone = function void (int client, int entity, StringMap values);
typedef fuckZones_Effect_OnActiveZone = function void (int client, int entity, StringMap values);
typedef fuckZones_Effect_OnLeaveZone = function void (int client, int entity, StringMap values);

enum struct eCreateZone
{
	char Name[MAX_ZONE_NAME_LENGTH];
	int Type;
	float Start[3];
	float End[3];
	float Origin[3];
	char OriginName[32];
	float Teleport[3];
	float Radius;
	char Color[64];
	int iColors[4];
	ArrayList PointsData;
	float PointsHeight;
	StringMap Effects;
	int Display;
	bool SetName;
	bool Show;
	int Trigger;
}

/**----------------------------------------------------------*/
// Natives

native void fuckZones_RegisterEffect(const char[] name, fuckZones_Effect_OnEnterZone OnEnterZone = INVALID_FUNCTION, fuckZones_Effect_OnActiveZone OnActiveZone = INVALID_FUNCTION, fuckZones_Effect_OnLeaveZone OnLeaveZone = INVALID_FUNCTION);
native void fuckZones_RegisterEffectKey(const char[] name, const char[] effect, const char[] defaultvalue);
native void fuckZones_ReloadEffects();
native void fuckZones_RegenerateZones();
native bool fuckZones_IsClientInZone(int client, const char[] name);
native bool fuckZones_IsClientInZoneIndex(int client, int zone);
native bool fuckZones_TeleportClientToZone(int client, const char[] name);
native bool fuckZones_TeleportClientToZoneIndex(int client, int zone);
native int fuckZones_GetClientZone(int client); // returns -1 if client is not in any Zone. if Client is in multiple zones returns first occure.

/*
 * Don't close this ArrayList. It will handled by fuckZones.
 *
 * return                Index or -1 for invalid index
 *
 */
native ArrayList fuckZones_GetEffectsList();

/*
 * Don't close this StringMap. It will handled by fuckZones.
 *
 * return                Index or -1 for invalid index
 *
 */
native StringMap fuckZones_GetZoneEffects(int zone);

/*
 *
 * return                Zone Type, 0 and lower is invalid type.
 *
 */
native int fuckZones_GetZoneType(int zone);
native bool fuckZones_GetZoneName(int zone, char[] name, int length);

native bool fuckZones_GetColorNameByCode(int color[4], char[] name, int length);
native bool fuckZones_GetColorCodeByName(const char[] name, int color[4]);
native bool fuckZones_GetDisplayNameByType(int type, char[] name, int length);
native int fuckZones_GetDisplayTypeByName(const char[] name);

/* 
 * Returns an ArrayList where all zones are saved.
 * It's a cloned ArrayList, so it must be closed.
 * 
* return                ArrayList, or -1 for no ArrayList
 *
 */
native ArrayList fuckZones_GetZoneList();

native bool fuckZones_IsPointInZone(int zone, float point[3]);



/**----------------------------------------------------------*/
// Forwards

/**
* Called whenever the plugin requests for effects to be registered.
* You should use this post forward to register new effects.
*
* noreturn
**/
forward void fuckZones_OnEffectsReady();

/**
* Called right before a player enters the zone.
*
* param client          Client index.
* param entity          Entity index for this zone.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action fuckZones_OnStartTouchZone(int client, int entity, const char[] zone_name, int type);

/**
* Called right before each tick while a player is in a zone.
*
* param client          Client index.
* param entity          Entity index for this zone.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action fuckZones_OnTouchZone(int client, int entity, const char[] zone_name, int type);

/**
* Called right before once a player leaves the zone.
*
* param client          Client index.
* param entity          Entity index for this zone.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action fuckZones_OnEndTouchZone(int client, int entity, const char[] zone_name, int type);

/**
* Called right after a player enters the zone.
*
* param client          Client index.
* param entity          Entity index for this zone.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnStartTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
* Called right after each tick while a player is in a zone.
*
* param client          Client index.
* param entity          Entity index for this zone.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
* Called right after once a player leaves the zone.
*
* param client          Client index.
* param entity          Entity index for this zone.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
* Called right after created zone
*
* param entity          Entity index.
* param zone_name       Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type);

/**
* Called right after updated effect
*
* param entity          Entity index.
* param zone_name       Name of the zone.
* param type            Type of zone.
* param values          StringMap with all effects + keys with values
*                       Don close this StringMap.
*
* noreturn
**/
forward void fuckZones_OnEffectUpdate(int zone, const char[] name, int type, StringMap values);



/**----------------------------------------------------------*/
// Stocks

stock any fuckZones_ClampCell(any value, any min, any max)
{
	if (value < min)
	{
		value = min;
	}

	if (value > max)
	{
		value = max;
	}

	return value;
}

stock bool fuckZones_IsPositionNull(float position[3])
{
	if (position[0] == 0.0 && position[1] == 0.0 && position[2] == 0.0)
	{
		return true;
	}

	return false;
}

stock void fuckZones_GetCurrentWorkshopMap(char[] sMap, int iMapSize)
{
	GetCurrentMap(sMap, iMapSize);
	ReplaceString(sMap, iMapSize, "/", "-", false);
} 

#if !defined REQUIRE_PLUGIN
public void __pl_fuckZones_SetNTVOptional()
{
	MarkNativeAsOptional("fuckZones_RegisterEffect");
	MarkNativeAsOptional("fuckZones_RegisterEffectKey");
	MarkNativeAsOptional("fuckZones_ReloadEffects");
	MarkNativeAsOptional("fuckZones_RegenerateZones");
	MarkNativeAsOptional("fuckZones_IsClientInZone");
	MarkNativeAsOptional("fuckZones_IsClientInZoneIndex");
	MarkNativeAsOptional("fuckZones_TeleportClientToZone");
	MarkNativeAsOptional("fuckZones_TeleportClientToZoneIndex");
	MarkNativeAsOptional("fuckZones_GetEffectsList");
	MarkNativeAsOptional("fuckZones_GetZoneEffects");
	MarkNativeAsOptional("fuckZones_GetZoneType");
	MarkNativeAsOptional("fuckZones_GetZoneName");
	MarkNativeAsOptional("fuckZones_GetColorNameByCode");
	MarkNativeAsOptional("fuckZones_GetColorCodeByName");
	MarkNativeAsOptional("fuckZones_GetDisplayNameByType");
	MarkNativeAsOptional("fuckZones_GetDisplayTypeByName");
	MarkNativeAsOptional("fuckZones_GetZoneList");
	MarkNativeAsOptional("fuckZones_IsPointInZone");
}
#endif

public SharedPlugin __pl_fuckZones =
{
	name = "fuckZones",
	file = "fuckZones.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
