-- Create an empty, internal table
-- Note that if you drop this table, the data is gone!
create table if not exists ratings(
    user_id int,
    movie_id int,
    rating int,
    time int
)
row format delimited
fields terminated by '\t'
stored as textfile;

-- Fill the ratings table with some actual data.
-- Since the following filepath resides in HDFS, we must use the 
-- LOAD DATA command (instead of LOAD DATA LOCAL). When using the 
-- LOAD DATA command, the data is *moved* (and not copied) into HIVE,
-- so, it won't exist in HDFS afterwards anymore
load data inpath  '/user/root/playground/ml-100k/u.data'
overwrite into table ratings;

-- Note that if the load data inpat ... command worked once, it won't work
-- a second time, because the file '/user/root/playground/ml-100k/u.data'
-- was *moved* from HDFS into HIVE!

-- To check if everything worked, execute select * from ratings; in a new 
-- query console