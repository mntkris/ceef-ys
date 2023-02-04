#! /bin/bash
V=15.1
P=~/pg/$V
rm -rf $P
mkdir $P &&
ln -s $P ~/pg/p &&
cd $P &&
wget https://ftp.postgresql.org/pub/source/v$V/postgresql-$V.tar.bz2 &&
tar xvf postgresql-$V.tar.bz2 &&
rm $P/postgresql-$V.tar.bz2 &&
mv $P/postgresql-$V $P/src &&
cd $P/src/contrib &&
cd $P/src &&
./configure --prefix=$P \
  --enable-nls='pl'  --with-perl --with-python --with-tcl \
  --with-icu --with-llvm --with-lz4 --with-zstd --with-openssl \
  --with-ldap --with-pam --with-systemd --with-ossp-uuid \
  --with-libxml --with-libxslt --with-pgport=55151 &&
make world &&
make check &&
make install-world &&
export PATH=$P/bin:$PATH &&
echo '========' &&
cd $P/src/contrib &&
git clone https://github.com/EnterpriseDB/pldebugger.git &&
cd $P/src/contrib/pldebugger &&
make &&
make install &&
echo '=======' &&
cd $P/src/contrib &&
git clone https://github.com/okbob/plpgsql_check.git &&
cd $P/src/contrib/plpgsql_check &&
make clean &&
make all &&
make install &&
# make installcheck && # wymaga serwera podniesionego
echo '=========' &&
cd $P &&
$P/bin/initdb -D $P/data &&
mkdir $P/log &&
echo "shared_preload_libraries = '\$libdir/plugin_debugger,\$libdir/plpgsql,\$libdir/plpgsql_check'" >> $P/data/postgresql.conf &&  #TODO better, sed?
echo "$P/bin/pg_ctl start -D $P/data --log=$P/log/postgresql.log --wait" > $P/start && chmod +x $P/start &&
echo "$P/bin/pg_ctl stop -D $P/data --wait" > $P/stop && chmod +x $P/stop &&
echo "$P/bin/pg_ctl status -D $P/data" > $P/status && chmod +x $P/status &&
echo "$P/bin/pg_ctl reload -D $P/data" > $P/reload && chmod +x $P/reload &&
$P/start &&
# $P/bin/psql --list
