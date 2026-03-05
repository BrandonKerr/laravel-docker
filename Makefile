.PHONY: up down artisan composer bun logs build

up:
	docker-compose up -d

down:
	docker-compose down

build:
	docker-compose up -d --build

artisan:
	docker-compose exec php php artisan $(CMD)

composer:
	docker-compose exec php composer $(CMD)

bun:
	docker-compose exec bun bun $(CMD)

logs:
	docker-compose logs -f
