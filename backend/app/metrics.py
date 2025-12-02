from prometheus_client import Counter, Gauge, Histogram

# Labels: method = facebook service method name, page_id = page id or 'unknown'
fb_api_calls = Counter(
    'facebook_api_calls_total',
    'Total Facebook Graph API calls made by the backend',
    ['method', 'page_id']
)

# Per-monitoring-cycle aggregated metrics (labels: user_id, page_id)
monitor_cycle_api_calls = Counter(
    'monitoring_cycle_api_calls_total',
    'Number of Facebook API calls made during a monitoring cycle',
    ['user_id', 'page_id']
)

monitor_cycle_reels = Counter(
    'monitoring_cycle_reels_scanned_total',
    'Number of reels scanned during a monitoring cycle',
    ['user_id', 'page_id']
)

monitor_cycle_comments = Counter(
    'monitoring_cycle_comments_scanned_total',
    'Number of comments scanned during a monitoring cycle',
    ['user_id', 'page_id']
)

monitor_cycle_replies_sent = Counter(
    'monitoring_cycle_replies_sent_total',
    'Number of public comment replies sent during a monitoring cycle',
    ['user_id', 'page_id']
)

monitor_cycle_inbox_sent = Counter(
    'monitoring_cycle_inbox_messages_sent_total',
    'Number of private replies (inbox) sent during a monitoring cycle',
    ['user_id', 'page_id']
)

# Monitor duration histogram (seconds)
monitor_cycle_duration_seconds = Histogram(
    'monitoring_cycle_duration_seconds',
    'Duration of a monitoring cycle in seconds',
    ['user_id', 'page_id']
)

# Scheduler-level gauges
scheduler_jobs_scheduled = Gauge(
    'scheduler_jobs_scheduled',
    'Number of monitoring jobs currently scheduled'
)


def label_for(page_id: str | None) -> str:
    return page_id if page_id else 'unknown'


