#if defined _fuckZones_included
  #endinput
#endif
#define _fuckZones_included

#define MAX_ZONE_NAME_LENGTH 128
#define MAX_ZONE_TYPE_LENGTH 64

#define MAX_EFFECT_NAME_LENGTH 128

#define MAX_KEY_NAME_LENGTH 128
#define MAX_KEY_VALUE_LENGTH 128

#define MAX_EFFECT_CALLBACKS 3
#define EFFECT_CALLBACK_ONENTERZONE 0
#define EFFECT_CALLBACK_ONACTIVEZONE 1
#define EFFECT_CALLBACK_ONLEAVEZONE 2

#define ZONE_TYPES 4
#define ZONE_TYPE_NONE 0
#define ZONE_TYPE_BOX 1
#define ZONE_TYPE_CIRCLE 2
#define ZONE_TYPE_POLY 3

#define DISPLAY_TYPE_TYPES 3
#define DISPLAY_TYPE_FULL 0
#define DISPLAY_TYPE_BOTTOM 1
#define DISPLAY_TYPE_HIDE 2

typedef fuckZones_Effect_OnEnterZone = function void (int client, int entity, StringMap values);
typedef fuckZones_Effect_OnActiveZone = function void (int client, int entity, StringMap values);
typedef fuckZones_Effect_OnLeaveZone = function void (int client, int entity, StringMap values);

/**----------------------------------------------------------*/
//Forwards

native void fuckZones_Register_Effect(const char[] name, fuckZones_Effect_OnEnterZone OnEnterZone = INVALID_FUNCTION, fuckZones_Effect_OnActiveZone OnActiveZone = INVALID_FUNCTION, fuckZones_Effect_OnLeaveZone OnLeaveZone = INVALID_FUNCTION);
native void fuckZones_Register_Effect_Key(const char[] name, const char[] effect, const char[] defaultvalue);
native void fuckZones_Request_QueueEffects();
native bool fuckZones_IsClientInZone(int client, const char[] name);
native bool fuckZones_TeleportClientToZone(int client, const char[] name);

/**----------------------------------------------------------*/
//Forwards

/**
* Called whenever the plugin requests for effects to be registered.
* You should use this post forward to register new effects.
*
* noreturn
**/
forward void fuckZones_OnQueueEffects_Post();

/**
* Called right before a player enters the zone.
*
* param client		    Client index.
* param entity          Entity index for this zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action fuckZones_OnStartTouchZone(int client, int entity, const char[] zone_name, int type);

/**
* Called right before each tick while a player is in a zone.
*
* param client		    Client index.
* param entity          Entity index for this zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action fuckZones_OnTouchZone(int client, int entity, const char[] zone_name, int type);

/**
* Called right before once a player leaves the zone.
*
* param client		    Client index.
* param entity          Entity index for this zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action fuckZones_OnEndTouchZone(int client, int entity, const char[] zone_name, int type);

/**
* Called right after a player enters the zone.
*
* param client		    Client index.
* param entity          Entity index for this zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnStartTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
* Called right after each tick while a player is in a zone.
*
* param client		    Client index.
* param entity          Entity index for this zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
* Called right after once a player leaves the zone.
*
* param client		    Client index.
* param entity          Entity index for this zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
*
* noreturn
**/
forward void fuckZones_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckZones_SetNTVOptional()
{
	MarkNativeAsOptional("ffuckZones_Register_Effect");
	MarkNativeAsOptional("ffuckZones_Register_Effect_Key");
	MarkNativeAsOptional("ffuckZones_Request_QueueEffects");
	MarkNativeAsOptional("ffuckZones_IsClientInZone");
	MarkNativeAsOptional("ffuckZones_TeleportClientToZone");
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
