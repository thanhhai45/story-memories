# Mọi lệnh chạy trong Docker — máy bạn chỉ cần Docker (Docker Desktop / OrbStack).
DC = docker compose
RUN = $(DC) run --rm web

.PHONY: up down build logs console test shell db-reset lock routes deploy-setup deploy kamal

up:            ## Khởi động toàn bộ (db, setup, web, jobs, css) — http://localhost:3000
	@[ -f .env ] || cp .env.example .env
	$(DC) up --build

down:          ## Dừng
	$(DC) down

build:         ## Build lại image phát triển
	$(DC) build

logs:          ## Xem log web + jobs
	$(DC) logs -f web jobs

console:       ## Rails console
	$(RUN) bin/rails console

shell:         ## Bash trong container
	$(RUN) bash

routes:
	$(RUN) bin/rails routes

test:          ## Chạy toàn bộ test (gồm test dựng video thật bằng FFmpeg)
	$(DC) run --rm -e RAILS_ENV=test web bash -c "bin/rails db:prepare && bin/rails test"

db-reset:      ## Xóa và tạo lại database phát triển
	$(RUN) bin/rails db:drop db:prepare

lock:          ## Tạo/cập nhật Gemfile.lock (cho cả amd64 + arm64)
	$(RUN) bash -c "bundle lock && bundle lock --add-platform x86_64-linux aarch64-linux"

deploy-setup:  ## Lần đầu: cài Docker trên server, khởi động Postgres, deploy app
	@[ -f .env.deploy ] || (echo "Hãy tạo .env.deploy từ .env.deploy.example" && exit 1)
	@[ -f Gemfile.lock ] || $(MAKE) lock
	bin/kamal setup

deploy:        ## Deploy phiên bản mới
	@[ -f Gemfile.lock ] || $(MAKE) lock
	bin/kamal deploy

kamal:         ## Lệnh Kamal tùy ý: make kamal ARGS="app logs -f"
	bin/kamal $(ARGS)
