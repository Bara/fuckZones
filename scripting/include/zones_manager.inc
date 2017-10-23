#if defined _zones_manager_included
#endinput
#endif
#define _zones_manager_included

#define MAX_RADIUS_ZONES 256
#define MAX_ZONES 256

#define MAX_ZONE_NAME_LENGTH 128
#define MAX_ZONE_TYPE_LENGTH 64

#define MAX_EFFECT_NAME_LENGTH 128

#define MAX_KEY_NAME_LENGTH 128
#define MAX_KEY_VALUE_LENGTH 128

#define MAX_EFFECT_CALLBACKS 3
#define EFFECT_CALLBACK_ONENTERZONE 0
#define EFFECT_CALLBACK_ONACTIVEZONE 1
#define EFFECT_CALLBACK_ONLEAVEZONE 2

#define DEFAULT_MODELINDEX "sprites/laserbeam.vmt"
#define DEFAULT_HALOINDEX "materials/sprites/halo.vmt"

#define ZONE_TYPES 3
#define ZONE_TYPE_BOX 0
#define ZONE_TYPE_CIRCLE 1
#define ZONE_TYPE_POLY 2

#define ZONE_INDEX_CURRENT -1337

typedef Zones_Manager_Effect_OnEnterZone = function void(int client, int entity, StringMap values);
typedef Zones_Manager_Effect_OnActiveZone = function void(int client, int entity, StringMap values);
typedef Zones_Manager_Effect_OnLeaveZone = function void(int client, int entity, StringMap values);

/**----------------------------------------------------------*/
//Forwards

/**
 * Registers a new zone effect.
 *
 * @param name			Name of the new effect.
 * @param OnEnterZone	The function which gets called when somebody enters the zone.
 * @param OnActiveZone	The function which gets called when a client is sitting in the zone.
 * @param OnLeaveZone	The function which gets called when a client leaves the zone.
 */
native void ZonesManager_RegisterEffect(const char[] name, Zones_Manager_Effect_OnEnterZone OnEnterZone = INVALID_FUNCTION, Zones_Manager_Effect_OnActiveZone OnActiveZone = INVALID_FUNCTION, Zones_Manager_Effect_OnLeaveZone OnLeaveZone = INVALID_FUNCTION);

/**
 * Registers a new zone effect key.
 */
native void ZonesManager_RegisterEffectKey(const char[] name, const char[] effect, const char[] defaultvalue);

/**
 * Registers a new zone effect key.
 */
native void ZonesManager_RequestQueueEffects();

/**
 * Saves current map zones to config (Currently does not work with zones created by natives).
 */
native void ZonesManager_SaveZones();

/**
 * Checks is a client is currently inside a zone.
 *
 * @param client		Client index.
 * @param zone			Index of the zone.
 * @return				True if the client is inside the zone, false otherwise.
 */
native bool ZonesManager_IsClientInZone(int client, int zone);

/**
 * Gets a zone index by its name.
 *
 * @param name			Name of the zone.
 * @return				Zone index, -1 on failure.
 */
native int ZonesManager_GetZoneIndexByName(const char[] name);

/**
 * Teleports a client inside a zone.
 *
 * @param client		Client index.
 * @param zone			Index of the zone.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_TeleportClientToZone(int client, int zone);

/**
 * Gets a clients current look point.
 *
 * @param client		Client index.
 * @param point			Buffer to store the vector points.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_GetClientLookPoint(int client, float point[3]);

/**
 * Starts a zone creation.
 *
 * @param type			Zone type.
 * @param name			Zone name.
 * @return				Index of the newly created zone.
 */
native int ZonesManager_StartZone(int type, const char[] name);

