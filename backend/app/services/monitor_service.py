from typing import List, Dict, Set
from app.models.models import Reel, Rule, Comment
from app.services.facebook_service import FacebookService
import logging

logger = logging.getLogger(__name__)

class MonitorService:
    def __init__(self, facebook_service: FacebookService):
        self.facebook_service = facebook_service
        # Track comments we've already processed/replied to in this process
        self._replied_comment_ids: Set[str] = set()

    def _matches(self, comment_text: str, rule: Rule) -> bool:
        lower_comment = comment_text.lower()
        if not rule.match_words or "." in rule.match_words:
            return True
        return any(keyword.lower() in lower_comment for keyword in rule.match_words)

    def _has_page_replied(self, comment: Comment, page_id: str) -> bool:
        # First, check nested replies we already have for this comment
        if comment.replies:
            if any(
                reply.from_user and reply.from_user.id == page_id
                for reply in comment.replies
            ):
                return True

        # As a more precise per-comment check, query Facebook for replies
        # to this specific comment ID and see if the page has replied there.
        try:
            return self.facebook_service.has_replied_to_comment(comment.id)
        except Exception:
            # On failure to check, fall back to "not replied" so monitoring
            # can still proceed (Facebook will reject duplicate replies).
            return False

    def _is_page_comment(self, comment: Comment, page_id: str) -> bool:
        """
        Return True if the top-level comment itself was authored by the page.

        In that case we should skip any automated reply logic, since the page
        is already the author of this comment.
        """
        return comment.from_user is not None and comment.from_user.id == page_id

    def perform_monitoring_cycle(self, rules: Dict[str, Rule]):
        enabled_rules = {k: v for k, v in rules.items() if v.enabled}
        if not enabled_rules:
            logger.debug("No enabled rules found, skipping cycle")
            return

        reels = self.facebook_service.get_reels()
        logger.debug("Fetched %s reels to evaluate rules", len(reels))
        page_id = self.facebook_service.page_id
        total_comments = 0
        replies_sent = 0
        inbox_sent = 0

        for reel in reels:
            rule = enabled_rules.get(reel.id)
            if not rule:
                continue

            comments = self.facebook_service.get_comments(reel.id)
            total_comments += len(comments)
            logger.debug("Processing %s comments for reel %s", len(comments), reel.id)
            for comment in comments:
                # Skip comments we've already processed in previous cycles
                if comment.id in self._replied_comment_ids:
                    continue
                # Skip comments authored by the page itself
                if self._is_page_comment(comment, page_id):
                    continue

                if self._has_page_replied(comment, page_id):
                    # Remember that this comment thread already has a page reply
                    self._replied_comment_ids.add(comment.id)
                    continue

                if self._matches(comment.message, rule):
                    try:
                        self.facebook_service.reply_to_comment(comment.id, rule.reply_message)
                        replies_sent += 1
                        logger.debug("Auto-replied to comment %s on reel %s", comment.id, reel.id)
                        # Mark this comment as replied so we don't process it again
                        self._replied_comment_ids.add(comment.id)

                        if rule.inbox_message:
                            try:
                                self.facebook_service.send_private_reply(comment.id, rule.inbox_message)
                                inbox_sent += 1
                                logger.debug("Sent private reply for comment %s", comment.id)
                            except Exception as e:
                                logger.exception("Failed to send private reply for comment %s: %s", comment.id, e)

                    except Exception as e:
                        logger.exception("Failed to reply to comment %s: %s", comment.id, e)

        logger.info(
            "Monitoring cycle complete: reels=%s comments=%s replies=%s inbox=%s rules=%s enabled_rules=%s",
            len(reels),
            total_comments,
            replies_sent,
            inbox_sent,
            len(rules),
            len(enabled_rules),
        )
