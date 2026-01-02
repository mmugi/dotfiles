MAKEFILE      := $(firstword $(MAKEFILE_LIST))
DOTFILES_ROOT := $(realpath $(dir $(MAKEFILE)))
SCRIPT_DIR    := $(DOTFILES_ROOT)/scripts

SHELL         = /usr/bin/env bash


.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help message.
	@$(SCRIPT_DIR)/make/help.sh "$(MAKEFILE)"


.PHONY: install uninstall
install: ## Install dotfiles.
	@$(SCRIPT_DIR)/install.sh
uninstall: ## Uninstall dotfiles.
	@$(SCRIPT_DIR)/uninstall.sh
uninstall-dryrun: ## Show what would be uninstalled without making any changes.
	@$(SCRIPT_DIR)/uninstall.sh --dryrun


.PHONY: init init-os
init: ## Run all initial setup tasks.
	@$(SCRIPT_DIR)/init/init.sh --all
init-os: ## Perform the initial setup specific to your operating system.
	@$(SCRIPT_DIR)/init/os.sh


.PHONY: brew-diff brew-dump
brew-diff: ## Run all initial setup tasks.
	@$(SCRIPT_DIR)/brew/brew-diff.sh
brew-dump: ## Perform the initial setup specific to your operating system.
	@$(SCRIPT_DIR)/brew/brew-dump.sh
