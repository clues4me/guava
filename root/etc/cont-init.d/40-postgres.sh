#!/usr/bin/with-contenv sh

mkdir -p /config/postgres
mkdir -p /var/run/postgresql 
chown postgres:postgres /var/run/postgresql
chown -R postgres:postgres /config/postgres
chmod 0700 /config/postgres
chmod -R +x /command/*

if [ -e /config/postgres/postgresql.conf ]; then
  echo "Database already configured"
else
  cd /command && ./s6-setuidgid postgres initdb
fi
