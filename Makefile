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

# CI combines the exact architecture images this workflow run pushed; see
# wodby/images arch-image-pins. Per-architecture tags are shared by every run,
# so an overlapping run may already have replaced one of them.
arch-image = $(if $(ARCH_IMAGE_PINS),$(or $(shell cat '$(ARCH_IMAGE_PINS)/$(subst :,_,$(subst /,_,$(1)))' 2>/dev/null),$(error No digest of $(1) was pushed by this workflow run)),$(1))

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
		$(call arch-image,$(REPO):$(IMAGETOOLS_TAG)-amd64) \
		$(call arch-image,$(REPO):$(IMAGETOOLS_TAG)-arm64)

update:
	./scripts/update.sh

release: build push

# Print the image make builds and pushes; CI pushes exactly this reference.
.PHONY: image-ref
image-ref:
	@printf '%s\n' '$(REPO):$(TAG)'
