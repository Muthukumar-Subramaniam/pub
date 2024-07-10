FROM httpd
RUN mv /usr/local/apache2/conf/httpd.conf /usr/local/apache2/conf/httpd.conf_bkp_orig
COPY httpd.conf /usr/local/apache2/conf/httpd.conf
RUN chmod 644 /usr/local/apache2/conf/httpd.conf
RUN mkdir /downloads
