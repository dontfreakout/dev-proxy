FROM nginxproxy/nginx-proxy:1.2.2
LABEL version="1.2.11"

RUN apt-get update && apt-get install -y \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY ./src/dev_proxy.conf /etc/nginx/conf.d/dev_proxy.conf

# New files for dynamic vhost page

COPY ./src/html /app/html

RUN mkdir -p /etc/nginx/certs && \
    ln -s /etc/nginx/certs /app/html/certs

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

# Find 'exec "$@"' in the original entrypoint.sh and prepend it with
RUN sed -Ei 's/^(exec "\$@")$/if [ -n "\$AUTOCERT" ]; then\n  .\/auto-cert.sh;\nfi\n\1/g' /app/docker-entrypoint.sh
RUN sed -Ei 's/(\(coalesce\s)(\$certName)(\s\$vhostCert\))/\1\$globals.Env.AUTOCERT \2\3/gm' /app/nginx.tmpl
