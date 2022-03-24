#!/usr/bin/env bash
mkdir -p ~/.docker
curl -so ~/.docker/ca.pem http://docker:9000/ca.pem
curl -so ~/.docker/cert.pem http://docker:9000/cert.pem
curl -so ~/.docker/key.pem http://docker:9000/key.pem
cd ~/
if [ -d "kong-gateway-operations" ]; then rm -Rf "kong-gateway-operations"; fi
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
cd kong-gateway-operations/installation
cp -R ssl-certs /srv/shared
mkdir -p /srv/shared/logs
touch $(grep '/srv/shared/logs/' docker-compose.yaml|awk '{print $2}'|xargs)
chmod a+w /srv/shared/logs/*
docker-compose down -v
unset KONG-LICENSE_DATA
docker-compose up -d
sleep 8
http POST "kongcluster:8001/licenses" payload=@/etc/kong/license.json
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp
sleep 8
http --headers GET kongcluster:8001 | grep Server
env | grep KONG | sort