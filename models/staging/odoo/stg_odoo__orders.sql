with src as (
  select
    case
      when order_id is null then 'UNKNOWN_ORDER'
      when trim(order_id) = '' then 'UNKNOWN_ORDER'
      else trim(order_id)
    end as order_id,

    case
      when customer_id is null then 'UNKNOWN_CUSTOMER'
      when trim(customer_id) = '' then 'UNKNOWN_CUSTOMER'
      else trim(customer_id)
    end as customer_id,

    case
      when status is null                                           then 'failed'
      when trim(status) = ''                                        then 'failed'
      when lower(trim(status)) in ('failed')                        then 'failed'
      when lower(trim(status)) in ('draft')                         then 'draft'
      when lower(trim(status)) in ('cancelled', 'canceled')         then 'cancelled'
      when lower(trim(status)) in ('paid', 'completed', 'refunded') then 'confirmed'
                                                                    else 'confirmed'
    end as order_status,

    case
      when total is null then '0'::decimal(10,2)
      when trim(total) = '' then '0'::decimal(10,2)
      else replace(trim(total), ',', '.')::decimal(10,2)
    end as amount_total,

    case
      when currency is null    then 'EUR'
      when trim(currency) = '' then 'EUR'
                               else upper(trim(currency))
    end as currency,

    -- para deduplicar
    ingested_at::timestamp_ntz as ingested_ts
  from {{ source('odoo', 'raw_orders') }}
),

dedup as (
  select *
  from src
  qualify row_number() over (
    partition by order_id
    order by ingested_ts desc nulls last
  ) = 1
)

select
  order_id,
  customer_id,
  order_status,
  amount_total,
  currency
from dedup
