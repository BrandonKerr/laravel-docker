# laradock-setup

A Docker-based Laravel project scaffold with an interactive setup script. No host dependencies beyond Docker — no PHP, Composer, or Node required on your machine.

## Quick Start

1. Clone this repo into a new directory for your project:
   ```bash
   git clone git@github.com:BrandonKerr/laradock-setup.git my-project
   cd my-project
   ```

2. Run the interactive setup:
   ```bash
   ./setup.sh
   ```

   The script will prompt you for:
   - **Project name** — used for container names, database name, and network
   - **Custom URL** — optional local domain with HTTPS (e.g. `myapp.test`)
   - **Database** — MariaDB, PostgreSQL, or SQLite
   - **Starter kit** — None, React, Vue, or Livewire
   - **Bun/Vite** — frontend asset bundling (included automatically with starter kits)
   - **Redis** — for caching, sessions, and queues
   - **Horizon** — Laravel queue monitoring (requires Redis)
   - **Reverb** — WebSocket server
   - **Mailpit** — local email testing

   It then builds the containers, installs Laravel, and starts everything up.

## Services

The setup generates a `docker-compose.yml` tailored to your choices:

- **php** — PHP 8.4-FPM application container
- **nginx** — Reverse proxy (port 8000, or 80/443 with custom URL)
- **db** — MariaDB or PostgreSQL (omitted for SQLite)
- **redis** — Caching, sessions, and queues (optional)
- **horizon** — Laravel Horizon queue worker (optional, requires Redis)
- **worker** — Standalone queue worker (when Redis chosen without Horizon)
- **reverb** — Laravel Reverb WebSocket server on port 8080 (optional)
- **bun** — Bun running Vite dev server on port 5173 (optional)
- **mailpit** — Local email testing with web UI on port 8025 (optional)

## Convenience Commands

After setup, use the Makefile for day-to-day tasks:

```bash
make up              # Start containers
make down            # Stop containers
make build           # Rebuild and start containers
make shell           # Open a bash shell in the PHP container
make artisan CMD=... # Run artisan commands
make composer CMD=...  # Run composer
make tinker          # Open Laravel Tinker
make migrate         # Run database migrations
make fresh-db        # Run migrate:fresh --seed
make test            # Run tests
make test-p          # Run tests in parallel (4 processes)
make status          # Show container status
make logs            # Tail container logs
make bun CMD=...     # Run bun (if included)
make bun-start       # Start the Bun/Vite container
make bun-stop        # Stop the Bun/Vite container
```

## Configuration

### Dockerfile
- PHP version, system dependencies, and extensions can be adjusted in `Dockerfile`
- Xdebug is installed but disabled by default (`xdebug.mode=off`)
- PHP memory limit is set to 1G

### Docker Images
Review the images in the generated `docker-compose.yml` and update versions as needed.

### Database Credentials
Configured via `.env` — the setup script sets defaults (`laravel`/`secret`). Update before deploying.
