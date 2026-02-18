with e as (
  select
    session_id,
    event_ts,

    case
      when user_id is null    then 'UNKNOWN_USER'
      when trim(user_id) = '' then 'UNKNOWN_USER'
                              else trim(user_id)
    end as user_id
  from {{ source('odoo', 'raw_web_events') }}
),

typed as (
  select
    case
      when session_id is null    then 'UNKNOWN_SESSION'
      when trim(session_id) = '' then 'UNKNOWN_SESSION'
                                 else trim(session_id)
    end as session_id,

case
    when event_ts is null
      or trim(event_ts::string) = ''
    then '1970-01-01 00:00:00'::timestamp_ntz

    -- 2026-02-16T10:20:00
    when regexp_like(trim(event_ts::string),
         '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         replace(trim(event_ts::string), 'T', ' '),
         'YYYY-MM-DD HH24:MI:SS'
    )

    -- 2026-02-16 11:00:00
    when regexp_like(trim(event_ts::string),
         '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         trim(event_ts::string),
         'YYYY-MM-DD HH24:MI:SS'
    )

    -- 2026/02/16 10:21:30
    when regexp_like(trim(event_ts::string),
         '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         trim(event_ts::string),
         'YYYY/MM/DD HH24:MI:SS'
    )

    -- 16-02-2026 11:01
    when regexp_like(trim(event_ts::string),
         '^[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         trim(event_ts::string),
         'DD-MM-YYYY HH24:MI'
    )

    else '1970-01-01 00:00:00'::timestamp_ntz
end as event_ts,

    user_id
  from e
)

select
  session_id,
  max(user_id) as user_id,        -- simple: nos quedamos con alguno
  min(event_ts) as session_start_ts,
  max(event_ts) as session_end_ts
from typed
group by session_id
