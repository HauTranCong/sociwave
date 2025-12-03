from typing import Dict, Set, Optional
from app.models.models import Rule, Comment
from app.services.facebook_service import FacebookService
from app import metrics
import logging
from time import time

logger = logging.getLogger(__name__)


class MonitorService:
    def __init__(self, facebook_service: FacebookService):
        self.facebook_service = facebook_service
        # Track comments we've already processed/replied to in this process
        self._replied_comment_ids: Set[str] = set()
        # Cache expensive per-comment "has page replied" checks
        self._comment_reply_cache: Dict[str, bool] = {}

    def _matches(self, comment_text: str, rule: Rule) -> bool:
        lower_comment = comment_text.lower()
        if not rule.match_words or "." in rule.match_words:
            return True
        return any(keyword.lower() in lower_comment for keyword in rule.match_words)

    def _has_page_replied(self, comment: Comment, page_id: str) -> bool:
        cached = self._comment_reply_cache.get(comment.id)
        if cached is not None:
            return cached

        # As a precise per-comment check, query Facebook for replies
        # to this specific comment ID and see if the page has replied there.
        try:
            has_replied = self.facebook_service.has_replied_to_comment(comment.id)
            self._comment_reply_cache[comment.id] = has_replied
            if has_replied:
                self._replied_comment_ids.add(comment.id)
            return has_replied
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

    def perform_monitoring_cycle(self, rules: Dict[str, Rule], user_id: Optional[int] = None):
        """Run one monitoring cycle. Pass user_id when called from scheduler so metrics can be labeled.
        """
        uid = str(user_id) if user_id is not None else 'unknown'
        page_id_label = metrics.label_for(self.facebook_service.page_id)

        start_ts = time()

        enabled_rules = {k: v for k, v in rules.items() if v.enabled}
        if not enabled_rules:
            logger.debug("No enabled rules found, skipping cycle")
            # return zeroed metrics
            return {
                'reels': 0,
                'comments': 0,
                'replies': 0,
                'inbox': 0,
                'duration_seconds': 0.0,
            }

        # Track API call estimates locally so we can persist per-cycle API usage
        api_calls = 0

        reels = self.facebook_service.get_reels()
        api_calls += 1
        logger.debug("Fetched %s reels to evaluate rules", len(reels))

        # We'll count only reels that have an enabled rule configured and were actually processed.
        reels_processed = 0

        page_id = self.facebook_service.page_id
        total_comments = 0
        replies_sent = 0
        inbox_sent = 0

        for reel in reels:
            rule = enabled_rules.get(reel.id)
            # Log whether this reel has an associated enabled rule
            if rule:
                reels_processed += 1
                logger.debug("Reel %s matched rule (enabled=%s)", reel.id, getattr(rule, 'enabled', None))
            else:
                logger.debug("Reel %s has no enabled rule configured; skipping", reel.id)
                continue

            comments = self.facebook_service.get_comments(reel.id)
            api_calls += 1
            total_comments += len(comments)
            try:
                metrics.monitor_cycle_comments.labels(user_id=uid, page_id=page_id_label).inc(len(comments))
            except Exception:
                pass

            logger.debug("Processing %s comments for reel %s", len(comments), reel.id)
            for comment in comments:
                # Skip comments we've already processed in previous cycles
                if comment.id in self._replied_comment_ids:
                    logger.debug("Skipping comment %s on reel %s: already processed in this process", comment.id, reel.id)
                    continue
                # Skip comments authored by the page itself
                if self._is_page_comment(comment, page_id):
                    logger.debug("Skipping comment %s on reel %s: authored by page", comment.id, reel.id)
                    continue

                # Check nested replies we already fetched; only fallback when truncated
                has_reply = comment.has_replied
                replies = comment.replies or []

                if not has_reply and replies:
                    if any(reply.from_user and reply.from_user.id == page_id for reply in replies):
                        has_reply = True

                if has_reply:
                    logger.debug("Skipping comment %s on reel %s: page already replied (nested data)", comment.id, reel.id)
                    self._replied_comment_ids.add(comment.id)
                    continue

                reply_count = comment.reply_count
                fallback_needed = False
                if reply_count is not None:
                    fallback_needed = reply_count > len(replies)

                if not fallback_needed and not replies and reply_count is None:
                    # No replies present and no summary information -> assume no replies
                    fallback_needed = False

                if not has_reply and fallback_needed:
                    try:
                        api_calls += 1
                        if self._has_page_replied(comment, page_id):
                            logger.debug("Skipping comment %s on reel %s: page already replied (fallback check)", comment.id, reel.id)
                            continue
                    except Exception:
                        # If check fails, assume not replied and continue
                        pass

                # Check and log match attempts
                matched = False
                try:
                    matched = self._matches(comment.message, rule)
                except Exception:
                    logger.exception("Error while evaluating rule match for comment %s on reel %s", comment.id, reel.id)

                if not matched:
                    logger.debug("Comment %s on reel %s did not match rule keywords", comment.id, reel.id)
                    continue

                # Matched -> reply
                try:
                    logger.debug("Rule matched comment %s on reel %s; attempting to reply", comment.id, reel.id)
                    api_calls += 1
                    resp = self.facebook_service.reply_to_comment(comment.id, rule.reply_message)
                    replies_sent += 1
                    try:
                        metrics.monitor_cycle_replies_sent.labels(user_id=uid, page_id=page_id_label).inc()
                    except Exception:
                        pass
                    logger.debug("Auto-replied to comment %s on reel %s; fb_response=%s", comment.id, reel.id, resp if resp is not None else {})
                    # Mark this comment as replied so we don't process it again
                    self._replied_comment_ids.add(comment.id)

                    if rule.inbox_message:
                        try:
                            api_calls += 1
                            self.facebook_service.send_private_reply(comment.id, rule.inbox_message)
                            inbox_sent += 1
                            try:
                                metrics.monitor_cycle_inbox_sent.labels(user_id=uid, page_id=page_id_label).inc()
                            except Exception:
                                pass
                            logger.debug("Sent private reply for comment %s", comment.id)
                        except Exception as e:
                            logger.exception("Failed to send private reply for comment %s: %s", comment.id, e)

                except Exception as e:
                    logger.exception("Failed to reply to comment %s: %s", comment.id, e)

        duration = time() - start_ts
        logger.info(
            "Monitoring cycle complete: fetched_reels=%s processed_reels=%s comments=%s replies=%s inbox=%s rules=%s enabled_rules=%s duration=%s",
            len(reels),
            reels_processed,
            total_comments,
            replies_sent,
            inbox_sent,
            len(rules),
            len(enabled_rules),
            duration,
        )

        # record duration histogram and api_calls metric
        try:
            metrics.monitor_cycle_duration_seconds.labels(user_id=uid, page_id=page_id_label).observe(duration)
        except Exception:
            pass

        try:
            metrics.monitor_cycle_api_calls.labels(user_id=uid, page_id=page_id_label).inc(api_calls)
        except Exception:
            pass

        # Record processed reels (only those with enabled rules) to Prometheus and return as 'reels'
        try:
            metrics.monitor_cycle_reels.labels(user_id=uid, page_id=page_id_label).inc(reels_processed)
        except Exception:
            pass

        return {
            'reels': reels_processed,
            'comments': total_comments,
            'replies': replies_sent,
            'inbox': inbox_sent,
            'duration_seconds': duration,
            'api_calls': api_calls,
        }
