#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR/docker/compose"

###############################################################################
# Prompt for project name
###############################################################################
DEFAULT_NAME="$(basename "$SCRIPT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
while true; do
    read -rp "Project name (lowercase, underscores, hyphens only) [$DEFAULT_NAME]: " PROJECT_NAME
    PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_NAME}"
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
# Prompt for Reverb (WebSockets)
###############################################################################
echo ""
echo "Include Laravel Reverb for WebSockets?"
select REVERB_CHOICE in "Yes" "No"; do
    case $REVERB_CHOICE in
        Yes|No) break ;;
        *) echo "Invalid selection." ;;
    esac
done

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
echo "Reverb:       $REVERB_CHOICE"
echo "====================="
echo ""
read -rp "Proceed? (Y/n) " CONFIRM
if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
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

# Append reverb fragment
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    cat "$COMPOSE_DIR/reverb.yml" >> "$SCRIPT_DIR/docker-compose.yml"
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
# Configure Reverb in .env
###############################################################################
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    sed -i "s/^BROADCAST_CONNECTION=.*/BROADCAST_CONNECTION=reverb/" "$SCRIPT_DIR/.env"
    cat >> "$SCRIPT_DIR/.env" <<'REVERB_ENV'

REVERB_APP_ID=my-app-id
REVERB_APP_KEY=my-app-key
REVERB_APP_SECRET=my-app-secret
REVERB_HOST=reverb
REVERB_PORT=8080
REVERB_SCHEME=http

VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"
VITE_REVERB_HOST="localhost"
VITE_REVERB_PORT="${REVERB_PORT}"
VITE_REVERB_SCHEME="${REVERB_SCHEME}"
REVERB_ENV
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

# Remove scaffold files that should be replaced by Laravel's versions
rm -f "$SCRIPT_DIR/.gitignore" "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/composer.json" "$SCRIPT_DIR/README.md"

docker-compose exec php composer create-project --prefer-dist "$COMPOSER_PACKAGE" /tmp/laravel
docker-compose exec php cp -r /tmp/laravel/. /var/www/
docker-compose exec php php artisan key:generate
docker-compose exec php php artisan storage:link
docker-compose exec php composer require brianium/paratest --dev

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
# Reverb post-install
###############################################################################
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    echo "Installing Laravel Reverb..."
    docker-compose exec php composer require laravel/reverb
    docker-compose exec php php artisan vendor:publish --provider="Laravel\Reverb\ReverbServiceProvider" --tag=reverb-config
    docker-compose exec php php artisan install:broadcasting --no-interaction
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
# Generate project README
###############################################################################
echo "Generating README..."

cat > "$SCRIPT_DIR/README.md" <<README_EOF
# ${PROJECT_NAME}

## Getting Started

Start the containers:
\`\`\`bash
make up
\`\`\`

The app will be available at http://localhost:8000/

## Services

| Service | Description | Port |
|---------|-------------|------|
| **php** | PHP 8.4-FPM application container | — |
| **nginx** | Reverse proxy | 8000 |
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
echo "Cleaning up..."
rm -rf "$SCRIPT_DIR/.git"
rm -- "$0"

###############################################################################
# Done
###############################################################################
echo ""
echo "Done! Your project is running at http://localhost:8000/"
if [[ "$REVERB_CHOICE" == "Yes" ]]; then
    echo "Reverb WebSocket server is running on ws://localhost:8080/"
fi
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Vite dev server is running at http://localhost:5173/"
fi
