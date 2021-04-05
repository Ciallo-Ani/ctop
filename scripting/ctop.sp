#include <sourcemod>
#include <morecolors>
#include <ctop>

#pragma newdecls required
#pragma semicolon 1

// database handle
Database gH_SQL = null;
bool gB_Connected = false;
bool gB_MySQL = false;

// Current map's name
char gS_Map[160];

// total start time
float g_fStartTime = -1.0;

// Reset Player's deaths
bool g_bResetDeaths[MAXPLAYERS + 1];

// player timer variables
playertimer_t gA_Timers[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[NMRIH] ctop",
	author = "Ciallo",
	description = "record runtime to sql and print it to chat",
	version = "2.0",
	url = "https://steamcommunity.com/id/anie1337/"
};

public void OnPluginStart()
{
	LoadTranslations("ctop.phrases");

	HookEvent("nmrih_round_begin", TIMER_START);
	HookEvent("player_extracted", TIMER_END);
	HookEvent("player_death", EVENT_DEATH);
	HookEvent("npc_killed", EVENT_NPC);

	RegConsoleCmd("sm_wr", Command_WR, "print wr in chat");
	RegConsoleCmd("sm_top", Command_TOP, "print wr in chat");
	/* RegConsoleCmd("sm_test", Command_test, "test"); */
	
	SQL_DBConnect();
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	// Get mapname
	GetCurrentMap(gS_Map, 160);

	// fuck workshop map
	GetMapDisplayName(gS_Map, gS_Map, 160);
}

public void OnClientPutInServer(int client)
{
	gA_Timers[client].iDeaths = 0;
	gA_Timers[client].iKills = 0;
}

/* public Action Command_test(int client, int args)
{
	
} */

public Action TIMER_START(Event e, const char[] n, bool b)
{
	g_fStartTime = GetGameTime();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		gA_Timers[i].iDeaths = 0;
		gA_Timers[i].iKills = 0;
	}
}

