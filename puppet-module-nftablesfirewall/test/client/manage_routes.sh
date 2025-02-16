#!/bin/bash

debug() {
    echo "$@" >&2
    "$@"
}

if ip route | grep -q 'default via 10.0.2.2'
then
    debug ip route del default via 10.0.2.2 2>/dev/null || true
fi
if [ -n "$1" ]
then
    if ! ip route | grep -q "default via $1"
    then
        debug ip route add default via "$1"
    fi
fi
