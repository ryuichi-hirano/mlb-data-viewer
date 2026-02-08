-- Wins + losses should equal games_played in team standings

select *
from {{ ref('int_team_standings') }}
where games_played is not null
  and wins is not null
  and losses is not null
  and wins + losses != games_played
