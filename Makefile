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


.PHONY: init init-os init-git-sign
init: ## Run all initial setup tasks.
	@$(SCRIPT_DIR)/init/init.sh --all
init-os: ## Perform the initial setup specific to your operating system.
	@$(SCRIPT_DIR)/init/os.sh
init-git-sign: ## Initialize all git commit signing settings.
	@$(SCRIPT_DIR)/init/git-sign.sh



.PHONY: brew-diff brew-dump
brew-diff: ## Show differences between installed brew package and those in the dotfiles Brewfile.
	@$(SCRIPT_DIR)/brew/brew-diff.sh
brew-dump: ## Write all installed packages into a Brewfile in dotfiles.
	@$(SCRIPT_DIR)/brew/brew-dump.sh
