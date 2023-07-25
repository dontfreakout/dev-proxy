#!/usr/bin/env bash
set -e

if [ "$HTTPS_PORT" != "443" ] && [ -n "$HTTPS_PORT" ]; then
	PORT=":$HTTPS_PORT"
	PROTOCOL="https"
else
	PORT=""
	PROTOCOL="http"
fi

# Retrieve a list of distinct server names from the nginx configuration.
LOCAL_DOMAINS=$(nginx -T 2>/dev/null | sed -nr "s/^\s+server_name\s+([^_ ]+)\s*;/\1/p" | uniq)

# Process the list of server names.
# Get the last two parts of each domain name.
# Sort by the first field.
echo "$LOCAL_DOMAINS" | \
awk -F'.' '{ print $(NF-1) "." $NF "\t" $0 }' | \
sort -k1,1 | \
awk -v PROTOCOL=$PROTOCOL -v PORT=$PORT -F'\t' 'BEGIN {
    GREEN="\033[1;32m"
    NC="\033[0m"
}
function format(i, link) { # Function to format the output.
    return "\t" i ". " PROTOCOL "://" link PORT "\n";
}
{
    if(x!=$1){ # Separation logic between different domains.
        if(x!="") print "\n" y;
        x=$1; y=GREEN $1 NC "\n"; i = 1;
    }
    y = y format(i++, $2); # Append formatted output
} END{ print y }' # END clause to ensure the last part is also printed out.
