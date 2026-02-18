select
  session_id,
  user_id,
  session_start_ts,
  session_end_ts,

  -- Split for easy joins to dim_date / dim_time
  session_start_ts::date as session_start_date,
  session_start_ts::time(0) as session_start_time,
  session_end_ts::date as session_end_date,
  session_end_ts::time(0) as session_end_time

from {{ ref('stg_odoo__web_sessions') }}
