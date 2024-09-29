#import .env
dpl ?= deploy.env
include $(dpl)
export $(shell sed 's/=.*//' $(dpl))

# grep the version from the mix file
VERSION=$(shell ./version.sh)

.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# DOCKER TASKS
# Build the container
build: ## Build the container
	docker manifest create --amend $(APP_NAME)
	docker build --platform linux/amd64,linux/arm64 --manifest $(APP_NAME) .

build-nc: ## Build the container without caching
	docker manifest create --amend $(APP_NAME)
	docker build --platform linux/amd64,linux/arm64 --no-cache --manifest $(APP_NAME) .

release: build-nc publish ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to registry

# Docker publish
publish: publish-latest publish-version ## Publish the `{version}` ans `latest` tagged containers to registry

publish-latest: tag-latest ## Publish the `latest` tagged container to registry
	@echo 'publish latest to $(DOCKER_REPO)'
	docker manifest push $(DOCKER_REPO)/$(APP_NAME):latest

publish-version: tag-version ## Publish the `{version}` tagged container to registry
	@echo 'publish $(VERSION) to $(DOCKER_REPO)'
	docker manifest push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# Docker tagging
tag: tag-latest tag-version ## Generate container tags for the `{version}` and `latest` tags

tag-latest: ## Generate container `latest` tag
	@echo 'create tag latest'
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):latest

tag-version: ## Generate container `{version}` tag
	@echo 'create tag $(VERSION)'
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):$(VERSION)
