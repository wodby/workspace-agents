-include env_make

# VERSION is the major version of the image layout that workspace runners rely on: the installer and
# the wrappers in bin/.
VERSION ?= 1

REPO = wodby/workspace-agents

TAG ?= $(VERSION)
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
		$(REPO):$(TAG)-amd64 \
		$(REPO):$(TAG)-arm64

update:
	./scripts/update.sh

release: build push
