{{
  config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'
  )
}}

with raw_src as (

    select *
    from {{ source('odoo', 'raw_orders') }}

    {% if is_incremental() %}
    where try_to_timestamp_ntz(ingested_at::string) >= (select max(ingested_ts) from {{ this }})
    {% endif %}

    -- {% if is_incremental() %}
    --   where try_to_timestamp_ntz(ingested_at::string) >= (
    --     select coalesce(
    --       dateadd('day', -1, max(ingested_ts)),
    --       '1900-01-01 00:00:00'::timestamp_ntz
    --     )
    --     from {{ this }}
    --   )
    -- {% endif %}

),

src as (

    select
        trim(order_id::string)    as order_id_raw,
        trim(customer_id::string) as customer_id_raw,
        lower(trim(status::string)) as status_raw,
        trim(total::string)       as total_raw,
        upper(trim(currency::string)) as currency_raw,
        trim(order_ts::string)    as order_ts_raw,

        coalesce(
          try_to_timestamp_ntz(ingested_at::string),
          '1970-01-01 00:00:00'::timestamp_ntz
        ) as ingested_ts

    from raw_src

),

clean as (

    select
        -- En un incremental con unique_key, no conviene colapsar nulos/blancos
        -- a 'UNKNOWN_ORDER': mejor excluirlos o mandarlos a cuarentena.
        order_id_raw as order_id,

        case
          when customer_id_raw is null or customer_id_raw = '' then 'UNKNOWN_CUSTOMER'
          else customer_id_raw
        end as customer_id,

        case
          when status_raw is null or status_raw = '' then 'failed'
          when status_raw = 'failed' then 'failed'
          when status_raw = 'draft' then 'draft'
          when status_raw in ('cancelled', 'canceled') then 'cancelled'
          when status_raw in ('paid', 'completed', 'refunded') then 'confirmed'
          else 'confirmed'
        end as order_status,

        coalesce(
          try_to_decimal(replace(total_raw, ',', '.'), 10, 2),
          0::decimal(10,2)
        ) as amount_total,

        case
          when currency_raw is null or currency_raw = '' then 'EUR'
          else currency_raw
        end as currency,

        coalesce(
          try_to_timestamp_ntz(replace(order_ts_raw, 'T', ' '), 'YYYY-MM-DD HH24:MI:SS'),
          try_to_timestamp_ntz(order_ts_raw, 'YYYY-MM-DD HH24:MI:SS'),
          try_to_timestamp_ntz(order_ts_raw, 'YYYY/MM/DD HH24:MI:SS'),
          try_to_timestamp_ntz(order_ts_raw, 'DD-MM-YYYY HH24:MI'),
          '1970-01-01 00:00:00'::timestamp_ntz
        ) as order_ts,

        ingested_ts

    from src
    where order_id_raw is not null
      and order_id_raw <> ''

),

dedup as (

    select *
    from clean
    qualify row_number() over (
        partition by order_id
        order by ingested_ts desc, order_ts desc
    ) = 1

)

select
    order_id,
    order_ts,
    customer_id,
    order_status,
    amount_total,
    currency,
    ingested_ts
from dedup