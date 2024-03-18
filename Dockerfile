FROM php:8.2.17-fpm-alpine AS builder

# Enviroment variables
ENV COMPOSER_ALLOW_SUPERUSER 1

# Install dependencies
RUN apk update
RUN apk upgrade
RUN apk --no-cache add \
        ${PHPIZE_DEPS} \
        supervisor \
        nano \
        git \
        openssh-client \
        bash \
        curl \
        libxml2 \
        libxml2-dev \
        zlib \
        zlib-dev \
        libpng \
        libpng-dev \
        libjpeg-turbo \
        libjpeg-turbo-dev \
        freetype \
        freetype-dev \
        libzip \
        libzip-dev \
        imagemagick \
        imagemagick-dev \
        mysql-client \
        autoconf \
        g++ \
        make \
        nginx \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo_mysql zip \
    && pecl install imagick \
    && docker-php-ext-enable imagick
RUN apk add --no-cache --update-cache nodejs=20.11.1-r0
RUN curl -L https://unpkg.com/@pnpm/self-installer | node
COPY --from=composer:2.7.2 /usr/bin/composer /usr/bin/composer

# WP CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/_wp
COPY docker/php/wp.sh /srv/wp.sh
RUN chmod +x /srv/wp.sh \
    && mv /srv/wp.sh /usr/bin/wp

# WordPress php.ini config
RUN { \
        echo 'file_uploads = On'; \
        echo 'memory_limit = 256M'; \
        echo 'upload_max_filesize = 64M'; \
        echo 'post_max_size = 64M'; \
        echo 'max_execution_time = 300'; \
        echo 'max_input_time = 300'; \
        echo 'max_input_vars = 3000'; \
        echo 'mysqli.allow_local_infile = On'; \
        echo 'session.save_path = "/tmp"'; \
        echo 'opcache.enable = On'; \
        echo 'opcache.memory_consumption = 128'; \
        echo 'opcache.interned_strings_buffer = 8'; \
        echo 'opcache.max_accelerated_files = 4000'; \
        echo 'opcache.validate_timestamps = 1'; \
        echo 'opcache.save_comments = 1'; \
        echo 'opcache.fast_shutdown = 1'; \
    } > /usr/local/etc/php/conf.d/wordpress-recommended.ini

WORKDIR /var/www/ibfatosvintenove

COPY --chown=www-data:www-data src/ .

# PHP FPM config
COPY docker/php/conf/php-fpm.conf /usr/local/etc/php-fpm.d/zzz_custom.conf

# Nginx config
COPY docker/nginx/conf/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/conf/default.conf /etc/nginx/conf.d/default.conf

# Https
COPY docker/nginx/certs /etc/nginx/certs

# Supervisor config
COPY docker/php/conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /var/www/ibfatosvintenove

EXPOSE 80 443

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]