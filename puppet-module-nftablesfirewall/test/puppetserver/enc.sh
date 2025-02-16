#!/bin/bash

if [ -e "/vagrant/enc.${1}.json" ]
then
    cat "/vagrant/enc.${1}.json"
    exit 0
fi
if [ -e "/vagrant/enc.json" ]
then
    cat "/vagrant/enc.json"
    exit 0
fi
printf '{"classes": {}, "environment": "production", "parameters": {}}'