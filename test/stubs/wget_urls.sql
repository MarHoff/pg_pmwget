WITH tsel AS (
  SELECT array_agg(format('http://pmwget.test/pg_pmwget_test.php?q=%s&e=30',id)) qarray
  FROM (
    SELECT generate_series(1,100)::bigint id
  )foo
)


SELECT *
FROM wget_urls((SELECT qarray FROM tsel)::url_array, b_parallel_jobs := 20, b_timeout := 5)
ORDER BY retries desc, batch asc;

--SELECT * FROM wget_urls_raw('https://hacker-news.firebaseio.com/v0/item/7897.json https://hacker-news.firebaseio.com/v0/item/7898.json https://hacker-news.firebaseio.com/v0/item/7899.json', workers := 100);