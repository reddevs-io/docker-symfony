FROM php:7.4-fpm-alpine

# persistent / runtime deps
RUN apk add --no-cache \
  acl \
  fcgi \
  file \
  gettext \
  ;

RUN set -eux; \
  apk add --no-cache --virtual .build-deps \
  $PHPIZE_DEPS \
  icu-dev \
  libzip-dev \
  zlib-dev \
  ; \
  \
  docker-php-ext-configure zip; \
  docker-php-ext-install -j$(nproc) \
  intl \
  zip \
  pdo_mysql \
  ; \
  pecl install \
  apcu-5.1.18 \
  ; \
  pecl clear-cache; \
  docker-php-ext-enable \
  apcu \
  opcache \
  ; \
  \
  runDeps="$( \
  scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
  | tr ',' '\n' \
  | sort -u \
  | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )"; \
  apk add --no-cache --virtual .api-phpexts-rundeps $runDeps; \
  \
  apk del .build-deps

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
# install Symfony Flex globally to speed up download of Composer packages (parallelized prefetching)
RUN set -eux; \
  composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
  composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

COPY .docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN deluser www-data && adduser -DH -h /home/www-data -s /sbin/nologin -u 1000 www-data

USER www-data

CMD ["php-fpm"]
