# laravel-docker
This repo is intended to act as a starting point for making a new Laravel project from within a Docker container. Why? 
Because I'm crazy and wanted to have a totally clean environment. This means that the server only needs to have Docker 
installed; no PHP, composer, or anything else is necessary because it's set up with this.

# Usage
The general idea is to use this repo to set up a new directory for your project, and then use composer to start a new 
Laravel project. This creates a wrapper container for the project and four services: 
 - a MariaDB database
 - an nginx web server
 - a PHP-FPM service for the app
 - a node service for running vite

# Quick Start
1. Clone this repo into a new directory for your project:
   ```bash
   git clone git@github.com:BrandonKerr/laravel-docker.git my-project
   cd my-project
   rm -rf .git
   ```
2. Run the setup (replace `my_project` with your project name):
   ```bash
   make init NAME=my_project
   ```

This will create your `.env`, update `docker-compose.yml`, build the containers, install Laravel, and start everything up. Your project will be running at http://localhost:8000/.

# Optional: Review Configuration
Before running `make init`, you may want to review and adjust:

## Dockerfile
The Dockerfile uses some values set in docker-compose.yml for the user, so there's no need to change that for the project.
You will need to do any adjustments to the PHP version, system dependencies, and PHP extensions.
 - Set the `FROM` value to use the desired image for the starting point (e.g. php:8.4-fpm).
 - Review each option under the `# Install system dependencies` section and add/remove dependencies as needed.
 - Review each setting under the `# Install PHP extensions` section and add/remove extensions as needed.

## Docker images
Review the images in `docker-compose.yml` and update any that should be:
 - node -> image
 - db -> image
 - nginx -> image

## Useful Commands
- View logs: `docker-compose logs -f`
- Rebuild: `docker-compose up -d --build`
- Run artisan: `docker-compose exec php php artisan`
- Run npm: `docker-compose exec node npm run dev`