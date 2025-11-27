from apscheduler.schedulers.background import BackgroundScheduler
from typing import Dict, Optional, Tuple
from datetime import datetime
from app.services.config_service import ConfigService
from app.services.facebook_service import FacebookService
from app.services.monitor_service import MonitorService
from app.core.database import SessionLocal
from app.models.models import UserModel
from sqlalchemy.orm import Session
import logging

logger = logging.getLogger(__name__)
# Ensure scheduler logs are visible even if root logger not configured
if logger.level == logging.NOTSET:
    logger.setLevel(logging.INFO)

# Default interval in seconds (5 minutes)
DEFAULT_INTERVAL_SECONDS = 60 * 5

class MonitoringScheduler:
    def __init__(self):
        # Allow short delays without marking runs as missed; avoid piling up missed runs.
        self.scheduler = BackgroundScheduler(
            job_defaults={
                "misfire_grace_time": 30,  # seconds tolerance before treating as missed
                "coalesce": True,          # merge runs if several were missed
                "max_instances": 5,        # prevent overlapping runs
            }
        )
        self.jobs: Dict[Tuple[int, str], object] = {}
        self.last_run: Dict[Tuple[int, str], datetime] = {}

    def _get_db(self) -> Session:
        db = SessionLocal()
        return db

    def _job_func(self, user_id: int, page_id: str):
        db = self._get_db()
        try:
            config_service = ConfigService(db, user_id=user_id, page_id=page_id)
            # Check if monitoring enabled in config
            enabled = config_service.get_monitoring_enabled()

            if not enabled:
                logger.debug('Monitoring disabled for user %s page %s; skipping scheduled run', user_id, page_id)
                return

            config = config_service.load_config()
            if not config.accessToken or not config.pageId:
                logger.info('Skipping scheduled run for user %s page %s: missing Facebook configuration', user_id, page_id)
                return
            # Build FacebookService from config and run MonitorService directly
            fb = FacebookService(
                access_token=config.accessToken,
                page_id=config.pageId,
                version=config.version,
                reels_limit=config.reelsLimit,
                comments_limit=config.commentsLimit,
                replies_limit=config.repliesLimit,
            )
            monitor_service = MonitorService(fb)
            rules = config_service.load_rules()
            logger.debug('Running scheduled monitoring cycle for user %s page %s: %s rules', user_id, page_id, len(rules))
            monitor_service.perform_monitoring_cycle(rules)
            logger.debug('Scheduled monitoring cycle completed for user %s page %s', user_id, page_id)
            self.last_run[(user_id, page_id)] = datetime.utcnow()
        except Exception as e:
            logger.exception('Scheduled monitoring job failed for user %s page %s: %s', user_id, page_id, e)
        finally:
            db.close()

    def _remove_job(self, user_id: int, page_id: str):
        job = self.jobs.pop((user_id, page_id), None)
        if job is None:
            return
        try:
            self.scheduler.remove_job(job.id)
        except Exception:
            pass

    def _schedule_user_job(self, user_id: int, page_id: str, interval_seconds: Optional[int] = None):
        db = self._get_db()
        try:
            config_service = ConfigService(db, user_id=user_id, page_id=page_id)
            if not config_service.get_monitoring_enabled():
                logger.info('Monitoring disabled for user %s page %s; not scheduling job', user_id, page_id)
                self._remove_job(user_id, page_id)
                return
            if interval_seconds is None:
                interval_seconds = config_service.get_monitoring_interval_seconds(DEFAULT_INTERVAL_SECONDS)
        except Exception as exc:
            interval_seconds = interval_seconds or DEFAULT_INTERVAL_SECONDS
            logger.exception('Falling back to default interval for user %s page %s due to error: %s', user_id, page_id, exc)
        finally:
            db.close()

        job_id = f'monitoring_job_user_{user_id}_page_{page_id}'
        try:
            if (user_id, page_id) in self.jobs:
                try:
                    self.scheduler.remove_job(job_id)
                except Exception:
                    pass
            job = self.scheduler.add_job(self._job_func, 'interval', seconds=interval_seconds, id=job_id, args=[user_id, page_id])
            self.jobs[(user_id, page_id)] = job
            if not self.scheduler.running:
                self.scheduler.start()
            logger.info('Monitoring scheduler started for user %s page %s with interval %s seconds', user_id, page_id, interval_seconds)
        except Exception as e:
            logger.exception('Failed to schedule monitoring job for user %s page %s: %s', user_id, page_id, e)

    def start(self):
        db = self._get_db()
        try:
            users = db.query(UserModel).all()
        except Exception as exc:
            logger.exception('Could not load users to start scheduler: %s', exc)
            users = []
        finally:
            db.close()

        if not users:
            logger.info('No users found; scheduler not starting monitoring jobs')
            return

        for user in users:
            try:
                from app.models.models import ConfigModel
                db = self._get_db()
                pages = db.query(ConfigModel.page_id).filter(ConfigModel.user_id == user.id).distinct().all()
            except Exception as exc:
                logger.exception('Could not load pages for user %s: %s', user.id, exc)
                pages = []
            finally:
                if 'db' in locals():
                    db.close()

            if not pages:
                # If no page-specific config rows, schedule default page
                self._schedule_user_job(user.id, "default")
            else:
                for (page_id,) in pages:
                    self._schedule_user_job(user.id, page_id or "default")

    def reschedule(self, user_id: int, page_id: str, interval_seconds: int):
        """Change the interval of the scheduled monitoring job for a specific user/page."""
        self._schedule_user_job(user_id, page_id, interval_seconds)

    def refresh_user_job(self, user_id: int, page_id: str):
        """Re-evaluate a user/page job (enable/disable based on their config)."""
        self._schedule_user_job(user_id, page_id)

    def shutdown(self):
        self.scheduler.shutdown(wait=False)
        logger.info('Monitoring scheduler shutdown')


# Module-level singleton to be used by main.py and API endpoints
monitoring_scheduler: Optional[MonitoringScheduler] = None
