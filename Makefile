.PHONY: up down reset logs test benchmark status

up:
	docker compose up -d --build

down:
	docker compose down

reset:            ## wipe all data and start from zero
	docker compose down -v

logs:
	docker compose logs -f --tail=100

test:             ## dbt tests incl. reconciliation with core
	docker compose exec dbt dbt test

benchmark:        ## pause changes, let pipeline catch up, time + compare all cards
	docker compose stop simulator
	docker compose run --rm -e BENCH_WAIT_SECONDS=150 metabase-setup python benchmark.py
	docker compose start simulator

status:
	curl -s localhost:8083/connectors/paymentyar-core/status