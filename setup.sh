#!/usr/bin/env bash
set -euo pipefail

if [[ ! -t 0 ]]; then
    echo "ERROR: This script requires an interactive terminal."
    echo "Run it directly: ./setup.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/docker/compose"
DEFAULT_NAME="$(basename "$SCRIPT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
USE_WHIPTAIL=false
if command -v whiptail &>/dev/null; then
    USE_WHIPTAIL=true
fi

if [[ "$USE_WHIPTAIL" == true ]]; then
    ###########################################################################
    # Whiptail TUI prompts
    ###########################################################################
    WT_TITLE="Laravel Docker Setup"

    # Project name
    PROJECT_NAME=""
    while true; do
        PROJECT_NAME=$(whiptail --inputbox "Project name (lowercase, underscores, hyphens only):" 10 60 "$DEFAULT_NAME" --title "$WT_TITLE" 3>&1 1>&2 2>&3) || exit 0
        [[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] && break
        whiptail --msgbox "Invalid name. Use lowercase letters, numbers, underscores, and hyphens (must start with a letter)." 10 60 --title "$WT_TITLE"
    done

    # Custom URL
    CUSTOM_URL=$(whiptail --inputbox "Custom URL (leave blank for localhost:8000):" 10 60 "" --title "$WT_TITLE" 3>&1 1>&2 2>&3) || exit 0

    # Database
    DB_CHOICE=$(whiptail --menu "Select a database:" 12 60 3 \
        "MariaDB"    "" \
        "PostgreSQL" "" \
        "SQLite"     "" \
        --title "$WT_TITLE" 3>&1 1>&2 2>&3) || exit 0

    # Starter kit
    KIT_CHOICE=$(whiptail --menu "Select a starter kit:" 13 60 4 \
        "None"     "Bare Laravel installation" \
        "React"    "React with Inertia" \
        "Vue"      "Vue with Inertia" \
        "Livewire" "Livewire with Volt" \
        --title "$WT_TITLE" 3>&1 1>&2 2>&3) || exit 0

    # Bun/Vite
    if [[ "$KIT_CHOICE" != "None" ]]; then
        BUN_CHOICE="Yes"
    else
        if whiptail --yesno "Include Bun/Vite for frontend asset bundling?" 8 60 --title "$WT_TITLE"; then
            BUN_CHOICE="Yes"
        else
            BUN_CHOICE="No"
        fi
    fi

    # Redis
    if whiptail --yesno "Include Redis for caching, sessions, and queues?" 8 60 --title "$WT_TITLE"; then
        REDIS_CHOICE="Yes"
    else
        REDIS_CHOICE="No"
    fi

    # Horizon
    if [[ "$REDIS_CHOICE" == "Yes" ]]; then
        if whiptail --yesno "Include Laravel Horizon for queue monitoring?" 8 60 --title "$WT_TITLE"; then
            HORIZON_CHOICE="Yes"
        else
            HORIZON_CHOICE="No"
        fi
    else
        HORIZON_CHOICE="No"
    fi

    # Reverb
    if whiptail --yesno "Include Laravel Reverb for WebSockets?" 8 60 --title "$WT_TITLE"; then
        REVERB_CHOICE="Yes"
    else
        REVERB_CHOICE="No"
    fi

    # Mailpit
    if whiptail --yesno "Include Mailpit for local email testing?" 8 60 --title "$WT_TITLE"; then
        MAILPIT_CHOICE="Yes"
    else
        MAILPIT_CHOICE="No"
    fi

    # Build summary text
    if [[ -n "$CUSTOM_URL" ]]; then
        SUMMARY_URL="https://$CUSTOM_URL"
    else
        SUMMARY_URL="http://localhost:8000"
    fi
    SUMMARY="Project name: $PROJECT_NAME
URL:          $SUMMARY_URL
Database:     $DB_CHOICE
Starter kit:  $KIT_CHOICE
Bun/Vite:     $BUN_CHOICE
Redis:        $REDIS_CHOICE
Horizon:      $HORIZON_CHOICE
Reverb:       $REVERB_CHOICE
Mailpit:      $MAILPIT_CHOICE"

    if ! whiptail --yesno "$SUMMARY\n\nProceed with setup?" 16 60 --title "Setup Summary"; then
        echo "Aborted."
        exit 0
    fi

else
    ###########################################################################
    # Fallback shell prompts
    ###########################################################################

    # Project name
    while true; do
        read -rp "Project name (lowercase, underscores, hyphens only) [$DEFAULT_NAME]: " PROJECT_NAME
        PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_NAME}"
        if [[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            break
        fi
        echo "Invalid name. Use lowercase letters, numbers, underscores, and hyphens (must start with a letter)."
    done

    # Custom URL
    echo ""
    read -rp "Custom URL (leave blank for localhost:8000): " CUSTOM_URL

    # Database
    echo ""
    echo "Select a database:"
    select DB_CHOICE in "MariaDB" "PostgreSQL" "SQLite"; do
        case $DB_CHOICE in
            MariaDB|PostgreSQL|SQLite) break ;;
            *) echo "Invalid selection." ;;
        esac
    done

    # Starter kit
    echo ""
    echo "Select a starter kit:"
    select KIT_CHOICE in "None" "React" "Vue" "Livewire"; do
        case $KIT_CHOICE in
            None|React|Vue|Livewire) break ;;
            *) echo "Invalid selection." ;;
        esac
    done

    # Bun/Vite
    if [[ "$KIT_CHOICE" != "None" ]]; then
        BUN_CHOICE="Yes"
    else
        echo ""
        echo "Include Bun/Vite for frontend asset bundling?"
        select BUN_CHOICE in "Yes" "No"; do
            case $BUN_CHOICE in
                Yes|No) break ;;
                *) echo "Invalid selection." ;;
            esac
        done
    fi

    # Redis
    echo ""
    echo "Include Redis for caching, sessions, and queues?"
    select REDIS_CHOICE in "Yes" "No"; do
        case $REDIS_CHOICE in
            Yes|No) break ;;
            *) echo "Invalid selection." ;;
        esac
    done

    # Horizon
    if [[ "$REDIS_CHOICE" == "Yes" ]]; then
        echo ""
        echo "Include Laravel Horizon for queue monitoring?"
        select HORIZON_CHOICE in "Yes" "No"; do
            case $HORIZON_CHOICE in
                Yes|No) break ;;
                *) echo "Invalid selection." ;;
            esac
        done
    else
        HORIZON_CHOICE="No"
    fi

    # Reverb
    echo ""
    echo "Include Laravel Reverb for WebSockets?"
    select REVERB_CHOICE in "Yes" "No"; do
        case $REVERB_CHOICE in
            Yes|No) break ;;
            *) echo "Invalid selection." ;;
        esac
    done

    # Mailpit
    echo ""
    echo "Include Mailpit for local email testing?"
    select MAILPIT_CHOICE in "Yes" "No"; do
        case $MAILPIT_CHOICE in
            Yes|No) break ;;
            *) echo "Invalid selection." ;;
        esac
    done

    # Confirm
    echo ""
    echo "=== Setup Summary ==="
    echo "Project name: $PROJECT_NAME"
    if [[ -n "$CUSTOM_URL" ]]; then
        echo "URL:          https://$CUSTOM_URL"
    else
        echo "URL:          http://localhost:8000"
    fi
    echo "Database:     $DB_CHOICE"
    echo "Starter kit:  $KIT_CHOICE"
    echo "Bun/Vite:     $BUN_CHOICE"
    echo "Redis:        $REDIS_CHOICE"
    echo "Horizon:      $HORIZON_CHOICE"
    echo "Reverb:       $REVERB_CHOICE"
    echo "Mailpit:      $MAILPIT_CHOICE"
    echo "====================="
    echo ""
    read -rp "Proceed? (Y/n) " CONFIRM
    if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

