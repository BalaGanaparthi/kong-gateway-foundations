#!/bin/bash

cd ~/kong-gateway-operations/troubleshooting
DECKFILE="/home/labuser/kong-gateway-operations/installation/deck/deck.yaml"
sed -i "s|KONG_ADMIN_API_URI|$KONG_ADMIN_API_URI|g" $DECKFILE > /dev/null 2>&1
deck dump --config $DECKFILE 
deck sync --config $DECKFILE -s broken-lab2.yaml > /dev/null 2>&1
