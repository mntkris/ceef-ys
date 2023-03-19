#! /bin/bash
~/pg/p/bin/psql -c "CREATE ROLE ceef WITH CREATEDB CREATEROLE INHERIT LOGIN BYPASSRLS PASSWORD 'fillme';" postgres
~/pg/p/bin/createdb --owner=ceef ceef_02_intro
~/pg/p/bin/createdb ceef_about
