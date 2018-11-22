-- Function: wget_url

CREATE OR REPLACE FUNCTION @extschema@.wget_urls
(
  url_array @extschema@.url_array ,
  b_min_latency double precision DEFAULT 0,
  b_timeout double precision DEFAULT 5,
  b_tries integer DEFAULT 1,
  b_waitretry double precision DEFAULT 10,
  b_parallel_jobs integer DEFAULT 10,
  b_delimiter text DEFAULT '@wget_token@',
  r_min_latency double precision DEFAULT 0,
  r_timeout double precision DEFAULT 10,
  r_tries integer DEFAULT 4,
  r_waitretry double precision DEFAULT 10,
  batch_size integer DEFAULT 2000,
  batch_delay double precision DEFAULT 0,
  batch_retries integer DEFAULT 1,
  batch_retries_failrate double precision DEFAULT 0.05
)
RETURNS TABLE (
  url @extschema@.url,
  payload text,
  ts_end timestamptz,
  duration double precision,
  batch bigint,
  retries integer,
  batch_failrate double precision) AS
$BODY$
DECLARE
    batches CURSOR FOR
      WITH
      tunnest AS (SELECT DISTINCT unnest(url_array) url),
      tbatches AS (SELECT ((row_number() OVER ()-1)/batch_size)+1 batch, tunnest.url FROM tunnest)
      SELECT
        tbatches.batch,
        array_agg(tbatches.url)::url_array url_array
        FROM tbatches
        GROUP BY tbatches.batch ORDER BY tbatches.batch;
BEGIN

WITH tunnest AS (SELECT DISTINCT unnest(url_array) url)
SELECT
   url::public.url,
   NULL::text payload,
   NULL::timestamptz ts_end,
   NULL::double precision duration ,
   NULL::bigint batch,
   NULL::integer retries
FROM tunnest




  FOR current_batch IN batches LOOP
    RETURN QUERY
      WITH RECURSIVE
      twget_raw as (
        SELECT *
          FROM @extschema@.wget_urls_raw(
            array_to_string(current_batch.url_array, ' '),
            min_latency := b_min_latency,
            timeout := b_timeout,
            tries := b_tries,
            waitretry := b_waitretry,
            parallel_jobs := b_parallel_jobs,
            delimiter := b_delimiter,
            delay := (CASE WHEN current_batch.batch<>1 THEN batch_delay ELSE 0 END)
          )
      ),
      texplode AS (
        SELECT
          regexp_split_to_array(regexp_split_to_table((SELECT * FROM twget_raw), '@wget_token@@wget_token@\n'),'@wget_token@') r
      ),
      trecurse AS (
          SELECT
            r[1]::@extschema@.url  url,
            NULLIF(r[2], '') payload,
            r[4]::timestamptz ts_end,
            EXTRACT(EPOCH FROM (r[4]::timestamptz-r[3]::timestamptz))::double precision duration,
            current_batch.batch,
            0 as retries,
            (count(*) FILTER (WHERE NULLIF(r[2], '') is NULL) OVER ())/((count(*) OVER ())::double precision) batch_failrate
            FROM texplode
        UNION ALL
          SELECT
            trecurse.url,
            wget_url(
              trecurse.url,
              min_latency:= r_min_latency,
              timeout:= r_timeout,
              tries:= r_tries,
              waitretry:= r_waitretry
            ) payload,
            clock_timestamp()::timestamptz ts_end,
            NULL duration,
            trecurse.batch,
            trecurse.retries+1 as retries,
            trecurse.batch_failrate
          FROM trecurse WHERE trecurse.payload IS NULL AND trecurse.retries < batch_retries AND trecurse.batch_failrate <= batch_retries_failrate
      ),
      tfilter AS (
        SELECT
          trecurse.url::url,
          trecurse.payload::text,
          trecurse.ts_end,
          COALESCE(
            trecurse.duration,
            EXTRACT(EPOCH FROM (trecurse.ts_end-(lag(trecurse.ts_end) OVER (ORDER BY trecurse.ts_end asc))))
          ) duration,
          trecurse.batch,
          trecurse.retries,
          trecurse.batch_failrate,
          max(trecurse.retries) OVER (PARTITION BY trecurse.url)=trecurse.retries as last_retry
        FROM trecurse
      )
      SELECT
        tfilter.url,
        tfilter.payload,
        tfilter.ts_end,
        tfilter.duration,
        tfilter.batch,
        tfilter.retries,
        tfilter.batch_failrate
      FROM tfilter WHERE last_retry ORDER BY tfilter.url
      ;
  END LOOP;
  RETURN;
END
$BODY$
  LANGUAGE PLPGSQL VOLATILE
  PARALLEL SAFE
  COST 2000;