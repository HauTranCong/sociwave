from typing import List, Dict
from app.models.models import Reel, Rule, Comment
from app.services.facebook_service import FacebookService

class MonitorService:
    def __init__(self, facebook_service: FacebookService):
        self.facebook_service = facebook_service

    def _matches(self, comment_text: str, rule: Rule) -> bool:
        lower_comment = comment_text.lower()
        if not rule.match_words or "." in rule.match_words:
            return True
        return any(keyword.lower() in lower_comment for keyword in rule.match_words)

    def _has_page_replied(self, comment: Comment, page_id: str) -> bool:
        if not comment.replies:
            return False
        return any(reply.from_user and reply.from_user.id == page_id for reply in comment.replies)

    def perform_monitoring_cycle(self, rules: Dict[str, Rule]):
        enabled_rules = {k: v for k, v in rules.items() if v.enabled}
        if not enabled_rules:
            print("No enabled rules found, skipping cycle")
            return

        reels = self.facebook_service.get_reels()
        page_id = self.facebook_service.page_id

        for reel in reels:
            rule = enabled_rules.get(reel.id)
            if not rule:
                continue

            comments = self.facebook_service.get_comments(reel.id)
            for comment in comments:
                if self._has_page_replied(comment, page_id):
                    continue

                if self._matches(comment.message, rule):
                    try:
                        self.facebook_service.reply_to_comment(comment.id, rule.reply_message)
                        print(f"Auto-replied to comment {comment.id} on reel {reel.id}")

                        if rule.inbox_message:
                            try:
                                self.facebook_service.send_private_reply(comment.id, rule.inbox_message)
                                print(f"Sent private reply for comment {comment.id}")
                            except Exception as e:
                                print(f"Failed to send private reply for comment {comment.id}: {e}")

                    except Exception as e:
                        print(f"Failed to reply to comment {comment.id}: {e}")
