FROM alpine:3.20 AS assets

WORKDIR /assets
COPY index.html nginx.conf ./

FROM nginx:1.27-alpine AS runtime

RUN rm -f /etc/nginx/conf.d/default.conf && \
    mkdir -p /tmp/client_temp \
             /tmp/proxy_temp \
             /tmp/fastcgi_temp \
             /tmp/uwsgi_temp \
             /tmp/scgi_temp && \
    chown -R nginx:nginx /tmp /usr/share/nginx/html

COPY --from=assets --chown=nginx:nginx /assets/index.html /usr/share/nginx/html/index.html
COPY --from=assets /assets/nginx.conf /etc/nginx/nginx.conf

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
