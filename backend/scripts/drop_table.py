"""Safely drop a table from the backend SQLite database.

Usage:
    python ./backend/scripts/drop_table.py --table monitoring_metrics

Options:
  --table <name>    Table name to drop (required)
  --yes             Skip interactive confirmation

This script will:
- Verify the DB exists at backend/data/sociwave.db
- Check whether the given table exists
- Prompt for confirmation before dropping
- Execute DROP TABLE IF EXISTS <table>;
"""
import argparse
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / 'data' / 'sociwave.db'


def table_exists(conn, table_name: str) -> bool:
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", (table_name,))
    return cur.fetchone() is not None


def drop_table(conn, table_name: str):
    cur = conn.cursor()
    cur.execute(f"DROP TABLE IF EXISTS {table_name};")
    conn.commit()


def main():
    parser = argparse.ArgumentParser(description='Drop a table from the backend SQLite DB')
    parser.add_argument('--table', required=True, help='Table name to drop')
    parser.add_argument('--yes', action='store_true', help='Skip confirmation')
    args = parser.parse_args()

    if not DB_PATH.exists():
        print(f"Database not found at {DB_PATH}. Aborting.")
        return

    conn = sqlite3.connect(DB_PATH)
    try:
        if not table_exists(conn, args.table):
            print(f"Table '{args.table}' does not exist in the database.")
            return
        if not args.yes:
            confirm = input(f"Are you sure you want to DROP table '{args.table}'? This cannot be undone. (yes/no): ")
            if confirm.strip().lower() != 'yes':
                print('Aborted by user.')
                return
        drop_table(conn, args.table)
        print(f"Table '{args.table}' dropped.")
    finally:
        conn.close()

if __name__ == '__main__':
    main()
