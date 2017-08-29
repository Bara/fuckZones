//Pragma
#pragma semicolon 1
#pragma newdecls required

//Sourcemod Includes
#include <sourcemod>
#include <tf2_stocks>
#include <zones_manager>

//ConVars
ConVar convar_Status;

//Globals

public Plugin myinfo =
{
	name = "Zones Manager - Effect - Melee Only",
	author = "Keith Warren (Drixevel)",
	description = "An effect for the zones manager plugin that applies melee only to clients.",
	version = "1.0.0",
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	convar_Status = CreateConVar("sm_zones_effect_meleeonly_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public void OnConfigsExecuted()
{
	Zones_Manager_Register_Effect("melee only", Effect_OnEnterZone, INVALID_FUNCTION, Effect_OnLeaveZone);
}

public void Effect_OnEnterZone(int client, int entity, StringMap values)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	TF2_AddCondition(client, TFCond_RestrictToMelee, TFCondDuration_Infinite);
}

public void Effect_OnLeaveZone(int client, int entity, StringMap values)
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	TF2_RemoveCondition(client, TFCond_RestrictToMelee);
}
