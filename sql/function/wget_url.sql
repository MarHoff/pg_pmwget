-- Function: wget_url(text, numeric, numeric, integer)

-- DROP FUNCTION @extschema@.wget_url(text, numeric, numeric, integer);

CREATE OR REPLACE FUNCTION @extschema@.wget_url(
    url @extschema@.url,
    min_latency double precision DEFAULT 0,
    timeout double precision DEFAULT 5,
    tries integer DEFAULT 1,
    waitretry double precision DEFAULT 10
    )
  RETURNS text AS
$BODY$
#!/bin/sh
sleep $2 & wget --timeout=$3 --tries=$4 --waitretry=$5 -qO- "$1" & wait
$BODY$
  LANGUAGE plsh VOLATILE
  PARALLEL SAFE
  COST 200;
