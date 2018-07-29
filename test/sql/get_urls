WITH
tsel AS (
  SELECT array_agg(url)::url_array
  FROM (
    SELECT 'https://hacker-news.firebaseio.com/v0/item/'||generate_series(1,100)||'.json' url
  )foo
)
SELECT * FROM get_urls((SELECT * FROM tsel))