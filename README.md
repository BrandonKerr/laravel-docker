# laravel-docker

A Docker-based Laravel project scaffold with an interactive setup script. No host dependencies beyond Docker — no PHP, Composer, or Node required on your machine.

## Quick Start

1. Clone this repo into a new directory for your project:
   ```bash
   git clone git@github.com:BrandonKerr/laravel-docker.git my-project
   cd my-project
   ```

2. Run the interactive setup:
   ```bash
   ./setup.sh
   ```

   The script will prompt you for:
   - **Project name** — used for container names, database name, and network
   - **Database** — MariaDB, PostgreSQL, or SQLite
   - **Bun/Vite** — whether to include a Bun container for frontend asset bundling

   It then builds the containers, installs Laravel, and starts everything up. Your project will be running at http://localhost:8000/.

## Services

The setup generates a `docker-compose.yml` tailored to your choices:

- **php** — PHP 8.4-FPM application container
- **nginx** — Reverse proxy on port 8000
- **db** — MariaDB or PostgreSQL (omitted for SQLite)
- **bun** — Bun running Vite dev server on port 5173 (optional)

## Convenience Commands

After setup, use the Makefile for day-to-day tasks:

```bash
make up              # Start containers
make down            # Stop containers
make build           # Rebuild and start containers
make artisan CMD=migrate    # Run artisan commands
make composer CMD=require\ some/package   # Run composer
make bun CMD=add\ axios     # Run bun (if included)
make logs            # Tail container logs
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
