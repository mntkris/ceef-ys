#! /bin/bash
~/pg/p/bin/psql -c "CREATE ROLE ceef WITH CREATEDB CREATEROLE INHERIT LOGIN BYPASSRLS PASSWORD 'fillme';" postgres
~/pg/p/bin/createdb ceef-book
~/pg/p/bin/createdb ceef-book-final 
