-- Game scores must be non-negative for completed games

select *
from {{ ref('stg_games') }}
where game_status_code = 'F'
  and (
    home_score < 0
    or away_score < 0
    or home_score is null
    or away_score is null
  )
