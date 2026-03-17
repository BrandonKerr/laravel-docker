FROM php:8.4-fpm

# Arguments defined in docker-compose.yml
ARG user
ARG uid

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libexif-dev \
    libicu-dev \
    libxslt-dev \
    sudo \
    nano \
    htop \
    mariadb-client

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd intl

# Install xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Configure xdebug
RUN echo "memory_limit=1G" >> /usr/local/etc/php/conf.d/docker-php-memory.ini
RUN echo "xdebug.mode=off" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
RUN echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create a user with the host UID (but don't rely on it for file ownership)
RUN useradd -u ${uid} -G www-data -m -d /home/${user} -s /bin/bash ${user}

# Make sure www-data group can write
RUN chown -R ${user}:www-data /var/www \
    && chmod -R 775 /var/www

WORKDIR /var/www

# Switch to the user
USER ${user}