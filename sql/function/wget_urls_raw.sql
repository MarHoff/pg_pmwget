-- Function: wget_urls(text, numeric, numeric, integer)

-- DROP FUNCTION @extschema@.wget_urls(text, numeric, numeric, integer);

CREATE OR REPLACE FUNCTION @extschema@.wget_urls_raw
(
    url_shlist @extschema@.url_shlist ,
    min_latency double precision DEFAULT 0,
    timeout double precision DEFAULT 5,
    tries integer DEFAULT 1,
    waitretry double precision DEFAULT 10,
    parallel_jobs integer DEFAULT 10,
    delimiter text DEFAULT '@wget_token@',
    delay double precision DEFAULT 0
  )
  RETURNS text AS
$BODY$
#!/bin/sh
export HOME='/tmp'
export WGET_STRING="$1"
export WGET_WAIT=$2
export WGET_TIMEOUT=$3
export WGET_TRIES=$4
export WGET_WAITRERY=$5
export PARALLEL_JOBS=$6
export PMWGET_DELIMITER=$7
sleep $8
sleep $2 & parallel --jobs $PARALLEL_JOBS 'echo -n {};echo -n $PMWGET_DELIMITER; START_TIME=$(date +"%F %T.%6N"); wget --timeout=$WGET_TIMEOUT --tries=$WGET_TRIES --waitretry=$WGET_WAITRERY -qO- {}; END_TIME=$(date +"%F %T.%6N"); echo $PMWGET_DELIMITER$START_TIME$PMWGET_DELIMITER$END_TIME$PMWGET_DELIMITER$PMWGET_DELIMITER' ::: $WGET_STRING & wait
#TODO quickly explain parallel usage
$BODY$
  LANGUAGE plsh VOLATILE
  COST 200;