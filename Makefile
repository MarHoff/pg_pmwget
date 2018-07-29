EXTENSION = pmwq
DATA = $(wildcard *.sql)

FUNCTION :=  func_get_url func_get_urls_raw func_get_urls
FUNCTION := $(addprefix sql/function/, $(addsuffix .sql, $(FUNCTION)))

DOMAIN := is_url url is_url_array url_array is_url_shlist url_shlist
DOMAIN := $(addprefix sql/domain/, $(addsuffix .sql, $(DOMAIN)))


#TESTS = $(wildcard TEST/SQL/*.sql)

usage:
	@echo 'pg_pmwq usage : "make install" to instal the extension, "make build" to build dev version against source SQL'

.PHONY : build
build : pmwq--dev.sql
	@echo 'Building develloper version'

pmwq--dev.sql : $(DOMAIN) $(FUNCTION) 
	cat $(DOMAIN) > $@ && cat $(FUNCTION) >> $@

#test:
#	pg_prove -v --pset tuples_only=1 $(TESTS)

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
