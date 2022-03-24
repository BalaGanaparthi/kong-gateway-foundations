#!/usr/bin/env bash
echo "Setting up CA, certificate and key for docker..."
mkdir -p ~/.docker
echo "Folder ~/.docker created."
curl -so ~/.docker/ca.pem http://docker:9000/ca.pem
echo "File ca.pem saved in ~/.docker folder."
curl -so ~/.docker/cert.pem http://docker:9000/cert.pem
echo "File cert.pem saved in ~/.docker folder."
curl -so ~/.docker/key.pem http://docker:9000/key.pem
echo "File key.pem saved in ~/.docker folder."

