.PHONY: all test lint goal-smoke-evals goal-smoke-evals-live install-local help

SHELL := /bin/bash
SHELLCHECK ?= shellcheck

all: lint test

test:
	@echo "Running installer tests..."
	@bash tests/install.sh
	@echo ""
	@echo "Running validation tests..."
	@bash tests/validate.sh

lint:
	@echo "Running shellcheck..."
	@if command -v "$(SHELLCHECK)" >/dev/null 2>&1; then \
		$(SHELLCHECK) install.sh lib/utils.sh tests/install.sh tests/validate.sh scripts/doctor.sh scripts/goal-run-smoke-evals.sh; \
	else \
		echo "$(SHELLCHECK) not found. Skipping lint."; \
		echo "Install from: https://github.com/koalaman/shellcheck"; \
		echo "Or set SHELLCHECK=/path/to/shellcheck"; \
	fi

goal-smoke-evals:
	@bash scripts/goal-run-smoke-evals.sh --dry-run

goal-smoke-evals-live:
	@bash scripts/goal-run-smoke-evals.sh --live

install-local:
	@echo "Installing GeneralPippy locally..."
	@./install.sh

help:
	@echo "Available targets:"
	@echo "  make test          Run the installer test suite"
	@echo "  make lint          Run shellcheck on shell scripts"
	@echo "  make goal-smoke-evals      Preview executable Eval 10/11 smoke runs"
	@echo "  make goal-smoke-evals-live Run live Eval 10/11 smoke runs"
	@echo "  make all           Run lint + test"
	@echo "  make install-local Install GeneralPippy to ~/.config/opencode"
	@echo "  make help          Show this help"
