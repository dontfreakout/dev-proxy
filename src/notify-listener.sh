#!/bin/sh
set -e

_reload_nginx() {
    nginx -s reload
}

if [ -n "$AUTOCERT" ]; then
    ./auto-cert.sh
fi

_reload_nginx