/**
 * Sets a zones name.
 *
 * @param zone			Index of the zone.
 * @param name			Zone name.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_SetZoneName(int zone, const char[] name);

/**
 * Sets a zones start point.
 *
 * @param zone			Index of the zone.
 * @param start			Start vector.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_SetZoneStart(int zone, float start[3]);

/**
 * Sets a zones end point.
 * This is currently only required for box zones.
 *
 * @param zone			Index of the zone.
 * @param end			End vector.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_SetZoneEnd(int zone, float end[3]);

/**
 * Sets a zones end point.
 * This is currently only required for circle zones.
 *
 * @param zone			Index of the zone.
 * @param radius		Radius of the circle.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_SetZoneRadius(int zone, float radius);

/**
 * Sets a zones color.
 * This uses decimal RGB color codes where 0 is R, 1 is G, 2 is B and 3 is alpha.
 *
 * @param zone			Index of the zone.
 * @param color			Array of decimal RGB colors.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_SetZoneColor(int zone, int color[4]);

/**
 * Sets a zones points height.
 * This is currently only required for polygon zones.
 *
 * @param zone			Index of the zone.
 * @param height		Height of the zone points.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_SetPointsHeight(int zone, float height);

/**
 * Adds a point to a zone.
 * This is currently only required for polygon zones.
 *
 * @param zone			Index of the zone.
 * @param point			Point vector to add.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_AddZonePoint(int zone, float point[3]);

/**
 * Adds a list of point to a zone.
 * This is currently only required for polygon zones.
 *
 * @param zone			Index of the zone.
 * @param points		ArrayList of points to add.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_AddMultipleZonePoints(int zone, ArrayList points);

/**
 * Removes a point from a zone.
 * This is currently only required for polygon zones.
 *
 * @param zone			Index of the zone.
 * @param points		Point vector to remove.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_RemoveZonePoint(int zone, float point[3]);

/**
 * Remove a list of point from a zone.
 * This is currently only required for polygon zones.
 *
 * @param zone			Index of the zone.
 * @param points		ArrayList of points to remove.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_RemoveMultipleZonePoints(int zone, ArrayList points);

/**
 * Remove all points from a zone.
 * This is currently only required for polygon zones.
 *
 * @param zone			Index of the zone.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_RemoveAllZonePoints(int zone);

/**
 * Finishes a zone creation and spawns it into the world.
 * This should be called last after initializing the zone with the other natives.
 *
 * @param zone			Index of the zone.
 * @return				Index to the zone, -1 on failure.
 */
native int ZonesManager_FinishZone(int zone);

/**
 * Creates a zone (Advanced).
 * This is useful when loading existing zones which you may have saved.
 * This function assumes you know what you are doing and does not do any error checking!
 *
 * @param type			Type of the zone.
 * @param name			Zone name.
 * @param start			Start vector.
 * @param end			End vector (Currently only required for box zones).
 * @param radius		Zone radius (Currently only required for circle zones).
 * @param color			Zone color (This uses decimal RGB color codes where 0 is R, 1 is G, 2 is B and 3 is alpha).
 * @param points		ArrayList of zone points (Currently only required for polygon zones).
 * @param height		Height of zone points (Currently only required for polygon zones).
 * @param height		ArrayList of effects for the zone.
 * @return				Index to the zone, -1 on failure.
 */
native int ZonesManager_CreateZoneAdvanced(int type, const char[] name, float start[3], float end[3] =  { -1.0, -1.0, -1.0 }, float radius = -1.0, int color[4] =  { 255, 255, 0, 255 }, ArrayList points = null, float height = 256.0, StringMap effects = null);

/**
 * Adds an effect to the zone.
 *
 * @param zone			Index of the zone.
 * @param effect		Name of effect to add.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_AddZoneEffect(int zone, const char[] name);

/**
 * Removes an effect from the zone.
 *
 * @param zone			Index of the zone.
 * @param effect		Name of effect to remove.
 * @return				True if successful, false otherwise.
 */
native bool ZonesManager_RemoveZoneEffect(int zone, const char[] name);

/**----------------------------------------------------------*/
//Forwards

