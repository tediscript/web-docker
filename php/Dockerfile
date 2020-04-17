FROM php:7.4-fpm

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo_mysql mysqli

RUN apt-get install -y \
        apt-utils \
        libssl-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        zip \
        unzip \
        wget \
        curl \
        ed

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

RUN apt-get autoremove -y