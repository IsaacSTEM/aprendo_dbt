select
  event_id,
  session_id,
  event_ts,
  event_name,
  page,

  -- Split for easy joins to dim_date / dim_time
  event_ts::date as event_date,
  event_ts::time(0) as event_time

from {{ ref('stg_odoo__web_events') }}
