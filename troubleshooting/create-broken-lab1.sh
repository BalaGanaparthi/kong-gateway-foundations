#!/bin/bash

cd ~/kong-gateway-operations/troubleshooting
DECKFILE="/home/labuser/kong-gateway-operations/installation/deck/deck.yaml"
sed -i "s|KONG_ADMIN_API_URI|$KONG_ADMIN_API_URI|g" $DECKFILE > /dev/null 2>&1
deck dump --config $DECKFILE
yes|deck reset --config $DECKFILE
deck sync --config $DECKFILE -s kong-brokenlab1.yaml > /dev/null 2>&1