/**
 * Called whenever the plugin requests for effects to be registered.
 * You should use this post forward to register new effects.
**/
forward void ZonesManager_OnQueueEffects_Post();

/**
 * Called right before a player enters the zone.
 *
 * @param client		  	Client index.
 * @param entity         	Entity index for this zone.
 * @param zone_name			Name of the zone.
 * @param type            	Type of zone.
 * @return                	Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action ZonesManager_OnStartTouchZone(int client, int entity, const char[] zone_name, int type);

/**
 * Called right before each tick while a player is in a zone.
 *
 * @param client		    Client index.
 * @param entity       		Entity index for this zone.
 * @param zone_name			Name of the zone.
 * @param type          	Type of zone.
 * @return              	Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action ZonesManager_OnTouchZone(int client, int entity, const char[] zone_name, int type);

/**
 * Called right before once a player leaves the zone.
 *
 * @param client			Client index.
 * @param entity          	Entity index for this zone.
 * @param zone_name			Name of the zone.
 * @param type            	Type of zone.
 * @return                	Plugin_Handled or Plugin_Stop = stops post forward counterpart from firing.
**/
forward Action ZonesManager_OnEndTouchZone(int client, int entity, const char[] zone_name, int type);

/**
 * Called right after a player enters the zone.
 *
 * @param client			Client index.
 * @param entity          	Entity index for this zone.
 * @param zone_name			Name of the zone.
 * @param type            	Type of zone.
**/
forward void ZonesManager_OnStartTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
 * Called right after each tick while a player is in a zone.
 *
 * @param client			Client index.
 * @param entity          	Entity index for this zone.
 * @param zone_name			Name of the zone.
 * @param type            	Type of zone.
**/
forward void ZonesManager_OnTouchZone_Post(int client, int entity, const char[] zone_name, int type);

/**
 * Called right after once a player leaves the zone.
 *
 * @param client			Client index.
 * @param entity          	Entity index for this zone.
 * @param zone_name			Name of the zone.
 * @param type            	Type of zone.
**/
forward void ZonesManager_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type);

#if !defined REQUIRE_PLUGIN
public void __pl_zones_manager_SetNTVOptional()
{
	MarkNativeAsOptional("ZonesManager_RequestQueueEffects");
	MarkNativeAsOptional("ZonesManager_SaveZones");
	MarkNativeAsOptional("ZonesManager_IsClientInZone");
	MarkNativeAsOptional("ZonesManager_GetZoneIndexByName");
	MarkNativeAsOptional("ZonesManager_TeleportClientToZone");
	MarkNativeAsOptional("ZonesManager_GetClientLookPoint");
	MarkNativeAsOptional("ZonesManager_RegisterEffect");
	MarkNativeAsOptional("ZonesManager_RegisterEffectKey");
	MarkNativeAsOptional("ZonesManager_CreateZoneAdvanced");
	MarkNativeAsOptional("ZonesManager_StartZone");
	MarkNativeAsOptional("ZonesManager_SetZoneName");
	MarkNativeAsOptional("ZonesManager_SetZoneStart");
	MarkNativeAsOptional("ZonesManager_SetZoneEnd");
	MarkNativeAsOptional("ZonesManager_SetZoneRadius");
	MarkNativeAsOptional("ZonesManager_SetZoneColor");
	MarkNativeAsOptional("ZonesManager_SetPointsHeight");
	MarkNativeAsOptional("ZonesManager_AddZonePoint");
	MarkNativeAsOptional("ZonesManager_AddMultipleZonePoints");
	MarkNativeAsOptional("ZonesManager_RemoveZonePoint");
	MarkNativeAsOptional("ZonesManager_RemoveMultipleZonePoints");
	MarkNativeAsOptional("ZonesManager_RemoveAllZonePoints");
	MarkNativeAsOptional("ZonesManager_AddZoneEffect");
	MarkNativeAsOptional("ZonesManager_RemoveZoneEffect");
	MarkNativeAsOptional("ZonesManager_FinishZone");
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