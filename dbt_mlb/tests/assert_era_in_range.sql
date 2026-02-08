-- ERA should be non-negative (or null). Values > 100 are suspicious but possible.
-- Flag only negative values as definite errors.

select *
from {{ ref('stg_pitching_stats') }}
where era is not null
  and era < 0
