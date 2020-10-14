// ct_latestrecords
char sql_createLatestRecords[] = "CREATE TABLE IF NOT EXISTS ct_latestrecords (steamid VARCHAR(32), name VARCHAR(32), runtime FLOAT NOT NULL DEFAULT '-1.0', map VARCHAR(32), deaths VARCHAR(32), PRIMARY KEY(map)) DEFAULT CHARSET=utf8mb4;";
char sql_insertLatestRecords[] = "INSERT INTO ct_latestrecords (steamid, name, runtime, map, deaths) VALUES('%s', '%s', '%f', '%s', %d);";