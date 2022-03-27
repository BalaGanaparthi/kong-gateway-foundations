#!/usr/bin/env bash

red=$(tput setaf 1)
normal=$(tput sgr0)

printf "\n${red}Setting up Kong Gateway Operations Lab Envrinment.${normal}"
printf "\n${red}Setting up CA, certificate and key for docker.${normal}"
mkdir -p ~/.docker
curl -so ~/.docker/ca.pem http://docker:9000/ca.pem
curl -so ~/.docker/cert.pem http://docker:9000/cert.pem
curl -so ~/.docker/key.pem http://docker:9000/key.pem
cd ~/
if [ -d "kong-gateway-operations" ]; then rm -Rf "kong-gateway-operations"; fi
printf "\n${red}Cloning Kong Gateway Operations Repo under user home directory.${normal}\n"
git clone https://github.com/gigaprimatus/kong-gateway-operations.git
cd kong-gateway-operations/installation
printf "\n${red}Copying SSL certificates to shared location.${normal}"
cp -R ssl-certs /srv/shared
printf "\n${red}Instantiating log files, accessibe at /srv/shared/logs/.${normal}"
mkdir -p /srv/shared/logs
touch $(grep '/srv/shared/logs/' docker-compose.yaml|awk '{print $2}'|xargs)
chmod a+w /srv/shared/logs/*
printf "\n${red}Cleaning up previous instances in Docker.${normal}\n"
docker-compose down -v
printf "\n${red}Unsetting KONG_LICENSE_DATA environment variable.${normal}"
if [ -z "KONG_LICENSE_DATA" ]; then unset KONG_LICENSE_DATA; fi
printf "\n${red}Bringing up Kong Gateway.${normal}\n"
docker-compose up -d
printf "\n${red}Waiting for Gateway startup to finish.${normal}"
sleep 8
printf "\n${red}Applying Enterprise License.${normal}\n"
http --headers POST "kongcluster:8001/licenses" payload=@/etc/kong/license.json | grep HTTP
printf "\n${red}Recreating Contral Plane.${normal}\n"
docker-compose stop kong-cp; docker-compose rm -f kong-cp; docker-compose up -d kong-cp
sleep 8
printf "\n${red}Checking Admin API.${normal}\n"
curl -IsX GET kongcluster:8001 | grep Server
printf "\n${red}Enabling the Developer Portal.${normal}\n"
curl -siX PATCH kongcluster:8001/workspaces/default -d "config.portal=true" | grep HTTP
printf "\n${red}Configuring decK.${normal}\n"
sed -i "s|KONG_ADMIN_API_URI|$KONG_ADMIN_API_URI|g" deck/deck.yaml
printf "\n${red}Copying the script to user path.${normal}\n"
mkdir -p ~/.local/bin
cp scram.sh ~/.local/bin/
source ~/.profile
printf "\n${red}Displaying Gateway URIs${normal}\n"
env | grep KONG | sort
printf "\n${red}Completed Setting up Kong Gateway Operations Lab Envrinment.${normal}\n\n"