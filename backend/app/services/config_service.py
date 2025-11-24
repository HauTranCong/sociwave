from sqlalchemy.orm import Session
from app.models.models import RuleModel, ConfigModel, Rule as RuleSchema
from typing import Dict

class ConfigService:
    def __init__(self, db: Session):
        self.db = db

    def load_config(self) -> Dict:
        configs = self.db.query(ConfigModel).all()
        return {c.key: c.value for c in configs}

    def save_config(self, config: Dict):
        for key, value in config.items():
            db_config = self.db.query(ConfigModel).filter(ConfigModel.key == key).first()
            if db_config:
                db_config.value = value
            else:
                db_config = ConfigModel(key=key, value=value)
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
                db_rule = RuleModel(object_id=object_id, **rule_data.dict())
                self.db.add(db_rule)
        self.db.commit()
