FROM nginxproxy/nginx-proxy:1.2.2
LABEL version="1.2.1"

COPY ./src/dev_proxy.conf /etc/nginx/conf.d/dev_proxy.conf

COPY ./src/auto-cert.sh /app/
COPY ./src/notify-listener.sh /app/
COPY ./src/Procfile /app/
COPY ./src/nginx.tmpl /app/
COPY ./src/show-vhosts.sh /app/

RUN chmod +x /app/auto-cert.sh
RUN chmod +x /app/notify-listener.sh

# Find 'exec "$@"' in the original entrypoint.sh and prepend it with
RUN sed -Ei 's/^(exec "\$@")$/if [ -n "\$AUTOCERT" ]; then\n  .\/auto-cert.sh;\nfi\n\1/g' /app/docker-entrypoint.sh
RUN sed -Ei 's/(\(coalesce\s)(\$certName)(\s\$vhostCert\))/\1\$globals.Env.AUTOCERT \2\3/gm' /app/nginx.tmpl
