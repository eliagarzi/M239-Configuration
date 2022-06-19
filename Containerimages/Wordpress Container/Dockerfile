FROM php:7.4-apache

WORKDIR /var/www/html

RUN apt-get update

RUN apt-get install curl tar vim -y

RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

#RUN apt-get install ghostscript libapache2-mod-php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y

RUN curl -LO https://wordpress.org/latest.tar.gz

RUN tar xzvf latest.tar.gz

RUN rm latest.tar.gz /etc/apache2/sites-enabled/000-default.conf

COPY wordpress.conf /etc/apache2/sites-enabled/

COPY wp-config.php /var/www/html/wordpress/

RUN chown -R www-data:www-data /var/www/html/wordpress/

RUN chmod -R 755 /var/www/html/wordpress/