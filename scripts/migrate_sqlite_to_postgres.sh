#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <sqlite_db_path> <postgres_dsn (ex: postgres://user:pass@host:port/db)>"
  exit 1
fi

SQLITE_DB="$1"
PG_DSN="$2"

echo "Exporting tables from $SQLITE_DB and loading into Postgres ($PG_DSN)."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Get list of user tables
readarray -t tables < <(sqlite3 "$SQLITE_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")

if [ ${#tables[@]} -eq 0 ]; then
  echo "No tables found in $SQLITE_DB"
  exit 1
fi

for t in "${tables[@]}"; do
  echo "Exporting table $t to CSV..."
  sqlite3 -header -csv "$SQLITE_DB" "SELECT * FROM \"$t\";" > "$TMPDIR/$t.csv"
  # get column names
  cols=$(sqlite3 "$SQLITE_DB" "PRAGMA table_info('$t');" | awk -F'|' '{print $2}' | paste -sd, -)
  if [ -z "$cols" ]; then
    echo "Warning: no columns found for table $t — skipping"
    continue
  fi
  echo "Creating table $t in Postgres (all columns TEXT)"
  psql "$PG_DSN" -v ON_ERROR_STOP=1 <<SQL
DROP TABLE IF EXISTS "$t";
CREATE TABLE "$t" ($(echo "$cols" | awk -F',' '{for(i=1;i<=NF;i++){printf "%s text%s", $i, (i<NF?", ":"");}}'));
SQL
  echo "Importing CSV into $t..."
  psql "$PG_DSN" -c "\copy \"$t\" FROM '$TMPDIR/$t.csv' WITH CSV HEADER"
done

echo "Migration complete.\nNotes: this script imports everything as TEXT (POC). Adjust types in Postgres as needed."