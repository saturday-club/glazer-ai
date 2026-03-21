# Makefile — Glazer AI
# Convenience targets for the local CI pipeline.

.PHONY: lint test build ci

## Run SwiftLint (strict mode)
lint:
	./scripts/lint.sh

## Run unit tests
test:
	./scripts/test.sh

## Build the app
build:
	./scripts/build.sh

## Run full CI pipeline: lint → test → build
ci:
	./scripts/ci.sh
