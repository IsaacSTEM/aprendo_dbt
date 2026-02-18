select
  payment_id,
  order_id,
  payment_method_key,
  payment_status,
  amount,
  currency,

  -- Split for easy joins to dim_date / dim_time
  payment_ts::date as payment_date,
  payment_ts::time(0) as payment_time

from {{ ref('stg_odoo__payments') }}
