from sqlalchemy.orm import Session
from app.models.models import RuleModel, ConfigModel, Rule as RuleSchema, Config as ConfigSchema
from typing import Dict, Optional

class ConfigService:
    def __init__(self, db: Session, user_id: Optional[int], page_id: Optional[str]):
        self.db = db
        self.user_id = user_id
        self.page_id = page_id

    def _require_scope(self):
        if self.user_id is None:
            raise ValueError("ConfigService requires user_id to scope data per user")
        if not self.page_id:
            raise ValueError("ConfigService requires page_id to scope data per page")

    def _get_config_value(self, key: str):
        self._require_scope()
        return (
            self.db.query(ConfigModel)
            .filter(
                ConfigModel.user_id == self.user_id,
                ConfigModel.page_id == self.page_id,
                ConfigModel.key == key,
            )
            .first()
        )

    def get_monitoring_enabled(self) -> bool:
        rec = self._get_config_value('monitoringEnabled')
        if rec is None or rec.value is None:
            return False
        try:
            return str(rec.value).lower() == 'true'
        except Exception:
            return False

    def get_monitoring_interval_seconds(self, default: int = 300) -> int:
        rec = self._get_config_value('monitoringIntervalSeconds')
        if rec is None or rec.value is None:
            return default
        try:
            return int(str(rec.value))
        except Exception:
            return default

    def load_config(self) -> ConfigSchema:
        self._require_scope()
        configs = (
            self.db.query(ConfigModel)
            .filter(
                ConfigModel.user_id == self.user_id,
                ConfigModel.page_id == self.page_id,
            )
            .all()
        )
        config_dict = {c.key: c.value for c in configs}
        # Convert string values from DB to correct types for Pydantic model
        # ensure boolean
        config_dict['useMockData'] = config_dict.get('useMockData', 'false').lower() == 'true'
        # ensure ints
        for key in ['reelsLimit', 'commentsLimit', 'repliesLimit']:
            if key in config_dict:
                try:
                    config_dict[key] = int(config_dict[key])
                except (TypeError, ValueError):
                    # fallback to defaults handled by Pydantic model
                    config_dict.pop(key, None)

        # provide required fields defaults if missing in DB
        # accessToken and pageId are required by the Pydantic Config schema
        # if they are missing in DB, set them to empty strings so validation will pass
        # (the application can still treat empty strings as not-configured)
        if 'accessToken' not in config_dict:
            config_dict['accessToken'] = ''
        if 'pageId' not in config_dict:
            config_dict['pageId'] = self.page_id or ''
        if 'version' not in config_dict:
            config_dict['version'] = 'v20.0'

        return ConfigSchema(**config_dict)

    def save_config(self, config: ConfigSchema):
        self._require_scope()
        config_dict = config.dict()
        for key, value in config_dict.items():
            db_config = (
                self.db.query(ConfigModel)
                .filter(
                    ConfigModel.user_id == self.user_id,
                    ConfigModel.page_id == self.page_id,
                    ConfigModel.key == key,
                )
                .first()
            )
            if db_config:
                db_config.value = str(value)
            else:
                db_config = ConfigModel(user_id=self.user_id, page_id=self.page_id, key=key, value=str(value))
                self.db.add(db_config)
        self.db.commit()

    def load_rules(self) -> Dict[str, RuleModel]:
        self._require_scope()
        rules = (
            self.db.query(RuleModel)
            .filter(
                RuleModel.user_id == self.user_id,
                RuleModel.page_id == self.page_id,
            )
            .all()
        )
        return {r.object_id: r for r in rules}

    def save_rules(self, rules: Dict[str, RuleSchema]):
        self._require_scope()
        # Map current DB rules for quick lookups and removal tracking
        existing_rules = {
            r.object_id: r
            for r in self.db.query(RuleModel)
            .filter(
                RuleModel.user_id == self.user_id,
                RuleModel.page_id == self.page_id,
            )
            .all()
        }
        incoming_ids = set(rules.keys())

        # Delete rules that are missing from the payload (user removed them)
        for object_id, db_rule in list(existing_rules.items()):
            if object_id not in incoming_ids:
                self.db.delete(db_rule)
                existing_rules.pop(object_id, None)

        # Upsert incoming rules
        for object_id, rule_data in rules.items():
            db_rule = existing_rules.get(object_id)
            if db_rule:
                db_rule.match_words = rule_data.match_words
                db_rule.reply_message = rule_data.reply_message
                db_rule.inbox_message = rule_data.inbox_message
                db_rule.enabled = rule_data.enabled
            else:
                # rule_data.dict() already includes object_id; avoid passing it twice
                db_rule = RuleModel(
                    user_id=self.user_id,
                    page_id=self.page_id,
                    **rule_data.dict()
                )
                self.db.add(db_rule)
        self.db.commit()

    def set_config_value(self, key: str, value: str):
        self._require_scope()
        db_config = self._get_config_value(key)
        if db_config:
            db_config.value = value
        else:
            db_config = ConfigModel(user_id=self.user_id, page_id=self.page_id, key=key, value=value)
            self.db.add(db_config)
        self.db.commit()

    def set_monitoring_enabled(self, enabled: bool):
        self.set_config_value('monitoringEnabled', 'true' if enabled else 'false')

    def set_monitoring_interval_seconds(self, interval_seconds: int):
        self.set_config_value('monitoringIntervalSeconds', str(int(interval_seconds)))

    def list_pages(self) -> list[str]:
        """Return distinct page_ids for the current user."""
        if self.user_id is None:
            raise ValueError("ConfigService requires user_id to scope data per user")
        results = (
            self.db.query(ConfigModel.page_id)
            .filter(ConfigModel.user_id == self.user_id)
            .distinct()
            .all()
        )
        return [row[0] for row in results if row and row[0]]

    def delete_page_scope(self):
        """Remove all config and rules for this user/page from the database."""
        self._require_scope()
        (
            self.db.query(ConfigModel)
            .filter(
                ConfigModel.user_id == self.user_id,
                ConfigModel.page_id == self.page_id,
            )
            .delete(synchronize_session=False)
        )
        (
            self.db.query(RuleModel)
            .filter(
                RuleModel.user_id == self.user_id,
                RuleModel.page_id == self.page_id,
            )
            .delete(synchronize_session=False)
        )
        self.db.commit()
