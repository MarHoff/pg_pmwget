WITH tsel AS (
  SELECT array_agg(format('https://hacker-news.firebaseio.com/v0/item/%s.json',id)) qarray
  FROM (
    SELECT generate_series(1,10)::bigint id
  )foo
)


SELECT *
FROM wget_urls((SELECT qarray FROM tsel), workers := 10, timeout := 5)
ORDER BY retries desc, batch asc;

--SELECT * FROM wget_urls_raw('https://hacker-news.firebaseio.com/v0/item/7897.json https://hacker-news.firebaseio.com/v0/item/7898.json https://hacker-news.firebaseio.com/v0/item/7899.json', workers := 100);