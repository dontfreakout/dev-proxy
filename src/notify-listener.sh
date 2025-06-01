#!/bin/sh
set -e

_reload_nginx() {
    nginx -s reload
}

if [ -n "$AUTOCERT" ]; then
    ./auto-cert.sh
fi

./show-vhosts.sh --json > html/vhosts.json

_reload_nginx
