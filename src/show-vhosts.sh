#!/usr/bin/env bash
set -e

RETRY_INTERVAL=2
RETRY_MAX=3

# Function to list domains from nginx config
# Output: space-separated list of domain names
_list_domains_internal() {
    local attempt=0
    local domains=""
    while [ $attempt -le $RETRY_MAX ]; do
        domains=$(nginx -T 2>/dev/null | sed -nr 's/^\s*server_name\s+([^;]+);.*/\1/p' | grep -v '^\s*_\s*$' | xargs -n1 | sort -u | xargs)

        if [ -n "${domains// }" ]; then
            echo "$domains"
            return 0
        fi

        if [ $attempt -lt $RETRY_MAX ]; then
            sleep $RETRY_INTERVAL
        else
            return 1
        fi
        attempt=$((attempt + 1))
    done
}


_generate_html_content() {
    local domains_str=$1
    local http_port_env="${HTTP_PORT:-80}"
    local https_port_env="${HTTPS_PORT}"

    local vhost_html_list=""

    if [ -z "$domains_str" ]; then
        vhost_html_list="<p class=\"no-vhosts\">No virtual hosts are currently configured.</p>"
    else
        vhost_html_list="<ul id=\"vhost-list\">"
        for domain in $domains_str; do
            local current_protocol="http"
            local current_port_str=""

            if [ -n "$https_port_env" ]; then
                current_protocol="https"
                if [ "$https_port_env" != "443" ]; then
                    current_port_str=":$https_port_env"
                fi
            else
                if [ "$http_port_env" != "80" ]; then
                    current_port_str=":$http_port_env"
                fi
            fi

            local link_domain="$domain"
            if [[ "$domain" == "*."* ]]; then
                link_domain="${domain#*.}"
            fi

            vhost_html_list="${vhost_html_list}<li><a href=\"${current_protocol}://${link_domain}${current_port_str}\" target=\"_blank\">${domain}</a></li>"
        done
        vhost_html_list="${vhost_html_list}</ul>"
    fi
    echo "$vhost_html_list"
}

_generate_html_page() {
    local template_file=$1
    local output_file=$2
    local domains_str=$(_list_domains_internal)

    local html_content=$(_generate_html_content "$domains_str")

    if [ ! -f "$template_file" ]; then
        echo "Error: Template file '$template_file' not found." >&2
        cat <<EOF > "$output_file"
<!DOCTYPE html>
<html lang="en">
<head><title>Available Services</title>
<style>body{font-family:sans-serif;padding:20px;}ul{list-style:none;padding-left:0;}li{margin-bottom:5px;}a{text-decoration:none;color:#007bff;}.no-vhosts{font-style:italic;color:#777;}</style>
</head>
<body><h1>Available Services</h1>${html_content}<footer>Nginx Proxy</footer></body></html>
EOF
    else
        awk -v marker="<!--VHOST_LIST_MARKER-->" -v content="$html_content" '
        BEGIN { found=0 }
        {
            if (sub(marker, content)) {
                found=1
            }
            print
        }
        END { if (!found) { print content } }
        ' "$template_file" > "$output_file"
    fi
}

_print_console() {
    local domains_str=$(_list_domains_internal)

    if [ -z "$domains_str" ]; then
        echo "No server names found in the nginx configuration."
        return 1
    fi

    local current_http_port_env="${HTTP_PORT:-80}"
    local current_https_port_env="${HTTPS_PORT}"

    local output_protocol="http"
    local output_port_str=""

    if [ -n "$current_https_port_env" ]; then
        output_protocol="https"
        if [ "$current_https_port_env" != "443" ]; then
            output_port_str=":$current_https_port_env"
        fi
    else
        if [ "$current_http_port_env" != "80" ]; then
            output_port_str=":$current_http_port_env"
        fi
    fi

    echo "$domains_str" | xargs -n1 | awk -F'.' '{
        if (NF >= 2) { print $(NF-1) "." $NF "\t" $0 }
        else { print $1 "\t" $0 }
    }' | sort -k1,1 | awk -v GREEN="[1;32m" -v NC="[0m" -v PROTOCOL="$output_protocol" -v PORT_STR="$output_port_str" -F'\t' 'BEGIN {
        CURRENT_GROUP=""
        SERVICE_COUNT=1
    }
    {
        if(CURRENT_GROUP != $1){
            if(CURRENT_GROUP != "") printf "\n";
            printf "%s%s%s\n", GREEN, $1, NC;
            CURRENT_GROUP=$1;
            SERVICE_COUNT=1;
        }

        display_name = $2
        link_host = $2
        if ( substr($2, 1, 2) == "*." ) {
            link_host = substr($2, 3)
        }
        # Inlined format_link logic:
        printf("	%d. %s (%s://%s%s)\n", SERVICE_COUNT++, display_name, PROTOCOL, link_host, PORT_STR);
    } END { if(CURRENT_GROUP != "") print ""; }'
}

# Main script logic
if [ "$1" == "--html" ]; then
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: $0 --html <template_file_path> <output_file_path>" >&2
        exit 1
    fi
    _generate_html_page "$2" "$3"
elif [ "$1" == "--list" ]; then
    _list_domains_internal || echo "No domains found"
    exit 0
else
    if ! _print_console; then
        sleep $RETRY_INTERVAL
        _print_console
    fi
fi
