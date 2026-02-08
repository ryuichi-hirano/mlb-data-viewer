-- Batting average must be between 0 and 1 (or null)
-- Applies to all layers: staging, intermediate, marts

select *
from {{ ref('stg_batting_stats') }}
where batting_average is not null
  and (batting_average < 0 or batting_average > 1)
