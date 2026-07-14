MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts
SHELL         := /usr/bin/env bash

.DEFAULT_GOAL := help

## Makefile
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"

## Dotfiles
.PHONY: install
install: ## Install dotfiles.
	@$(SCRIPT_DIR)/install.sh

.PHONY: uninstall dryrun-uninstall
uninstall: ## Uninstall dotfiles.
	@$(SCRIPT_DIR)/uninstall.sh
dryru-uninstall: ## Show what would be uninstalled without making any changes.
	@$(SCRIPT_DIR)/uninstall.sh --dryrun

.PHONY: init init-os
init: ## Run all initial setup tasks.
	@$(SCRIPT_DIR)/init/init.sh --all
init-os: ## Perform the initial setup specific to your operating system.
	@$(SCRIPT_DIR)/init/os.sh

## Git
.PHONY: git-sign
git-sign: ## Configure git commit signing settings.
	@$(SCRIPT_DIR)/git/git-sign.sh

## Homebrew
.PHONY: brew-diff brew-dump
brew-diff: ## Show differences between installed brew package and those in the dotfiles Brewfile.
	@$(SCRIPT_DIR)/brew/brew-diff.sh
brew-dump: ## Write all installed packages into a Brewfile in dotfiles.
	@$(SCRIPT_DIR)/brew/brew-dump.sh
