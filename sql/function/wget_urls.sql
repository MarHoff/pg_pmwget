-- Function: item_json(text, integer, boolean, numeric, numeric, text, text, text)

CREATE OR REPLACE FUNCTION @extschema@.wget_urls(
    url_array @extschema@.url_array ,
    wait numeric DEFAULT 0,
    timeout numeric DEFAULT 5,
    tries integer DEFAULT 3,
    workers integer DEFAULT 10,
    delimiter text DEFAULT '@wget_token@'
)
  RETURNS TABLE (url @extschema@.url, payload text, ts_end timestamptz, duration double precision) AS
$BODY$
WITH
wget_urls as (SELECT * FROM @extschema@.wget_urls_raw(array_to_string(url_array,' '), wait := wait , timeout := timeout, tries := tries, workers := workers, delimiter := delimiter)),
explode AS (SELECT regexp_split_to_array(regexp_split_to_table((SELECT * FROM wget_urls) ,'@wget_token@@wget_token@\n'),'@wget_token@') r)
SELECT r[1]::@extschema@.url  url, NULLIF(r[2],'') payload, r[4]::timestamptz ts_end, EXTRACT(EPOCH FROM (r[4]::timestamptz-r[3]::timestamptz))::double precision duration FROM explode order by r[1];
$BODY$
  LANGUAGE sql VOLATILE
  PARALLEL SAFE
  COST 2000;