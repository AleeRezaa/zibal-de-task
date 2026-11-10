select max(source_ts) as last_event
from {{ source('raw', 'cdc_events') }}
having last_event < now64(3) - interval 5 minute