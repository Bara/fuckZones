#if defined _zones_manager_included
  #endinput
#endif
#define _zones_manager_included

typedef Zones_Manager_Effect_OnEnterZone = function void (int client, int entity, StringMap values);
typedef Zones_Manager_Effect_OnActiveZone = function void (int client, int entity, StringMap values);
typedef Zones_Manager_Effect_OnLeaveZone = function void (int client, int entity, StringMap values);

/**----------------------------------------------------------*/
//Forwards

native void ZonesManager_Register_Effect(const char[] name, Zones_Manager_Effect_OnEnterZone OnEnterZone = INVALID_FUNCTION, Zones_Manager_Effect_OnActiveZone OnActiveZone = INVALID_FUNCTION, Zones_Manager_Effect_OnLeaveZone OnLeaveZone = INVALID_FUNCTION);
native void ZonesManager_Register_Effect_Key(const char[] name, const char[] effect, const char[] defaultvalue);
native void ZonesManager_Request_QueueEffects();
native bool ZonesManager_IsClientInZone(int client, const char[] name);
native bool ZonesManager_TeleportClientToZone(int client, const char[] name);

/**----------------------------------------------------------*/
//Forwards

/**
* Called whenever the plugin requests for effects to be registered.
* You should use this post forward to register new effects.
*
* noreturn
**/
forward void ZonesManager_OnQueueEffects_Post();

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
forward Action ZonesManager_OnStartTouchZone(int client, int entity, const char[] zone_name, int type);

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
forward Action ZonesManager_OnTouchZone(int client, int entity, const char[] zone_name, int type);

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
forward Action ZonesManager_OnEndTouchZone(int client, int entity, const char[] zone_name, int type);

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
forward void ZonesManager_OnStartTouchZone_Post(int client, int entity, const char[] zone_name, int type);

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
forward void ZonesManager_OnTouchZone_Post(int client, int entity, const char[] zone_name, int type);

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
forward void ZonesManager_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type);

#if !defined REQUIRE_PLUGIN
public void __pl_zones_manager_SetNTVOptional()
{
	MarkNativeAsOptional("ZonesManager_Register_Effect");
	MarkNativeAsOptional("ZonesManager_Register_Effect_Key");
	MarkNativeAsOptional("ZonesManager_Request_QueueEffects");
	MarkNativeAsOptional("ZonesManager_IsClientInZone");
}
#endif

public SharedPlugin __pl_zones_manager =
{
	name = "zones_manager",
	file = "zones_manager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
