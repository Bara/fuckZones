#if defined _zones_manager_included
  #endinput
#endif
#define _zones_manager_included

typedef Zones_Manager_Effect_OnEnterZone = function void (int client, StringMap values);

/**----------------------------------------------------------*/
//Forwards

native void Zones_Manager_Register_Effect(const char[] name, Zones_Manager_Effect_OnEnterZone OnEnterZone = INVALID_FUNCTION);

/**----------------------------------------------------------*/
//Forwards

/**
* Called right before a player enters the zone.
*
* param client		    Client index.
* param id              Index of the zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
* param entity          Index of the entity touched. (only used by box-type zones)
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action ZonesManager_OnStartTouchZone(int client, int id, const char[] zone_name, int type, int entity);

/**
* Called right before each tick while a player is in a zone.
*
* param client		    Client index.
* param entity_or_id	Index of the zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
* param entity          Index of the entity touched. (only used by box-type zones)
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action ZonesManager_OnTouchZone(int client, int id, const char[] zone_name, int type, int entity);

/**
* Called right before once a player leaves the zone.
*
* param client		    Client index.
* param entity_or_id	Index of the zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
* param entity          Index of the entity touched. (only used by box-type zones)
*
* return                Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action ZonesManager_OnEndTouchZone(int client, int id, const char[] zone_name, int type, int entity);

/**
* Called right after a player enters the zone.
*
* param client		    Client index.
* param entity_or_id	Index of the zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
* param entity          Index of the entity touched. (only used by box-type zones)
*
* noreturn
**/
forward void ZonesManager_OnStartTouchZone_Post(int client, int id, const char[] zone_name, int type, int entity);

/**
* Called right after each tick while a player is in a zone.
*
* param client		    Client index.
* param entity_or_id	Index of the zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
* param entity          Index of the entity touched. (only used by box-type zones)
*
* noreturn
**/
forward void ZonesManager_OnTouchZone_Post(int client, int id, const char[] zone_name, int type, int entity);

/**
* Called right after once a player leaves the zone.
*
* param client		    Client index.
* param entity_or_id	Index of the zone.
* param zone_name		Name of the zone.
* param type            Type of zone.
* param entity          Index of the entity touched. (only used by box-type zones)
*
* noreturn
**/
forward void ZonesManager_OnEndTouchZone_Post(int client, int id, const char[] zone_name, int type, int entity);

#if !defined REQUIRE_PLUGIN
public void __pl_zones_manager_SetNTVOptional()
{
	MarkNativeAsOptional("Zones_Manager_Register_Effect");
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
