#!/bin/bash
set -eux

sudo make build
sudo make install
sudo -u postgres psql -c "DROP EXTENSION IF EXISTS pmwq;"
sudo -u postgres psql -c "CREATE EXTENSION pmwq;"