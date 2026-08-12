MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts
LIB_DIR       := $(DOTFILES_ROOT)/lib
SHELL         := /usr/bin/env bash

.DEFAULT_GOAL := help

## Makefile
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"

## Dotfiles
.PHONY: install uninstall dryrun-uninstall
install: ## Install dotfiles.
	@$(SCRIPT_DIR)/dotfiles/install.sh
uninstall: ## Uninstall dotfiles.
	@$(SCRIPT_DIR)/dotfiles/uninstall.sh
uninstall-dryrun: ## Show what would be uninstalled without making any changes.
	@$(SCRIPT_DIR)/dotfiles/uninstall.sh --dryrun

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
.PHONY: test lint
test: ## Run the bash library smoke tests.
	@bash $(LIB_DIR)/test/smoke.sh
lint: ## Run shellcheck over the bash library and scripts.
	@shellcheck -s bash $(LIB_DIR)/bash/*.sh $(LIB_DIR)/bash/themes/*.sh \
		$(LIB_DIR)/test/*.sh $(SCRIPT_DIR)/*/*.sh $(DOTFILES_ROOT)/bootstrap.sh
