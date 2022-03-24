#!/usr/bin/env bash
echo "Setting up CA, certificate and key for docker..."
mkdir -p ~/.docker
echo "Folder ~/.docker created."
curl -so ~/.docker/ca.pem http://docker:9000/ca.pem
curl -so ~/.docker/cert.pem http://docker:9000/cert.pem
curl -so ~/.docker/key.pem http://docker:9000/key.pem
echo "Files ca.pem, cert.pem and key.pem saved in ~/.docker folder"