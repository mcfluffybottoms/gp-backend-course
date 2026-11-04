# Домашняя работа по SQL на датасете Dota 2.
#
#   make up        — поднять PostgreSQL и залить схему с данными (первый раз дольше)
#   make test      — прогнать все задачи по вашим запросам из queries/
#   make one N=07  — прогнать одну задачу по номеру
#   make psql      — интерактивный сеанс psql, чтобы покрутить запрос руками
#   make down      — остановить базу, данные сохранить
#   make reset     — пересоздать базу с нуля
#   make clean     — остановить базу и убрать временные файлы

.PHONY: up down reset test one psql clean

up:
	docker compose up -d --wait

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d --wait

test: up
	cd tests && python3 -m unittest test_queries -v

one: up
	@test -n "$(N)" || (echo "укажите номер задачи: make one N=07" && exit 1)
	cd tests && python3 -m unittest test_queries -v -k test_$(N)


psql:
	docker compose exec postgres psql -U student -d shop

clean: down
	find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
