-- OPS should equal OBP + SLG (within rounding tolerance of 0.005)

select *
from {{ ref('int_player_season_batting') }}
where on_base_percentage is not null
  and slugging_percentage is not null
  and on_base_plus_slugging is not null
  and abs(on_base_plus_slugging - (on_base_percentage + slugging_percentage)) > 0.005
