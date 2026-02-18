with typed as (
  select
    case
      when event_id is null    then 'UNKNOWN_EVENT'
      when trim(event_id) = '' then 'UNKNOWN_EVENT'
                               else trim(event_id)
    end as event_id,

    case
      when session_id is null    then 'UNKNOWN_SESSION'
      when trim(session_id) = '' then 'UNKNOWN_SESSION'
                                 else trim(session_id)
    end as session_id,

    case
      when event_ts is null    then '1970-01-01 00:00:00'::timestamp_ntz
      when trim(event_ts) = '' then '1970-01-01 00:00:00'::timestamp_ntz
                               else event_ts::timestamp_ntz
    end as event_ts,

    case
      when event_name is null    then 'unknown_event'
      when trim(event_name) = '' then 'unknown_event'
                                 else lower(trim(event_name))
    end as event_name,

    -- page = path de la URL (ej: /products/camiseta-roja)
    case
      when page_url is null                            then '/'
      when trim(page_url) = ''                         then '/'
      when parse_url(page_url):path::string is null    then '/'
      when trim(parse_url(page_url):path::string) = '' then '/'
                                                       else parse_url(page_url):path::string
    end as page,

    ingested_at::timestamp_ntz as ingested_ts
  from {{ source('odoo', 'raw_web_events') }}
),

dedup as (
  select *
  from typed
  qualify row_number() over (
    partition by event_id
    order by ingested_ts desc
  ) = 1
)

select
  event_id,
  session_id,
  event_ts,
  event_name,
  page
from dedup
