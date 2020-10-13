#include "completetop/sqlqueries.sp"
#include "completetop/var.sp"
#include <morecolors>


public void db_setupDatabase()
{
	////////////////////////////////
	// INIT CONNECTION TO DATABASE//
	////////////////////////////////
	char szError[255];
	g_hDb = SQL_Connect("ctop", false, szError, 255);
	
	if (g_hDb == null)
	{
		SetFailState("Unable to connect to database (%s)", szError);
		return;
	}
	
	char szIdent[8];
	SQL_ReadDriver(g_hDb, szIdent, 8);

	// If updating from a previous version
	SQL_LockDatabase(g_hDb);
	SQL_FastQuery(g_hDb, "SET NAMES  'utf8'");
	
	////////////////////////////////
	// CHECK WHICH CHANGES ARE    //
	// TO BE DONE TO THE DATABASE //
	////////////////////////////////
	
	SQL_UnlockDatabase(g_hDb);
	db_createTables();
		
	return;
}

public void db_createTables()
{
	Transaction createTableTnx = SQL_CreateTransaction();
	
	SQL_AddQuery(createTableTnx, sql_createLatestRecords);
	
	SQL_ExecuteTransaction(g_hDb, createTableTnx, SQLTxn_CreateDatabaseSuccess, SQLTxn_CreateDatabaseFailed);

}

public void SQLTxn_CreateDatabaseSuccess(Handle db, any data, int numQueries, Handle[] results, any[] queryData)
{
	PrintToServer("Database tables succesfully created!");
}

public void SQLTxn_CreateDatabaseFailed(Handle db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState("Database tables could not be created! Error: %s", error);
}

//insert view wr
public void db_InsertLatestRecords(char szSteamID[32], char szName[128], float FinalTime, char szMapName[128], int deaths)
{
	char szQuery[512];
	Format(szQuery, 512, sql_insertLatestRecords, szSteamID, szName, FinalTime, szMapName, deaths);
	SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery, DBPrio_Low);
}

public void SQL_CheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("SQL Error (SQL_CheckCallback): %s", error);
		return;
	}
}

//print wr
public void db_selectMapRecordTime(int client, char szMapName[128])
{
	char szQuery[1024];

	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szMapName);

	Format(szQuery, 1024, "SELECT runtime, map, name, deaths FROM ct_latestrecords WHERE map = '%s' ORDER BY runtime ASC", g_szMapName);
	SQL_TQuery(g_hDb, db_selectMapRecordTimeCallback, szQuery, pack, DBPrio_Low);
}

public void db_selectMapRecordTimeCallback(Handle owner, Handle hndl, const char[] error, any pack)
{
	if (hndl == null)
	{
		LogError("SQL Error (db_selectMapRecordTimeCallback): %s", error);
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szMapNameArg[128];
	ReadPackString(pack, szMapNameArg, sizeof(szMapNameArg));
	CloseHandle(pack);
	
	

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		float runtime;
		char szMapName[128];
		char szRecord[32];
		char szName[64];
		char szDeaths[32];
		runtime = SQL_FetchFloat(hndl, 0);
		SQL_FetchString(hndl, 1, szMapName, sizeof(szMapName));
		SQL_FetchString(hndl, 2, szName, sizeof(szName));
		SQL_FetchString(hndl, 3, szDeaths, sizeof(szDeaths));

		if (!StrEqual(szMapName, g_szMapName))
		{
			CPrintToChatAll("{aqua}当前地图无记录");
		}
		else
		{
			FormatTimeFloat(client, runtime, 3, szRecord, sizeof(szRecord));

			CPrintToChatAll("玩家{deeppink} %s \x01以{blueviolet} %s \x01的记录保持了该地图记录,死亡{darkred} %s \x01次", szName, szRecord, szDeaths);
		}
	}
	else
	CPrintToChatAll("{aqua}当前地图无记录");
}