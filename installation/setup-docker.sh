#!/usr/bin/env bash

red=$(tput setaf 1)
normal=$(tput sgr0)

printf "\n${red}Setting up CA, certificate and key for Docker.${normal}"
mkdir -p ~/.docker
cp misc/docker-config.json ~/.docker/config.json
curl -so ~/.docker/ca.pem http://docker:9000/ca.pem
curl -so ~/.docker/cert.pem http://docker:9000/cert.pem
curl -so ~/.docker/key.pem http://docker:9000/key.pem
mkdir -p /srv/shared/misc
cp loopback.yaml /srv/shared/misc
cp misc/kong_realm_template.json /srv/shared/misc
cp misc/prometheus.yaml /srv/shared/misc
cp misc/statsd.rules.yaml /srv/shared/misc
if [ ! -f "~/.local/bin/scram.sh" ]
then
  mkdir -p ~/.local/bin
  cp ~/kong-gateway-operations/installation/scram.sh ~/.local/bin/
  source /home/labuser/.profile
fi
docker-compose pull &>/dev/null &
printf "\n${red}Docker Setup complete.${normal}\n\n"