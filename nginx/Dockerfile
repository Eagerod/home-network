FROM ncfgbase

RUN \
    apt-get update -y && \
    apt-get install -y nginx

COPY reverse-proxy.conf /etc/nginx/sites-available/reverse-proxy.conf
RUN ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/reverse-proxy.conf

CMD ["nginx", "-g", "daemon off;"]
