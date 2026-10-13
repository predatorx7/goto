.PHONY: all build test clean install uninstall fmt lint

BINARY_NAME=goto-cli
BIN_DIR=./bin
PREFIX?=$(HOME)/.local/bin
GO?=go

# Find go if not in default PATH
ifeq (, $(shell which $(GO) 2>/dev/null))
	ifneq (, $(wildcard /usr/local/go/bin/go))
		GO=/usr/local/go/bin/go
	else ifneq (, $(wildcard /opt/homebrew/bin/go))
		GO=/opt/homebrew/bin/go
	endif
endif

VERSION?=$(shell git describe --tags --exact-match 2>/dev/null || grep -E 'Version\s*=\s*"[^"]+"' internal/version/version.go | sed -E 's/.*"([^"]+)".*/\1/' || echo "0.3.0")
COMMIT?=$(shell git rev-parse --short HEAD 2>/dev/null || echo "")

LDFLAGS=-s -w -X github.com/predatorx7/goto/internal/version.Version=$(VERSION)
ifneq ($(COMMIT),)
	LDFLAGS+=-X github.com/predatorx7/goto/internal/version.GitCommit=$(COMMIT)
endif

all: test build

build:
	@mkdir -p $(BIN_DIR)
	$(GO) build -ldflags "$(LDFLAGS)" -o $(BIN_DIR)/$(BINARY_NAME) ./cmd/goto-cli
	@echo "Build complete: $(BIN_DIR)/$(BINARY_NAME) (v$(VERSION))"

test:
	$(GO) test -v ./...

fmt:
	$(GO) fmt ./...

clean:
	rm -rf $(BIN_DIR)
	@echo "Cleaned build artifacts."

install:
	./install.sh install --prefix $(PREFIX)

uninstall:
	./install.sh uninstall --prefix $(PREFIX)
