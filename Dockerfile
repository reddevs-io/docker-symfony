ARG PHP_VERSION=7.4

FROM php:${PHP_VERSION}-fpm-alpine

# persistent / runtime deps
RUN apk add --no-cache \
  acl \
  fcgi \
  file \
  gettext \
  git \
  ;

ARG APCU_VERSION=5.1.18
RUN set -eux; \
  apk add --no-cache --virtual .build-deps \
  $PHPIZE_DEPS \
  icu-dev \
  libzip-dev \
  postgresql-dev \
  zlib-dev \
  ; \
  \
  docker-php-ext-configure zip; \
  docker-php-ext-install -j$(nproc) \
  intl \
  pdo_pgsql \
  zip \
  ; \
  pecl install \
  apcu-${APCU_VERSION} \
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

RUN ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY docker/php/conf.d/symfony.prod.ini $PHP_INI_DIR/conf.d/symfony.ini

RUN set -eux; \
  { \
  echo '[www]'; \
  echo 'ping.path = /ping'; \
  } | tee /usr/local/etc/php-fpm.d/docker-healthcheck.conf

# Workaround to allow using PHPUnit 8 with Symfony 4.3
ENV SYMFONY_PHPUNIT_VERSION=8.3

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
# install Symfony Flex globally to speed up download of Composer packages (parallelized prefetching)
RUN set -eux; \
  composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
  composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /srv/www

COPY docker/php/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
RUN chmod +x /usr/local/bin/docker-healthcheck

HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["docker-healthcheck"]

CMD ["php-fpm"]