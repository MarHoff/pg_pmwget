SELECT * FROM wget_urls('{https://hacker-news.firebaseio.com/v0/item/7897.json,
                 https://hacker-news.firebaseio.com/v0/item/7898.json,
                        https://hacker-news.firebaseio.com/v0/item/7899.json}'
, workers := 100);

--SELECT * FROM wget_urls_raw('https://hacker-news.firebaseio.com/v0/item/7897.json https://hacker-news.firebaseio.com/v0/item/7898.json https://hacker-news.firebaseio.com/v0/item/7899.json', workers := 100);