with src as (
  select
    case
      when customer_id is null    then 'UNKNOWN_CUSTOMER'
      when trim(customer_id) = '' then 'UNKNOWN_CUSTOMER'
      else trim(upper(customer_id))
    end as customer_id,

    case
      when customer_email is null    then 'unknown_email'
      when trim(customer_email) = '' then 'unknown_email'
      else md5(lower(trim(customer_email)))
    end as email_hash

  from {{ source('odoo', 'raw_orders') }}
)

select
  customer_id,
  max(email_hash) as email_hash
from src
group by customer_id

union all

select
  'UNKNOWN_USER' as customer_id,
  'unknown_email' as email_hash