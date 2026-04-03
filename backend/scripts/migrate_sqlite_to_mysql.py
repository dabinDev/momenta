import os
import sqlite3
from typing import Iterable

import pymysql


TABLE_ORDER = [
    "dept",
    "role",
    "menu",
    "api",
    "user",
    "user_app_config",
    "app_release",
    "video_task",
    "video_task_asset",
    "voice_transcription_log",
    "role_menu",
    "role_api",
    "user_role",
    "auditlog",
    "deptclosure",
]

CHUNK_SIZE = 200


def env(name: str, default: str = "") -> str:
    return str(os.getenv(name, default) or "").strip()


def get_sqlite_connection() -> sqlite3.Connection:
    sqlite_path = env("SQLITE_PATH", os.path.join(os.path.dirname(__file__), "..", "db.sqlite3"))
    sqlite_path = os.path.abspath(sqlite_path)
    if not os.path.exists(sqlite_path):
        raise FileNotFoundError(f"SQLite database not found: {sqlite_path}")
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    return conn


def get_mysql_connection(database_required: bool = True):
    database = env("MYSQL_DB")
    if database_required and not database:
        raise RuntimeError("MYSQL_DB is required")
    return pymysql.connect(
        host=env("MYSQL_HOST", "127.0.0.1"),
        port=int(env("MYSQL_PORT", "3306")),
        user=env("MYSQL_USER", "root"),
        password=env("MYSQL_PASSWORD"),
        database=database if database_required else None,
        charset=env("MYSQL_CHARSET", "utf8mb4"),
        autocommit=False,
        cursorclass=pymysql.cursors.Cursor,
    )


def sqlite_table_exists(conn: sqlite3.Connection, table_name: str) -> bool:
    cursor = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        (table_name,),
    )
    return cursor.fetchone() is not None


def mysql_table_exists(conn, table_name: str) -> bool:
    with conn.cursor() as cursor:
        cursor.execute("SHOW TABLES LIKE %s", (table_name,))
        return cursor.fetchone() is not None


def sqlite_columns(conn: sqlite3.Connection, table_name: str) -> list[str]:
    cursor = conn.execute(f'PRAGMA table_info("{table_name}")')
    return [str(row["name"]) for row in cursor.fetchall()]


def fetch_rows(conn: sqlite3.Connection, table_name: str, columns: list[str]) -> list[tuple]:
    order_sql = ' ORDER BY "id"' if "id" in columns else ""
    selected_columns = ", ".join([f'"{column}"' for column in columns])
    sql = f'SELECT {selected_columns} FROM "{table_name}"{order_sql}'
    cursor = conn.execute(sql)
    return [tuple(row[column] for column in columns) for row in cursor.fetchall()]


def chunks(items: list[tuple], size: int) -> Iterable[list[tuple]]:
    for index in range(0, len(items), size):
        yield items[index : index + size]


def quote_identifier(name: str) -> str:
    return f"`{name}`"


def migrate_table(sqlite_conn: sqlite3.Connection, mysql_conn, table_name: str, truncate_target: bool) -> None:
    if not sqlite_table_exists(sqlite_conn, table_name):
        print(f"[skip] sqlite table missing: {table_name}")
        return
    if not mysql_table_exists(mysql_conn, table_name):
        raise RuntimeError(f"MySQL table does not exist: {table_name}")

    columns = sqlite_columns(sqlite_conn, table_name)
    rows = fetch_rows(sqlite_conn, table_name, columns)

    if not rows:
        print(f"[ok] {table_name}: 0 rows")
        return

    column_sql = ", ".join(quote_identifier(column) for column in columns)
    placeholder_sql = ", ".join(["%s"] * len(columns))
    insert_sql = f"INSERT INTO {quote_identifier(table_name)} ({column_sql}) VALUES ({placeholder_sql})"

    with mysql_conn.cursor() as cursor:
        if truncate_target:
            cursor.execute(f"DELETE FROM {quote_identifier(table_name)}")

        for batch in chunks(rows, CHUNK_SIZE):
            cursor.executemany(insert_sql, batch)

        if "id" in columns:
            cursor.execute(f"SELECT COALESCE(MAX(`id`), 0) + 1 FROM {quote_identifier(table_name)}")
            next_id = int(cursor.fetchone()[0])
            cursor.execute(f"ALTER TABLE {quote_identifier(table_name)} AUTO_INCREMENT = %s", (next_id,))

    mysql_conn.commit()
    print(f"[ok] {table_name}: {len(rows)} rows")


def main() -> None:
    truncate_target = env("TRUNCATE_TARGET", "false").lower() == "true"

    sqlite_conn = get_sqlite_connection()
    mysql_conn = get_mysql_connection(database_required=True)

    try:
        with mysql_conn.cursor() as cursor:
            cursor.execute("SET SESSION sql_mode = REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', '')")
            cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
        mysql_conn.commit()

        for table_name in TABLE_ORDER:
            migrate_table(sqlite_conn, mysql_conn, table_name, truncate_target=truncate_target)
    finally:
        try:
            with mysql_conn.cursor() as cursor:
                cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
            mysql_conn.commit()
        except Exception:
            pass
        mysql_conn.close()
        sqlite_conn.close()


if __name__ == "__main__":
    main()
