select
  customer_id,
  email_hash
from {{ ref('stg_odoo__customers') }}
