#if defined _zones_manager_included
  #endinput
#endif
#define _zones_manager_included

forward Action ZonesManager_OnStartTouchZone(int activator, int zone_entity, const char[] zone_name);
forward Action ZonesManager_OnTouchZone(int activator, int zone_entity, const char[] zone_name);
forward Action ZonesManager_OnEndTouchZone(int activator, int zone_entity, const char[] zone_name);
forward void ZonesManager_OnStartTouchZone_Post(int activator, int zone_entity, const char[] zone_name);
forward void ZonesManager_OnTouchZone_Post(int activator, int zone_entity, const char[] zone_name);
forward void ZonesManager_OnEndTouchZone_Post(int activator, int zone_entity, const char[] zone_name);

#if !defined REQUIRE_PLUGIN
public __pl_zones_manager_SetNTVOptional()
{
	//MarkNativeAsOptional("");
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
