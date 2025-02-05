#!/bin/bash

echo "⏳ Updating package lists..."
apt-get update -y

echo "📦 Installing SQLite3..."
apt-get install -y sqlite3

# Background job to wait for database and insert the backup
(
    echo "🔄 Waiting for Duplicati database to be created..."
    DB_PATH="/config/Duplicati-server.sqlite"
    MAX_WAIT=120  # Maximum wait time in seconds

    SECONDS=0
    while [ ! -f "$DB_PATH" ]; do
        if [ "$SECONDS" -ge "$MAX_WAIT" ]; then
            echo "❌ Error: Database file not found after $MAX_WAIT seconds. Exiting."
            exit 1
        fi
        sleep 5
    done
    echo "✅ Duplicati database found!"

    # Retry loop in case of database locks
    RETRIES=5
    while [ $RETRIES -gt 0 ]; do
        echo "🔄 Checking if a backup job already exists..."
        BACKUP_EXISTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM Backup;" 2>/dev/null)

        if [[ -z "$BACKUP_EXISTS" || "$BACKUP_EXISTS" -eq 0 ]]; then
            echo "🆕 No backups found. Importing backup configuration into SQLite..."
            sqlite3 "$DB_PATH" <<EOF
BEGIN TRANSACTION;
INSERT INTO Backup (Name, Description, Tags, TargetURL, DBPath) VALUES 
(
    "Nextcloud Backup",
    "",
    "",
    "s3://admin-duplicati-backups/nextcloud-backup?s3-server-name=minio%3A9000&s3-location-constraint=&s3-storage-class=&s3-client=aws&auth-username=admin&auth-password=strongpassword&endpoint=http%3A%2F%2Fminio%3A9000",
    "/config/JYZSHHDWLX.sqlite"
);
COMMIT;
EOF
            if [ $? -eq 0 ]; then
                echo "✅ Backup configuration imported successfully!"
                break
            else
                echo "⚠️ Database locked, retrying in 5 seconds..."
                sleep 5
                RETRIES=$((RETRIES - 1))
            fi
        else
            echo "✔️ A backup job already exists. Skipping import."
            break
        fi
    done
) &  # Run in the background

# Start Duplicati as the primary process
echo "🚀 Starting Duplicati..."
exec /init
