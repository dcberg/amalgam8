.DEFAULT_GOAL	:= build

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

SHELL 		:= /bin/bash
APP_NAME	:= sidecar
APP_VER		:= 0.1
IMAGE_NAME  := $(APP_NAME):$(APP_VER)
DOCKERFILE  := ./docker/Dockerfile.ubuntu
BINDIR		:= bin

GO			:= GO15VENDOREXPERIMENT=1 go

GOFILES		= $(shell find . -type f -name '*.go' -not -path "./vendor/*")
GODIRS		= $(shell $(GO) list -f '{{.Dir}}' ./... | grep -vxFf <($(GO) list -f '{{.Dir}}' ./vendor/...))
GOPKGS		= $(shell $(GO) list ./... | grep -vxFf <($(GO) list ./vendor/...))

# build flags to create a statically linked binary (required for scratch-based image)
BUILDFLAGS	:= -a -installsuffix nocgo -tags netgo

# linker flags to set build info variables
# note #1: -ldflags requires using the symbol name(s) as reported by 'go tool nm <binary object>'. Struct fields are not supported.
# note #2: buildDate is using Golang RFC 3339 time format - version.go relies on this format
BUILD_SYM	:= $(shell $(GO) list -f '{{ .ImportComment }}')/utils/version
LDFLAGS		+= -X $(BUILD_SYM).version=$(APP_VER)
LDFLAGS		+= -X $(BUILD_SYM).gitRevision=$(shell git rev-parse --short HEAD 2> /dev/null  || echo unknown)
LDFLAGS		+= -X $(BUILD_SYM).branch=$(shell git rev-parse --abbrev-ref HEAD 2> /dev/null  || echo unknown)
LDFLAGS		+= -X $(BUILD_SYM).buildUser=$(shell whoami || echo nobody)@$(shell hostname -f || echo builder)
LDFLAGS		+= -X $(BUILD_SYM).buildDate=$(shell date +%Y-%m-%dT%H:%M:%S%:z)
LDFLAGS		+= -X $(BUILD_SYM).goVersion=$(word 3,$(shell $(GO) version))

#--------------
#-- high-level
#--------------
.PHONY: verify precommit

# to be run by CI to verify validity of code changes
verify: check build test
	
# to be run by developer before checking-in code changes
precommit: format verify

#---------
#-- build
#---------
.PHONY: build compile clean

build:
	@echo "--> building executable"
	@$(GO) build $(BUILDFLAGS) -ldflags '$(LDFLAGS)' -o $(BINDIR)/$(APP_NAME)

compile:
	@echo "--> compiling packages"
	@$(GO) build $(GOPKGS)

clean:
	@echo "--> cleaning compiled objects and binaries"
	@$(GO) clean -tags netgo -i $(GOPKGS)
	@rm -rf $(BINDIR)/*

#--------
#-- test
#--------
.PHONY: test test.all

test:
	@echo "--> running unit tests, excluding long tests"
	@$(GO) test -v $(GOPKGS) -short

test.all:
	@echo "--> running unit tests, including long tests"
	@$(GO) test -v $(GOPKGS)

#---------------
#-- checks
#---------------
.PHONY: check format format.check vet lint

check: format.check vet lint

format: tools.goimports
	@echo "--> formatting code with 'goimports' tool"
	@goimports -w -l $(GOFILES)

format.check: tools.goimports
	@echo "--> checking code formatting with 'goimports' tool"
	@goimports -l $(GOFILES) | sed -e "s/^/\?\t/" | tee >(test -z)

vet: tools.govet
	@echo "--> checking code correctness with 'go vet' tool"
	@$(GO) vet $(GOPKGS)

lint: tools.golint
	@echo "--> checking code style with 'golint' tool"
	@echo $(GODIRS) | xargs -n 1 golint

#------------------
#-- dependencies
#------------------
.PHONY: depend.update depend.install

depend.update: tools.glide
	@echo "--> updating dependencies from glide.yaml"
	@glide update --strip-vcs --update-vendored
	
depend.install:	tools.glide
	@echo "--> installing dependencies from glide.lock "
	@glide install --strip-vcs --update-vendored
	
#----------
#-- docker
#----------
.PHONY: docker

docker:
	@echo "--> building docker image"
	@docker build -t $(IMAGE_NAME) -f $(DOCKERFILE) .

#---------------
#-- tools
#---------------
.PHONY: tools tools.goimports tools.golint tools.govet tools.glide

tools: tools.goimports tools.golint tools.govet tools.glide

tools.goimports:
	@command -v goimports >/dev/null ; if [ $$? -ne 0 ]; then \
    	echo "--> installing goimports"; \
    	$(GO) get golang.org/x/tools/cmd/goimports; \
    fi

tools.govet:
	@go tool vet 2>/dev/null ; if [ $$? -eq 3 ]; then \
		echo "--> installing govet"; \
 		$(GO) get golang.org/x/tools/cmd/vet; \
 	fi

tools.golint:
	@command -v golint >/dev/null ; if [ $$? -ne 0 ]; then \
    	echo "--> installing golint"; \
    	$(GO) get github.com/golang/lint/golint; \
    fi
	
tools.glide:
	@command -v glide >/dev/null ; if [ $$? -ne 0 ]; then \
    	echo "--> installing glide"; \
		mkdir -p /tmp/glide-0.10.2-linux-amd64; \
		wget -qO- https://github.com/Masterminds/glide/releases/download/0.10.2/glide-0.10.2-linux-amd64.tar.gz | tar xz -C /tmp/glide-0.10.2-linux-amd64; \
		cp /tmp/glide-0.10.2-linux-amd64/linux-amd64/glide ~/bin; \
    fi
