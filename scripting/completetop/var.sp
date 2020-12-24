#define MYSQL 0
#define SQLITE 1
#define PERCENT 0x25

// Current map's name
char g_szMapName[128];

// Time when run was started
float g_fStartTime[MAXPLAYERS + 1];

// Total time the run took
float g_fFinalTime[MAXPLAYERS + 1];

// Total time the run took in 00:00:00 format
char g_szFinalTime[MAXPLAYERS + 1][32];

// Player's Death times
int g_iDeath[MAXPLAYERS + 1];

// Client's steamID
char g_szSteamID[MAXPLAYERS + 1][32];

/*----------  SQL Variables  ----------*/


// SQL driver
Handle g_hDb = null;
