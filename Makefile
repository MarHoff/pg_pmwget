EXTENSION = pmwget
DATA = $(wildcard *.sql)


DOMAIN := is_url url is_url_array url_array is_url_shlist url_shlist
DOMAIN := $(addprefix sql/domain/, $(addsuffix .sql, $(DOMAIN)))

FUNCTION :=  wget_url wget_urls_raw wget_urls
FUNCTION := $(addprefix sql/function/, $(addsuffix .sql, $(FUNCTION)))

TESTS = $(wildcard test/sql/*.sql)

usage:
	@echo 'pg_pmwget usage : "make install" to instal the extension, "make build" to build dev version against source SQL'

.PHONY : build
build : pmwget--dev.sql
	@echo 'Building develloper version'

pmwget--dev.sql : $(DOMAIN) $(FUNCTION) 
	cat $(DOMAIN) > $@ && cat $(FUNCTION) >> $@

.PHONY : test
test :
	sudo  -u postgres pg_prove -v --pset tuples_only=1 $(TESTS)

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
