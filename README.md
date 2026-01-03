# laravel-docker
This repo is intended to act as a starting point for making a new Laravel project from within a Docker container. Why? Because I'm crazy and wanted to have a totally clean environment. This means that the server only needs to have Docker installed; no PHP, composer, or anything else is necessary because it's set up with this.

# Usage
The general idea is to use this repo to set up a new directory for your project, and then use composer to start a new Laravel project. This creates a wrapper container for the project and three services: 
 - a MariaDB database
 - an nginx web server
 - a PHP-FPM service for the app

# Set up
Clone this repo into a new directory for your project.
e.g. `git clone git@github.com:BrandonKerr/laravel-docker.git my-project`

This will obviously link it to this repo, so remove the .git directory: `rm -rf .git`
(You could also download a ZIP and deal with that, but this is easier)
## Update docker-compose
The docker-compose.yml file will need to be updated for your project:
 - Go through the docker-compose.yml file and replace all instances of `my_project` with the name of your new project.
 - You'll also need to set the uid to match your own. To get this, in your server's CLI simply run `echo $UID`. Set the app -> build -> args ->uid to this value.
You'll also need to review the images and update any that should be.
 - db -> image
 - nginx -> image
## Update Dockerfile
The Dockerfile uses some values set in docker-compose.yml for the user, so there's no need to change that for the project. You will need to do any adjustments to the PHP version, system dependencies, and PHP extensions.
 - Set the `FROM` value to use the desired image for the starting point (e.g. php:8.2-fpm).
 - Review each option under the `# Install system dependencies` section and add/remove dependencies as needed.
 - Review each setting under the `# Install PHP extensions` section and add/remove extensions as needed.
## Create .env
There is a .env.example file provided here, which used the latest one provided by Laravel at the time of this creation, with a minor adjustment for the DB settings.
Use this file to make your .env: `mv .env.example .env`. Then update the `DB_HOST` and `DB_DATABASE` values as necessary and uncomment them.

# Build and Run the Containers
With everything configured, you can now build the containers: `docker-compose build`.

Once they've been built, you can start the containers: `docker-compose up -d`.

# Create Laravel Project
With the containers built and running, we can use it to create a new Laravel project. 
 - Enter into the container: `docker-compose exec app bash`
 - Use Laravel's composer command to create a new project in the /tmp directory: `composer create-project --prefer-dist laravel/laravel /tmp/laravel`. Note that this goes into /tmp because our current directory isn't empty due to this setup.
 - Once that's complete, copy the files over from /tmp: `cp -r /tmp/laravel/* /var/www/`. This will allow the Docker-related files to remain in place.

# Done
You should now have your project running at http://localhost:8000/.

## Useful Commands
- View logs: `docker-compose logs -f`
- Rebuild: `docker-compose up -d --build`
- Run artisan: `docker-compose exec app php artisan`
- Run npm: `docker-compose exec app npm run dev`