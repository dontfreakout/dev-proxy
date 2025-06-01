#!/usr/bin/env bash
set -e

RETRY_INTERVAL=2
RETRY_MAX=3

function get_domains_with_retry() {
	local retry_count=$RETRY_MAX
	local domains

	while [ "$retry_count" -gt 0 ]; do
		# Retrieve a list of distinct server names from the nginx configuration.
		domains=$(nginx -T 2>/dev/null | sed -nr "s/^\s+server_name\s+([^_ ]+)\s*;/\1/p" | uniq)

		# Remove localhost from the list, if present.
		domains=$(echo "$domains" | grep -v -E '^(localhost|127\.0\.0\.1)$')

		# If domains found (not empty after removing whitespace), return them
		if [ -n "${domains//[:space:]}" ]; then
			echo "$domains"
			return 0
		fi

		# Decrement retry count and wait before retrying
		retry_count=$((retry_count - 1))
		if [ "$retry_count" -gt 0 ]; then
			sleep $RETRY_INTERVAL
		fi
	done

	# All retries exhausted
	return 1
}

function list_domains() {
	local domains

	if domains=$(get_domains_with_retry); then
		echo "$domains"
	else
		echo "No server names found in the nginx configuration."
		return 1
	fi
}

function print() {
	local domains

	if ! domains=$(get_domains_with_retry); then
		echo "No server names found in the nginx configuration."
		return 1
	fi

	# Process the list of server names.
	# Get the last two parts of each domain name.
	# Sort by the first field.
	echo "$domains" | \
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
}

function print_json() {
	local domains

	if ! domains=$(get_domains_with_retry); then
		echo "{}"
		return 1
	fi

	# Process the list of server names and format as JSON [{"name": "example.com", "url": "$PROTOCOL://example.com:$PORT"}]
	echo "$domains" | jq -R -s -c '
		[split("\n")[] | select(length > 0) |
		{
			"name": .,
			"url": "'"$PROTOCOL"'://\(.)'"$PORT"'"
		}] ' 2>/dev/null || {}
}

if [ -n "$HTTPS_PORT" ]; then
	PORT=$(if [ "$HTTPS_PORT" -ne 443 ]; then echo ":$HTTPS_PORT"; else echo ""; fi)
	PROTOCOL="https"
else
	PORT=""
	PROTOCOL="http"
fi

# print the list of server names, if it fails, try again after N seconds (dont output error on first try)
if [ "$1" == "--list" ]; then
	list_domains
	exit 0
fi

if [ "$1" == "--json" ]; then
	print_json
	exit 0
fi

print 2>/dev/null || (sleep $RETRY_INTERVAL && print)
