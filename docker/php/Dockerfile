# Multi-stage Dockerfile for Laravel PHP-FPM
# Stage 1: Composer build stage
FROM composer:2.6 AS composer-stage

WORKDIR /app

# Copy composer files
COPY ucilnice/composer.json ucilnice/composer.lock ./

# Install dependencies (no dev dependencies for production)
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader

# Generate optimized autoloader
RUN composer dump-autoload --optimize --classmap-authoritative --no-scripts

# Stage 2: PHP-FPM runtime (minimal Alpine)
FROM php:8.2-fpm-alpine3.18

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    # System dependencies
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    # Build dependencies (will be removed later)
    $PHPIZE_DEPS \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        mbstring \
        intl \
        opcache \
    && apk del $PHPIZE_DEPS

# Install Redis extension
RUN apk add --no-cache pcre-dev $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del pcre-dev $PHPIZE_DEPS

# Configure PHP-FPM
RUN sed -i 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/;clear_env = no/clear_env = no/' /usr/local/etc/php-fpm.d/www.conf

# Configure PHP
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY --chown=appuser:appuser ucilnice/ .

# Copy vendor from composer stage
COPY --from=composer-stage --chown=appuser:appuser /app/vendor ./vendor

# Create necessary directories with proper permissions
RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R appuser:appuser storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php -r "if (file_exists('/var/www/html/storage/logs/laravel.log')) { exit(0); } exit(1);" || exit 1

EXPOSE 9000

CMD ["php-fpm"]

