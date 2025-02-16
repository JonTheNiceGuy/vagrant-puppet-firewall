#!/bin/bash
debug() {
    if [ "${DEBUG:-0}" != "0" ]
    then
        echo "$@" >&2
    fi
}
error() {
    echo "$@" >&2
}
result() {
    rc="$1"
    echo "Puppet apply exit is $rc" >&2
    if [ "$rc" == 0 ] || [ "$rc" == 2 ]
    then
        debug Run completed successfully.
        return
    fi
    if [ "$rc" == 1 ]
    then
        error "Run failed, or wasn't attempted due to another run in progress."
        exit $rc
    elif [ "$rc" == 4 ]
    then
        error "Run completed, but some failures occurred. No changes were made."
        exit $rc
    elif [ "$rc" == 6 ]
    then
        error "Run completed, but some failures occurred. Changes were made."
        exit $rc
    else
        error "An unexpected error code was received."
        exit $rc
    fi
}