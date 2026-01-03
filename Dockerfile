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

# Create system user
RUN useradd -G www-data,root -u $uid -d /home/$user $user \
    && mkdir -p /home/$user/.composer \
    && chown -R $user:$user /home/$user

# Allow user to run sudo without password (for Laravel setup only)
RUN echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$user \
    && chmod 0440 /etc/sudoers.d/$user

# Set correct ownership for /var/www (but don't create Laravel directories)
RUN mkdir -p /var/www \
    && chown -R $user:www-data /var/www \
    && chmod 755 /var/www

# Set working directory
WORKDIR /var/www

# Set the user
USER $user
