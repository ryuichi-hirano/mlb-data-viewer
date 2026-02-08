-- Release speed should be between 40 and 110 mph when present
-- Exit velocity should be between 10 and 125 mph when present

select *
from {{ ref('stg_statcast') }}
where (release_speed is not null and (release_speed < 40 or release_speed > 110))
   or (exit_velocity is not null and (exit_velocity < 10 or exit_velocity > 125))
