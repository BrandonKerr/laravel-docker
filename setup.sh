#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/docker/compose"

###############################################################################
# Prompt for project name
###############################################################################
while true; do
    read -rp "Project name (lowercase, underscores, hyphens only): " PROJECT_NAME
    if [[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        break
    fi
    echo "Invalid name. Use lowercase letters, numbers, underscores, and hyphens (must start with a letter)."
done

###############################################################################
# Prompt for database
###############################################################################
echo ""
echo "Select a database:"
select DB_CHOICE in "MariaDB" "PostgreSQL" "SQLite"; do
    case $DB_CHOICE in
        MariaDB|PostgreSQL|SQLite) break ;;
        *) echo "Invalid selection." ;;
    esac
done

###############################################################################
# Prompt for starter kit
###############################################################################
echo ""
echo "Select a starter kit:"
select KIT_CHOICE in "None" "React" "Vue" "Livewire"; do
    case $KIT_CHOICE in
        None|React|Vue|Livewire) break ;;
        *) echo "Invalid selection." ;;
    esac
done

###############################################################################
# Prompt for Bun/Vite (only if no starter kit — kits require Bun)
###############################################################################
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

###############################################################################
# Prompt for Redis
###############################################################################
echo ""
echo "Include Redis for caching, sessions, and queues?"
select REDIS_CHOICE in "Yes" "No"; do
    case $REDIS_CHOICE in
        Yes|No) break ;;
        *) echo "Invalid selection." ;;
    esac
done

###############################################################################
# Prompt for Horizon (only if Redis chosen)
###############################################################################
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

###############################################################################
# Confirm choices
###############################################################################
echo ""
echo "=== Setup Summary ==="
echo "Project name: $PROJECT_NAME"
echo "Database:     $DB_CHOICE"
echo "Starter kit:  $KIT_CHOICE"
echo "Bun/Vite:     $BUN_CHOICE"
echo "Redis:        $REDIS_CHOICE"
echo "Horizon:      $HORIZON_CHOICE"
echo "====================="
echo ""
read -rp "Proceed? (y/n) " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
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
# Generate .env
###############################################################################
echo "Generating .env..."
cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"

case $DB_CHOICE in
    MariaDB)
        sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_HOST=.*/DB_HOST=db/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_PORT=.*/DB_PORT=3306/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_USERNAME=.*/DB_USERNAME=laravel/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=secret/" "$SCRIPT_DIR/.env"
        ;;
    PostgreSQL)
        sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_HOST=.*/DB_HOST=db/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_PORT=.*/DB_PORT=5432/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_USERNAME=.*/DB_USERNAME=laravel/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=secret/" "$SCRIPT_DIR/.env"
        ;;
    SQLite)
        sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_HOST=.*/#DB_HOST=/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_PORT=.*/#DB_PORT=/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_DATABASE=.*/DB_DATABASE=\/var\/www\/database\/database.sqlite/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_USERNAME=.*/#DB_USERNAME=/" "$SCRIPT_DIR/.env"
        sed -i "s/^DB_PASSWORD=.*/#DB_PASSWORD=/" "$SCRIPT_DIR/.env"
        ;;
esac

###############################################################################
# Configure Redis in .env
###############################################################################
if [[ "$REDIS_CHOICE" == "Yes" ]]; then
    sed -i "s/^REDIS_HOST=.*/REDIS_HOST=redis/" "$SCRIPT_DIR/.env"
    sed -i "s/^CACHE_STORE=.*/CACHE_STORE=redis/" "$SCRIPT_DIR/.env"
    sed -i "s/^SESSION_DRIVER=.*/SESSION_DRIVER=redis/" "$SCRIPT_DIR/.env"
    sed -i "s/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" "$SCRIPT_DIR/.env"
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
        sed -i '/mariadb-client/d' "$SCRIPT_DIR/Dockerfile"
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
# Build and start containers
###############################################################################
echo "Building and starting containers..."
cd "$SCRIPT_DIR"
docker-compose build
docker-compose up -d

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
docker-compose exec php composer create-project --prefer-dist "$COMPOSER_PACKAGE" /tmp/laravel
docker-compose exec php cp -r /tmp/laravel/. /var/www/
docker-compose exec php php artisan key:generate
docker-compose exec php php artisan storage:link

###############################################################################
# Database-specific post-install
###############################################################################
if [[ "$DB_CHOICE" == "SQLite" ]]; then
    echo "Setting up SQLite database..."
    docker-compose exec php touch /var/www/database/database.sqlite
fi

###############################################################################
# Run migrations (SQLite always; other DBs when starter kit needs auth tables)
###############################################################################
if [[ "$DB_CHOICE" == "SQLite" || "$KIT_CHOICE" != "None" ]]; then
    echo "Running migrations..."
    docker-compose exec php php artisan migrate
fi

###############################################################################
# Horizon post-install
###############################################################################
if [[ "$HORIZON_CHOICE" == "Yes" ]]; then
    echo "Installing Laravel Horizon..."
    docker-compose exec php composer require laravel/horizon
    docker-compose exec php php artisan horizon:install
fi

###############################################################################
# Bun/Vite post-install
###############################################################################
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Configuring Vite for Docker..."
    # Starter kits ship vite.config.ts, base Laravel ships vite.config.js
    if [[ -f "$SCRIPT_DIR/vite.config.ts" ]]; then
        VITE_CONFIG="vite.config.ts"
    else
        VITE_CONFIG="vite.config.js"
    fi
    VITE_PATH="$SCRIPT_DIR/$VITE_CONFIG"
    if grep -q 'server:' "$VITE_PATH"; then
        # Patch existing server block
        sed -i 's/server: {/server: {\n        host: "0.0.0.0",\n        hmr: {\n            host: "localhost",\n        },/' "$VITE_PATH"
    else
        # No server block — add one before the closing });
        sed -i '/^});/i\    server: {\n        host: "0.0.0.0",\n        hmr: {\n            host: "localhost",\n        },\n    },' "$VITE_PATH"
    fi
    docker-compose restart bun
fi

###############################################################################
# Clean up scaffold artifacts
###############################################################################
echo "Cleaning up..."
rm -rf "$SCRIPT_DIR/.git"
rm -- "$0"

###############################################################################
# Done
###############################################################################
echo ""
echo "Done! Your project is running at http://localhost:8000/"
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Vite dev server is running at http://localhost:5173/"
fi