###############################################################################
# Sanitize and validate custom URL
###############################################################################
CUSTOM_URL="${CUSTOM_URL#http://}"
CUSTOM_URL="${CUSTOM_URL#https://}"
CUSTOM_URL="${CUSTOM_URL%/}"
if [[ -n "$CUSTOM_URL" && ! "$CUSTOM_URL" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
    echo "Invalid URL. Use a hostname like 'myapp.test' (letters, numbers, dots, hyphens only)."
    exit 1
fi

###############################################################################
# Assemble docker-compose.yml
###############################################################################
echo ""
echo "Assembling docker-compose.yml..."

# Start with base (php + nginx)
cp "$COMPOSE_DIR/base.yml" "$SCRIPT_DIR/docker-compose.yml"

# Add db depends_on to php service (or remove placeholder)
if [[ "$DB_CHOICE" != "SQLite" ]]; then
    sed -i 's/^__DB_DEPENDS__/    depends_on:\n      - db/' "$SCRIPT_DIR/docker-compose.yml"
else
    sed -i '/^__DB_DEPENDS__$/d' "$SCRIPT_DIR/docker-compose.yml"
fi

# Configure nginx ports, SSL volume, and healthcheck
if [[ -n "$CUSTOM_URL" ]]; then
    sed -i 's/^__NGINX_PORTS__/      - "80:80"\n      - "443:443"/' "$SCRIPT_DIR/docker-compose.yml"
    sed -i 's~^__NGINX_SSL_VOLUME__~      - ./docker/nginx/ssl:/etc/nginx/ssl:ro~' "$SCRIPT_DIR/docker-compose.yml"
    sed -i 's~^__NGINX_HEALTHCHECK__~      test: ["CMD-SHELL", "curl -fk https://localhost/ || exit 1"]~' "$SCRIPT_DIR/docker-compose.yml"
else
    sed -i 's/^__NGINX_PORTS__/      - "8000:80"/' "$SCRIPT_DIR/docker-compose.yml"
    sed -i '/^__NGINX_SSL_VOLUME__$/d' "$SCRIPT_DIR/docker-compose.yml"
    sed -i 's~^__NGINX_HEALTHCHECK__~      test: ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]~' "$SCRIPT_DIR/docker-compose.yml"
fi

# Append database fragment
if [[ "$DB_CHOICE" == "MariaDB" ]]; then
    cat "$COMPOSE_DIR/mariadb.yml" >> "$SCRIPT_DIR/docker-compose.yml"
elif [[ "$DB_CHOICE" == "PostgreSQL" ]]; then
    cat "$COMPOSE_DIR/postgres.yml" >> "$SCRIPT_DIR/docker-compose.yml"
fi

# Append redis fragment
if [[ "$REDIS_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/redis.yml" >> "$SCRIPT_DIR/docker-compose.yml"
fi

# Append horizon or standalone worker fragment
if [[ "$HORIZON_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/horizon.yml" >> "$SCRIPT_DIR/docker-compose.yml"
elif [[ "$REDIS_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/worker.yml" >> "$SCRIPT_DIR/docker-compose.yml"
fi

# Append reverb fragment
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/reverb.yml" >> "$SCRIPT_DIR/docker-compose.yml"
fi

# Append mailpit fragment
if [[ "$MAILPIT_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/mailpit.yml" >> "$SCRIPT_DIR/docker-compose.yml"
fi

# Append bun fragment
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/bun.yml" >> "$SCRIPT_DIR/docker-compose.yml"
fi

# Append networks
cat >> "$SCRIPT_DIR/docker-compose.yml" <<EOF

networks:
  __PROJECT_NAME__:
    driver: bridge
EOF

# Append volumes (only if needed)
VOLUMES=()
if [[ "$DB_CHOICE" == "MariaDB" ]]; then
    VOLUMES+=("mysql_data")
elif [[ "$DB_CHOICE" == "PostgreSQL" ]]; then
    VOLUMES+=("pg_data")
fi
if [[ "$REDIS_CHOICE" == "Yes" ]]; then
    VOLUMES+=("redis_data")
fi
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    VOLUMES+=("node_modules")
fi

if [[ ${#VOLUMES[@]} -gt 0 ]]; then
    echo "" >> "$SCRIPT_DIR/docker-compose.yml"
    echo "volumes:" >> "$SCRIPT_DIR/docker-compose.yml"
    for vol in "${VOLUMES[@]}"; do
        echo "  ${vol}:" >> "$SCRIPT_DIR/docker-compose.yml"
    done
fi

# Replace project name placeholder throughout docker-compose.yml
sed -i "s/__PROJECT_NAME__/${PROJECT_NAME}/g" "$SCRIPT_DIR/docker-compose.yml"

###############################################################################
# Generate minimal .env for docker-compose build (DB credentials for compose)
###############################################################################
echo "Generating .env..."
cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
if [[ "$DB_CHOICE" != "SQLite" ]]; then
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$SCRIPT_DIR/.env"
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=laravel/" "$SCRIPT_DIR/.env"
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=secret/" "$SCRIPT_DIR/.env"
fi

###############################################################################
# Modify Dockerfile based on database choice
###############################################################################
echo "Configuring Dockerfile for $DB_CHOICE..."
case $DB_CHOICE in
    MariaDB)
        # Already configured for MariaDB by default — no changes needed
        ;;
    PostgreSQL)
        sed -i 's/mariadb-client/postgresql-client \\\n    libpq-dev/' "$SCRIPT_DIR/Dockerfile"
        sed -i 's/pdo_mysql/pdo_pgsql/' "$SCRIPT_DIR/Dockerfile"
        ;;
    SQLite)
        sed -i 's/mariadb-client/libsqlite3-dev/' "$SCRIPT_DIR/Dockerfile"
        sed -i 's/pdo_mysql/pdo_sqlite/' "$SCRIPT_DIR/Dockerfile"
        ;;
esac

###############################################################################
# Install phpredis extension in Dockerfile
###############################################################################
if [[ "$REDIS_CHOICE" == "Yes" ]]; then
    echo "Adding phpredis extension to Dockerfile..."
    sed -i '/pecl install xdebug/a RUN pecl install redis && docker-php-ext-enable redis' "$SCRIPT_DIR/Dockerfile"
fi

###############################################################################
# Configure SSL and nginx for custom URL
###############################################################################
if [[ -n "$CUSTOM_URL" ]]; then
    echo "Generating SSL certificate for $CUSTOM_URL..."
    mkdir -p "$SCRIPT_DIR/docker/nginx/ssl"

    USED_MKCERT=false
    if command -v mkcert &>/dev/null; then
        # Ensure mkcert CA is installed
        if [[ ! -f "$(mkcert -CAROOT)/rootCA.pem" ]]; then
            echo "Installing mkcert local CA..."
            mkcert -install
        fi
        mkcert -cert-file "$SCRIPT_DIR/docker/nginx/ssl/cert.pem" \
               -key-file "$SCRIPT_DIR/docker/nginx/ssl/key.pem" \
               "$CUSTOM_URL"
        USED_MKCERT=true
    else
        echo "mkcert not found, generating self-signed certificate with openssl..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SCRIPT_DIR/docker/nginx/ssl/key.pem" \
            -out "$SCRIPT_DIR/docker/nginx/ssl/cert.pem" \
            -subj "/CN=$CUSTOM_URL"
    fi

    # Verify cert was created
    if [[ ! -s "$SCRIPT_DIR/docker/nginx/ssl/cert.pem" || ! -s "$SCRIPT_DIR/docker/nginx/ssl/key.pem" ]]; then
        echo "ERROR: SSL certificate generation failed for $CUSTOM_URL"
        exit 1
    fi

    # Replace HTTP nginx config with HTTPS config
    cp "$SCRIPT_DIR/docker/nginx/nginx-ssl.conf" "$SCRIPT_DIR/docker/nginx/nginx.conf"
    sed -i "s/__SERVER_NAME__/${CUSTOM_URL}/g" "$SCRIPT_DIR/docker/nginx/nginx.conf"
fi

# Remove SSL template so nginx doesn't load it as a second config
rm -f "$SCRIPT_DIR/docker/nginx/nginx-ssl.conf"

###############################################################################
# Build and start containers
###############################################################################
echo "Building and starting containers..."
cd "$SCRIPT_DIR"
docker-compose build

# Start only the core containers first (others need Laravel installed)
CORE_SERVICES="php nginx"
if [[ "$DB_CHOICE" != "SQLite" ]]; then CORE_SERVICES+=" db"; fi
if [[ "$REDIS_CHOICE" == "Yes" ]]; then CORE_SERVICES+=" redis"; fi
if [[ "$MAILPIT_CHOICE" == "Yes" ]]; then CORE_SERVICES+=" mailpit"; fi
docker-compose up -d --wait $CORE_SERVICES

###############################################################################
# Determine composer package based on starter kit
###############################################################################
case $KIT_CHOICE in
    React)     COMPOSER_PACKAGE="laravel/react-starter-kit" ;;
    Vue)       COMPOSER_PACKAGE="laravel/vue-starter-kit" ;;
    Livewire)  COMPOSER_PACKAGE="laravel/livewire-starter-kit" ;;
    *)         COMPOSER_PACKAGE="laravel/laravel" ;;
esac

###############################################################################
# Install Laravel
###############################################################################
echo "Installing Laravel..."

# Remove scaffold files that should be replaced by Laravel's versions
rm -f "$SCRIPT_DIR/.gitignore" "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env" "$SCRIPT_DIR/composer.json" "$SCRIPT_DIR/README.md"

docker-compose exec php composer create-project --prefer-dist "$COMPOSER_PACKAGE" /tmp/laravel
docker-compose exec php cp -r /tmp/laravel/. /var/www/
docker-compose exec php php artisan key:generate
docker-compose exec php php artisan storage:link
docker-compose exec php composer require brianium/paratest --dev

###############################################################################
# Configure .env (after Laravel install so it's not overwritten)
###############################################################################
echo "Configuring .env..."

case $DB_CHOICE in
    MariaDB)
        sed -i "s/^#\? *DB_CONNECTION=.*/DB_CONNECTION=mysql/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_HOST=.*/DB_HOST=db/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_PORT=.*/DB_PORT=3306/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_USERNAME=.*/DB_USERNAME=laravel/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_PASSWORD=.*/DB_PASSWORD=secret/" "$SCRIPT_DIR/.env"
        ;;
    PostgreSQL)
        sed -i "s/^#\? *DB_CONNECTION=.*/DB_CONNECTION=pgsql/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_HOST=.*/DB_HOST=db/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_PORT=.*/DB_PORT=5432/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_USERNAME=.*/DB_USERNAME=laravel/" "$SCRIPT_DIR/.env"
        sed -i "s/^#\? *DB_PASSWORD=.*/DB_PASSWORD=secret/" "$SCRIPT_DIR/.env"
        ;;
    SQLite)
        # Laravel 12 defaults to SQLite — no changes needed
        ;;
esac

# APP_URL
if [[ -n "$CUSTOM_URL" ]]; then
    sed -i "s|^APP_URL=.*|APP_URL=https://${CUSTOM_URL}|" "$SCRIPT_DIR/.env"
else
    sed -i "s|^APP_URL=.*|APP_URL=http://localhost:8000|" "$SCRIPT_DIR/.env"
fi

# Redis
if [[ "$REDIS_CHOICE" == "Yes" ]]; then
    sed -i "s/^#\? *REDIS_HOST=.*/REDIS_HOST=redis/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *CACHE_STORE=.*/CACHE_STORE=redis/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *SESSION_DRIVER=.*/SESSION_DRIVER=redis/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" "$SCRIPT_DIR/.env"
fi

# Reverb
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    sed -i "s/^#\? *BROADCAST_CONNECTION=.*/BROADCAST_CONNECTION=reverb/" "$SCRIPT_DIR/.env"
    cat >> "$SCRIPT_DIR/.env" <<'REVERB_ENV'

REVERB_APP_ID=my-app-id
REVERB_APP_KEY=my-app-key
REVERB_APP_SECRET=my-app-secret
REVERB_HOST=reverb
REVERB_PORT=8080
REVERB_SCHEME=http

VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
VITE_REVERB_HOST="__REVERB_VITE_HOST__"
VITE_REVERB_PORT="${REVERB_PORT}"
VITE_REVERB_SCHEME="${REVERB_SCHEME}"
REVERB_ENV
    REVERB_VITE_HOST="${CUSTOM_URL:-localhost}"
    sed -i "s/__REVERB_VITE_HOST__/${REVERB_VITE_HOST}/" "$SCRIPT_DIR/.env"
fi

# Mailpit
if [[ "$MAILPIT_CHOICE" == "Yes" ]]; then
    sed -i "s/^#\? *MAIL_MAILER=.*/MAIL_MAILER=smtp/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *MAIL_HOST=.*/MAIL_HOST=mailpit/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *MAIL_PORT=.*/MAIL_PORT=1025/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *MAIL_USERNAME=.*/MAIL_USERNAME=null/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *MAIL_PASSWORD=.*/MAIL_PASSWORD=null/" "$SCRIPT_DIR/.env"
    sed -i "s/^#\? *MAIL_ENCRYPTION=.*/MAIL_ENCRYPTION=null/" "$SCRIPT_DIR/.env"
fi

###############################################################################
# Database-specific post-install
###############################################################################
if [[ "$DB_CHOICE" == "SQLite" ]]; then
    echo "Setting up SQLite database..."
    docker-compose exec php touch /var/www/database/database.sqlite
fi

###############################################################################
# Run migrations
###############################################################################
echo "Running migrations..."
docker-compose exec php php artisan migrate

###############################################################################
# Horizon post-install
###############################################################################
if [[ "$HORIZON_CHOICE" == "Yes" ]]; then
    echo "Installing Laravel Horizon..."
    docker-compose exec php composer require laravel/horizon
    docker-compose exec php php artisan horizon:install
fi

###############################################################################
# Reverb post-install
###############################################################################
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    echo "Installing Laravel Reverb..."
    docker-compose exec php composer require laravel/reverb
    docker-compose exec php php artisan vendor:publish --provider="Laravel\Reverb\ReverbServiceProvider" --tag=reverb-config
    docker-compose exec php php artisan vendor:publish --tag=broadcasting
fi

# Run any migrations published by Horizon/Reverb
if [[ "$HORIZON_CHOICE" == "Yes" || "$REVERB_CHOICE" == "Yes" ]]; then
    echo "Running additional migrations..."
    docker-compose exec php php artisan migrate
fi

###############################################################################
# Start remaining containers (now that Laravel + packages are installed)
###############################################################################
docker-compose up -d

###############################################################################
# Bun/Vite post-install
###############################################################################
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Configuring Vite for Docker..."
    HMR_HOST="${CUSTOM_URL:-localhost}"
    # Starter kits ship vite.config.ts, base Laravel ships vite.config.js
    if [[ -f "$SCRIPT_DIR/vite.config.ts" ]]; then
        VITE_CONFIG="vite.config.ts"
    else
        VITE_CONFIG="vite.config.js"
    fi
    VITE_PATH="$SCRIPT_DIR/$VITE_CONFIG"
    if grep -q 'host: "0.0.0.0"' "$VITE_PATH"; then
        # Already patched — skip
        :
    elif grep -q 'server:' "$VITE_PATH"; then
        # Patch existing server block
        sed -i "s/server: {/server: {\n        host: \"0.0.0.0\",\n        hmr: {\n            host: \"${HMR_HOST}\",\n        },/" "$VITE_PATH"
    else
        # No server block — add one before the closing });
        sed -i "/^});/i\    server: {\n        host: \"0.0.0.0\",\n        hmr: {\n            host: \"${HMR_HOST}\",\n        },\n    }," "$VITE_PATH"
    fi
    if ! docker-compose restart bun; then
        echo "WARNING: Bun container failed to restart. You can retry with: docker-compose restart bun"
    fi
fi

###############################################################################
# Generate project README
###############################################################################
echo "Generating README..."

if [[ -n "$CUSTOM_URL" ]]; then
    APP_DISPLAY_URL="https://$CUSTOM_URL"
    NGINX_PORT="80, 443"
else
    APP_DISPLAY_URL="http://localhost:8000"
    NGINX_PORT="8000"
fi

cat > "$SCRIPT_DIR/README.md" <<README_EOF
# ${PROJECT_NAME}

## Getting Started

Start the containers:
\`\`\`bash
make up
\`\`\`

The app will be available at ${APP_DISPLAY_URL}

## Services

| Service | Description | Port |
|---------|-------------|------|
| **php** | PHP 8.4-FPM application container | — |
| **nginx** | Reverse proxy | ${NGINX_PORT} |
README_EOF

if [[ "$DB_CHOICE" == "MariaDB" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **db** | MariaDB | 3306 |
README_EOF
elif [[ "$DB_CHOICE" == "PostgreSQL" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **db** | PostgreSQL | 5432 |
README_EOF
fi

if [[ "$REDIS_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **redis** | Redis | 6379 |
README_EOF
fi

if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **reverb** | Laravel Reverb WebSocket server | 8080 |
README_EOF
fi

if [[ "$BUN_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **bun** | Bun + Vite dev server | 5173 |
README_EOF
fi

if [[ "$HORIZON_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **horizon** | Laravel Horizon queue worker | — |
README_EOF
elif [[ "$REDIS_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **worker** | Queue worker | — |
README_EOF
fi

if [[ "$MAILPIT_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
| **mailpit** | Local email testing | 8025 |
README_EOF
fi

cat >> "$SCRIPT_DIR/README.md" <<README_EOF

## Makefile Commands

\`\`\`bash
make up                # Start containers
make down              # Stop containers
make build             # Rebuild and start containers
make shell             # Open a bash shell in the PHP container
make artisan CMD=...   # Run an artisan command
make composer CMD=...  # Run a composer command
make tinker            # Open Laravel Tinker
make migrate           # Run database migrations
make fresh-db          # Run migrate:fresh --seed
make test              # Run tests
make test-p            # Run tests in parallel (4 processes)
make status            # Show container status
make logs              # Tail container logs
README_EOF

if [[ "$BUN_CHOICE" == "Yes" ]]; then
    cat >> "$SCRIPT_DIR/README.md" <<README_EOF
make bun CMD=...       # Run a bun command
make bun-start         # Start the Bun/Vite container
make bun-stop          # Stop the Bun/Vite container
README_EOF
fi

cat >> "$SCRIPT_DIR/README.md" <<README_EOF
\`\`\`

## Configuration

- **Dockerfile** — PHP version, system dependencies, and extensions
- **docker-compose.yml** — Service definitions and port mappings
- **.env** — Application and database configuration
- Xdebug is installed but disabled by default (\`xdebug.mode=off\`)
README_EOF

###############################################################################
# Clean up scaffold artifacts
###############################################################################
if [[ ! -f "$SCRIPT_DIR/artisan" ]]; then
    echo "ERROR: Laravel does not appear to be installed (artisan not found)."
    echo "Skipping cleanup so you can investigate."
    exit 1
fi

echo "Cleaning up..."
rm -rf "$SCRIPT_DIR/.git"
rm -- "$0"

###############################################################################
# Done
###############################################################################
echo ""
echo "Done! Your project is running at ${APP_DISPLAY_URL}"
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    echo "Reverb WebSocket server is running on ws://${CUSTOM_URL:-localhost}:8080/"
fi
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Vite dev server is running at http://${CUSTOM_URL:-localhost}:5173/"
fi
if [[ "$MAILPIT_CHOICE" == "Yes" ]]; then
    echo "Mailpit inbox is at http://${CUSTOM_URL:-localhost}:8025/"
fi
if [[ -n "$CUSTOM_URL" ]]; then
    echo ""
    echo "NOTE: Add the following line to your /etc/hosts file:"
    echo "  127.0.0.1  $CUSTOM_URL"
    if [[ "$USED_MKCERT" == true ]]; then
        # Check if running in WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            CAROOT="$(mkcert -CAROOT)"
            echo ""
            echo "WSL DETECTED: To trust the certificate in your Windows browser:"
            echo "  1. Find the CA cert at: $CAROOT/rootCA.pem"
            echo "  2. Open that file in Windows Explorer and double-click rootCA.pem → Install Certificate"
            echo "  3. Select 'Local Machine' → 'Place all certificates in the following store'"
            echo "  4. Browse → 'Trusted Root Certification Authorities' → OK → Finish"
            echo "  5. Restart your browser"
        fi
    else
        echo ""
        echo "A self-signed certificate was used. Your browser will show a security warning."
        echo "Install mkcert for trusted local certificates:"
        echo "  sudo apt install mkcert libnss3-tools -y"
    fi
fi
