with spine as (

  -- 24h * 60m * 60s = 86400 rows
  select
    seq4() as sec_of_day
  from table(generator(rowcount => 86400))

),

parts as (

  select
    floor(sec_of_day / 3600) as hour_24,
    floor((sec_of_day % 3600) / 60) as minute,
    (sec_of_day % 60) as second
  from spine

),

final as (

  select
    -- Key for joins from facts: TIME(0) value
    to_time(
      lpad(hour_24::string, 2, '0') || ':' ||
      lpad(minute::string, 2, '0') || ':' ||
      lpad(second::string, 2, '0')
    ) as time_of_day,

    hour_24,
    minute,
    second,

    -- Helpful formats
    lpad(hour_24::string, 2, '0') || ':' || lpad(minute::string, 2, '0') as time_hhmm,

    -- Simple day-part buckets
    case
      when hour_24 < 7 then 'night'
      when hour_24 < 14 then 'morning'
      when hour_24 < 20 then 'afternoon'
      else 'evening'
    end as day_part,

    -- Simple business-hours flag (Mon–Sun agnostic)
    case
      when hour_24 >= 9 and hour_24 < 18 then true
      else false
    end as is_business_hours

  from parts

)

select *
from final
