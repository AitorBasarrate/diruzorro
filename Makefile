run:
	docker compose up --build

stop:
	docker compose down

clean:
	docker compose down -v

logs:
	docker compose logs -f

build:
	docker compose build
