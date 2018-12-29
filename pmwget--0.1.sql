--
-- Regular Expression for URL validation
--
-- Author: Diego Perini
-- Updated: 2010/12/05
-- License: MIT
--
-- Copyright (c) 2010-2013 Diego Perini (http://www.iport.it)

CREATE OR REPLACE FUNCTION @extschema@.is_url(
    test_string text)
  RETURNS boolean AS
$BODY$
SELECT test_string ~* (
    E'^' ||
    -- protocol identifier
    E'(?:(?:https?|ftp)://)' ||
    -- user:pass authentication
    E'(?:\\S+(?::\\S*)?@)?' ||
    E'(?:' ||
      -- IP address exclusion
      -- private & local networks
      E'(?!(?:10|127)(?:\\.\\d{1,3}){3})' ||
      E'(?!(?:169\\.254|192\\.168)(?:\\.\\d{1,3}){2})' ||
      E'(?!172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.\\d{1,3}){2})' ||
      -- IP address dotted notation octets
      -- excludes loopback network 0.0.0.0
      -- excludes reserved space >= 224.0.0.0
      -- excludes network & broacast addresses
      -- (first & last IP address of each class)
      E'(?:[1-9]\\d?|1\\d\\d|2[01]\\d|22[0-3])' ||
      E'(?:\\.(?:1?\\d{1,2}|2[0-4]\\d|25[0-5])){2}' ||
      E'(?:\\.(?:[1-9]\\d?|1\\d\\d|2[0-4]\\d|25[0-4]))' ||
    E'|' ||
      -- host name
      E'(?:(?:[a-z\\u00a1-\\uffff0-9]-*)*[a-z\\u00a1-\\uffff0-9]+)' ||
      -- domain name
      E'(?:\\.(?:[a-z\\u00a1-\\uffff0-9]-*)*[a-z\\u00a1-\\uffff0-9]+)*' ||
      -- TLD identifier
      E'(?:\\.(?:[a-z\\u00a1-\\uffff]{2,}))' ||
      -- TLD may end with dot
      E'\\.?' ||
    E')' ||
    -- port number
    E'(?::\\d{2,5})?' ||
    -- resource path
    E'(?:[/?#]\\S*)?' ||
    E'$'
  );
$BODY$
  LANGUAGE SQL IMMUTABLE
  PARALLEL SAFE
  COST 1;
CREATE DOMAIN @extschema@.url AS text NOT NULL
    CONSTRAINT url_check CHECK
    (@extschema@.is_url(VALUE))
;
CREATE OR REPLACE FUNCTION @extschema@.is_url_array(
    test_array text[])
  RETURNS boolean AS
$BODY$
SELECT bool_and(@extschema@.is_url(test)) FROM unnest(test_array) a(test);
$BODY$
  LANGUAGE SQL IMMUTABLE
  PARALLEL SAFE
  COST 1;
CREATE DOMAIN @extschema@.url_array AS text[] NOT NULL
    CONSTRAINT url_array_check CHECK
    (@extschema@.is_url_array(VALUE))
;
CREATE OR REPLACE FUNCTION @extschema@.is_url_shlist(
    test_shlist text)
  RETURNS boolean AS
$BODY$
SELECT @extschema@.is_url_array(string_to_array(test_shlist,' '::text));
$BODY$
  LANGUAGE SQL IMMUTABLE
  PARALLEL SAFE
  COST 1;
CREATE DOMAIN @extschema@.url_shlist AS text NOT NULL
    CONSTRAINT url_shlist_check CHECK
    (@extschema@.is_url_shlist(VALUE))
;
-- Function: wget_url(text, numeric, numeric, integer)

CREATE OR REPLACE FUNCTION @extschema@.wget_url
(
    url @extschema@.url,
    min_latency double precision DEFAULT 0,
    timeout double precision DEFAULT 5,
    tries integer DEFAULT 1,
    waitretry double precision DEFAULT 0



  )
  RETURNS text AS
$BODY$
#!/bin/sh
export HOME='/tmp'
export WGET_URL="$1"
export WGET_MIN_LATENCY=$2
export WGET_TIMEOUT=$3
export WGET_TRIES=$4
export WGET_WAITRETRY=$5

sleep $WGET_MIN_LATENCY & wget --timeout=$WGET_TIMEOUT --tries=$WGET_TRIES --waitretry=$WGET_WAITRETRY -qO- $WGET_URL & wait
$BODY$
  LANGUAGE plsh VOLATILE
  PARALLEL SAFE
  COST 200;
-- Function: wget_urls(text, numeric, numeric, integer)

CREATE OR REPLACE FUNCTION @extschema@.wget_urls_raw
(
    url_shlist @extschema@.url_shlist ,
    min_latency double precision DEFAULT 0,
    timeout double precision DEFAULT 5,
    tries integer DEFAULT 1,
    waitretry double precision DEFAULT 0,
    parallel_jobs integer DEFAULT 10,
    delimiter text DEFAULT '@wget_token@',
    delay double precision DEFAULT 0
  )
  RETURNS text AS
$BODY$
#!/bin/sh
export HOME='/tmp'
export WGET_URL_SHLIST="$1"
export WGET_MIN_LATENCY=$2
export WGET_TIMEOUT=$3
export WGET_TRIES=$4
export WGET_WAITRETRY=$5
export WGET_PARALLEL_JOBS=$6
export WGET_DELIMITER="$7"
export WGET_DELAY=$8

sleep $WGET_DELAY
sleep $WGET_MIN_LATENCY & parallel --jobs $WGET_PARALLEL_JOBS 'echo -n {};echo -n $WGET_DELIMITER; START_TIME=$(date +"%F %T.%6N"); wget --timeout=$WGET_TIMEOUT --tries=$WGET_TRIES --waitretry=$WGET_WAITRETRY -qO- {}; END_TIME=$(date +"%F %T.%6N"); echo $WGET_DELIMITER$START_TIME$WGET_DELIMITER$END_TIME$WGET_DELIMITER$WGET_DELIMITER' ::: $WGET_URL_SHLIST & wait
#TODO quickly explain parallel usage
$BODY$
  LANGUAGE plsh VOLATILE
  COST 200;-- Function: wget_url

CREATE OR REPLACE FUNCTION @extschema@.wget_urls
(
  url_array @extschema@.url_array ,
  i_min_latency double precision DEFAULT 0,
  i_timeout double precision DEFAULT 5,
  i_tries integer DEFAULT 1,
  i_waitretry double precision DEFAULT 0,
  i_parallel_jobs integer DEFAULT 10,
  i_delimiter text DEFAULT '@wget_token@',
  i_delay double precision DEFAULT 0,
  r_min_latency double precision DEFAULT 0,
  r_timeout double precision DEFAULT 5,
  r_tries integer DEFAULT 1,
  r_waitretry double precision DEFAULT 0,
  r_parallel_jobs integer DEFAULT 10,
  r_delimiter text DEFAULT '@wget_token@',
  r_delay double precision DEFAULT 0,
  batch_size integer DEFAULT 2000,
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
  FOR current_batch IN batches LOOP
    RETURN QUERY
      WITH RECURSIVE
      trecurse AS (
          SELECT
            r[1]::@extschema@.url  url,
            NULLIF(r[2], '') payload,
            r[4]::timestamptz ts_end,
            EXTRACT(EPOCH FROM (r[4]::timestamptz-r[3]::timestamptz))::double precision duration,
            current_batch.batch,
            0 as retries,
            (count(*) FILTER (WHERE NULLIF(r[2], '') is NULL) OVER ())/((count(*) OVER ())::double precision) batch_failrate
            FROM (
              SELECT
                regexp_split_to_array(
                  regexp_split_to_table(
                    (SELECT * FROM
                      @extschema@.wget_urls_raw(
                        array_to_string(current_batch.url_array, ' '),
                        min_latency := i_min_latency,
                        timeout := i_timeout,
                        tries := i_tries,
                        waitretry := i_waitretry,
                        parallel_jobs := i_parallel_jobs,
                        delimiter := i_delimiter,
                        delay := (CASE WHEN current_batch.batch<>1 THEN i_delay ELSE 0 END)
                      )
                    ),
                    '@wget_token@@wget_token@\n'),
                  '@wget_token@') r
            ) inititial_try
        UNION ALL
          SELECT
            r[1]::@extschema@.url  url,
            NULLIF(r[2], '') payload,
            r[4]::timestamptz ts_end,
            EXTRACT(EPOCH FROM (r[4]::timestamptz-r[3]::timestamptz))::double precision duration,
            recurse_try.batch,
            recurse_try.retries+1 as retries,
            recurse_try.batch_failrate
            FROM (
              SELECT
                regexp_split_to_array(
                  regexp_split_to_table(
                    (SELECT * FROM
                      @extschema@.wget_urls_raw(
                        array_to_string(
                        wget_agg.urls_retry,
                          ' '),
                        min_latency := r_min_latency,
                        timeout := r_timeout,
                        tries := r_tries,
                        waitretry := r_waitretry,
                        parallel_jobs := r_parallel_jobs,
                        delimiter := r_delimiter,
                        delay := r_delay
                      )
                    ),
                    '@wget_token@@wget_token@\n'),
                  '@wget_token@') r,
                wget_agg.batch,
                wget_agg.retries,
                wget_agg.batch_failrate
              FROM (
                SELECT array_agg(source_recurse.url::text) as urls_retry, source_recurse.batch, source_recurse.retries, source_recurse.batch_failrate
                FROM (
                  SELECT trecurse.url, trecurse.payload, trecurse.batch,  trecurse.retries, trecurse.batch_failrate, trecurse.retries=(max(trecurse.retries) OVER (PARTITION BY trecurse.url)) as is_last
                  FROM trecurse
                ) source_recurse
                WHERE source_recurse.is_last AND source_recurse.retries < batch_retries AND source_recurse.payload IS NULL AND source_recurse.batch_failrate <= batch_retries_failrate
                GROUP BY source_recurse.batch, source_recurse.retries, source_recurse.batch_failrate
              ) wget_agg
            ) recurse_try
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