#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zones_manager>

public Plugin myinfo =
{
	name = "Zones-Manager: Furious Knife Only",
	author = "Keith Warren (Drixevel)",
	description = "A furious plugin to add a quick zone type for the zones manager interface.",
	version = "1.0.0",
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("zonesmanager.phrases");
}

public void ZonesManager_OnTouchZone_Post(int activator, int zone_entity, const char[] zone_name)
{
	if (StrEqual(zone_name, "Furious Knife Only") && activator > 0 && activator < MaxClients)
	{
		int melee = GetPlayerWeaponSlot(activator, 2);

		if (melee != -1)
		{
			SetEntPropEnt(activator, Prop_Send, "m_hActiveWeapon", melee);
		}
	}
}
