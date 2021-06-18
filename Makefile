include .env
export

init:
	git submodule update --init --recursive

up: init
	docker-compose up -d

down:
	docker-compose down

tty-solr:
	docker-compose exec solr bash

ps:
	docker-compose ps

load-data: init
	bin/load-data

test-relevancy:
	bundle exec rspec --require $(RELEVANCY_SPECS_PATH)/spec_helper.rb $(RELEVANCY_SPECS_PATH)
