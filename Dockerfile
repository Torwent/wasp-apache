FROM alpine:latest
LABEL author="Torwent"
ENV server_name=localhost
RUN apk add --no-cache apache2-ssl
RUN apk add --no-cache apache2-proxy
RUN apk add --no-cache apache2-utils
RUN rm -rf /var/www/localhost/cgi-bin/
RUN htpasswd -c -b /etc/apache2/.htpasswd "$USER" "$PASSWORD"
CMD exec /usr/sbin/httpd -D FOREGROUND -f /etc/apache2/httpd.conf