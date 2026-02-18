-- models/marts/shared/dim_date.sql
-- Date dimension (generated). Builds the full base year (from data) + the next full year.

with base as (

  -- Base year from the data; fallback to current_date if no rows
  select
    year(coalesce(min(cast(event_ts as date)), current_date)) as base_year
  from {{ ref('stg_odoo__web_events') }}

),

bounds as (

  select
    to_date(cast(base_year as varchar) || '-01-01') as start_date,
    to_date(cast(base_year + 1 as varchar) || '-12-31') as end_date
  from base

),

date_spine as (

  -- Generate enough days to cover 2 full years, then filter by end_date
  select
    dateadd(day, seq4(), (select start_date from bounds)) as date_day
  from table(generator(rowcount => 800))

),

filtered as (

  select
    date_day
  from date_spine
  where date_day <= (select end_date from bounds)

)

select
  date_day,

  -- Core calendar fields
  year(date_day) as year,
  quarter(date_day) as quarter,
  month(date_day) as month,
  day(date_day) as day,

  -- ISO calendar fields
  dayofweekiso(date_day) as day_of_week_iso,
  weekiso(date_day) as week_of_year_iso,

  -- Handy flags
  case
    when dayofweekiso(date_day) in (6, 7) then true
    else false
  end as is_weekend,

  case
    when day(date_day) = 1 then true
    else false
  end as is_month_start,

  case
    when date_day = last_day(date_day) then true
    else false
  end as is_month_end,

  -- Useful labels / keys
  trim(to_char(date_day, 'MONTH')) as month_name,
  trim(to_char(date_day, 'DAY')) as day_name,
  to_char(date_day, 'YYYY-MM') as year_month,
  to_char(date_day, 'YYYY') || '-Q' || quarter(date_day) as year_quarter

from filtered
