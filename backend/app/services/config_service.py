from sqlalchemy.orm import Session
from app.models.models import RuleModel, ConfigModel, Rule as RuleSchema, Config as ConfigSchema
from typing import Dict

class ConfigService:
    def __init__(self, db: Session):
        self.db = db

    def load_config(self) -> ConfigSchema:
        configs = self.db.query(ConfigModel).all()
        config_dict = {c.key: c.value for c in configs}
        # Convert string values from DB to correct types for Pydantic model
        config_dict['useMockData'] = config_dict.get('useMockData', 'false').lower() == 'true'
        for key in ['reelsLimit', 'commentsLimit', 'repliesLimit']:
            if key in config_dict:
                config_dict[key] = int(config_dict[key])
        return ConfigSchema(**config_dict)

    def save_config(self, config: ConfigSchema):
        config_dict = config.dict()
        for key, value in config_dict.items():
            db_config = self.db.query(ConfigModel).filter(ConfigModel.key == key).first()
            if db_config:
                db_config.value = str(value)
            else:
                db_config = ConfigModel(key=key, value=str(value))
                self.db.add(db_config)
        self.db.commit()

    def load_rules(self) -> Dict[str, RuleModel]:
        rules = self.db.query(RuleModel).all()
        return {r.object_id: r for r in rules}

    def save_rules(self, rules: Dict[str, RuleSchema]):
        for object_id, rule_data in rules.items():
            db_rule = self.db.query(RuleModel).filter(RuleModel.object_id == object_id).first()
            if db_rule:
                db_rule.match_words = rule_data.match_words
                db_rule.reply_message = rule_data.reply_message
                db_rule.inbox_message = rule_data.inbox_message
                db_rule.enabled = rule_data.enabled
            else:
                # rule_data.dict() already includes object_id; avoid passing it twice
                db_rule = RuleModel(**rule_data.dict())
                self.db.add(db_rule)
        self.db.commit()
