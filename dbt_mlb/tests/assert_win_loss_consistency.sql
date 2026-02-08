-- For each game in int_game_results, exactly one team should win and one should lose
-- (excluding ties which should not exist in completed games)

select
    game_pk,
    count(*) as row_count,
    sum(case when is_win then 1 else 0 end) as win_count,
    sum(case when is_loss then 1 else 0 end) as loss_count
from {{ ref('int_game_results') }}
group by game_pk
having count(*) != 2
    or sum(case when is_win then 1 else 0 end) != 1
    or sum(case when is_loss then 1 else 0 end) != 1
