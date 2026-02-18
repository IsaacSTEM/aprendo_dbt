with typed as (
  select
    case
      when payment_id is null    then 'UNKNOWN_PAYMENT'
      when trim(payment_id) = '' then 'UNKNOWN_PAYMENT'
      else trim(payment_id)
    end as payment_id,

    case
      when order_id is null    then 'UNKNOWN_ORDER'
      when trim(order_id) = '' then 'UNKNOWN_ORDER'
      else trim(order_id)
    end as order_id,

    md5(
      case
        when provider is null    then 'unknown'
        when trim(provider) = '' then 'unknown'
                                 else lower(trim(provider))
      end
    ) as payment_method_key,

    case
      when status is null                       then 'void'
      when trim(status) = ''                    then 'void'
      when lower(trim(status)) in ('succeeded') then 'succeeded'
      when lower(trim(status)) in ('failed')    then 'failed'
      when lower(trim(status)) in ('refunded')  then 'cancelled'
      when lower(trim(status)) in ('void')      then 'void'
                                                else 'void'
    end as payment_status,

    -- amount: limpiar símbolo € y castear a decimal
    case
      when amount is null    then '0'::decimal(10,2)
      when trim(amount) = '' then '0'::decimal(10,2)
                             else replace(replace(trim(amount),'€', ''),',', '.')::decimal(10,2)
    end as amount,

    case
      when currency is null    then 'EUR'
      when trim(currency) = '' then 'EUR'
                               else upper(trim(currency))
    end as currency,

    case
    when payment_ts is null
      or trim(payment_ts::string) = ''
    then '1970-01-01 00:00:00'::timestamp_ntz

    -- 2026-02-16T10:20:00
    when regexp_like(trim(payment_ts::string),
         '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         replace(trim(payment_ts::string), 'T', ' '),
         'YYYY-MM-DD HH24:MI:SS'
    )

    -- 2026-02-16 11:00:00
    when regexp_like(trim(payment_ts::string),
         '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         trim(payment_ts::string),
         'YYYY-MM-DD HH24:MI:SS'
    )

    -- 2026/02/16 10:21:30
    when regexp_like(trim(payment_ts::string),
         '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         trim(payment_ts::string),
         'YYYY/MM/DD HH24:MI:SS'
    )

    -- 16-02-2026 11:01
    when regexp_like(trim(payment_ts::string),
         '^[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}$')
    then to_timestamp_ntz(
         trim(payment_ts::string),
         'DD-MM-YYYY HH24:MI'
    )

    else '1970-01-01 00:00:00'::timestamp_ntz
end as payment_ts,

    -- para quedarnos con el último duplicado
    ingested_at::timestamp_ntz as ingested_ts
  from {{ source('odoo', 'raw_payments') }}
),

dedup as (
  select *
  from typed
  qualify row_number() over (
    partition by payment_id
    order by ingested_ts desc
  ) = 1
),

only_known_orders as (
  select dedup.*
  from dedup
  join {{ ref('stg_odoo__orders') }} orders
    on dedup.order_id = orders.order_id
)

select
  payment_id,
  payment_ts,
  order_id,
  payment_method_key,
  payment_status,
  amount,
  currency
from only_known_orders
