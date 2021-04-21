-- Following commands are not fully working. To be safe, just import the u.item file
-- from the hue UI
create table if not exists names(
    movie_id int,
    title string,
    airing_date date,
    col1 int,
    col2 int,
    col3 int,
    col4 int,
    col5 int,
    col6 int,
    col7 int,
    col8 int,
    col9 int,
    col10 int,
    col11 int,
    col12 int,
    col13 int,
    col14 int,
    col15 int,
    col16 int,
    col17 int,
    col18 int,
    col19 int)
row format delimited
fields terminated by '|'
stored as textfile;

load data inpath  '/user/root/playground/ml-100k/u.item'
overwrite into table names;