select
  payment_method_key,
  payment_method
from {{ ref('stg_odoo__payment_methods') }}