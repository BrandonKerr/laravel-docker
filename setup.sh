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
# Prompt for Bun/Vite
###############################################################################
echo ""
echo "Include Bun/Vite for frontend asset bundling?"
select BUN_CHOICE in "Yes" "No"; do
    case $BUN_CHOICE in
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
echo "Bun/Vite:     $BUN_CHOICE"
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
# Build and start containers
###############################################################################
echo "Building and starting containers..."
cd "$SCRIPT_DIR"
docker-compose build
docker-compose up -d

###############################################################################
# Install Laravel
###############################################################################
echo "Installing Laravel..."
docker-compose exec php composer create-project --prefer-dist laravel/laravel /tmp/laravel
docker-compose exec php cp -r /tmp/laravel/. /var/www/
docker-compose exec php php artisan key:generate
docker-compose exec php php artisan storage:link

###############################################################################
# Database-specific post-install
###############################################################################
if [[ "$DB_CHOICE" == "SQLite" ]]; then
    echo "Setting up SQLite database..."
    docker-compose exec php touch /var/www/database/database.sqlite
    docker-compose exec php php artisan migrate
fi

###############################################################################
# Bun/Vite post-install
###############################################################################
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Configuring Vite for Docker..."
    sed -i 's/server: {/server: {\n        host: "0.0.0.0",\n        hmr: {\n            host: "localhost",\n        },/' vite.config.js
    docker-compose restart bun
fi

###############################################################################
# Done
###############################################################################
echo ""
echo "Done! Your project is running at http://localhost:8000/"
if [[ "$BUN_CHOICE" == "Yes" ]]; then
    echo "Vite dev server is running at http://localhost:5173/"
fi
