-include env_make

REPO = wodby/workspace-agents

# RELEASE_VERSION is a semantic version from a release tag. Other builds publish latest.
ifneq ($(RELEASE_VERSION),)
	TAG ?= $(RELEASE_VERSION)
else
	TAG ?= latest
endif
IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build test push buildx-imagetools-create update release

default: build

build:
	docker build -t $(REPO):$(TAG) ./

test:
	IMAGE=$(REPO):$(TAG) ./tests/test.sh

push:
	docker push $(REPO):$(TAG)

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
		$(REPO):$(IMAGETOOLS_TAG)-amd64 \
		$(REPO):$(IMAGETOOLS_TAG)-arm64

update:
	./scripts/update.sh

release: build push
