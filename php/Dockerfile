FROM php:7.4-fpm

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libsodium-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        libzip-dev \
        apt-utils \
        zip \
        unzip \
        wget \
        curl \
        ed \
    && docker-php-ext-configure \
        gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo_mysql \
        mysqli \
        sodium \
        zip

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

RUN curl -o /root/.composer/keys.dev.pub https://composer.github.io/snapshots.pub

RUN curl -o /root/.composer/keys.tags.pub https://composer.github.io/releases.pub

RUN apt-get autoremove -y