public Action TIMER_END(Event e, const char[] n, bool b)
{
	int client = e.GetInt("player_id");

	// Get client name
	GetClientName(client, gA_Timers[client].sName, 128);
	
	// Get SteamID
	gA_Timers[client].iSteamid = GetSteamAccountID(client);
	
	// Get runtime and format it to a string
	gA_Timers[client].fFinalTime = GetGameTime() - g_fStartTime;
	FormatTimeFloat(1, gA_Timers[client].fFinalTime, 3, gA_Timers[client].sFinalTime, 32);

	char sQuery[512];

	FormatEx(sQuery, 512, "SELECT time, counts FROM playertimes WHERE map = '%s' AND auth = %d ORDER BY time ASC;", gS_Map, gA_Timers[client].iSteamid);

	gH_SQL.Query(SQL_OnFinishCheck_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public Action EVENT_DEATH(Event e, const char[] n, bool b)
{
	int client = GetClientOfUserId(e.GetInt("userid"));

	if(g_bResetDeaths[client])
	{
		gA_Timers[client].iDeaths = 0;
		g_bResetDeaths[client] = false;
	}

	gA_Timers[client].iDeaths++;
}

public Action EVENT_NPC(Event e, const char[] n, bool b)
{
	int client = e.GetInt("killeridx");

	if(IsValidClient(client))
	{
		gA_Timers[client].iKills++;
	}
}

public Action Command_WR(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[32];

	if (args == 0)
	{
		FormatEx(sCommand, 160, "%s", gS_Map);
	}
	else
	{
		GetCmdArg(1, sCommand, 32);
	}

	ShowWR(client, sCommand);

	return Plugin_Handled;
}

public Action Command_TOP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[32];

	if (args == 0)
	{
		FormatEx(sCommand, 160, "%s", gS_Map);
	}
	else
	{
		GetCmdArg(1, sCommand, 32);
	}

	StartWRMenu(client, sCommand);

	return Plugin_Handled;
}

void ShowWR(int client, const char[] map)
{
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteString(map);

	int iLength = ((strlen(map) * 2) + 1);
	char[] sEscapedMap = new char[iLength];
	gH_SQL.Escape(map, sEscapedMap, iLength);

	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT name, time, deaths, kills FROM playertimes WHERE map = '%s' ORDER BY time ASC, kills DESC;", sEscapedMap);
	gH_SQL.Query(SQL_WR_Callback, sQuery, dp);
}

void StartWRMenu(int client, const char[] map)
{
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteString(map);

	int iLength = ((strlen(map) * 2) + 1);
	char[] sEscapedMap = new char[iLength];
	gH_SQL.Escape(map, sEscapedMap, iLength);

	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT name, time, deaths, counts, kills FROM playertimes WHERE map = '%s' ORDER BY time ASC, kills DESC;", sEscapedMap);
	gH_SQL.Query(SQL_WR_Callback2, sQuery, dp);
}

public void SQL_OnFinishCheck_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	if(g_bResetDeaths[client])
	{
		gA_Timers[client].iDeaths = 0;
	}

	char sQuery[512];

	if(results.FetchRow() && results.HasResults)
	{
		gA_Timers[client].iCounts = results.FetchInt(1);
		
		if(gA_Timers[client].fFinalTime < results.FetchFloat(0))
		{
			FormatEx(sQuery, 512,
			"UPDATE playertimes SET time = %f, deaths = %d, counts = counts + 1, kills = %d WHERE map = '%s' AND auth = %d;", 
			gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills, gS_Map, gA_Timers[client].iSteamid);
		}
		else
		{
			FormatEx(sQuery, 512,
			"UPDATE playertimes SET counts = counts + 1 WHERE map = '%s' AND auth = %d;",
			gS_Map, gA_Timers[client].iSteamid);
		}
	}
	else
	{
		FormatEx(sQuery, 512,
		"INSERT INTO playertimes (auth, name, map, time, deaths, counts, kills) VALUES (%d, '%s', '%s', %f, %d, 1, %d);",
		gA_Timers[client].iSteamid, gA_Timers[client].sName, gS_Map, gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills);
	}

	gH_SQL.Query(SQL_OnFinish_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_OnFinish_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer SQL query(onfinish) failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	CPrintToChatAll("%t", "Complete", gA_Timers[client].sName, gA_Timers[client].sFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iKills, ++gA_Timers[client].iCounts);

	g_bResetDeaths[client] = true;
}

public void SQL_WR_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int serial = data.ReadCell();

	char sMap[192];
	data.ReadString(sMap, 192);

	delete data;

	if(results == null)
	{
		LogError("Timer SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(serial);

	if(client == 0)
	{
		return;
	}

	if(results.FetchRow() && results.HasResults)
	{
		// 0 - player name
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, MAX_NAME_LENGTH);

		// 1 - time
		float time = results.FetchFloat(1);
		char sTime[32];
		FormatTimeFloat(1, time, 3, sTime, sizeof(sTime));

		// 2 - deaths
		int deaths = results.FetchInt(2);

		// 3 - kills
		int kills = results.FetchInt(3);

		CPrintToChatAll("%t", "Chat", sName, sMap, sTime, deaths, kills);
	}
	else
	{
		CPrintToChatAll("%t", "NoRecords");
	}
}

public void SQL_WR_Callback2(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int serial = data.ReadCell();

	char sMap[192];
	data.ReadString(sMap, 192);

	delete data;

	if(results == null)
	{
		LogError("Timer SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(serial);

	if(client == 0)
	{
		return;
	}

	Menu hMenu = new Menu(WRMenu_Handler);

	int iCount = 0;

	while(results.FetchRow())
	{
		if(++iCount <= 100)
		{
			// 0 - player name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(0, sName, MAX_NAME_LENGTH);

			// 1 - time
			float time = results.FetchFloat(1);
			char sTime[32];
			FormatTimeFloat(1, time, 3, sTime, sizeof(sTime));

			// 2 - deaths
			int deaths = results.FetchInt(2);

			// 3 - completions
			int counts = results.FetchInt(3);

			// 4 - kills
			int kills = results.FetchInt(4);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "%t", "Top", sName, sTime, deaths, kills, counts, client);
			hMenu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
		}
	}

	char sFormattedTitle[256];

	if(hMenu.ItemCount == 0)
	{
		hMenu.SetTitle("%T", "Map", client, sMap);
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%t", "NoRecords", client);

		hMenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
	}

	else
	{
		FormatEx(sFormattedTitle, 192, "%T %s: ", "RecordFor", client, sMap);
		hMenu.SetTitle(sFormattedTitle);
	}

	hMenu.Display(client, -1);
}

public int WRMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	char sQuery[1024];

	if(gB_MySQL)
	{
		FormatEx(sQuery, 1024,
		"CREATE TABLE IF NOT EXISTS `playertimes` (auth INT, name VARCHAR(32), time FLOAT NOT NULL DEFAULT '-1.0', map VARCHAR(128), deaths INT, counts INT, kills INT) DEFAULT CHARSET=utf8mb4;");
	}

	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);

}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Reason: %s", error);

		return;
	}

	gB_Connected = true;
	
	OnMapStart();
}

