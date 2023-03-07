#!/usr/bin/env bash
set -e

if [ "$HTTPS_PORT" != "443" ] && [ -n "$HTTPS_PORT" ]; then
	PORT=":$HTTPS_PORT"
else
	PORT=""
fi

LOCAL_DOMAINS=$(nginx -T 2>/dev/null | sed -nr "s/^\s+server_name\s+([^_ ]+)\s*;/\1/p" | uniq)
LOOP_COUNTER=1
for domain in $LOCAL_DOMAINS; do
		echo -e "${LOOP_COUNTER}.\thttps://${domain}${PORT}"
		LOOP_COUNTER=$((LOOP_COUNTER+1))
done
