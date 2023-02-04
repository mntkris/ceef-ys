#! /bin/bash
P=~/pg
rm -rf $P/pgadmin4
sudo rm -rf /var/lib/pgadmin 
sudo rm -rf /var/log/pgadmin
sudo mkdir /var/lib/pgadmin &&
sudo mkdir /var/log/pgadmin &&
cd $P && 
sudo chown $USER /var/lib/pgadmin &&
sudo chown $USER /var/log/pgadmin &&
python -m venv pgadmin4 &&
source $P/pgadmin4/bin/activate &&
pip install pgadmin4 &&
pgadmin4