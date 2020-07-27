################################################################################
# Variables
################################################################################
export GO111MODULE ?= on
export GOPROXY ?= https://proxy.golang.org
export GOSUMDB ?= sum.golang.org
# By default, disable CGO_ENABLED. See the details on https://golang.org/cmd/cgo
CGO         ?= 0
BINARIES ?= api

################################################################################
# Release version
################################################################################
ifdef REL_VERSION
	API_VERSION := $(REL_VERSION)
	API_LATEST_VERSION := latest
else
	API_VERSION := edge
	API_LATEST_VERSION := edge
endif

RELEASE_NAME := dapr-secret-api-go

################################################################################
# Docker
################################################################################
DOCKER := docker
DOCKERFILE_DIR ?= ./docker
DOCKERFILE := Dockerfile

DOCKER_IMAGE_LATEST_VERSION := $(RELEASE_NAME):$(API_LATEST_VERSION)
DOCKER_IMAGE_VERSION := $(RELEASE_NAME):$(API_VERSION)

################################################################################
# Architectue
################################################################################
LOCAL_ARCH := $(shell uname -m)
ifeq ($(LOCAL_ARCH),x86_64)
	TARGET_ARCH_LOCAL=amd64
else ifeq ($(shell echo $(LOCAL_ARCH) | head -c 5),armv8)
	TARGET_ARCH_LOCAL=arm64
else ifeq ($(shell echo $(LOCAL_ARCH) | head -c 4),armv)
	TARGET_ARCH_LOCAL=arm
else
	TARGET_ARCH_LOCAL=amd64
endif
export GOARCH ?= $(TARGET_ARCH_LOCAL)

################################################################################
# OS
################################################################################
LOCAL_OS := $(shell uname)
ifeq ($(LOCAL_OS),Linux)
   TARGET_OS_LOCAL = linux
else ifeq ($(LOCAL_OS),Darwin)
   TARGET_OS_LOCAL = darwin
else
   TARGET_OS_LOCAL ?= windows
endif
export GOOS ?= $(TARGET_OS_LOCAL)

################################################################################
# Binaries extension
################################################################################
ifeq ($(GOOS),windows)
BINARY_EXT_LOCAL:=.exe
GOLANGCI_LINT:=golangci-lint.exe
else
BINARY_EXT_LOCAL:=
GOLANGCI_LINT:=golangci-lint
endif

export BINARY_EXT ?= $(BINARY_EXT_LOCAL)

################################################################################
# GO build flags
################################################################################
BASE_PACKAGE_NAME := github.com/azuredevcollege/aks/dapr-secrets-add-pod-identity/src/api-go

DEFAULT_LDFLAGS := -X $(BASE_PACKAGE_NAME)/pkg/version.commit=$(API_VERSION) -X $(BASE_PACKAGE_NAME)/pkg/version.version=$(API_VERSION)
ifeq ($(DEBUG),)
  BUILDTYPE_DIR:=release
  LDFLAGS:="$(DEFAULT_LDFLAGS) -s -w"
else ifeq ($(DEBUG),0)
  BUILDTYPE_DIR:=release
  LDFLAGS:="$(DEFAULT_LDFLAGS) -s -w"
else
  BUILDTYPE_DIR:=debug
  GCFLAGS:=-gcflags="all=-N -l"
  LDFLAGS:="$(DEFAULT_LDFLAGS)"
  $(info Build with debugger information)
endif

################################################################################
# output directory
################################################################################
OUT_DIR := ./dist
API_OUT_DIR := $(OUT_DIR)/$(GOOS)_$(GOARCH)/$(BUILDTYPE_DIR)
API_LINUX_OUT_DIR := $(OUT_DIR)/linux_$(GOARCH)/$(BUILDTYPE_DIR)

################################################################################
# Target: build                                                                
################################################################################
.PHONY: build
API_BINS:=$(foreach ITEM,$(BINARIES),$(API_OUT_DIR)/$(ITEM)$(BINARY_EXT))
build: $(API_BINS)

# Generate builds for dapr binaries for the target
# Params:
# $(1): the binary name for the target
# $(2): the binary main directory
# $(3): the target os
# $(4): the target arch
# $(5): the output directory
define genBinariesForTarget
.PHONY: $(5)/$(1)
$(5)/$(1):
	CGO_ENABLED=$(CGO) GOOS=$(3) GOARCH=$(4) go build $(GCFLAGS) -ldflags=$(LDFLAGS) \
	-o $(5)/$(1) \
	$(2)/main.go;
endef

# Generate binary targets
$(foreach ITEM,$(BINARIES),$(eval $(call genBinariesForTarget,$(ITEM)$(BINARY_EXT),./cmd/$(ITEM),$(GOOS),$(GOARCH),$(API_OUT_DIR))))

################################################################################
# Target: lint                                                                
################################################################################
.PHONY: lint	
lint:
	$(GOLANGCI_LINT) run --fix

################################################################################
# Target: docker-image
################################################################################
.PHONY: docker-image
docker-build:
	$(DOCKER) build -t $(DOCKER_IMAGE_VERSION) -f $(DOCKERFILE_DIR)/$(DOCKERFILE) .

check-docker-publish-args:
ifeq ($(dockerserver),)
	$(error docker server must be set: dockerserver=<dockerserver>)
endif
ifeq ($(dockerusername),)
	$(error docker login must be set: dockerlogin=<dockerusername>)
endif
ifeq ($(dockerpassword),)
	$(error docker password must be set: dockerpassword=<dockerpassword>)
endif

.PHONY: docker-publish
docker-publish: check-docker-publish-args
	$(DOCKER) login -p $(dockerpassword) -u $(dockerusername)
	$(DOCKER) build -t $(dockerserver)/$(DOCKER_IMAGE_VERSION) -f $(DOCKERFILE_DIR)/$(DOCKERFILE) .
	$(DOCKER) tag $(dockerserver)/$(DOCKER_IMAGE_VERSION) $(dockerserver)/$(DOCKER_IMAGE_LATEST_VERSION)
	$(DOCKER) push $(dockerserver)/$(DOCKER_IMAGE_VERSION)
	$(DOCKER) push $(dockerserver)/$(DOCKER_IMAGE_LATEST_VERSION)