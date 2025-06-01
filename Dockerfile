FROM nginxproxy/nginx-proxy:1.2.2
LABEL version="1.2.2"

COPY ./src/dev_proxy.conf /etc/nginx/conf.d/dev_proxy.conf

# New files for dynamic vhost page
COPY ./src/vhost_list_template.html /app/vhost_list_template.html
COPY ./src/initial_loading_page.html /app/initial_loading_page.html
COPY ./src/error_display_page.html /app/error_display_page.html
COPY ./src/regenerate_vhosts_and_reload_nginx.sh /app/regenerate_vhosts_and_reload_nginx.sh

# Original file copies
COPY ./src/auto-cert.sh /app/
COPY ./src/notify-listener.sh /app/
COPY ./src/Procfile /app/
COPY ./src/nginx.tmpl /app/
COPY ./src/show-vhosts.sh /app/

# Permissions
RUN chmod +x /app/auto-cert.sh
RUN chmod +x /app/notify-listener.sh
RUN chmod +x /app/show-vhosts.sh
RUN chmod +x /app/regenerate_vhosts_and_reload_nginx.sh

# Find 'exec "$@"' in the original entrypoint.sh and prepend it with
RUN sed -Ei 's/^(exec "\$@")$/if [ -n "\$AUTOCERT" ]; then\n  .\/auto-cert.sh;\nfi\n\1/g' /app/docker-entrypoint.sh
RUN sed -Ei 's/(\(coalesce\s)(\$certName)(\s\$vhostCert\))/\1\$globals.Env.AUTOCERT \2\3/gm' /app/nginx.tmpl
