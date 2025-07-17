#!/bin/bash
set -euo pipefail

echo "Starting backup restoration process..."

# Найти последний .bak-файл
BACKUP_FILE=$(docker exec sqltemp bash -c "ls -1 /var/opt/mssql/backup/VPICList_lite_*.bak 2>/dev/null | sort | tail -n 1")

if [ -z "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found in container"
    exit 1
fi

SQL_USER="SA"
SQL_PASSWORD="DevPassword123#"

# Проверить наличие файла
docker exec sqltemp ls -l "$BACKUP_FILE" || {
    echo "Error: Backup file not found in container"
    exit 1
}

# Получить логические имена файлов
echo "Getting logical file names from backup..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "RESTORE FILELISTONLY FROM DISK = '$BACKUP_FILE'"

# Восстановить БД
echo "Restoring database..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "RESTORE DATABASE vpic 
        FROM DISK = '$BACKUP_FILE' 
        WITH MOVE 'vPICList_Lite1' TO '/var/opt/mssql/data/vpic.mdf',
        MOVE 'vPICList_Lite1_log' TO '/var/opt/mssql/data/vpic_log.ldf',
        REPLACE"

# Проверить восстановление
echo "Verifying database restoration..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "SELECT DB_NAME(database_id) as DatabaseName, 
        state_desc as Status 
        FROM sys.databases 
        WHERE name = 'vpic'"

# Получить информацию о таблицах
echo "Getting database information..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -d vpic \
    -Q "SELECT 
            t.TABLE_NAME, 
            (SELECT COUNT(*) FROM vpic.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount,
            (SELECT COUNT_BIG(*) FROM vpic.sys.tables st 
             INNER JOIN vpic.sys.partitions p ON st.object_id = p.object_id 
             WHERE st.name = t.TABLE_NAME) as RowCount
        FROM vpic.INFORMATION_SCHEMA.TABLES t
        WHERE TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME;"