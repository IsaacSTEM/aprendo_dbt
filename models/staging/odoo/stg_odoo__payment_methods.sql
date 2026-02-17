with src as (
  select
    case
      when provider is null    then 'unknown'
      when trim(provider) = '' then 'unknown'
                               else lower(trim(provider))
    end as payment_method
  from {{ source('odoo', 'raw_payments') }}
)

select
  md5(payment_method) as payment_method_key,
  payment_method
from src
group by
  payment_method_key,
  payment_method
