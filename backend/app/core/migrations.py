import logging
from typing import Iterable, List
from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)


def _table_exists(engine: Engine, table_name: str) -> bool:
    inspector = inspect(engine)
    return table_name in inspector.get_table_names()


def _column_names(engine: Engine, table_name: str) -> List[str]:
    with engine.connect() as conn:
        rows = conn.execute(text(f"PRAGMA table_info('{table_name}')")).fetchall()
    return [row[1] for row in rows]


def _unique_index_columns(engine: Engine, table_name: str) -> List[List[str]]:
    indexes: List[List[str]] = []
    with engine.connect() as conn:
        idx_rows = conn.execute(text(f"PRAGMA index_list('{table_name}')")).fetchall()
        for idx in idx_rows:
            # idx columns: seq, name, unique flag, origin, partial
            is_unique = False
            try:
                is_unique = bool(int(idx[2]))
            except Exception:
                is_unique = False
            if not is_unique:
                continue
            idx_name = idx[1]
            cols = conn.execute(text(f"PRAGMA index_info('{idx_name}')")).fetchall()
            indexes.append([col[2] for col in cols])
    return indexes


def _has_unique_index(engine: Engine, table_name: str, columns: Iterable[str]) -> bool:
    target = set(columns)
    for cols in _unique_index_columns(engine, table_name):
        if set(cols) == target and len(cols) == len(target):
            return True
    return False


def migrate_config_table(engine: Engine):
    """Ensure config table is user/page scoped (user_id + page_id + key unique)."""
    if not _table_exists(engine, "config"):
        return

    columns = _column_names(engine, "config")
    has_user_id = "user_id" in columns
    has_page_id = "page_id" in columns
    has_user_page_key_unique = _has_unique_index(engine, "config", ["user_id", "page_id", "key"])

    if has_user_id and has_page_id and has_user_page_key_unique:
        return

    logger.info("Migrating config table to be user/page scoped")
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS config_new (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    page_id VARCHAR NOT NULL DEFAULT 'default',
                    key VARCHAR,
                    value VARCHAR,
                    UNIQUE(user_id, page_id, key)
                )
                """
            )
        )
        if "key" in columns:
            # If page_id column exists, preserve it; otherwise default to 'default'
            if "page_id" in columns:
                conn.execute(
                    text(
                        """
                        INSERT OR IGNORE INTO config_new (user_id, page_id, key, value)
                        SELECT user_id, page_id, key, value FROM config
                        """
                    )
                )
            else:
                conn.execute(
                    text(
                        """
                        INSERT OR IGNORE INTO config_new (user_id, page_id, key, value)
                        SELECT user_id, 'default' AS page_id, key, value FROM config
                        """
                    )
                )
        conn.execute(text("DROP TABLE config"))
        conn.execute(text("ALTER TABLE config_new RENAME TO config"))


def migrate_rules_table(engine: Engine):
    """Ensure rules table is user/page scoped (user_id + page_id + object_id primary key)."""
    if not _table_exists(engine, "rules"):
        return

    columns = _column_names(engine, "rules")
    has_user_id = "user_id" in columns
    has_page_id = "page_id" in columns
    has_composite_unique = _has_unique_index(engine, "rules", ["user_id", "page_id", "object_id"])

    if has_user_id and has_page_id and has_composite_unique:
        return

    logger.info("Migrating rules table to be user/page scoped")
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS rules_new (
                    user_id INTEGER NOT NULL,
                    page_id VARCHAR NOT NULL DEFAULT 'default',
                    object_id VARCHAR NOT NULL,
                    match_words JSON,
                    reply_message VARCHAR,
                    inbox_message VARCHAR,
                    enabled BOOLEAN,
                    PRIMARY KEY (user_id, page_id, object_id)
                )
                """
            )
        )
        if "object_id" in columns:
            if "page_id" in columns:
                conn.execute(
                    text(
                        """
                        INSERT OR IGNORE INTO rules_new (user_id, page_id, object_id, match_words, reply_message, inbox_message, enabled)
                        SELECT user_id, page_id, object_id, match_words, reply_message, inbox_message, enabled FROM rules
                        """
                    )
                )
            else:
                conn.execute(
                    text(
                        """
                        INSERT OR IGNORE INTO rules_new (user_id, page_id, object_id, match_words, reply_message, inbox_message, enabled)
                        SELECT user_id, 'default' AS page_id, object_id, match_words, reply_message, inbox_message, enabled FROM rules
                        """
                    )
                )
        conn.execute(text("DROP TABLE rules"))
        conn.execute(text("ALTER TABLE rules_new RENAME TO rules"))


def run_migrations(engine: Engine):
    migrate_config_table(engine)
    migrate_rules_table(engine)
