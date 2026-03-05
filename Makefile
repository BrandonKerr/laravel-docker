.PHONY: init

NAME ?= my_project

init: .env
	sed -i 's/__PROJECT_NAME__/$(NAME)/g' docker-compose.yml
	sed -i 's/^DB_DATABASE=.*/DB_DATABASE=$(NAME)/' .env
	docker-compose build
	docker-compose up -d
	docker-compose exec php composer create-project --prefer-dist laravel/laravel /tmp/laravel
	docker-compose exec php cp -r /tmp/laravel/. /var/www/
	docker-compose exec php php artisan key:generate
	docker-compose exec php php artisan storage:link
	@echo ""
	@echo "Done! Your project is running at http://localhost:8000/"

.env:
	cp .env.example .env
