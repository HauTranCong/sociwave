from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.models import MonitoringMetric
from app.models.models import RuleModel
from typing import List, Optional
from sqlalchemy import func
from fastapi import Depends

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get('/summary')
def metrics_summary(user_id: Optional[int] = None, page_id: Optional[str] = None, limit: int = 100, db: Session = Depends(get_db)):
    """Return recent monitoring metrics filtered by user_id or page_id. Results ordered by start_time desc."""
    q = db.query(MonitoringMetric)
    if user_id is not None:
        q = q.filter(MonitoringMetric.user_id == user_id)
    if page_id is not None:
        q = q.filter(MonitoringMetric.page_id == page_id)
    q = q.order_by(MonitoringMetric.id.desc()).limit(limit)
    rows = q.all()
    results = []
    for r in rows:
        # Simple, non-complex calculation: count enabled rules in rules table for this user/page
        try:
            q = db.query(RuleModel).filter(RuleModel.user_id == r.user_id, RuleModel.page_id == r.page_id, RuleModel.enabled == True)
            reels_active_count = q.count()
        except Exception:
            # fallback to stored value if anything goes wrong
            reels_active_count = r.reels_scanned

        results.append({
            'id': r.id,
            'user_id': r.user_id,
            'page_id': r.page_id,
            'start_time': r.start_time,
            'duration_seconds': float(r.duration_seconds) if r.duration_seconds is not None else 0.0,
            'reels_scanned': r.reels_scanned,
            # expose processed/active reels explicitly so dashboards don't double-count fetched reels
            'reels_active': reels_active_count,
            'comments_scanned': r.comments_scanned,
            'replies_sent': r.replies_sent,
            'inbox_sent': r.inbox_sent,
            'api_calls': r.api_calls,
        })

    return results


@router.get('/aggregate')
def metrics_aggregate(user_id: Optional[int] = None, page_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Return aggregated sums over monitoring metrics (helpful for dashboards/quick totals)."""
    # Compute reels_active from enabled rules in rules table (simple count)
    reels_active_count = 0
    try:
        rq = db.query(func.count(RuleModel.object_id))
        if user_id is not None:
            rq = rq.filter(RuleModel.user_id == user_id)
        if page_id is not None:
            rq = rq.filter(RuleModel.page_id == page_id)
        rq = rq.filter(RuleModel.enabled == True)
        reels_active_count = int(rq.scalar() or 0)
    except Exception:
        reels_active_count = 0

    q = db.query(
        func.coalesce(func.sum(MonitoringMetric.comments_scanned), 0).label('comments_scanned'),
        func.coalesce(func.sum(MonitoringMetric.replies_sent), 0).label('replies_sent'),
        func.coalesce(func.sum(MonitoringMetric.inbox_sent), 0).label('inbox_sent'),
        func.coalesce(func.sum(MonitoringMetric.api_calls), 0).label('api_calls'),
        func.count(MonitoringMetric.id).label('rows'),
    )
    if user_id is not None:
        q = q.filter(MonitoringMetric.user_id == user_id)
    if page_id is not None:
        q = q.filter(MonitoringMetric.page_id == page_id)

    row = q.one()
    return {
        'rows': int(row.rows or 0),
        'reels_active': int(reels_active_count),
        'comments_scanned': int(row.comments_scanned or 0),
        'replies_sent': int(row.replies_sent or 0),
        'inbox_sent': int(row.inbox_sent or 0),
        'api_calls': int(row.api_calls or 0),
    }


@router.delete('/')
def delete_metrics(user_id: Optional[int] = None, page_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Delete monitoring metrics. If user_id or page_id are provided, only matching rows will be deleted.
    Returns the number of deleted rows.
    """
    q = db.query(MonitoringMetric)
    if user_id is not None:
        q = q.filter(MonitoringMetric.user_id == user_id)
    if page_id is not None:
        q = q.filter(MonitoringMetric.page_id == page_id)
    # count rows to be deleted
    try:
        count = q.count()
        # perform delete
        q.delete(synchronize_session=False)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'deleted': int(count)}
