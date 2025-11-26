from apscheduler.schedulers.background import BackgroundScheduler
from typing import Optional
from app.services.config_service import ConfigService
from app.services.facebook_service import FacebookService
from app.services.monitor_service import MonitorService
from app.core.database import SessionLocal
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
        self.job = None

    def _get_db(self) -> Session:
        db = SessionLocal()
        return db

    def _job_func(self):
        db = self._get_db()
        try:
            config_service = ConfigService(db)
            # Check if monitoring enabled in config
            enabled = config_service.get_monitoring_enabled()

            if not enabled:
                logger.debug('Monitoring disabled in config; skipping scheduled run')
                return

            config = config_service.load_config()
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
            logger.debug('Running scheduled monitoring cycle: %s rules', len(rules))
            monitor_service.perform_monitoring_cycle(rules)
            logger.debug('Scheduled monitoring cycle completed')
        except Exception as e:
            logger.exception('Scheduled monitoring job failed: %s', e)
        finally:
            db.close()

    def start(self, interval_seconds: Optional[int] = None):
        db = None
        try:
            db = self._get_db()
            from app.services.config_service import ConfigService
            config_service = ConfigService(db)
            monitoringEnabled = config_service.get_monitoring_enabled()
            if not monitoringEnabled:
                logger.info('Monitoring disabled in config; not starting scheduler job')
                return
            if interval_seconds is None:
                interval_seconds = config_service.get_monitoring_interval_seconds(DEFAULT_INTERVAL_SECONDS)
        except Exception:
            interval_seconds = interval_seconds or DEFAULT_INTERVAL_SECONDS
        finally:
            if db:
                db.close()

        if self.job is not None:
            self.scheduler.remove_job(self.job.id)

        self.job = self.scheduler.add_job(self._job_func, 'interval', seconds=interval_seconds, id='monitoring_job')
        # Start scheduler if not already running
        if not self.scheduler.running:
            self.scheduler.start()
        logger.info('Monitoring scheduler started with interval %s seconds', interval_seconds)

    def reschedule(self, interval_seconds: int):
        """Change the interval of the scheduled monitoring job at runtime."""
        try:
            if self.job is not None:
                self.scheduler.remove_job(self.job.id)
            self.job = self.scheduler.add_job(self._job_func, 'interval', seconds=interval_seconds, id='monitoring_job')
            logger.info('Monitoring scheduler rescheduled to %s seconds', interval_seconds)
            # ensure scheduler running
            if not self.scheduler.running:
                self.scheduler.start()
        except Exception as e:
            logger.exception('Failed to reschedule monitoring job: %s', e)

    def shutdown(self):
        self.scheduler.shutdown(wait=False)
        logger.info('Monitoring scheduler shutdown')


# Module-level singleton to be used by main.py and API endpoints
monitoring_scheduler: Optional[MonitoringScheduler] = None
