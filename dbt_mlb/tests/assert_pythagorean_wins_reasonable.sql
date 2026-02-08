-- Pythagorean expected wins should be within 15 games of actual wins
-- Larger deviations indicate potential data quality issues

select *
from {{ ref('fct_team_season_summary') }}
where pythagorean_wins is not null
  and wins is not null
  and abs(pythagorean_wins - wins) > 15
