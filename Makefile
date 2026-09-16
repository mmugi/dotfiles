MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts
LIB_DIR       := $(DOTFILES_ROOT)/lib
TEST_DIR      := $(DOTFILES_ROOT)/test
CONFIG_DIR    := $(DOTFILES_ROOT)/configs
SHELL         := /usr/bin/env bash

# sh 版の配置スクリプトを検証するシェル。存在しないものは飛ばす。
SH_TEST_SHELLS ?= /bin/sh /bin/dash /opt/homebrew/bin/bash

.DEFAULT_GOAL := help

## Makefile
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"

## Git
.PHONY: git-sign git-completion-conf
git-sign: ## Configure git commit signing settings.
	@$(SCRIPT_DIR)/git/git-sign.sh
git-completion-conf: ## Generate git-completion shell config (default bash; TARGET_SHELL to override).
	@$(SCRIPT_DIR)/git/git-completion-conf.sh --shell $(or $(TARGET_SHELL),bash)

## Shell
.PHONY: shell-prompt-conf
shell-prompt-conf: ## Generate shell prompt config (default bash; TARGET_SHELL to override).
	@$(SCRIPT_DIR)/shell/generate-prompt-conf.sh --shell $(or $(TARGET_SHELL),bash)

## Homebrew
.PHONY: brew-diff brew-dump
brew-diff: ## Show differences between installed brew package and those in the dotfiles Brewfile.
	@$(SCRIPT_DIR)/brew/brew-diff.sh
brew-dump: ## Write all installed packages into a Brewfile in dotfiles.
	@$(SCRIPT_DIR)/brew/brew-dump.sh

## Development
.PHONY: test test-sh lint
test: ## Run the bash library smoke tests.
	@bash $(TEST_DIR)/smoke.sh
test-sh: ## Run the sh deployment smoke tests on every available shell.
	@for s in $(SH_TEST_SHELLS); do \
		[ -x "$$s" ] || continue; \
		echo "--- $$s ---"; \
		TEST_SH="$$s" "$$s" $(TEST_DIR)/deploy.sh || exit 1; \
	done
lint: ## Run shellcheck over the libraries, scripts and distributed hooks.
	@shellcheck -s bash $(LIB_DIR)/bash/*.sh $(LIB_DIR)/bash/themes/*.sh \
		$(TEST_DIR)/smoke.sh $(SCRIPT_DIR)/*/*.sh \
		$(CONFIG_DIR)/claude/.claude/hooks/*.sh
	@shellcheck -s dash $(DOTFILES_ROOT)/install.sh $(DOTFILES_ROOT)/uninstall.sh \
		$(LIB_DIR)/shell/*.sh $(TEST_DIR)/deploy.sh
