#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <shop>
	
char g_sSound[MAXPLAYERS+1][PLATFORM_MAX_PATH];

StringMap g_hHitsounds;

public Plugin myinfo =
{
	name = "[Shop] HitSounds",
	author = ".NiGHT",
	version = "1.4",
	url  = "github.com/NiGHT757/-SHOP-Hitsounds"
};

public void OnPluginStart()
{
	g_hHitsounds = new StringMap();

	if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];

	StringMapSnapshot MapSnapshot = g_hHitsounds.Snapshot();
	for(int i = 0, iLength = MapSnapshot.Length; i < iLength; i++)
	{
		MapSnapshot.GetKey(i, sBuffer, sizeof(sBuffer));
		
		g_hHitsounds.GetString(sBuffer, sBuffer, sizeof(sBuffer));
		PrecacheSound(sBuffer, true);

		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}
	delete MapSnapshot;
}

public void Shop_Started()
{
	char sName[64], sDescription[64];
	char sBuffer[PLATFORM_MAX_PATH];

	KeyValues kv = new KeyValues("Hitsounds");

	Shop_GetCfgFile(sBuffer, sizeof(sBuffer), "hitsounds.txt");

	if (!kv.ImportFromFile(sBuffer)) 
		SetFailState("Couldn't parse file %s", sBuffer);
	
	kv.GetString("name", sName, sizeof(sName), "HitSounds");
	kv.GetString("description", sDescription, sizeof(sDescription));
	
	CategoryId category_id = Shop_RegisterCategory("hit_sounds", sName, sDescription);
	
	if (kv.GotoFirstSubKey(true))
	{
		do
		{
			if (kv.GetSectionName(sName, sizeof(sName)) && Shop_StartItem(category_id, sName))
			{
				kv.GetString("sound", sBuffer, sizeof(sBuffer));
				g_hHitsounds.SetString(sName, sBuffer);

				kv.GetString("name", sName, sizeof(sName), sName);
				kv.GetString("description", sDescription, sizeof(sDescription), "");
				Shop_SetInfo(sName, sDescription, kv.GetNum("price", 1000), kv.GetNum("sellprice", -1), Item_Togglable, kv.GetNum("duration", 604800));
				Shop_SetCallbacks(_, OnEquipItem, _, _, _, OnPreviewItem);
				Shop_EndItem();
			}
		} while (kv.GotoNextKey(true));
	}
	delete kv;
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	g_sSound[client][0] = '\0';
}

public ShopAction OnEquipItem(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_sSound[iClient][0] = '\0';
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(iClient, category_id);
	
	if(g_hHitsounds.GetString(item, g_sSound[iClient], sizeof(g_sSound[])))
		return Shop_UseOn;
	
	PrintToChat(iClient, " [\x02SHOP\x01] \x02ERROR: \x01Failed to activate hitsounds.");
	return Shop_Raw;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], float damagePosition[3])
{		
	if(!damage || !IsClientValid(attacker) || !g_sSound[attacker][0] || !IsClientValid(victim) || GetClientTeam(attacker) == GetClientTeam(victim))
		return;
	
	EmitSoundToClient(attacker, g_sSound[attacker], attacker, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS);
}

public void OnPreviewItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	char buffer[PLATFORM_MAX_PATH];
	
	if(!g_hHitsounds.GetString(item, buffer, PLATFORM_MAX_PATH))
	{
		LogError("It seems that registered item \"%s\" not exists in the settings", item);
		return;
	}

	EmitSoundToClient(client, buffer, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS);
}

stock bool IsClientValid(int client)
{
    return (client && client <= MaxClients) && IsClientInGame(client);
}