-- Getting the top 20 most often rated movies
with top_movies as (
    select movie_id, count(movie_id) as rating_count
    from ratings
    group by movie_id
    order by rating_count desc
    limit 20)

select n.title, t.rating_count
from top_movies t inner join names n
on t.movie_id = n.movie_id;