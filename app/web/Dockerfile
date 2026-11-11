FROM nginxinc/nginx-unprivileged:1.27-alpine
ENV API_HOST=notes-api
# nginx's entrypoint renders /etc/nginx/templates/*.template with envsubst
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 8080
