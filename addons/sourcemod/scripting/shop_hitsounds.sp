#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <shop>

KeyValues Kv;

bool g_bEnabled[MAXPLAYERS+1];
	
char g_sSound[MAXPLAYERS+1][PLATFORM_MAX_PATH];

StringMap g_hHitsounds;

public Plugin myinfo =
{
	name = "[Shop] HitSounds",
	author = ".NiGHT",
	version = "1.3",
	url  = "https://steamcommunity.com/id/NiGHT757"
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
	char buffer[PLATFORM_MAX_PATH], sSound[PLATFORM_MAX_PATH], sName[64];

	if (Kv != null) Kv.Close();
	Kv = new KeyValues("Hitsounds");
	g_hHitsounds.Clear();
	Shop_GetCfgFile(buffer, sizeof(buffer), "hitsounds.txt");

	if (!Kv.ImportFromFile(buffer)) 
		SetFailState("Couldn't parse file %s", buffer);
		
	if (Kv.GotoFirstSubKey(true))
	{
		do
		{
			if (Kv.GetSectionName(sName, sizeof(sName)))
			{
				Kv.GetString("sound", sSound, sizeof(sSound));
				g_hHitsounds.SetString(sName, sSound);
				FakePrecacheSound(sSound);
				Format(sSound, sizeof(sSound), "sound/%s", sSound);
				AddFileToDownloadsTable(sSound);
			}
		} while (Kv.GotoNextKey(true));
	}
	Kv.Rewind();
}

public void Shop_Started()
{
	if (Kv == null) OnMapStart();
	Kv.Rewind();
	char sName[64], sDescription[64];
	Kv.GetString("name", sName, sizeof(sName), "HitSounds");
	Kv.GetString("description", sDescription, sizeof(sDescription));
	
	CategoryId category_id = Shop_RegisterCategory("hit_sounds", sName, sDescription);
	
	Kv.Rewind();
	
	if (Kv.GotoFirstSubKey(true))
	{
		do
		{
			if (Kv.GetSectionName(sName, sizeof(sName)) && Shop_StartItem(category_id, sName))
			{
				Kv.GetString("name", sName, sizeof(sName), sName);
				Kv.GetString("description", sDescription, sizeof(sDescription), "");
				Shop_SetInfo(sName, sDescription, Kv.GetNum("price", 1000), Kv.GetNum("sellprice", -1), Item_Togglable, Kv.GetNum("duration", 604800));
				Shop_SetCallbacks(_, OnEquipItem, _, _, _, OnPreviewItem);
				Shop_EndItem();
			}
		} while (Kv.GotoNextKey(true));
	}
	Kv.Rewind();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnClientPostAdminCheck(int client)
{
	g_bEnabled[client] = false;
}

public ShopAction OnEquipItem(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bEnabled[iClient] = false;
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(iClient, category_id);
	
	if(g_hHitsounds.GetString(item, g_sSound[iClient], sizeof(g_sSound[])))
	{
		g_bEnabled[iClient] = true;
		return Shop_UseOn;
	}
	
	PrintToChat(iClient, " [\x02SHOP\x01] \x02ERROR: \x01Failed to activate hitsounds.");
	return Shop_Raw;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], float damagePosition[3])
{		
	if(!g_bEnabled[attacker] || damage < 1 || !IsValidClient(attacker) || !IsValidClient(victim) || GetClientTeam(attacker) == GetClientTeam(victim))
		return;
	
	EmitSoundToClient(attacker, g_sSound[attacker], attacker, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS);
}

public void OnPreviewItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	char buffer[PLATFORM_MAX_PATH];
	
	Kv.Rewind();
	if(!g_hHitsounds.GetString(item, buffer, PLATFORM_MAX_PATH))
	{
		LogError("It seems that registered item \"%s\" not exists in the settings", item);
		return;	
	}

	EmitSoundToClient(client, buffer, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS);
}

stock void FakePrecacheSound(const char[] szPath)
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}

stock bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;
		
	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}