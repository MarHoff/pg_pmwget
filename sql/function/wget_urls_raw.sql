-- Function: wget_urls(text, numeric, numeric, integer)

-- DROP FUNCTION @extschema@.wget_urls(text, numeric, numeric, integer);

CREATE OR REPLACE FUNCTION @extschema@.wget_urls_raw
(
    url_shlist @extschema@.url_shlist ,
    wait numeric DEFAULT 0,
    timeout numeric DEFAULT 5,
    tries integer DEFAULT 3,
    workers integer DEFAULT 10,
    delimiter text DEFAULT '@wget_token@'
  )
  RETURNS text AS
$BODY$
#!/bin/sh
export HOME='/tmp'
export WGET_STRING="$1"
export WGET_WAIT=$2
export WGET_TIMEOUT=$3
export WGET_TRIES=$4
export WGET_WORKERS=$5
export WGET_TOKEN=$6
parallel -j $WGET_WORKERS 'echo -n {};echo -n $WGET_TOKEN;wget -T $WGET_TIMEOUT -t $WGET_TRIES -qO- {};echo $WGET_TOKEN$WGET_TOKEN' ::: $WGET_STRING
#TODO quickly explain parallel usage
$BODY$
  LANGUAGE plsh VOLATILE
  COST 200;
