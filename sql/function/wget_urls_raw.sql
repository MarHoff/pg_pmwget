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
  COST 200;