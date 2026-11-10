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

benchmark:        ## time every card before/after, writes docs/benchmark.md
	docker compose run --rm metabase-setup python benchmark.py

status:
	curl -s localhost:8083/connectors/paymentyar-core/status