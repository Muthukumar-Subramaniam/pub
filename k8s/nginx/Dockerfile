FROM nginx
RUN mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf_bkp
COPY default.conf /etc/nginx/conf.d/default.conf
RUN mkdir /downloads
