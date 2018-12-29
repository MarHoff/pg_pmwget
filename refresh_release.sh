#!/bin/bash
set -eux

make build
sudo make install
sudo -u postgres psql -c "DROP EXTENSION IF EXISTS pmwget CASCADE;"
sudo -u postgres psql -c "CREATE EXTENSION pmwget;"