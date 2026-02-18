select
  order_id,
  customer_id,
  order_status,
  amount_total,
  currency,

  -- Split for easy joins to dim_date / dim_time
  order_ts::date as order_date,
  order_ts::time(0) as order_time

from {{ ref('stg_odoo__orders') }}
