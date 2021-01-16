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

// Player's deaths
int g_iDeaths[MAXPLAYERS + 1];

// bool Player's Completions
bool g_bCounts[MAXPLAYERS + 1];

// bool Player's FasterTime
bool g_bFasterTime[MAXPLAYERS + 1];

// total start time
float g_fStartTime = -1.0;

// Reset Player's deaths
bool g_bResetDeaths = false;

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

/* public Action Command_test(int client, int args)
{
	
} */

public Action TIMER_START(Event re, const char[] name, bool dontBroadcast)
{
	g_fStartTime = GetGameTime();
	g_bResetDeaths = true;
}

public Action TIMER_END(Event re, const char[] name, bool dontBroadcast)
{
	int client = re.GetInt("player_id");

	// Get client name
	char sName[128];
	GetClientName(client, sName, 128);
	
	// Get SteamID
	gA_Timers[client].iSteamid = GetSteamAccountID(client);
	
	// Get runtime and format it to a string
	gA_Timers[client].fFinalTime = GetGameTime() - g_fStartTime;
	FormatTimeFloat(1, gA_Timers[client].fFinalTime, 3, gA_Timers[client].sFinalTime, 32);

	// Get Player's Deaths
	gA_Timers[client].iDeaths = g_iDeaths[client];

	char sQuery[512];
	char sQuery2[512];

	FormatEx(sQuery, 512, "SELECT time, counts FROM playertimes WHERE map = '%s' AND auth = %d ORDER BY time ASC;", gS_Map, gA_Timers[client].iSteamid);

	gH_SQL.Query(SQL_OnFinishCheck_Callback, sQuery, GetClientSerial(client), DBPrio_High);

	if(!g_bCounts[client])
	{
		FormatEx(sQuery2, 512,
		"INSERT INTO playertimes (auth, name, map, time, deaths, counts) VALUES (%d, '%s', '%s', %f, %d, %d);",
		gA_Timers[client].iSteamid, sName, gS_Map, gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, ++gA_Timers[client].iCounts);
	}
	else if(g_bCounts[client] && g_bFasterTime[client])
	{
		FormatEx(sQuery2, 512,
		"UPDATE playertimes SET map = %s, time = %f, deaths = %d, counts = counts + 1 WHERE map = '%s' AND auth = %d;", 
		gS_Map, gA_Timers[client].fFinalTime, gA_Timers[client].iDeaths, gS_Map, gA_Timers[client].iSteamid);
	}

	CPrintToChatAll("%t", "Complete", client, gA_Timers[client].sFinalTime, gA_Timers[client].iDeaths, gA_Timers[client].iCounts);

	gH_SQL.Query(SQL_OnFinish_Callback, sQuery2, GetClientSerial(client), DBPrio_High);

	g_iDeaths[client] = 0;
}

public Action EVENT_DEATH(Event de, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(de.GetInt("userid"));

	if(g_bResetDeaths)
	{
		g_iDeaths[client] = 0;
		g_bResetDeaths = false;
	}

	g_iDeaths[client]++;
}

public Action Command_WR(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	ShowWR(client, gS_Map);

	return Plugin_Handled;
}

public Action Command_TOP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	StartWRMenu(client, gS_Map);

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
	FormatEx(sQuery, 512, "SELECT name, time, deaths, auth FROM playertimes WHERE map = '%s' ORDER BY time ASC, deaths ASC;", sEscapedMap);
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
	FormatEx(sQuery, 512, "SELECT name, time, deaths, auth FROM playertimes WHERE map = '%s' ORDER BY time ASC, deaths ASC;", sEscapedMap);
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

	if(results.FetchRow() && results.HasResults)
	{
		g_bCounts[client] = true;
		gA_Timers[client].iCounts = results.FetchInt(1);

		if(gA_Timers[client].fFinalTime > results.FetchFloat(0))
		{
			g_bFasterTime[client] = false;
		}
		else
		{
			g_bFasterTime[client] = true;
		}
	}
	else
	{
		g_bCounts[client] = false;
	}
}

public void SQL_OnFinish_Callback(Database db, DBResultSet results, const char[] error, any data)
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

		CPrintToChatAll("%t", "Chat", sName, gS_Map, sTime, deaths);
	}
	else
	{
		CPrintToChatAll("%t", "MapNoRecords");
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

			char sDisplay[128];
			FormatEx(sDisplay, 128, "%s - %s (%d %T)", sName, sTime, deaths, "Deaths", client);
			hMenu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
		}
	}

	char sFormattedTitle[256];

	if(hMenu.ItemCount == 0)
	{
		hMenu.SetTitle("%T", "Map", client, sMap);
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%T", "MapNoRecords", client);

		hMenu.AddItem("-1", sNoRecords);
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
		"CREATE TABLE IF NOT EXISTS `playertimes` (auth INT, name VARCHAR(32), time FLOAT NOT NULL DEFAULT '-1.0', map VARCHAR(128), deaths INT, counts INT) DEFAULT CHARSET=utf8mb4;");
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

