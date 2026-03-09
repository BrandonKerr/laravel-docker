.PHONY: up down shell artisan composer bun bun-start bun-stop tinker migrate fresh test test-p logs build

up:
	docker-compose up -d

down:
	docker-compose down

build:
	docker-compose up -d --build

shell:
	docker-compose exec php bash

artisan:
	docker-compose exec php php artisan $(CMD)

composer:
	docker-compose exec php composer $(CMD)

bun:
	docker-compose exec bun bun $(CMD)

tinker:
	docker-compose exec php php artisan tinker

migrate:
	docker-compose exec php php artisan migrate

fresh-db:
	docker-compose exec php php artisan migrate:fresh --seed

test:
	docker-compose exec php php artisan test

test-p:
	docker-compose exec php php artisan test -p --processes=4

bun-start:
	docker-compose start bun

bun-stop:
	docker-compose stop bun

logs:
	docker-compose logs -f
