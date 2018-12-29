DROP TABLE IF EXISTS testbig;

WITH tsel AS (
  SELECT array_agg(format('https://hacker-news.firebaseio.com/v0/item/%s.json',id)) qarray
  FROM (
    SELECT generate_series(20001,30000)::bigint id
  )foo
)


SELECT * INTO testbig
FROM wget_urls((SELECT qarray FROM tsel), b_parallel_jobs :=100 , b_min_latency :=60, b_timeout:=10, batch_size := 800, batch_delay := 5)
ORDER BY retries desc, batch asc;


SELECT
batch,
min(ts_end) ts_start,
EXTRACT(EPOCH FROM (max(ts_end)-min(ts_end))) total_duration,
avg(duration) avg_duration,
max(duration) max_duration,
min(duration) min_duration,
batch_failrate,
max (retries) retries,
count(*),
count(*) FILTER (WHERE payload IS NOT NULL) count_ok,
count(*) FILTER (WHERE retries <> 0 ) count_retried
FROM testbig
GROUP BY batch, batch_failrate
ORDER BY batch asc

--SELECT * FROM testbig WHERE retries =1 ORDER BY batch, ts_end