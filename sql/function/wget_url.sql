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
