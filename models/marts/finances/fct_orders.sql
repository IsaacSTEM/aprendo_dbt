select
  order_id,
  customer_id,
  order_status,
  amount_total,
  currency,

  -- Split for easy joins to dim_date / dim_time
  ingested_at::date as order_date,
  ingested_at::time(0) as order_time

from {{ ref('stg_odoo__orders') }}
