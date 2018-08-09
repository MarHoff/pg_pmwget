-- Function: wget_url

CREATE OR REPLACE FUNCTION @extschema@.wget_urls(
  url_array @extschema@.url_array ,
  wait numeric DEFAULT 0,
  timeout numeric DEFAULT 5,
  tries integer DEFAULT 3,
  workers integer DEFAULT 10,
  delimiter text DEFAULT '@wget_token@',
  nbpasses integer DEFAULT 3,
  batch_size integer DEFAULT 2000
)
RETURNS TABLE (
  url @extschema@.url,
  payload text,
  ts_end timestamptz,
  duration double precision,
  batch bigint,
  passes integer) AS
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
  FOR current_batch IN batches LOOP
    RETURN QUERY
      WITH RECURSIVE
      twget_raw as (
        SELECT *
          FROM @extschema@.wget_urls_raw(
            array_to_string(current_batch.url_array, ' '),
            wait := wait ,
            timeout := timeout,
            tries := tries,
            workers := workers,
            delimiter := delimiter)
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
            1 as passes
            FROM texplode
        UNION ALL
          SELECT
            trecurse.url,
            wget_url(trecurse.url, wait := wait , timeout := timeout, tries := tries) payload,
            clock_timestamp()::timestamptz ts_end,
            NULL duration,
            trecurse.batch,
            trecurse.passes+1 as passes
          FROM trecurse WHERE trecurse.payload IS NULL AND trecurse.passes < nbpasses
      )
      SELECT
        trecurse.url::url,
        trecurse.payload::text,
        trecurse.ts_end,
        COALESCE(
          trecurse.duration,
          EXTRACT(EPOCH FROM (trecurse.ts_end-(lag(trecurse.ts_end) OVER (ORDER BY trecurse.ts_end asc))))
        ),
        trecurse.batch,
        trecurse.passes
      FROM trecurse;
  END LOOP;
  RETURN;
END
$BODY$
  LANGUAGE PLPGSQL VOLATILE
  PARALLEL SAFE
  COST 2000;