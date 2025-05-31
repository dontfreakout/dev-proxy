#!/bin/sh
# This script is called by docker-gen when the Nginx configuration has been regenerated.
# It first generates the dynamic vhost HTML page and then reloads Nginx.

set -e

TEMPLATE_FILE="/app/vhost_list_template.html"
OUTPUT_HTML_FILE="/app/current_vhosts.html"
SHOW_VHOSTS_SCRIPT="/app/show-vhosts.sh"

# Generate the dynamic vhost page
# Check if the template file exists, otherwise show-vhosts.sh will use its internal basic fallback
if [ -f "$TEMPLATE_FILE" ]; then
    "$SHOW_VHOSTS_SCRIPT" --html "$TEMPLATE_FILE" "$OUTPUT_HTML_FILE"
else
    # If template is missing, we can still call show-vhosts.sh;
    # it has a fallback to create a basic HTML page.
    # Or, we could choose to create a very minimal file here or log an error.
    # For now, relying on show-vhosts.sh's internal fallback.
    "$SHOW_VHOSTS_SCRIPT" --html "$TEMPLATE_FILE" "$OUTPUT_HTML_FILE" # It will log template not found to stderr
fi

# Reload Nginx to apply the main configuration changes
# (and make sure it picks up any new static files if relevant, though current_vhosts.html is already known)
nginx -s reload

exit 0
