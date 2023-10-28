#!/usr/bin/with-contenv sh

chmod -R +x /run/*
cp -rn /app/guacamole /config
mkdir -p /root/.config/freerdp/known_hosts
