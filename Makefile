include .env
export

up:
	docker-compose up -d

down:
	docker-compose down

tty-solr:
	docker-compose exec solr bash

ps:
	docker-compose ps

load-data:
	bin/load-data

test-relevancy:
	bundle exec rspec --require $(RELEVANCY_SPECS_PATH)/spec_helper.rb $(RELEVANCY_SPECS_PATH)
